// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TreasureNFT - Issuer-branded NFT for vault storage
/// @notice ERC-721 with issuer-controlled minting
/// @dev Treasure NFTs are stored inside Vault NFTs as the "collectible" component
contract TreasureNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    string private _baseTokenURI;

    mapping(address => bool) public authorizedMinters;

    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);

    error NotAuthorizedMinter(address caller);

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender] && msg.sender != owner()) {
            revert NotAuthorizedMinter(msg.sender);
        }
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = baseURI_;
    }

    /// @notice Authorize an address to mint Treasure NFTs
    /// @param minter Address to authorize
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /// @notice Revoke minting authorization
    /// @param minter Address to revoke
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /// @notice Mint a new Treasure NFT
    /// @param to Recipient address
    /// @return tokenId The minted token ID
    function mint(address to) external onlyAuthorizedMinter returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    /// @notice Mint multiple Treasure NFTs to the same address
    /// @param to Recipient address
    /// @param count Number of tokens to mint
    /// @return tokenIds The minted token IDs
    function mintBatch(address to, uint256 count) external onlyAuthorizedMinter returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _nextTokenId++;
            _mint(to, tokenIds[i]);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Update the base URI for token metadata
    /// @param baseURI_ New base URI
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    /// @notice Get the total number of Treasure NFTs minted
    /// @return Total supply
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }
}
