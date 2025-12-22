// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ITreasureNFT - Interface for issuer-branded treasure NFTs
/// @notice ERC-721 with issuer-controlled minting for vault storage
interface ITreasureNFT is IERC721 {
    /// @notice Mint a new Treasure NFT
    /// @param to Recipient address
    /// @return tokenId The minted token ID
    function mint(address to) external returns (uint256 tokenId);

    /// @notice Mint multiple Treasure NFTs to the same address
    /// @param to Recipient address
    /// @param count Number of tokens to mint
    /// @return tokenIds The minted token IDs
    function mintBatch(address to, uint256 count) external returns (uint256[] memory tokenIds);

    /// @notice Authorize an address to mint Treasure NFTs
    /// @param minter Address to authorize
    function authorizeMinter(address minter) external;

    /// @notice Revoke minting authorization
    /// @param minter Address to revoke
    function revokeMinter(address minter) external;

    /// @notice Check if an address is an authorized minter
    /// @param minter Address to check
    /// @return Whether the address is authorized
    function authorizedMinters(address minter) external view returns (bool);

    /// @notice Get total supply of Treasure NFTs
    /// @return Total number of Treasure NFTs minted
    function totalSupply() external view returns (uint256);
}
