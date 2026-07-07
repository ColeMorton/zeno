// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {IBtcToken} from "./interfaces/IBtcToken.sol";
import {VaultMath} from "./libraries/VaultMath.sol";

/// @title VaultNFT
/// @notice ERC-998 composable vault that wraps a Treasure NFT and BTC collateral.
/// @dev Implements the BTCNFT Protocol vault lifecycle. Each vault is an ERC-998 composable
/// container: an ERC-721 Treasure NFT and ERC-20 collateral are locked inside the vault token.
///
/// Vesting: All vaults enforce a 1129-day (`VaultMath.VESTING_PERIOD`) lock from mint time.
/// Withdrawals are blocked until this lock expires.
///
/// Perpetual withdrawal: Once vested, the owner may withdraw exactly 1.0% of the current
/// active collateral balance every 30 days. The rate is
/// `VaultMath.WITHDRAWAL_RATE / VaultMath.BASIS_POINTS` = 1000 / 100000 = 1.0%. Each successful
/// withdrawal resets the 30-day cooldown for that vault.
///
/// Stripping: Once vested, the owner may move any amount of active collateral into an immunized
/// reserve, minting vBTC 1:1. Reserve collateral cannot be withdrawn,
/// so outstanding vBTC is always backed 1:1 (`totalStrippedReserve == vBTC totalSupply`).
/// Recombination (`recombine`) burns vBTC to reactivate reserve. Redemption of the reserve is
/// only possible through recombination or a dormancy claim — vBTC floats freely in between.
///
/// Early redemption: Before vesting completes, owners may exit and receive a pro-rata share
/// of active collateral (`elapsed / 1129 days × collateral`), forfeiting the remainder to the
/// match pool. Requires zero outstanding stripped reserve.
///
/// Match pool: Forfeited collateral accrues to all active vaults pro-rata via a global
/// accumulator (`accMatchPerCollateral`). Each vault settles its accrued share into active
/// collateral on every collateral-changing operation or explicitly via `claimMatch`. The
/// accounting is order-independent and conserving: settled shares never exceed the pool.
///
/// Dormancy recovery: If a vault with outstanding reserve has been inactive for 1129 days and
/// its owner holds fewer vBTC than the reserve, any address may poke it. After a 30-day grace
/// period (`VaultMath.GRACE_PERIOD`) any vBTC holder may burn vBTC to claim reserve collateral
/// 1:1, fractionally. The vault, its Treasure NFT, and its active collateral are untouched.
///
/// Delegation: Owners may grant wallet-level (applies to all owned vaults) or vault-specific
/// withdrawal permissions to third-party delegates, each capped at `FULL_BPS` (10000 = 100%).
contract VaultNFT is ERC721, IVaultNFT {
    using SafeERC20 for IERC20;

    /// @notice Address used to burn Treasure NFTs during early redemption
    address public constant BURN_ADDRESS = address(0xdead);
    /// @notice Full 100% expressed in basis points (10_000 BPS = 100%)
    uint256 public constant FULL_BPS = 10000;
    /// @notice Fixed-point precision for the match pool accumulator
    uint256 private constant ACC_PRECISION = 1e18;

    /// @notice Counter for the next vault token ID to mint
    uint256 private _nextTokenId;

    /// @notice The vBTC token contract (vestedBTC ERC-20)
    IBtcToken public immutable btcToken;
    /// @notice The accepted ERC-20 collateral token address
    address public immutable collateralToken;

    /// @notice Mapping from vault token ID to the wrapped Treasure NFT contract address
    mapping(uint256 => address) private _treasureContract;
    /// @notice Mapping from vault token ID to the wrapped Treasure NFT token ID
    mapping(uint256 => uint256) private _treasureTokenId;
    /// @notice Mapping from vault token ID to the active (withdrawable) collateral balance
    mapping(uint256 => uint256) private _collateralAmount;
    /// @notice Mapping from vault token ID to the immunized reserve backing outstanding vBTC
    mapping(uint256 => uint256) private _strippedReserve;
    /// @notice Mapping from vault token ID to the block timestamp when the vault was minted
    mapping(uint256 => uint256) private _mintTimestamp;
    /// @notice Mapping from vault token ID to the timestamp of the last collateral withdrawal
    mapping(uint256 => uint256) private _lastWithdrawal;
    /// @notice Mapping from vault token ID to the timestamp of the last owner activity
    mapping(uint256 => uint256) private _lastActivity;
    /// @notice Mapping from vault token ID to the timestamp when a dormancy poke was initiated
    mapping(uint256 => uint256) private _pokeTimestamp;
    /// @notice Mapping from vault token ID to the accumulator value at its last match settlement
    mapping(uint256 => uint256) private _matchDebt;

    // ========== Wallet-Level Withdrawal Delegation State ==========

    /// @notice Wallet-level delegate permissions: owner => delegate => permission
    mapping(address => mapping(address => WalletDelegatePermission)) public walletDelegates;
    /// @notice Total delegated basis points per wallet owner
    mapping(address => uint256) public walletTotalDelegatedBPS;
    /// @notice Delegation epoch per wallet owner; incremented by `revokeAllWithdrawalDelegates`
    mapping(address => uint256) public walletDelegationEpoch;
    /// @notice Delegate cooldown timestamps: delegate => tokenId => last withdrawal time
    mapping(address => mapping(uint256 => uint256)) public delegateVaultCooldown;

    // ========== Vault-Level Withdrawal Delegation State ==========

    /// @notice Vault-specific delegate permissions: tokenId => delegate => permission
    mapping(uint256 => mapping(address => VaultDelegatePermission)) public vaultDelegates;
    /// @notice Total delegated basis points per vault token ID
    mapping(uint256 => uint256) public vaultTotalDelegatedBPS;

    // ========== Match Pool State ==========

    /// @notice Forfeited collateral not yet settled into vaults
    uint256 public matchPool;
    /// @notice Total active collateral across all vaults (settled values; excludes reserves)
    uint256 public totalActiveCollateral;
    /// @notice Total immunized reserve across all vaults; equals vBTC total supply
    uint256 public totalStrippedReserve;
    /// @notice Global accumulator: match pool collateral accrued per unit of active collateral,
    /// scaled by `ACC_PRECISION`
    uint256 public accMatchPerCollateral;
    /// @notice Forfeitures that occurred while no active collateral existed, carried to the next accrual
    uint256 private _matchCarry;

    /// @notice Deploy the VaultNFT contract and set immutable token references
    /// @param _btcToken Address of the vBTC token contract
    /// @param _collateralToken Address of the accepted collateral ERC-20 token
    /// @param _name ERC-721 token name
    /// @param _symbol ERC-721 token symbol
    constructor(
        address _btcToken,
        address _collateralToken,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        if (_btcToken == address(0)) revert ZeroAddress();
        if (_collateralToken == address(0)) revert ZeroAddress();
        btcToken = IBtcToken(_btcToken);
        collateralToken = _collateralToken;
    }

    /// @notice Mint a new Vault NFT by depositing a Treasure NFT and collateral
    /// @dev Transfers the Treasure NFT and collateral from the caller into the vault.
    /// @param treasureContract_ The ERC-721 contract address of the Treasure NFT to wrap
    /// @param treasureTokenId_ The token ID of the Treasure NFT to wrap
    /// @param collateralToken_ The ERC-20 collateral token address (must match `collateralToken`)
    /// @param collateralAmount_ The amount of collateral to deposit (must be > 0)
    /// @return tokenId The newly minted vault token ID
    function mint(
        address treasureContract_,
        uint256 treasureTokenId_,
        address collateralToken_,
        uint256 collateralAmount_
    ) external returns (uint256 tokenId) {
        if (collateralToken_ != collateralToken) {
            revert InvalidCollateralToken(collateralToken_);
        }
        if (collateralAmount_ == 0) revert ZeroCollateral();

        IERC721(treasureContract_).transferFrom(msg.sender, address(this), treasureTokenId_);
        IERC20(collateralToken_).safeTransferFrom(msg.sender, address(this), collateralAmount_);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        _treasureContract[tokenId] = treasureContract_;
        _treasureTokenId[tokenId] = treasureTokenId_;
        _collateralAmount[tokenId] = collateralAmount_;
        _mintTimestamp[tokenId] = block.timestamp;
        _lastActivity[tokenId] = block.timestamp;
        _matchDebt[tokenId] = accMatchPerCollateral;

        totalActiveCollateral += collateralAmount_;

        emit VaultMinted(
            tokenId,
            msg.sender,
            treasureContract_,
            treasureTokenId_,
            collateralAmount_
        );
    }

    /// @notice Withdraw collateral from a vested vault after the withdrawal cooldown
    /// @dev Withdrawals are rate-limited to 1.0% of the current active collateral balance per
    /// 30-day period. The stripped reserve is immunized and cannot be withdrawn. The vault's
    /// accrued match share is settled first, so the 1.0% applies to the settled balance.
    /// @param tokenId The vault token ID to withdraw from
    /// @return amount The amount of collateral withdrawn
    function withdraw(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (!VaultMath.canWithdraw(_lastWithdrawal[tokenId], block.timestamp)) {
            revert WithdrawalTooSoon(tokenId, _lastWithdrawal[tokenId] + VaultMath.WITHDRAWAL_PERIOD);
        }

        _settleMatch(tokenId);

        amount = VaultMath.calculateWithdrawal(_collateralAmount[tokenId]);
        if (amount == 0) return 0;

        _collateralAmount[tokenId] -= amount;
        totalActiveCollateral -= amount;
        _lastWithdrawal[tokenId] = block.timestamp;
        _updateActivity(tokenId);

        IERC20(collateralToken).safeTransfer(msg.sender, amount);

        emit Withdrawn(tokenId, msg.sender, amount);
    }

    /// @notice Redeem a vault early, forfeiting a portion of collateral based on elapsed vesting time
    /// @dev Requires zero outstanding stripped reserve — recombination before redemption.
    /// Active collateral is split linearly with elapsed vesting time:
    ///   returned  = collateral × elapsed / VaultMath.VESTING_PERIOD (1129 days)
    ///   forfeited = collateral − returned
    /// The vault's accrued match share is settled first, so it participates in the split; the
    /// forfeited portion accrues to the match pool for remaining vaults. The Treasure NFT is
    /// transferred to `BURN_ADDRESS` and the vault token is burned.
    /// @param tokenId The vault token ID to redeem
    /// @return returned The amount of collateral returned to the caller
    /// @return forfeited The amount of collateral forfeited to the match pool
    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (_strippedReserve[tokenId] > 0) {
            revert StripOutstanding(tokenId, _strippedReserve[tokenId]);
        }

        _settleMatch(tokenId);

        uint256 collateral = _collateralAmount[tokenId];
        (returned, forfeited) = VaultMath.calculateEarlyRedemption(
            collateral,
            _mintTimestamp[tokenId],
            block.timestamp
        );

        totalActiveCollateral -= collateral;

        if (forfeited > 0) {
            _accrueMatch(forfeited);
        }

        address treasureContract_ = _treasureContract[tokenId];
        uint256 treasureTokenId_ = _treasureTokenId[tokenId];

        IERC721(treasureContract_).transferFrom(address(this), BURN_ADDRESS, treasureTokenId_);

        _clearVaultState(tokenId);
        _burn(tokenId);

        if (returned > 0) {
            IERC20(collateralToken).safeTransfer(msg.sender, returned);
        }

        emit EarlyRedemption(tokenId, msg.sender, returned, forfeited);
    }

    /// @notice Strip active collateral into the immunized reserve, minting vBTC 1:1
    /// @dev Vested vaults only — vesting is the protocol's time lock and stripping must not
    /// provide early liquidity against it. Once vested: any amount up to the active collateral
    /// balance, repeatedly. Reserve collateral cannot be withdrawn, keeping every outstanding
    /// vBTC backed 1:1.
    /// @param tokenId The vault token ID to strip from
    /// @param amount The amount of active collateral to move to reserve and mint as vBTC
    function strip(uint256 tokenId, uint256 amount) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (amount == 0) revert ZeroAmount();

        _settleMatch(tokenId);

        uint256 active = _collateralAmount[tokenId];
        if (amount > active) revert InsufficientCollateral(tokenId, amount, active);

        _collateralAmount[tokenId] = active - amount;
        totalActiveCollateral -= amount;
        _strippedReserve[tokenId] += amount;
        totalStrippedReserve += amount;
        _updateActivity(tokenId);

        btcToken.mint(msg.sender, amount);

        emit Stripped(tokenId, msg.sender, amount);
    }

    /// @notice Burn vBTC to move stripped reserve back into active collateral
    /// @dev Callable by the vault owner for any amount up to the outstanding reserve. Any market
    /// discount on vBTC makes buy-back-and-recombine profitable — the arbitrage loop that
    /// disciplines the vBTC float without a peg.
    /// @param tokenId The vault token ID to recombine into
    /// @param amount The amount of vBTC to burn and reserve to reactivate
    function recombine(uint256 tokenId, uint256 amount) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (amount == 0) revert ZeroAmount();

        uint256 reserve = _strippedReserve[tokenId];
        if (amount > reserve) revert InsufficientReserve(tokenId, amount, reserve);

        uint256 available = btcToken.balanceOf(msg.sender);
        if (available < amount) revert InsufficientBtcToken(amount, available);

        _settleMatch(tokenId);

        btcToken.burnFrom(msg.sender, amount);

        _strippedReserve[tokenId] = reserve - amount;
        totalStrippedReserve -= amount;
        _collateralAmount[tokenId] += amount;
        totalActiveCollateral += amount;
        _updateActivity(tokenId);

        emit Recombined(tokenId, msg.sender, amount);
    }

    /// @notice Settle the vault's accrued match pool share into its active collateral
    /// @dev Settlement also happens automatically on every collateral-changing operation.
    /// Credited collateral remains inside the vault and vests like any other collateral,
    /// so settlement needs no vesting gate.
    /// @param tokenId The vault token ID to settle
    /// @return amount The amount of match pool collateral credited to the vault
    function claimMatch(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

        amount = _settleMatch(tokenId);
        _updateActivity(tokenId);
    }

    /// @notice Poke a dormant vault to initiate the 30-day grace period before reserve becomes claimable
    /// @dev Dormancy eligibility requires all three conditions:
    ///   1. Stripped reserve is outstanding (`_strippedReserve[tokenId] > 0`).
    ///   2. The vault owner currently holds fewer vBTC than the reserve.
    ///   3. No vault activity has been recorded for >= 1129 days (`VaultMath.DORMANCY_THRESHOLD`).
    /// The poke records `block.timestamp` in `_pokeTimestamp[tokenId]` and starts the 30-day grace
    /// period (`VaultMath.GRACE_PERIOD`). During this window the vault owner can call `proveActivity`
    /// to cancel the dormancy claim. Any address may poke a dormant vault.
    /// @param tokenId The vault token ID to poke
    function pokeDormant(uint256 tokenId) external {
        _requireOwned(tokenId);
        (bool eligible, DormancyState state) = isDormantEligible(tokenId);
        if (!eligible) revert NotDormantEligible(tokenId);
        if (state != DormancyState.ACTIVE) revert AlreadyPoked(tokenId);

        _pokeTimestamp[tokenId] = block.timestamp;

        emit DormantPoked(
            tokenId,
            ownerOf(tokenId),
            msg.sender,
            block.timestamp + VaultMath.GRACE_PERIOD
        );
        emit DormancyStateChanged(tokenId, DormancyState.POKE_PENDING);
    }

    /// @notice Prove activity on a vault to reset dormancy timers and clear any pending poke
    /// @dev Only the vault owner may call this. Updates `_lastActivity` to the current block
    /// timestamp and resets `_pokeTimestamp` if a poke was pending.
    /// @param tokenId The vault token ID to prove activity for
    function proveActivity(uint256 tokenId) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

        _updateActivity(tokenId);

        emit ActivityProven(tokenId, msg.sender);
    }

    /// @notice Burn vBTC to claim reserve collateral 1:1 from a dormant vault
    /// @dev The vault must be in `DormancyState.CLAIMABLE` (poke recorded and the 30-day grace
    /// period elapsed without the owner proving activity). Fractional and permissionless: any
    /// vBTC holder may burn any amount up to the outstanding reserve, repeatedly. Only reserve
    /// collateral transfers — the vault token, its Treasure NFT, and its active collateral remain
    /// with the owner. Once the reserve reaches zero the vault is no longer dormancy-eligible.
    /// @param tokenId The vault token ID to claim from
    /// @param amount The amount of vBTC to burn and reserve collateral to receive
    /// @return claimed The amount of reserve collateral transferred to the caller
    function claimDormantCollateral(uint256 tokenId, uint256 amount)
        external
        returns (uint256 claimed)
    {
        _requireOwned(tokenId);
        (, DormancyState state) = isDormantEligible(tokenId);
        if (state != DormancyState.CLAIMABLE) revert NotClaimable(tokenId);
        if (amount == 0) revert ZeroAmount();

        uint256 reserve = _strippedReserve[tokenId];
        if (amount > reserve) revert InsufficientReserve(tokenId, amount, reserve);

        uint256 available = btcToken.balanceOf(msg.sender);
        if (available < amount) revert InsufficientBtcToken(amount, available);

        btcToken.burnFrom(msg.sender, amount);

        _strippedReserve[tokenId] = reserve - amount;
        totalStrippedReserve -= amount;
        claimed = amount;

        IERC20(collateralToken).safeTransfer(msg.sender, amount);

        emit DormantCollateralClaimed(tokenId, ownerOf(tokenId), msg.sender, amount);
    }

    /// @notice Check whether a vault is eligible for dormancy processing and determine its current state
    /// @dev A vault is eligible when: (1) stripped reserve is outstanding, (2) the owner holds less
    /// vBTC than the reserve, and (3) there has been no activity for 1129 days. The state progresses
    /// from ACTIVE -> POKE_PENDING (after poke) -> CLAIMABLE (after 30-day grace period).
    /// @param tokenId The vault token ID to check
    /// @return eligible Whether the vault meets dormancy eligibility criteria
    /// @return state The current dormancy state of the vault
    function isDormantEligible(uint256 tokenId)
        public
        view
        returns (bool eligible, DormancyState state)
    {
        _requireOwned(tokenId);

        uint256 reserve = _strippedReserve[tokenId];
        if (reserve == 0) {
            return (false, DormancyState.ACTIVE);
        }

        address owner_ = ownerOf(tokenId);
        if (btcToken.balanceOf(owner_) >= reserve) {
            return (false, DormancyState.ACTIVE);
        }

        if (!VaultMath.isDormant(_lastActivity[tokenId], block.timestamp)) {
            return (false, DormancyState.ACTIVE);
        }

        eligible = true;

        if (_pokeTimestamp[tokenId] == 0) {
            state = DormancyState.ACTIVE;
        } else if (VaultMath.isGracePeriodExpired(_pokeTimestamp[tokenId], block.timestamp)) {
            state = DormancyState.CLAIMABLE;
        } else {
            state = DormancyState.POKE_PENDING;
        }
    }

    // ========== View Functions ==========

    /// @notice Retrieve comprehensive information about a vault
    /// @param tokenId The vault token ID to query
    /// @return treasureContract_ The address of the wrapped Treasure NFT contract
    /// @return treasureTokenId_ The token ID of the wrapped Treasure NFT
    /// @return collateralToken_ The address of the collateral token
    /// @return collateralAmount_ The active collateral balance in the vault
    /// @return strippedReserve_ The immunized reserve backing outstanding vBTC
    /// @return mintTimestamp_ The timestamp when the vault was minted
    /// @return lastWithdrawal_ The timestamp of the last withdrawal
    /// @return lastActivity_ The timestamp of the last recorded activity
    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract_,
            uint256 treasureTokenId_,
            address collateralToken_,
            uint256 collateralAmount_,
            uint256 strippedReserve_,
            uint256 mintTimestamp_,
            uint256 lastWithdrawal_,
            uint256 lastActivity_
        )
    {
        _requireOwned(tokenId);
        return (
            _treasureContract[tokenId],
            _treasureTokenId[tokenId],
            collateralToken,
            _collateralAmount[tokenId],
            _strippedReserve[tokenId],
            _mintTimestamp[tokenId],
            _lastWithdrawal[tokenId],
            _lastActivity[tokenId]
        );
    }

    /// @notice Check whether a vault has completed its 1129-day vesting period
    /// @param tokenId The vault token ID to check
    /// @return True if the vault is vested, false otherwise
    function isVested(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp);
    }

    /// @notice Calculate the amount of collateral currently withdrawable from a vault
    /// @dev Returns 0 if the vault is not yet vested or the 30-day withdrawal cooldown has not
    /// elapsed. Includes the unsettled match share in the base, matching what `withdraw` pays.
    /// @param tokenId The vault token ID to query
    /// @return The withdrawable collateral amount (1.0% of settled active balance per period)
    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return 0;
        }
        if (!VaultMath.canWithdraw(_lastWithdrawal[tokenId], block.timestamp)) {
            return 0;
        }
        return VaultMath.calculateWithdrawal(_collateralAmount[tokenId] + _pendingMatch(tokenId));
    }

    /// @notice Get the Treasure NFT contract address wrapped in a vault
    /// @param tokenId The vault token ID to query
    /// @return The Treasure NFT contract address
    function treasureContract(uint256 tokenId) external view returns (address) {
        _requireOwned(tokenId);
        return _treasureContract[tokenId];
    }

    /// @notice Get the active collateral amount in a vault
    /// @param tokenId The vault token ID to query
    /// @return The active collateral balance
    function collateralAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _collateralAmount[tokenId];
    }

    /// @notice Get the immunized reserve backing outstanding vBTC for a vault
    /// @param tokenId The vault token ID to query
    /// @return The stripped reserve balance
    function strippedReserve(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _strippedReserve[tokenId];
    }

    /// @notice Get a vault's accrued-but-unsettled match pool share
    /// @param tokenId The vault token ID to query
    /// @return The match pool amount that would be credited on the next settlement
    function pendingMatch(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _pendingMatch(tokenId);
    }

    /// @notice Get the timestamp when a vault was minted
    /// @param tokenId The vault token ID to query
    /// @return The mint timestamp
    function mintTimestamp(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _mintTimestamp[tokenId];
    }

    /// @notice Get the timestamp of the last withdrawal from a vault
    /// @param tokenId The vault token ID to query
    /// @return The last withdrawal timestamp (0 if never withdrawn)
    function lastWithdrawal(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _lastWithdrawal[tokenId];
    }

    /// @notice Get the timestamp when the next withdrawal will be permitted
    /// @param tokenId The vault token ID to query
    /// @return The cooldown timestamp (0 if no prior withdrawal)
    function withdrawalCooldown(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        uint256 lastWithdrawal_ = _lastWithdrawal[tokenId];
        if (lastWithdrawal_ == 0) {
            return 0;
        }
        return lastWithdrawal_ + VaultMath.WITHDRAWAL_PERIOD;
    }

    /// @notice Get the timestamp of the last activity on a vault
    /// @param tokenId The vault token ID to query
    /// @return The last activity timestamp
    function lastActivity(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _lastActivity[tokenId];
    }

    // ========== Match Pool Internal Functions ==========

    /// @notice Accrue forfeited collateral to all active vaults pro-rata
    /// @dev Increments the global accumulator by `amount / totalActiveCollateral`. If no active
    /// collateral exists, the amount is carried until the next accrual with active collateral.
    /// @param amount The forfeited collateral amount to accrue
    function _accrueMatch(uint256 amount) internal {
        matchPool += amount;

        uint256 distributable = amount + _matchCarry;
        if (totalActiveCollateral == 0) {
            _matchCarry = distributable;
        } else {
            _matchCarry = 0;
            accMatchPerCollateral += (distributable * ACC_PRECISION) / totalActiveCollateral;
        }

        emit MatchPoolFunded(amount, matchPool);
    }

    /// @notice Settle a vault's accrued match share into its active collateral
    /// @dev Order-independent reward-debt accounting: the vault's weight is its active collateral,
    /// constant between settlements because every collateral change settles first. The sum of all
    /// settlements over any accumulator interval never exceeds the amount accrued over it.
    /// @param tokenId The vault token ID to settle
    /// @return pending The amount credited to the vault's active collateral
    function _settleMatch(uint256 tokenId) internal returns (uint256 pending) {
        uint256 acc = accMatchPerCollateral;
        uint256 debt = _matchDebt[tokenId];
        if (acc == debt) return 0;

        pending = (_collateralAmount[tokenId] * (acc - debt)) / ACC_PRECISION;
        _matchDebt[tokenId] = acc;
        if (pending == 0) return 0;

        matchPool -= pending;
        _collateralAmount[tokenId] += pending;
        totalActiveCollateral += pending;

        emit MatchClaimed(tokenId, pending);
    }

    /// @notice Compute a vault's unsettled match share without mutating state
    /// @param tokenId The vault token ID to query
    /// @return The pending match amount
    function _pendingMatch(uint256 tokenId) internal view returns (uint256) {
        return (_collateralAmount[tokenId] * (accMatchPerCollateral - _matchDebt[tokenId]))
            / ACC_PRECISION;
    }

    // ========== Vault Lifecycle Internal Functions ==========

    /// @notice Update the last activity timestamp for a vault and reset any pending dormancy poke
    /// @dev Internal function called after state-mutating operations to keep the vault active.
    /// Emits `DormancyStateChanged` if a poke was pending and is now cleared.
    /// @param tokenId The vault token ID to update
    function _updateActivity(uint256 tokenId) internal {
        _lastActivity[tokenId] = block.timestamp;
        if (_pokeTimestamp[tokenId] != 0) {
            _pokeTimestamp[tokenId] = 0;
            emit DormancyStateChanged(tokenId, DormancyState.ACTIVE);
        }
    }

    /// @notice Clear all state associated with a vault token ID
    /// @dev Internal function called during early redemption to reset vault mappings before
    /// burning the token.
    /// @param tokenId The vault token ID to clear
    function _clearVaultState(uint256 tokenId) internal {
        delete _treasureContract[tokenId];
        delete _treasureTokenId[tokenId];
        delete _collateralAmount[tokenId];
        delete _strippedReserve[tokenId];
        delete _mintTimestamp[tokenId];
        delete _lastWithdrawal[tokenId];
        delete _lastActivity[tokenId];
        delete _pokeTimestamp[tokenId];
        delete _matchDebt[tokenId];
    }

    // ========== Wallet-Level Withdrawal Delegation Functions ==========

    /// @notice Grant a wallet-level withdrawal delegation to a delegate address
    /// @dev The delegate will be able to withdraw from any vault owned by `msg.sender`
    /// according to the specified percentage. Total delegated percentage cannot exceed 100%.
    /// Permissions granted before the last `revokeAllWithdrawalDelegates` (older epoch) are inert
    /// and treated as fresh grants here.
    /// @param delegate The address to grant withdrawal delegation to
    /// @param percentageBPS The percentage of each withdrawal the delegate may claim, in basis points (100 = 1%)
    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external {
        if (delegate == address(0)) revert ZeroAddress();
        if (delegate == msg.sender) revert CannotDelegateSelf();
        if (percentageBPS == 0 || percentageBPS > FULL_BPS) revert InvalidPercentage(percentageBPS);

        uint256 epoch = walletDelegationEpoch[msg.sender];
        uint256 currentDelegated = walletTotalDelegatedBPS[msg.sender];
        WalletDelegatePermission storage existingPermission = walletDelegates[msg.sender][delegate];
        bool isUpdate = existingPermission.active && existingPermission.epoch == epoch;
        uint256 oldPercentageBPS = existingPermission.percentageBPS;

        if (isUpdate) {
            currentDelegated -= oldPercentageBPS;
        }
        if (currentDelegated + percentageBPS > FULL_BPS) revert ExceedsDelegationLimit();

        walletDelegates[msg.sender][delegate] = WalletDelegatePermission({
            percentageBPS: percentageBPS,
            epoch: epoch,
            active: true
        });

        walletTotalDelegatedBPS[msg.sender] = currentDelegated + percentageBPS;

        if (isUpdate) {
            emit WalletDelegateUpdated(msg.sender, delegate, oldPercentageBPS, percentageBPS);
        } else {
            emit WalletDelegateGranted(msg.sender, delegate, percentageBPS);
        }
    }

    /// @notice Revoke a specific wallet-level delegate's withdrawal permission
    /// @param delegate The address of the delegate to revoke
    function revokeWithdrawalDelegate(address delegate) external {
        WalletDelegatePermission storage permission = walletDelegates[msg.sender][delegate];
        if (!permission.active || permission.epoch != walletDelegationEpoch[msg.sender]) {
            revert DelegateNotActive(msg.sender, delegate);
        }

        walletTotalDelegatedBPS[msg.sender] -= permission.percentageBPS;
        permission.active = false;

        emit WalletDelegateRevoked(msg.sender, delegate);
    }

    /// @notice Revoke all wallet-level withdrawal delegates for the caller
    /// @dev Increments the caller's delegation epoch, invalidating every existing wallet-level
    /// permission, and resets `walletTotalDelegatedBPS` to zero. Fresh grants start clean.
    function revokeAllWithdrawalDelegates() external {
        walletDelegationEpoch[msg.sender]++;
        walletTotalDelegatedBPS[msg.sender] = 0;
        emit AllWalletDelegatesRevoked(msg.sender);
    }

    // ========== Vault-Level Delegation Functions ==========

    /// @notice Grant a vault-specific withdrawal delegation to a delegate address
    /// @dev Vault-specific delegations take precedence over wallet-level delegations.
    /// An optional expiry can be set; pass 0 for `durationSeconds` for no expiry.
    /// @param tokenId The vault token ID to grant delegation for
    /// @param delegate The address to grant withdrawal delegation to
    /// @param percentageBPS The percentage of each withdrawal the delegate may claim, in basis points (100 = 1%)
    /// @param durationSeconds The delegation duration in seconds (0 for no expiry)
    function grantVaultDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS,
        uint256 durationSeconds
    ) external {
        if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);
        if (delegate == address(0)) revert ZeroAddress();
        if (delegate == msg.sender) revert CannotDelegateSelf();
        if (percentageBPS == 0 || percentageBPS > FULL_BPS) revert InvalidPercentage(percentageBPS);

        uint256 currentVaultDelegated = vaultTotalDelegatedBPS[tokenId];
        VaultDelegatePermission storage existing = vaultDelegates[tokenId][delegate];
        bool isUpdate = existing.active;
        uint256 oldPercentageBPS = existing.percentageBPS;

        if (isUpdate) {
            currentVaultDelegated -= oldPercentageBPS;
        }
        if (currentVaultDelegated + percentageBPS > FULL_BPS) revert ExceedsVaultDelegationLimit(tokenId);

        uint256 expiresAt = durationSeconds > 0 ? block.timestamp + durationSeconds : 0;
        vaultDelegates[tokenId][delegate] = VaultDelegatePermission({
            percentageBPS: percentageBPS,
            expiresAt: expiresAt,
            active: true
        });
        vaultTotalDelegatedBPS[tokenId] = currentVaultDelegated + percentageBPS;

        if (isUpdate) {
            emit VaultDelegateUpdated(tokenId, delegate, oldPercentageBPS, percentageBPS, expiresAt);
        } else {
            emit VaultDelegateGranted(tokenId, delegate, percentageBPS, expiresAt);
        }
    }

    /// @notice Revoke a vault-specific delegate's withdrawal permission
    /// @param tokenId The vault token ID to revoke delegation from
    /// @param delegate The address of the delegate to revoke
    function revokeVaultDelegate(uint256 tokenId, address delegate) external {
        if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);

        VaultDelegatePermission storage permission = vaultDelegates[tokenId][delegate];
        if (!permission.active) revert VaultDelegateNotActive(tokenId, delegate);

        vaultTotalDelegatedBPS[tokenId] -= permission.percentageBPS;
        permission.active = false;

        emit VaultDelegateRevoked(tokenId, delegate);
    }

    /// @notice Withdraw collateral from a vault as an authorized delegate
    /// @dev Vault-specific delegations take precedence over wallet-level delegations.
    /// The delegate's share is calculated as `percentageBPS / FULL_BPS` of the 1.0% withdrawal pool.
    /// @param tokenId The vault token ID to withdraw from
    /// @return withdrawnAmount The amount of collateral transferred to the delegate
    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
        _requireOwned(tokenId);
        address vaultOwner = ownerOf(tokenId);

        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }

        // Resolution: Vault-specific takes precedence over wallet-level
        uint256 effectivePercentageBPS;

        VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][msg.sender];
        if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
            // Vault-specific permission active and not expired
            effectivePercentageBPS = vaultPerm.percentageBPS;
        } else {
            // Fall back to wallet-level
            WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][msg.sender];
            if (!walletPerm.active || walletPerm.epoch != walletDelegationEpoch[vaultOwner]) {
                revert NotActiveDelegate(tokenId, msg.sender);
            }
            effectivePercentageBPS = walletPerm.percentageBPS;
        }

        uint256 delegateLastWithdrawal = delegateVaultCooldown[msg.sender][tokenId];
        if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
            revert WithdrawalPeriodNotMet(tokenId, msg.sender);
        }

        _settleMatch(tokenId);

        uint256 currentCollateral = _collateralAmount[tokenId];
        uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
        withdrawnAmount = (totalPool * effectivePercentageBPS) / FULL_BPS;

        if (withdrawnAmount == 0) return 0;

        _collateralAmount[tokenId] = currentCollateral - withdrawnAmount;
        totalActiveCollateral -= withdrawnAmount;
        delegateVaultCooldown[msg.sender][tokenId] = block.timestamp;
        _updateActivity(tokenId);

        IERC20(collateralToken).safeTransfer(msg.sender, withdrawnAmount);

        emit DelegatedWithdrawal(tokenId, msg.sender, vaultOwner, withdrawnAmount);

        return withdrawnAmount;
    }

    /// @notice Check whether a delegate can withdraw from a vault and compute the withdrawable amount
    /// @param tokenId The vault token ID to check
    /// @param delegate The delegate address to check
    /// @return canWithdraw Whether the delegate is permitted to withdraw now
    /// @return amount The amount the delegate would receive
    /// @return delegationType The type of delegation in effect (None, WalletLevel, or VaultSpecific)
    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount, DelegationType delegationType)
    {
        address vaultOwner;
        try this.ownerOf(tokenId) returns (address owner_) {
            vaultOwner = owner_;
        } catch {
            return (false, 0, DelegationType.None);
        }

        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return (false, 0, DelegationType.None);
        }

        // Resolution with type reporting
        uint256 effectivePercentageBPS;
        DelegationType dtype;

        VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][delegate];
        if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
            effectivePercentageBPS = vaultPerm.percentageBPS;
            dtype = DelegationType.VaultSpecific;
        } else {
            WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][delegate];
            if (!walletPerm.active || walletPerm.epoch != walletDelegationEpoch[vaultOwner]) {
                return (false, 0, DelegationType.None);
            }
            effectivePercentageBPS = walletPerm.percentageBPS;
            dtype = DelegationType.WalletLevel;
        }

        uint256 delegateLastWithdrawal = delegateVaultCooldown[delegate][tokenId];
        if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
            return (false, 0, dtype);
        }

        uint256 currentCollateral = _collateralAmount[tokenId] + _pendingMatch(tokenId);
        uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
        amount = (totalPool * effectivePercentageBPS) / FULL_BPS;

        return (amount > 0, amount, dtype);
    }

    /// @notice Get the wallet-level delegation permission for a specific owner-delegate pair
    /// @param owner The wallet owner address
    /// @param delegate The delegate address
    /// @return The wallet-level delegate permission struct
    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory)
    {
        return walletDelegates[owner][delegate];
    }

    /// @notice Get the last withdrawal timestamp for a delegate on a specific vault
    /// @param delegate The delegate address
    /// @param tokenId The vault token ID
    /// @return The timestamp of the delegate's last withdrawal (0 if never withdrawn)
    function getDelegateCooldown(address delegate, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return delegateVaultCooldown[delegate][tokenId];
    }

    /// @notice Get the effective delegation for a vault-delegate pair, resolving precedence
    /// @dev Vault-specific delegations take precedence over wallet-level delegations.
    /// Returns expiry information for vault-specific permissions.
    /// @param tokenId The vault token ID
    /// @param delegate The delegate address
    /// @return percentageBPS The effective delegated percentage in basis points
    /// @return dtype The type of effective delegation
    /// @return isExpired Whether a vault-specific delegation has expired
    function getEffectiveDelegation(uint256 tokenId, address delegate)
        external
        view
        returns (uint256 percentageBPS, DelegationType dtype, bool isExpired)
    {
        VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][delegate];

        // Check vault-specific first
        if (vaultPerm.active) {
            bool expired = vaultPerm.expiresAt > 0 && block.timestamp > vaultPerm.expiresAt;
            // Return vault-specific info even if expired (for visibility)
            return (vaultPerm.percentageBPS, DelegationType.VaultSpecific, expired);
        }

        // Fall back to wallet-level
        address vaultOwner;
        try this.ownerOf(tokenId) returns (address owner_) {
            vaultOwner = owner_;
        } catch {
            return (0, DelegationType.None, false);
        }

        WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][delegate];
        if (walletPerm.active && walletPerm.epoch == walletDelegationEpoch[vaultOwner]) {
            return (walletPerm.percentageBPS, DelegationType.WalletLevel, false);
        }

        return (0, DelegationType.None, false);
    }

    /// @notice ERC-721 hook called on mint, transfer, and burn
    /// @dev Overrides OpenZeppelin's `_update` to track activity on transfers.
    /// Only updates activity for actual transfers (not mints or burns).
    /// @param to The recipient address
    /// @param tokenId The token ID being transferred
    /// @param auth The address initiating the transfer
    /// @return from The previous owner address
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from != address(0) && to != address(0)) {
            _updateActivity(tokenId);
        }
        return from;
    }
}
