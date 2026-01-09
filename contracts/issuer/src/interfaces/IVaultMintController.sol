// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVaultMintController - Interface for atomic vault minting
/// @notice Mints treasure + vault in a single transaction
interface IVaultMintController {
    /// @notice Emitted when a vault is atomically minted
    event VaultMinted(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 treasureId,
        bytes32 achievementType,
        uint256 collateralAmount
    );

    error ZeroCollateral();
    error ZeroAddress();

    /// @notice Atomically mint treasure with achievement and wrap into vault
    /// @param achievementType The achievement type for the treasure
    /// @param collateralAmount Amount of collateral to deposit
    /// @return vaultId The minted vault token ID
    function mintVault(
        bytes32 achievementType,
        uint256 collateralAmount
    ) external returns (uint256 vaultId);

    /// @notice Get the TreasureNFT address
    function treasureNFT() external view returns (address);

    /// @notice Get the VaultNFT address
    function vaultNFT() external view returns (address);

    /// @notice Get the collateral token address
    function collateralToken() external view returns (address);
}
