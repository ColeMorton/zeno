// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VestedBTC} from "./VestedBTC.sol";

/// @title ZenoVault — perpetual BTC income vault
/// @notice Lock any ERC-721 treasure plus BTC collateral for 1129 days, then withdraw
///         1% of remaining active collateral every 30 days, forever. Early exits forfeit
///         collateral linearly to remaining holders via a conserved accumulator index.
///         Immutable: no owner, no admin, no oracle, no fees.
///
/// @dev vBTC is a floating principal strip backed 1:1 by an immunized per-vault reserve.
///      `strip(id, amount)` moves active collateral into the reserve and mints vBTC 1:1 —
///      fractional and repeatable, vested vaults only. Withdrawals draw from active
///      collateral only, so `strippedReserve == vbtc.totalSupply()` holds at all times:
///      par is the on-chain NAV floor. Redemption of the reserve requires recombination
///      (owner burns vBTC) or a fractional dormancy claim — in between, vBTC floats freely
///      and the owner-buyback arbitrage disciplines the discount without a peg. You cannot
///      sell the principal and keep collecting its coupon: stripped collateral earns no
///      withdrawals until recombined.
contract ZenoVault is ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant VESTING_PERIOD = 1129 days;
    uint256 public constant WITHDRAWAL_PERIOD = 30 days;
    uint256 public constant DORMANCY_THRESHOLD = 1129 days;
    uint256 public constant GRACE_PERIOD = 30 days;
    uint256 public constant WITHDRAWAL_RATE_BPS = 100; // 1% per period
    uint256 public constant BPS = 10_000;
    uint256 private constant INDEX_PRECISION = 1e18;
    address public constant BURN_ADDRESS = address(0xdEaD);

    struct Vault {
        address treasure;
        uint256 treasureId;
        uint256 collateral; // active: withdrawable, match-accruing
        uint256 reserve; // immunized: backs vBTC 1:1, untouchable by withdrawals
        uint256 matchIndexSnapshot;
        uint64 mintedAt;
        uint64 lastWithdrawal;
        uint64 lastActivity;
        uint64 pokedAt; // 0 = no pending dormancy poke
    }

    IERC20 public immutable collateralToken;
    VestedBTC public immutable vbtc;

    mapping(uint256 => Vault) public vaults;
    uint256 public nextId = 1;

    /// @dev Sum of settled active collateral across live vaults; denominator for forfeit distribution.
    uint256 public totalActiveCollateral;
    /// @dev Cumulative forfeited-collateral-per-unit-of-active-collateral, scaled by 1e18.
    uint256 public matchIndex;
    /// @dev Aggregate immunized reserve. Invariant: equals vbtc.totalSupply() — the NAV floor.
    uint256 public strippedReserve;

    event Minted(uint256 indexed id, address indexed owner, address treasure, uint256 treasureId, uint256 collateral);
    event Withdrawn(uint256 indexed id, uint256 amount);
    event EarlyRedeemed(uint256 indexed id, uint256 returned, uint256 forfeited);
    event Redeemed(uint256 indexed id, uint256 collateral);
    event MatchSettled(uint256 indexed id, uint256 accrued);
    event Stripped(uint256 indexed id, uint256 amount);
    event Recombined(uint256 indexed id, uint256 amount);
    event DormancyPoked(uint256 indexed id, address indexed poker);
    event ActivityProven(uint256 indexed id);
    event DormantClaimed(uint256 indexed id, address indexed claimer, uint256 amount);

    error NotOwner();
    error ZeroAmount();
    error StillVesting();
    error AlreadyVested();
    error WithdrawalCooldown();
    error InsufficientCollateral();
    error InsufficientReserve();
    error StripOutstanding();
    error NotDormant();
    error GraceNotExpired();
    error NoPendingPoke();
    error AlreadyPoked();

    constructor(IERC20 collateralToken_, string memory vbtcName, string memory vbtcSymbol)
        ERC721("Zeno Vault", "ZVAULT")
    {
        collateralToken = collateralToken_;
        vbtc = new VestedBTC(vbtcName, vbtcSymbol);
    }

    // ---------------------------------------------------------------- lifecycle

    function mint(address treasure, uint256 treasureId, uint256 amount) external nonReentrant returns (uint256 id) {
        if (amount == 0) revert ZeroAmount();
        // Credit the amount actually received, so fee-on-transfer tokens can't over-credit.
        uint256 before = collateralToken.balanceOf(address(this));
        IERC721(treasure).transferFrom(msg.sender, address(this), treasureId);
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        amount = collateralToken.balanceOf(address(this)) - before;
        if (amount == 0) revert ZeroAmount();
        id = nextId++;
        Vault storage v = vaults[id];
        v.treasure = treasure;
        v.treasureId = treasureId;
        v.collateral = amount;
        v.matchIndexSnapshot = matchIndex;
        v.mintedAt = uint64(block.timestamp);
        v.lastActivity = uint64(block.timestamp);
        totalActiveCollateral += amount;
        _safeMint(msg.sender, id);
        emit Minted(id, msg.sender, treasure, treasureId, amount);
    }

    /// @notice Withdraw 1% of remaining active collateral. Vested vaults only, once per 30 days.
    ///         The stripped reserve is immunized: a fully stripped vault withdraws nothing.
    function withdraw(uint256 id) external nonReentrant {
        Vault storage v = _ownedVault(id);
        if (!isVested(id)) revert StillVesting();
        uint256 last = v.lastWithdrawal == 0 ? v.mintedAt + VESTING_PERIOD - WITHDRAWAL_PERIOD : v.lastWithdrawal;
        if (block.timestamp < last + WITHDRAWAL_PERIOD) revert WithdrawalCooldown();
        _settleMatch(id, v);
        uint256 amount = (v.collateral * WITHDRAWAL_RATE_BPS) / BPS;
        if (amount == 0) revert ZeroAmount();
        v.collateral -= amount;
        totalActiveCollateral -= amount;
        v.lastWithdrawal = uint64(block.timestamp);
        _touch(v);
        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(id, amount);
    }

    /// @notice Exit before vesting completes. Returns active collateral pro-rata to time served;
    ///         the remainder is forfeited to all other active vaults. Treasure is burned.
    /// @dev Stripping is vesting-gated and early redemption is pre-vesting, so an early-redeemable
    ///      vault can never carry reserve — the StripOutstanding check is defense in depth.
    function earlyRedeem(uint256 id) external nonReentrant {
        Vault storage v = _ownedVault(id);
        if (isVested(id)) revert AlreadyVested();
        if (v.reserve > 0) revert StripOutstanding();
        _settleMatch(id, v);

        uint256 collateral = v.collateral;
        totalActiveCollateral -= collateral;
        uint256 returned = (collateral * (block.timestamp - v.mintedAt)) / VESTING_PERIOD;
        uint256 forfeited = collateral - returned;
        if (forfeited > 0 && totalActiveCollateral > 0) {
            matchIndex += (forfeited * INDEX_PRECISION) / totalActiveCollateral;
        } else {
            // No remaining holders to reward: last holder exits with full collateral.
            returned = collateral;
            forfeited = 0;
        }

        address treasure = v.treasure;
        uint256 treasureId = v.treasureId;
        delete vaults[id];
        _burn(id);
        IERC721(treasure).transferFrom(address(this), BURN_ADDRESS, treasureId);
        if (returned > 0) collateralToken.safeTransfer(msg.sender, returned);
        emit EarlyRedeemed(id, returned, forfeited);
    }

    /// @notice Redeem a vested vault in full: collateral and treasure return to the owner.
    ///         Requires zero outstanding reserve — recombine (fractionally, at leisure) first.
    function redeem(uint256 id) external nonReentrant {
        Vault storage v = _ownedVault(id);
        if (!isVested(id)) revert StillVesting();
        if (v.reserve > 0) revert StripOutstanding();
        _settleMatch(id, v);

        uint256 collateral = v.collateral;
        totalActiveCollateral -= collateral;
        address treasure = v.treasure;
        uint256 treasureId = v.treasureId;
        delete vaults[id];
        _burn(id);
        IERC721(treasure).transferFrom(address(this), msg.sender, treasureId);
        collateralToken.safeTransfer(msg.sender, collateral);
        emit Redeemed(id, collateral);
    }

    /// @notice Fold accrued match-pool rewards into a vault's active collateral. Callable by anyone.
    function settleMatch(uint256 id) external {
        _requireOwned(id);
        _settleMatch(id, vaults[id]);
    }

    // ---------------------------------------------------------------- stripping

    /// @notice Move active collateral into the immunized reserve, minting vBTC 1:1.
    ///         Vested vaults only — vesting is the time lock and stripping must not provide
    ///         early liquidity against it. Fractional and repeatable once vested. Vault,
    ///         treasure, and withdrawal rights over remaining active collateral are retained.
    function strip(uint256 id, uint256 amount) external nonReentrant {
        Vault storage v = _ownedVault(id);
        if (!isVested(id)) revert StillVesting();
        if (amount == 0) revert ZeroAmount();
        _settleMatch(id, v);
        if (amount > v.collateral) revert InsufficientCollateral();

        v.collateral -= amount;
        totalActiveCollateral -= amount;
        v.reserve += amount;
        strippedReserve += amount;
        _touch(v);
        vbtc.mint(msg.sender, amount);
        emit Stripped(id, amount);
    }

    /// @notice Burn vBTC 1:1 to move reserve back into active collateral. Fractional.
    ///         Any market discount on vBTC makes buy-back-and-recombine profitable — the
    ///         arbitrage that disciplines the float.
    function recombine(uint256 id, uint256 amount) external nonReentrant {
        Vault storage v = _ownedVault(id);
        if (amount == 0) revert ZeroAmount();
        if (amount > v.reserve) revert InsufficientReserve();
        _settleMatch(id, v);

        vbtc.burnFrom(msg.sender, amount);
        v.reserve -= amount;
        strippedReserve -= amount;
        v.collateral += amount;
        totalActiveCollateral += amount;
        _touch(v);
        emit Recombined(id, amount);
    }

    // ---------------------------------------------------------------- dormancy

    /// @notice Flag a vault with outstanding reserve whose owner has been inactive for 1129 days.
    function pokeDormant(uint256 id) external {
        Vault storage v = vaults[id];
        _requireOwned(id);
        if (v.reserve == 0) revert NotDormant();
        if (block.timestamp < v.lastActivity + DORMANCY_THRESHOLD) revert NotDormant();
        // Owner still holding enough vBTC to recombine is not economically abandoned.
        if (vbtc.balanceOf(ownerOf(id)) >= v.reserve) revert NotDormant();
        if (v.pokedAt != 0) revert AlreadyPoked();
        v.pokedAt = uint64(block.timestamp);
        emit DormancyPoked(id, msg.sender);
    }

    /// @notice Owner cancels a pending dormancy poke.
    function proveActivity(uint256 id) external {
        Vault storage v = _ownedVault(id);
        _touch(v);
        emit ActivityProven(id);
    }

    /// @notice After the 30-day grace period, any vBTC holder may burn any amount up to the
    ///         outstanding reserve to claim reserve collateral 1:1 — fractional, repeatable.
    ///         Only the reserve transfers: the vault, its treasure, and its active collateral
    ///         remain with the owner. Reserve at zero ends dormancy eligibility.
    function claimDormant(uint256 id, uint256 amount) external nonReentrant {
        Vault storage v = vaults[id];
        _requireOwned(id);
        if (v.pokedAt == 0) revert NoPendingPoke();
        if (block.timestamp < v.pokedAt + GRACE_PERIOD) revert GraceNotExpired();
        if (amount == 0) revert ZeroAmount();
        if (amount > v.reserve) revert InsufficientReserve();

        vbtc.burnFrom(msg.sender, amount);
        v.reserve -= amount;
        strippedReserve -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit DormantClaimed(id, msg.sender, amount);
    }

    // ---------------------------------------------------------------- views

    function isVested(uint256 id) public view returns (bool) {
        return block.timestamp >= uint256(vaults[id].mintedAt) + VESTING_PERIOD;
    }

    function pendingMatch(uint256 id) public view returns (uint256) {
        Vault storage v = vaults[id];
        return (v.collateral * (matchIndex - v.matchIndexSnapshot)) / INDEX_PRECISION;
    }

    // ---------------------------------------------------------------- internal

    function _settleMatch(uint256 id, Vault storage v) internal {
        uint256 accrued = (v.collateral * (matchIndex - v.matchIndexSnapshot)) / INDEX_PRECISION;
        v.matchIndexSnapshot = matchIndex;
        if (accrued > 0) {
            v.collateral += accrued;
            totalActiveCollateral += accrued;
            emit MatchSettled(id, accrued);
        }
    }

    function _touch(Vault storage v) internal {
        v.lastActivity = uint64(block.timestamp);
        v.pokedAt = 0;
    }

    function _ownedVault(uint256 id) internal view returns (Vault storage) {
        if (ownerOf(id) != msg.sender) revert NotOwner();
        return vaults[id];
    }

    /// @dev Any transfer counts as owner activity.
    function _update(address to, uint256 id, address auth) internal override returns (address) {
        address from = super._update(to, id, auth);
        if (from != address(0) && to != address(0)) _touch(vaults[id]);
        return from;
    }
}
