// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVaultNFTDormancy
/// @notice Interface for dormancy management functionality
interface IVaultNFTDormancy {
    enum DormancyState {
        ACTIVE,
        POKE_PENDING,
        CLAIMABLE
    }

    event DormantPoked(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed poker,
        uint256 graceDeadline
    );
    event DormancyStateChanged(uint256 indexed tokenId, DormancyState newState);
    event ActivityProven(uint256 indexed tokenId, address indexed owner);
    event DormantCollateralClaimed(
        uint256 indexed tokenId,
        address indexed originalOwner,
        address indexed claimer,
        uint256 collateralClaimed
    );

    error NotDormantEligible(uint256 tokenId);
    error AlreadyPoked(uint256 tokenId);
    error NotClaimable(uint256 tokenId);

    /// @notice Poke a dormant vault to start grace period
    function pokeDormant(uint256 tokenId) external;

    /// @notice Prove activity to exit dormancy state
    function proveActivity(uint256 tokenId) external;

    /// @notice Claim collateral from a claimable dormant vault
    function claimDormantCollateral(uint256 tokenId) external returns (uint256 collateral);

    /// @notice Check if vault is dormant eligible and its state
    function isDormantEligible(uint256 tokenId)
        external
        view
        returns (bool eligible, DormancyState state);
}
