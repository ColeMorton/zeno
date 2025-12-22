// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAchievementNFT} from "./IAchievementNFT.sol";
import {ITreasureNFT} from "./ITreasureNFT.sol";

/// @title IAchievementMinter - Interface for achievement verification and minting
/// @notice Verifies protocol state and mints achievement soulbounds
/// @dev Uses bytes32 identifiers for extensibility
interface IAchievementMinter {
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

    error NotVaultOwner(uint256 vaultId, address caller);
    error VaultNotUsingIssuerTreasure(uint256 vaultId, address treasureContract);
    error VaultNotVested(uint256 vaultId);
    error MatchNotClaimed(uint256 vaultId);
    error MissingMinterAchievement(address wallet);
    error MissingMaturedAchievement(address wallet);
    error ZeroCollateral();
    error InvalidDurationAchievement(bytes32 achievementType);
    error DurationNotMet(uint256 vaultId, bytes32 achievementType, uint256 required, uint256 elapsed);

    /// @notice Claim the MINTER achievement
    /// @param vaultId The vault token ID to verify
    function claimMinterAchievement(uint256 vaultId) external;

    /// @notice Claim the MATURED achievement
    /// @param vaultId The vault token ID to verify
    function claimMaturedAchievement(uint256 vaultId) external;

    /// @notice Claim a duration-based achievement
    /// @param vaultId The vault token ID to verify
    /// @param achievementType The duration achievement type to claim
    function claimDurationAchievement(uint256 vaultId, bytes32 achievementType) external;

    /// @notice Mint a Hodler Supreme vault (composite achievement)
    /// @param collateralToken The ERC-20 token to use as collateral
    /// @param collateralAmount Amount of collateral to deposit
    /// @param tier Vault tier (0-4)
    /// @return vaultId The minted vault token ID
    function mintHodlerSupremeVault(
        address collateralToken,
        uint256 collateralAmount,
        uint8 tier
    ) external returns (uint256 vaultId);

    /// @notice Check if a wallet can claim MINTER achievement for a vault
    /// @param wallet Address to check
    /// @param vaultId Vault to verify
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimMinterAchievement(address wallet, uint256 vaultId)
        external
        view
        returns (bool canClaim, string memory reason);

    /// @notice Check if a wallet can claim MATURED achievement for a vault
    /// @param wallet Address to check
    /// @param vaultId Vault to verify
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimMaturedAchievement(address wallet, uint256 vaultId)
        external
        view
        returns (bool canClaim, string memory reason);

    /// @notice Check if a wallet can claim a duration achievement for a vault
    /// @param wallet Address to check
    /// @param vaultId Vault to verify
    /// @param achievementType Duration achievement type
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimDurationAchievement(address wallet, uint256 vaultId, bytes32 achievementType)
        external
        view
        returns (bool canClaim, string memory reason);

    /// @notice Check if a wallet can mint Hodler Supreme vault
    /// @param wallet Address to check
    /// @return canMint Whether the vault can be minted
    /// @return reason Failure reason if cannot mint
    function canMintHodlerSupremeVault(address wallet)
        external
        view
        returns (bool canMint, string memory reason);

    /// @notice Check if an achievement type is a duration achievement
    /// @param achievementType Achievement type to check
    /// @return Whether it's a duration achievement
    function isDurationAchievement(bytes32 achievementType) external view returns (bool);

    /// @notice Get the duration threshold for an achievement type
    /// @param achievementType Achievement type to query
    /// @return Duration in seconds (0 if not a duration achievement)
    function getDurationThreshold(bytes32 achievementType) external view returns (uint256);

    /// @notice Get the achievement NFT contract
    function achievements() external view returns (IAchievementNFT);

    /// @notice Get the treasure NFT contract
    function treasureNFT() external view returns (ITreasureNFT);

    // Achievement type constants
    function MINTER() external view returns (bytes32);
    function MATURED() external view returns (bytes32);
    function HODLER_SUPREME() external view returns (bytes32);
    function FIRST_MONTH() external view returns (bytes32);
    function QUARTER_STACK() external view returns (bytes32);
    function HALF_YEAR() external view returns (bytes32);
    function ANNUAL() external view returns (bytes32);
    function DIAMOND_HANDS() external view returns (bytes32);

    // Duration constants
    function FIRST_MONTH_DURATION() external view returns (uint256);
    function QUARTER_STACK_DURATION() external view returns (uint256);
    function HALF_YEAR_DURATION() external view returns (uint256);
    function ANNUAL_DURATION() external view returns (uint256);
    function DIAMOND_HANDS_DURATION() external view returns (uint256);
    function HODLER_SUPREME_DURATION() external view returns (uint256);
}
