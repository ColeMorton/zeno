// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IVaultNFTDelegation} from "./IVaultNFTDelegation.sol";

/// @title IVaultNFT
/// @notice Main interface for VaultNFT, including dormancy and inheriting delegation concerns
interface IVaultNFT is IERC721, IVaultNFTDelegation {
    /// @notice Tracks the three-phase dormancy lifecycle of a vault.
    /// @dev ACTIVE: Normal state, or dormancy criteria met but vault not yet poked.
    ///      POKE_PENDING: A poke has been recorded; the 30-day grace period is running.
    ///      CLAIMABLE: Grace period expired without owner activity; reserve may be claimed.
    enum DormancyState {
        ACTIVE,
        POKE_PENDING,
        CLAIMABLE
    }

    // ========== Core Vault Events ==========

    /// @notice Emitted when a new vault is minted by depositing a Treasure NFT and collateral.
    /// @param tokenId The newly minted vault token ID.
    /// @param owner The address that minted the vault and received the NFT.
    /// @param treasureContract The ERC-721 contract of the deposited Treasure NFT.
    /// @param treasureTokenId The token ID of the deposited Treasure NFT.
    /// @param collateral The amount of ERC-20 collateral deposited.
    event VaultMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address treasureContract,
        uint256 treasureTokenId,
        uint256 collateral
    );

    /// @notice Emitted when collateral is withdrawn from a vested vault.
    /// @param tokenId The vault token ID.
    /// @param to The address that received the collateral.
    /// @param amount The amount of collateral withdrawn (1.0% of active balance).
    event Withdrawn(uint256 indexed tokenId, address indexed to, uint256 amount);

    /// @notice Emitted when a vault is redeemed before the 1129-day vesting period ends.
    /// @param tokenId The vault token ID that was redeemed.
    /// @param owner The address that initiated the early redemption.
    /// @param returned The amount of collateral returned to the owner.
    /// @param forfeited The amount of collateral forfeited to the match pool.
    event EarlyRedemption(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 returned,
        uint256 forfeited
    );

    /// @notice Emitted when active collateral is stripped into the immunized reserve and vBTC is minted.
    /// @param tokenId The vault token ID.
    /// @param to The address that received the vBTC tokens.
    /// @param amount The amount of collateral moved to reserve and vBTC minted (1:1).
    event Stripped(uint256 indexed tokenId, address indexed to, uint256 amount);

    /// @notice Emitted when vBTC is burned to move reserve back into active collateral.
    /// @param tokenId The vault token ID.
    /// @param from The address that burned the vBTC tokens.
    /// @param amount The amount of vBTC burned and reserve reactivated (1:1).
    event Recombined(uint256 indexed tokenId, address indexed from, uint256 amount);

    /// @notice Emitted when accrued match pool share is settled into a vault's active collateral.
    /// @param tokenId The vault token ID.
    /// @param amount The amount of match pool collateral credited to the vault.
    event MatchClaimed(uint256 indexed tokenId, uint256 amount);

    /// @notice Emitted when forfeited collateral from an early redemption is added to the match pool.
    /// @param amount The amount of collateral added in this forfeiture event.
    /// @param newBalance The updated total match pool balance after the addition.
    event MatchPoolFunded(uint256 amount, uint256 newBalance);

    // ========== Dormancy Events ==========

    /// @notice Emitted when a dormant vault is poked to begin the 30-day grace period.
    /// @param tokenId The vault token ID that was poked.
    /// @param owner The current owner of the vault.
    /// @param poker The address that initiated the poke.
    /// @param graceDeadline The timestamp after which the vault transitions to CLAIMABLE.
    event DormantPoked(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed poker,
        uint256 graceDeadline
    );

    /// @notice Emitted when a vault transitions between dormancy states.
    /// @param tokenId The vault token ID.
    /// @param newState The dormancy state the vault has transitioned into.
    event DormancyStateChanged(uint256 indexed tokenId, DormancyState newState);

    /// @notice Emitted when a vault owner proves activity, resetting the dormancy timer.
    /// @param tokenId The vault token ID.
    /// @param owner The vault owner who proved activity and cleared the pending poke.
    event ActivityProven(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a third party burns vBTC to claim reserve from a dormant vault.
    /// @param tokenId The vault token ID whose reserve was claimed.
    /// @param originalOwner The owner of the dormant vault.
    /// @param claimer The address that burned vBTC and received reserve collateral.
    /// @param amount The amount of vBTC burned and reserve collateral transferred (1:1).
    event DormantCollateralClaimed(
        uint256 indexed tokenId,
        address indexed originalOwner,
        address indexed claimer,
        uint256 amount
    );

    // ========== Core Vault Errors ==========

    /// @notice Thrown when the caller is not the owner of the specified vault token.
    error NotTokenOwner(uint256 tokenId);

    /// @notice Thrown when a withdrawal is attempted before the 1129-day vesting period ends.
    error StillVesting(uint256 tokenId);

    /// @notice Thrown when a withdrawal is attempted before the 30-day cooldown has elapsed.
    /// @param tokenId The vault token ID.
    /// @param nextAllowed The earliest timestamp at which the next withdrawal is permitted.
    error WithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed);

    /// @notice Thrown when a mint is attempted with a zero collateral amount.
    error ZeroCollateral();

    /// @notice Thrown when a strip, recombine, or dormancy claim is attempted with a zero amount.
    error ZeroAmount();

    /// @notice Thrown when a strip amount exceeds the vault's active collateral balance.
    /// @param tokenId The vault token ID.
    /// @param requested The requested strip amount.
    /// @param available The vault's active collateral balance.
    error InsufficientCollateral(uint256 tokenId, uint256 requested, uint256 available);

    /// @notice Thrown when a recombine or dormancy claim amount exceeds the vault's stripped reserve.
    /// @param tokenId The vault token ID.
    /// @param requested The requested amount.
    /// @param available The vault's stripped reserve balance.
    error InsufficientReserve(uint256 tokenId, uint256 requested, uint256 available);

    /// @notice Thrown when the caller's vBTC balance is below the required burn amount.
    /// @param required The vBTC amount required to proceed.
    /// @param available The caller's current vBTC balance.
    error InsufficientBtcToken(uint256 required, uint256 available);

    /// @notice Thrown when early redemption is attempted while stripped reserve is outstanding.
    /// @param tokenId The vault token ID.
    /// @param reserve The outstanding stripped reserve that must be recombined first.
    error StripOutstanding(uint256 tokenId, uint256 reserve);

    /// @notice Thrown when the collateral token address does not match the accepted `collateralToken`.
    error InvalidCollateralToken(address token);

    // ========== Dormancy Errors ==========

    /// @notice Thrown when dormancy eligibility criteria are not satisfied for the vault.
    error NotDormantEligible(uint256 tokenId);

    /// @notice Thrown when a poke is attempted on a vault that already has a pending poke.
    error AlreadyPoked(uint256 tokenId);

    /// @notice Thrown when a dormant reserve claim is attempted before the grace period expires.
    error NotClaimable(uint256 tokenId);


    // ========== Core Vault Functions ==========

    /// @notice Mint a new ERC-998 composable vault by depositing a Treasure NFT and ERC-20 collateral.
    /// @dev Starts the 1129-day vesting lock from the current block timestamp.
    /// @param treasureContract The ERC-721 contract address of the Treasure NFT to wrap.
    /// @param treasureTokenId The token ID of the Treasure NFT to deposit.
    /// @param collateralToken The ERC-20 collateral token address (must match the contract's accepted token).
    /// @param collateralAmount The amount of collateral to deposit (must be > 0).
    /// @return tokenId The newly minted vault token ID.
    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId);

    /// @notice Withdraw 1.0% of the current active collateral balance from a vested vault.
    /// @dev The vault must have completed its 1129-day vesting period and the 30-day cooldown
    /// since the last withdrawal must have elapsed. Withdrawals draw from active collateral only;
    /// the stripped reserve is immunized. Each call resets the 30-day cooldown.
    /// @param tokenId The vault token ID to withdraw from.
    /// @return amount The amount of collateral withdrawn (1.0% of active balance).
    function withdraw(uint256 tokenId) external returns (uint256 amount);

    /// @notice Redeem a vault before vesting completes, forfeiting a pro-rata share to the match pool.
    /// @dev Requires zero outstanding stripped reserve (recombination before redemption).
    /// Returned collateral = active collateral × elapsed / 1129 days. The forfeited remainder
    /// is accrued to the match pool and the Treasure NFT is sent to the burn address.
    /// @param tokenId The vault token ID to redeem.
    /// @return returned The collateral amount returned to the caller.
    /// @return forfeited The collateral amount forfeited to the match pool.
    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited);

    /// @notice Strip active collateral into the immunized reserve, minting vBTC 1:1 to the owner.
    /// @dev Vested vaults only — vesting is the protocol's time lock and stripping must not
    /// provide early liquidity against it. Once vested: any amount up to the active collateral
    /// balance, repeatedly. Reserve collateral is immunized: withdrawals cannot touch it, so every
    /// outstanding vBTC is backed 1:1 by reserve. Redemption of the reserve requires recombination
    /// (owner burns vBTC) or a dormancy claim.
    /// @param tokenId The vault token ID to strip from.
    /// @param amount The amount of active collateral to move to reserve and mint as vBTC.
    function strip(uint256 tokenId, uint256 amount) external;

    /// @notice Burn vBTC to move stripped reserve back into active collateral.
    /// @dev Callable by the vault owner for any amount up to the outstanding reserve. The natural
    /// arbitrage anchor: any market discount on vBTC makes buy-back-and-recombine profitable.
    /// @param tokenId The vault token ID to recombine into.
    /// @param amount The amount of vBTC to burn and reserve to reactivate.
    function recombine(uint256 tokenId, uint256 amount) external;

    /// @notice Settle the vault's accrued match pool share into its active collateral.
    /// @dev Settlement also happens automatically on every collateral-changing operation
    /// (withdraw, strip, recombine, earlyRedeem, delegated withdrawal). Credited collateral
    /// remains inside the vault and is subject to vesting like any other collateral.
    /// @param tokenId The vault token ID to settle.
    /// @return amount The amount of match pool collateral credited to the vault.
    function claimMatch(uint256 tokenId) external returns (uint256 amount);

    // ========== Dormancy Functions ==========

    /// @notice Poke a dormant vault to begin the 30-day grace period before reserve becomes claimable.
    /// @dev Any address may call this if all three dormancy criteria are met: stripped reserve is
    /// outstanding, the owner holds less vBTC than the reserve, and there has been no activity
    /// for at least 1129 days. Records the current timestamp and transitions the vault to POKE_PENDING.
    /// @param tokenId The vault token ID to poke.
    function pokeDormant(uint256 tokenId) external;

    /// @notice Prove owner activity on a vault, resetting the dormancy timer and cancelling any pending poke.
    /// @dev Only the vault owner may call this. Updates the last activity timestamp to now and clears
    /// any recorded poke timestamp, returning the vault to the ACTIVE dormancy state.
    /// @param tokenId The vault token ID to prove activity for.
    function proveActivity(uint256 tokenId) external;

    /// @notice Burn vBTC to claim reserve collateral 1:1 from a dormant vault.
    /// @dev The vault must be in the CLAIMABLE state (poked and grace period elapsed without owner
    /// activity). Fractional: any amount up to the outstanding reserve, repeatedly, by any holder.
    /// The vault itself, its Treasure NFT, and its active collateral are untouched; only the
    /// reserve backing the burned vBTC transfers. Once the reserve reaches zero the vault ceases
    /// to be dormancy-eligible.
    /// @param tokenId The vault token ID to claim from.
    /// @param amount The amount of vBTC to burn and reserve collateral to receive.
    /// @return claimed The amount of reserve collateral transferred to the caller.
    function claimDormantCollateral(uint256 tokenId, uint256 amount)
        external
        returns (uint256 claimed);

    /// @notice Check whether a vault meets dormancy eligibility criteria and determine its current phase.
    /// @dev A vault is eligible when: (1) stripped reserve is outstanding, (2) the owner holds less
    /// vBTC than the reserve, and (3) the vault has been inactive for at least 1129 days. The state
    /// progresses ACTIVE → POKE_PENDING → CLAIMABLE as poke and grace period conditions are met.
    /// @param tokenId The vault token ID to evaluate.
    /// @return eligible True if all three dormancy criteria are satisfied.
    /// @return state The current dormancy phase: ACTIVE, POKE_PENDING, or CLAIMABLE.
    function isDormantEligible(uint256 tokenId)
        external
        view
        returns (bool eligible, DormancyState state);

    // ========== View Functions ==========

    /// @notice Retrieve all stored data for a vault in a single call.
    /// @param tokenId The vault token ID to query.
    /// @return treasureContract The address of the wrapped Treasure NFT contract.
    /// @return treasureTokenId The token ID of the wrapped Treasure NFT.
    /// @return collateralToken The ERC-20 collateral token address.
    /// @return collateralAmount The active collateral balance in the vault.
    /// @return strippedReserve The immunized reserve backing outstanding vBTC.
    /// @return mintTimestamp The block timestamp when the vault was minted (vesting start).
    /// @return lastWithdrawal The timestamp of the last collateral withdrawal (0 if never withdrawn).
    /// @return lastActivity The timestamp of the last recorded owner activity.
    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract,
            uint256 treasureTokenId,
            address collateralToken,
            uint256 collateralAmount,
            uint256 strippedReserve,
            uint256 mintTimestamp,
            uint256 lastWithdrawal,
            uint256 lastActivity
        );

    /// @notice Return whether a vault has completed its 1129-day vesting lock period.
    /// @param tokenId The vault token ID to check.
    /// @return True if 1129 days have elapsed since the mint timestamp, false otherwise.
    function isVested(uint256 tokenId) external view returns (bool);

    /// @notice Calculate the collateral amount currently withdrawable from a vault.
    /// @dev Returns 0 if the vault is not yet vested or the 30-day withdrawal cooldown has not elapsed.
    /// Includes any unsettled match pool share in the base, matching what `withdraw` would pay.
    /// @param tokenId The vault token ID to query.
    /// @return The withdrawable amount (1.0% of active collateral if eligible, otherwise 0).
    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256);

    /// @notice Get the earliest timestamp at which the next withdrawal will be permitted.
    /// @param tokenId The vault token ID to query.
    /// @return The cooldown expiry timestamp (0 if the vault has never had a withdrawal).
    function withdrawalCooldown(uint256 tokenId) external view returns (uint256);

    /// @notice Get the immunized reserve backing outstanding vBTC for a vault.
    /// @param tokenId The vault token ID to query.
    /// @return The stripped reserve balance.
    function strippedReserve(uint256 tokenId) external view returns (uint256);

    /// @notice Get a vault's accrued-but-unsettled match pool share.
    /// @param tokenId The vault token ID to query.
    /// @return The match pool amount that would be credited on the next settlement.
    function pendingMatch(uint256 tokenId) external view returns (uint256);

    /// @notice Get the block timestamp when a vault was minted (vesting start).
    /// @param tokenId The vault token ID to query.
    /// @return The mint timestamp.
    function mintTimestamp(uint256 tokenId) external view returns (uint256);

    /// @notice Total immunized reserve across all vaults.
    /// @dev Invariant: equals the vBTC total supply. This is the on-chain NAV floor: every
    /// outstanding vBTC is backed 1:1 by reserve collateral.
    /// @return The global stripped reserve.
    function totalStrippedReserve() external view returns (uint256);

    /// @notice The ERC-20 collateral token accepted by this vault contract.
    /// @return The immutable collateral token address.
    function collateralToken() external view returns (address);
}
