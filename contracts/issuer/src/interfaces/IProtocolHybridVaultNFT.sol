// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IProtocolHybridVaultNFT
/// @notice Minimal interface for Protocol HybridVaultNFT used by HybridMintController
/// @dev Only includes the mint function needed by the controller
interface IProtocolHybridVaultNFT is IERC721 {
    /// @notice Mint a new hybrid vault with dual collateral
    /// @param treasureContract Address of the treasure NFT contract
    /// @param treasureTokenId Token ID of the treasure NFT to deposit
    /// @param primaryAmount Amount of primary collateral (cbBTC)
    /// @param secondaryAmount Amount of secondary collateral (LP tokens)
    /// @return tokenId The minted vault token ID
    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        uint256 primaryAmount,
        uint256 secondaryAmount
    ) external returns (uint256 tokenId);
}
