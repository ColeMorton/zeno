// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAchievementNFT} from "./interfaces/IAchievementNFT.sol";
import {ITreasureNFT} from "./interfaces/ITreasureNFT.sol";

/// @notice Minimal interface for protocol vault state verification
interface IVaultState {
    function ownerOf(uint256 tokenId) external view returns (address);
    function treasureContract(uint256 tokenId) external view returns (address);
    function mintTimestamp(uint256 tokenId) external view returns (uint256);
    function isVested(uint256 tokenId) external view returns (bool);
    function matchClaimed(uint256 tokenId) external view returns (bool);
    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId);
}

/// @title AchievementMinter - Verifies protocol state and mints achievements
/// @notice Claims achievements by verifying on-chain protocol state
/// @dev Issuer-layer contract with no direct protocol integration
contract AchievementMinter is Ownable {
    using SafeERC20 for IERC20;

    // ==================== Achievement Type Constants ====================

    bytes32 public constant MINTER = keccak256("MINTER");
    bytes32 public constant MATURED = keccak256("MATURED");
    bytes32 public constant HODLER_SUPREME = keccak256("HODLER_SUPREME");
    bytes32 public constant FIRST_MONTH = keccak256("FIRST_MONTH");
    bytes32 public constant QUARTER_STACK = keccak256("QUARTER_STACK");
    bytes32 public constant HALF_YEAR = keccak256("HALF_YEAR");
    bytes32 public constant ANNUAL = keccak256("ANNUAL");
    bytes32 public constant DIAMOND_HANDS = keccak256("DIAMOND_HANDS");

    // ==================== Duration Constants ====================

    uint256 public constant FIRST_MONTH_DURATION = 30 days;
    uint256 public constant QUARTER_STACK_DURATION = 91 days;
    uint256 public constant HALF_YEAR_DURATION = 182 days;
    uint256 public constant ANNUAL_DURATION = 365 days;
    uint256 public constant DIAMOND_HANDS_DURATION = 730 days;
    uint256 public constant HODLER_SUPREME_DURATION = 1129 days;

    // ==================== State Variables ====================

    IAchievementNFT public immutable achievements;
    ITreasureNFT public immutable treasureNFT;
    IVaultState public immutable protocol;

    /// @notice Maps achievement type to required duration (0 = not a duration achievement)
    mapping(bytes32 => uint256) public durationThresholds;

    // ==================== Events ====================

    event MinterAchievementClaimed(address indexed wallet, uint256 indexed vaultId);
    event MaturedAchievementClaimed(address indexed wallet, uint256 indexed vaultId);
    event DurationAchievementClaimed(
        address indexed wallet,
        uint256 indexed vaultId,
        bytes32 indexed achievementType
    );
    event HodlerSupremeVaultMinted(
        address indexed wallet,
        uint256 indexed vaultId,
        uint256 treasureId,
        uint256 collateralAmount
    );

    // ==================== Errors ====================

    error NotVaultOwner(uint256 vaultId, address caller);
    error VaultNotUsingIssuerTreasure(uint256 vaultId, address treasureContract);
    error VaultNotVested(uint256 vaultId);
    error MatchNotClaimed(uint256 vaultId);
    error MissingMinterAchievement(address wallet);
    error MissingMaturedAchievement(address wallet);
    error ZeroCollateral();
    error InvalidDurationAchievement(bytes32 achievementType);
    error DurationNotMet(uint256 vaultId, bytes32 achievementType, uint256 required, uint256 elapsed);

    // ==================== Constructor ====================

    constructor(
        address achievements_,
        address treasureNFT_,
        address protocol_
    ) Ownable(msg.sender) {
        achievements = IAchievementNFT(achievements_);
        treasureNFT = ITreasureNFT(treasureNFT_);
        protocol = IVaultState(protocol_);

        // Initialize duration thresholds
        durationThresholds[FIRST_MONTH] = FIRST_MONTH_DURATION;
        durationThresholds[QUARTER_STACK] = QUARTER_STACK_DURATION;
        durationThresholds[HALF_YEAR] = HALF_YEAR_DURATION;
        durationThresholds[ANNUAL] = ANNUAL_DURATION;
        durationThresholds[DIAMOND_HANDS] = DIAMOND_HANDS_DURATION;
    }

    // ==================== Core Achievement Functions ====================

    /// @notice Claim the MINTER achievement
    /// @dev Verifies caller owns a vault containing issuer's Treasure NFT
    /// @param vaultId The vault token ID to verify
    function claimMinterAchievement(uint256 vaultId) external {
        // 1. Verify caller owns the vault
        if (protocol.ownerOf(vaultId) != msg.sender) {
            revert NotVaultOwner(vaultId, msg.sender);
        }

        // 2. Verify vault contains issuer's treasure
        address vaultTreasure = protocol.treasureContract(vaultId);
        if (vaultTreasure != address(treasureNFT)) {
            revert VaultNotUsingIssuerTreasure(vaultId, vaultTreasure);
        }

        // 3. Mint achievement (AchievementNFT handles duplicate prevention)
        achievements.mint(msg.sender, MINTER);

        emit MinterAchievementClaimed(msg.sender, vaultId);
    }

    /// @notice Claim the MATURED achievement
    /// @dev Verifies vault is vested and match pool has been claimed
    /// @param vaultId The vault token ID to verify
    function claimMaturedAchievement(uint256 vaultId) external {
        // 1. Verify wallet has MINTER achievement
        if (!achievements.hasAchievement(msg.sender, MINTER)) {
            revert MissingMinterAchievement(msg.sender);
        }

        // 2. Verify caller owns the vault
        if (protocol.ownerOf(vaultId) != msg.sender) {
            revert NotVaultOwner(vaultId, msg.sender);
        }

        // 3. Verify vault contains issuer's treasure
        address vaultTreasure = protocol.treasureContract(vaultId);
        if (vaultTreasure != address(treasureNFT)) {
            revert VaultNotUsingIssuerTreasure(vaultId, vaultTreasure);
        }

        // 4. Verify vault is vested
        if (!protocol.isVested(vaultId)) {
            revert VaultNotVested(vaultId);
        }

        // 5. Verify match was claimed
        if (!protocol.matchClaimed(vaultId)) {
            revert MatchNotClaimed(vaultId);
        }

        // 6. Mint achievement (AchievementNFT handles duplicate prevention)
        achievements.mint(msg.sender, MATURED);

        emit MaturedAchievementClaimed(msg.sender, vaultId);
    }

    // ==================== Duration Achievement Functions ====================

    /// @notice Claim a duration-based achievement
    /// @dev Verifies vault has been held for the required duration
    /// @param vaultId The vault token ID to verify
    /// @param achievementType The duration achievement type to claim
    function claimDurationAchievement(uint256 vaultId, bytes32 achievementType) external {
        uint256 threshold = durationThresholds[achievementType];
        if (threshold == 0) {
            revert InvalidDurationAchievement(achievementType);
        }

        // 1. Verify caller owns the vault
        if (protocol.ownerOf(vaultId) != msg.sender) {
            revert NotVaultOwner(vaultId, msg.sender);
        }

        // 2. Verify vault contains issuer's treasure
        address vaultTreasure = protocol.treasureContract(vaultId);
        if (vaultTreasure != address(treasureNFT)) {
            revert VaultNotUsingIssuerTreasure(vaultId, vaultTreasure);
        }

        // 3. Verify duration met
        uint256 elapsed = block.timestamp - protocol.mintTimestamp(vaultId);
        if (elapsed < threshold) {
            revert DurationNotMet(vaultId, achievementType, threshold, elapsed);
        }

        // 4. Mint achievement (AchievementNFT handles duplicate prevention)
        achievements.mint(msg.sender, achievementType);

        emit DurationAchievementClaimed(msg.sender, vaultId, achievementType);
    }

    // ==================== Composite Achievement Functions ====================

    /// @notice Mint a Hodler Supreme vault (composite achievement)
    /// @dev Atomically mints achievement + treasure + vault
    /// @param collateralToken The ERC-20 token to use as collateral
    /// @param collateralAmount Amount of collateral to deposit
    /// @return vaultId The minted vault token ID
    function mintHodlerSupremeVault(
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 vaultId) {
        // 1. Verify MINTER achievement
        if (!achievements.hasAchievement(msg.sender, MINTER)) {
            revert MissingMinterAchievement(msg.sender);
        }

        // 2. Verify MATURED achievement
        if (!achievements.hasAchievement(msg.sender, MATURED)) {
            revert MissingMaturedAchievement(msg.sender);
        }

        if (collateralAmount == 0) {
            revert ZeroCollateral();
        }

        // 3. Mint HODLER_SUPREME achievement
        achievements.mint(msg.sender, HODLER_SUPREME);

        // 4. Mint Hodler Supreme Treasure
        uint256 treasureId = treasureNFT.mint(address(this));

        // 5. Transfer collateral from caller
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // 6. Approve protocol to take treasure and collateral
        IERC721(address(treasureNFT)).approve(address(protocol), treasureId);
        IERC20(collateralToken).approve(address(protocol), collateralAmount);

        // 7. Mint vault on protocol
        vaultId = protocol.mint(
            address(treasureNFT),
            treasureId,
            collateralToken,
            collateralAmount
        );

        // 8. Transfer vault to caller
        IERC721(address(protocol)).transferFrom(address(this), msg.sender, vaultId);

        emit HodlerSupremeVaultMinted(msg.sender, vaultId, treasureId, collateralAmount);
    }

    // ==================== View Functions ====================

    /// @notice Check if a wallet can claim MINTER achievement for a vault
    /// @param wallet Address to check
    /// @param vaultId Vault to verify
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimMinterAchievement(address wallet, uint256 vaultId)
        external
        view
        returns (bool canClaim, string memory reason)
    {
        if (achievements.hasAchievement(wallet, MINTER)) {
            return (false, "Already has MINTER achievement");
        }

        if (protocol.ownerOf(vaultId) != wallet) {
            return (false, "Not vault owner");
        }

        if (protocol.treasureContract(vaultId) != address(treasureNFT)) {
            return (false, "Vault not using issuer treasure");
        }

        return (true, "");
    }

    /// @notice Check if a wallet can claim MATURED achievement for a vault
    /// @param wallet Address to check
    /// @param vaultId Vault to verify
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimMaturedAchievement(address wallet, uint256 vaultId)
        external
        view
        returns (bool canClaim, string memory reason)
    {
        if (!achievements.hasAchievement(wallet, MINTER)) {
            return (false, "Missing MINTER achievement");
        }

        if (achievements.hasAchievement(wallet, MATURED)) {
            return (false, "Already has MATURED achievement");
        }

        if (protocol.ownerOf(vaultId) != wallet) {
            return (false, "Not vault owner");
        }

        if (protocol.treasureContract(vaultId) != address(treasureNFT)) {
            return (false, "Vault not using issuer treasure");
        }

        if (!protocol.isVested(vaultId)) {
            return (false, "Vault not vested");
        }

        if (!protocol.matchClaimed(vaultId)) {
            return (false, "Match not claimed");
        }

        return (true, "");
    }

    /// @notice Check if a wallet can claim a duration achievement for a vault
    /// @param wallet Address to check
    /// @param vaultId Vault to verify
    /// @param achievementType Duration achievement type
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimDurationAchievement(address wallet, uint256 vaultId, bytes32 achievementType)
        external
        view
        returns (bool canClaim, string memory reason)
    {
        uint256 threshold = durationThresholds[achievementType];
        if (threshold == 0) {
            return (false, "Invalid duration achievement");
        }

        if (achievements.hasAchievement(wallet, achievementType)) {
            return (false, "Already has this achievement");
        }

        if (protocol.ownerOf(vaultId) != wallet) {
            return (false, "Not vault owner");
        }

        if (protocol.treasureContract(vaultId) != address(treasureNFT)) {
            return (false, "Vault not using issuer treasure");
        }

        uint256 elapsed = block.timestamp - protocol.mintTimestamp(vaultId);
        if (elapsed < threshold) {
            return (false, "Duration not met");
        }

        return (true, "");
    }

    /// @notice Check if a wallet can mint Hodler Supreme vault
    /// @param wallet Address to check
    /// @return canMint Whether the vault can be minted
    /// @return reason Failure reason if cannot mint
    function canMintHodlerSupremeVault(address wallet)
        external
        view
        returns (bool canMint, string memory reason)
    {
        if (!achievements.hasAchievement(wallet, MINTER)) {
            return (false, "Missing MINTER achievement");
        }

        if (!achievements.hasAchievement(wallet, MATURED)) {
            return (false, "Missing MATURED achievement");
        }

        if (achievements.hasAchievement(wallet, HODLER_SUPREME)) {
            return (false, "Already has HODLER_SUPREME achievement");
        }

        return (true, "");
    }

    /// @notice Check if an achievement type is a duration achievement
    /// @param achievementType Achievement type to check
    /// @return Whether it's a duration achievement
    function isDurationAchievement(bytes32 achievementType) external view returns (bool) {
        return durationThresholds[achievementType] > 0;
    }

    /// @notice Get the duration threshold for an achievement type
    /// @param achievementType Achievement type to query
    /// @return Duration in seconds (0 if not a duration achievement)
    function getDurationThreshold(bytes32 achievementType) external view returns (uint256) {
        return durationThresholds[achievementType];
    }
}
