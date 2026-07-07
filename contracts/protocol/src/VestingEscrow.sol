// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {IRedeemHook} from "./interfaces/IRedeemHook.sol";
import {VaultMath} from "./libraries/VaultMath.sol";

/// @title VestingEscrow
/// @notice Escrows a secondary ERC-20 leg against a VaultNFT, released 100% at vesting.
/// @dev Composes a dual-collateral product from the single vault primitive: the vault holds the
/// primary leg (1% monthly perpetual withdrawal), this escrow holds the secondary leg keyed to
/// the same vault token and the same vesting clock (the vault's mint timestamp, copied at
/// deposit). Claim rights follow vault ownership. Early exit is atomic: the escrow is bound as
/// the vault's redeem hook, so `VaultNFT.earlyRedeem` settles both legs in one transaction with
/// the same pro-rata forfeiture curve. Forfeited escrow accrues to remaining escrow positions
/// pro-rata via an order-independent accumulator, mirroring the vault's match pool.
contract VestingEscrow is IRedeemHook {
    using SafeERC20 for IERC20;

    /// @notice Fixed-point precision for the match pool accumulator
    uint256 private constant ACC_PRECISION = 1e18;

    /// @notice The vault contract this escrow composes with
    IVaultNFT public immutable vault;
    /// @notice The escrowed ERC-20 token
    IERC20 public immutable token;

    /// @notice Escrowed amount per vault token ID
    mapping(uint256 => uint256) public escrowAmount;
    /// @notice Vault mint timestamp copied at deposit; survives vault burn
    mapping(uint256 => uint256) public mintTimestamp;
    /// @notice Accumulator value at each position's last match settlement
    mapping(uint256 => uint256) private _matchDebt;

    /// @notice Forfeited escrow not yet settled into positions
    uint256 public matchPool;
    /// @notice Total escrowed amount across all positions (settled values)
    uint256 public totalEscrowed;
    /// @notice Global accumulator: forfeited escrow accrued per unit escrowed, scaled by `ACC_PRECISION`
    uint256 public accMatchPerEscrowed;
    /// @notice Forfeitures that occurred while nothing was escrowed, carried to the next accrual
    uint256 private _matchCarry;

    /// @notice Emitted when a secondary leg is escrowed against a vault
    event Deposited(uint256 indexed tokenId, address indexed depositor, uint256 amount);
    /// @notice Emitted when a vested position is claimed by the vault owner
    event Claimed(uint256 indexed tokenId, address indexed owner, uint256 amount);
    /// @notice Emitted when a position is settled during the vault's early redemption
    event EarlyRedeemed(
        uint256 indexed tokenId,
        address indexed redeemer,
        uint256 returned,
        uint256 forfeited
    );
    /// @notice Emitted when accrued match pool share is settled into a position
    event MatchClaimed(uint256 indexed tokenId, uint256 amount);
    /// @notice Emitted when forfeited escrow is added to the match pool
    event MatchPoolFunded(uint256 amount, uint256 newBalance);

    /// @notice Thrown when a constructor address argument is zero
    error ZeroAddress();
    /// @notice Thrown when a deposit amount is zero
    error ZeroAmount();
    /// @notice Thrown when depositing to a vault that already has an escrowed position
    error AlreadyDeposited(uint256 tokenId);
    /// @notice Thrown when the vault's redeem hook is not bound to this escrow
    error HookNotBound(uint256 tokenId);
    /// @notice Thrown when the caller is not the vault owner
    error NotVaultOwner(uint256 tokenId);
    /// @notice Thrown when claiming before the vault's vesting period has elapsed
    error StillVesting(uint256 tokenId);
    /// @notice Thrown when there is no escrowed position for the vault
    error NothingEscrowed(uint256 tokenId);
    /// @notice Thrown when the caller is not the vault contract
    error NotVault();

    constructor(address vault_, address token_) {
        if (vault_ == address(0)) revert ZeroAddress();
        if (token_ == address(0)) revert ZeroAddress();
        vault = IVaultNFT(vault_);
        token = IERC20(token_);
    }

    /// @notice Escrow the secondary leg against a vault token
    /// @dev One position per vault. Requires the vault's redeem hook to already be bound to this
    /// escrow so early exit is guaranteed atomic — deposits without the binding would strand on
    /// vault burn. Copies the vault's mint timestamp as the position's vesting clock.
    /// @param tokenId The vault token ID to escrow against
    /// @param amount The token amount to escrow (must be > 0)
    function deposit(uint256 tokenId, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (escrowAmount[tokenId] != 0) revert AlreadyDeposited(tokenId);
        if (vault.redeemHook(tokenId) != address(this)) revert HookNotBound(tokenId);

        token.safeTransferFrom(msg.sender, address(this), amount);

        escrowAmount[tokenId] = amount;
        mintTimestamp[tokenId] = vault.mintTimestamp(tokenId);
        _matchDebt[tokenId] = accMatchPerEscrowed;
        totalEscrowed += amount;

        emit Deposited(tokenId, msg.sender, amount);
    }

    /// @notice Claim the full escrowed amount after the vault's vesting period
    /// @dev Claim rights follow vault ownership. Settles the position's accrued match share first.
    /// @param tokenId The vault token ID whose position to claim
    /// @return amount The token amount transferred to the owner
    function claim(uint256 tokenId) external returns (uint256 amount) {
        if (vault.ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);
        if (escrowAmount[tokenId] == 0) revert NothingEscrowed(tokenId);
        if (!VaultMath.isVested(mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }

        _settleMatch(tokenId);

        amount = escrowAmount[tokenId];
        totalEscrowed -= amount;
        _clearPosition(tokenId);

        token.safeTransfer(msg.sender, amount);

        emit Claimed(tokenId, msg.sender, amount);
    }

    /// @inheritdoc IRedeemHook
    /// @dev Called by the vault at the end of `earlyRedeem`. Applies the same pro-rata forfeiture
    /// curve as the vault's primary leg; the forfeited remainder accrues to remaining positions.
    function onEarlyRedeem(uint256 tokenId, address redeemer) external {
        if (msg.sender != address(vault)) revert NotVault();

        if (escrowAmount[tokenId] == 0) return;

        _settleMatch(tokenId);

        uint256 amount = escrowAmount[tokenId];
        (uint256 returned, uint256 forfeited) = VaultMath.calculateEarlyRedemption(
            amount,
            mintTimestamp[tokenId],
            block.timestamp
        );

        totalEscrowed -= amount;
        _clearPosition(tokenId);

        if (forfeited > 0) {
            _accrueMatch(forfeited);
        }
        if (returned > 0) {
            token.safeTransfer(redeemer, returned);
        }

        emit EarlyRedeemed(tokenId, redeemer, returned, forfeited);
    }

    /// @notice Settle a position's accrued match pool share into its escrowed amount
    /// @param tokenId The vault token ID whose position to settle
    /// @return amount The amount credited to the position
    function claimMatch(uint256 tokenId) external returns (uint256 amount) {
        if (vault.ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);
        if (escrowAmount[tokenId] == 0) revert NothingEscrowed(tokenId);

        amount = _settleMatch(tokenId);
    }

    /// @notice Get a position's accrued-but-unsettled match pool share
    /// @param tokenId The vault token ID to query
    /// @return The match pool amount that would be credited on the next settlement
    function pendingMatch(uint256 tokenId) external view returns (uint256) {
        return _pendingMatch(tokenId);
    }

    /// @notice Get the amount claimable now: full position (plus pending match) once vested, else 0
    /// @param tokenId The vault token ID to query
    /// @return The claimable token amount
    function claimable(uint256 tokenId) external view returns (uint256) {
        if (escrowAmount[tokenId] == 0) return 0;
        if (!VaultMath.isVested(mintTimestamp[tokenId], block.timestamp)) return 0;
        return escrowAmount[tokenId] + _pendingMatch(tokenId);
    }

    /// @notice Accrue forfeited escrow to all positions pro-rata
    function _accrueMatch(uint256 amount) internal {
        matchPool += amount;

        uint256 distributable = amount + _matchCarry;
        if (totalEscrowed == 0) {
            _matchCarry = distributable;
        } else {
            _matchCarry = 0;
            accMatchPerEscrowed += (distributable * ACC_PRECISION) / totalEscrowed;
        }

        emit MatchPoolFunded(amount, matchPool);
    }

    /// @notice Settle a position's accrued match share into its escrowed amount
    function _settleMatch(uint256 tokenId) internal returns (uint256 pending) {
        uint256 acc = accMatchPerEscrowed;
        uint256 debt = _matchDebt[tokenId];
        if (acc == debt) return 0;

        pending = (escrowAmount[tokenId] * (acc - debt)) / ACC_PRECISION;
        _matchDebt[tokenId] = acc;
        if (pending == 0) return 0;

        matchPool -= pending;
        escrowAmount[tokenId] += pending;
        totalEscrowed += pending;

        emit MatchClaimed(tokenId, pending);
    }

    /// @notice Compute a position's unsettled match share without mutating state
    function _pendingMatch(uint256 tokenId) internal view returns (uint256) {
        return (escrowAmount[tokenId] * (accMatchPerEscrowed - _matchDebt[tokenId]))
            / ACC_PRECISION;
    }

    /// @notice Clear all state for a position
    function _clearPosition(uint256 tokenId) internal {
        delete escrowAmount[tokenId];
        delete mintTimestamp[tokenId];
        delete _matchDebt[tokenId];
    }
}
