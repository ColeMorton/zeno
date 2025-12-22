// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IAchievementNFT - Interface for soulbound achievement attestations
/// @notice ERC-5192 compliant non-transferable NFT representing wallet achievements
/// @dev Uses bytes32 identifiers for extensibility without contract redeployment
interface IAchievementNFT is IERC721 {
    /// @notice Mint an achievement to a wallet
    /// @param to Wallet earning the achievement
    /// @param type_ Type of achievement being earned (bytes32 identifier)
    /// @return tokenId The minted token ID
    function mint(address to, bytes32 type_) external returns (uint256 tokenId);

    /// @notice Authorize an address to mint achievements
    /// @param minter Address to authorize
    function authorizeMinter(address minter) external;

    /// @notice Revoke minting authorization
    /// @param minter Address to revoke
    function revokeMinter(address minter) external;

    /// @notice Check if an address is an authorized minter
    /// @param minter Address to check
    /// @return Whether the address is authorized
    function authorizedMinters(address minter) external view returns (bool);

    /// @notice Check if a wallet has a specific achievement
    /// @param wallet Address to check
    /// @param type_ Achievement type to query
    /// @return Whether the wallet has this achievement
    function hasAchievement(address wallet, bytes32 type_) external view returns (bool);

    /// @notice Get the achievement type for a token
    /// @param tokenId Token ID to query
    /// @return The achievement type (bytes32 identifier)
    function achievementType(uint256 tokenId) external view returns (bytes32);

    /// @notice Check if a wallet has a specific achievement (convenience)
    /// @param wallet Address to check
    /// @param type_ Achievement type to query
    /// @return Whether the wallet has this achievement
    function hasAchievementOfType(address wallet, bytes32 type_) external view returns (bool);

    /// @notice ERC-5192: Check if a token is locked (soulbound)
    /// @param tokenId The token to check
    /// @return True (always locked)
    function locked(uint256 tokenId) external view returns (bool);

    /// @notice Get the total number of achievements minted
    /// @return Total supply
    function totalSupply() external view returns (uint256);

    // Achievement type constants
    function MINTER() external view returns (bytes32);
    function MATURED() external view returns (bytes32);
    function HODLER_SUPREME() external view returns (bytes32);
    function FIRST_MONTH() external view returns (bytes32);
    function QUARTER_STACK() external view returns (bytes32);
    function HALF_YEAR() external view returns (bytes32);
    function ANNUAL() external view returns (bytes32);
    function DIAMOND_HANDS() external view returns (bytes32);
}
