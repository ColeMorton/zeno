// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IChapterAchievementNFT} from "./interfaces/IChapterAchievementNFT.sol";
import {ChapterAchievementSVG} from "./ChapterAchievementSVG.sol";

/// @title ChapterAchievementNFT - Soulbound chapter achievement tokens
/// @notice ERC-5192 compliant non-transferable NFT representing chapter achievements
/// @dev Separate from personal journey achievements (AchievementNFT)
contract ChapterAchievementNFT is ERC721, Ownable, IChapterAchievementNFT {
    // ==================== State Variables ====================

    uint256 private _nextTokenId;

    /// @notice Whether to use on-chain SVG (true) or baseURI (false)
    bool public useOnChainSVG;
    string private _baseTokenURI;

    /// @notice Maps tokenId to its achievement type
    mapping(uint256 => bytes32) public achievementType;

    /// @notice Maps tokenId to its chapter
    mapping(uint256 => bytes32) public tokenChapter;

    /// @notice Tracks which achievements a wallet has earned
    mapping(address => mapping(bytes32 => bool)) private _hasAchievement;

    /// @notice Addresses authorized to mint achievements
    mapping(address => bool) public authorizedMinters;

    // ==================== Modifiers ====================

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender]) {
            revert NotAuthorizedMinter(msg.sender);
        }
        _;
    }

    // ==================== Constructor ====================

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        bool useOnChainSVG_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = baseURI_;
        useOnChainSVG = useOnChainSVG_;
    }

    // ==================== Admin Functions ====================

    /// @inheritdoc IChapterAchievementNFT
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /// @inheritdoc IChapterAchievementNFT
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /// @notice Update the base URI for token metadata
    /// @param baseURI_ New base URI
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    /// @notice Toggle between on-chain SVG and external URI
    /// @param useOnChain Whether to use on-chain SVG
    function setUseOnChainSVG(bool useOnChain) external onlyOwner {
        useOnChainSVG = useOnChain;
    }

    // ==================== Core Functions ====================

    /// @inheritdoc IChapterAchievementNFT
    function mint(
        address to,
        bytes32 achievementId,
        bytes32 chapterId
    ) external onlyAuthorizedMinter returns (uint256 tokenId) {
        if (_hasAchievement[to][achievementId]) {
            revert AchievementAlreadyEarned(to, achievementId);
        }

        tokenId = _nextTokenId++;
        achievementType[tokenId] = achievementId;
        tokenChapter[tokenId] = chapterId;
        _hasAchievement[to][achievementId] = true;

        _mint(to, tokenId);

        emit Locked(tokenId);
        emit ChapterAchievementEarned(to, tokenId, achievementId, chapterId);
    }

    // ==================== View Functions ====================

    /// @inheritdoc IChapterAchievementNFT
    function hasAchievement(address wallet, bytes32 achievementId) external view returns (bool earned) {
        return _hasAchievement[wallet][achievementId];
    }

    /// @inheritdoc IChapterAchievementNFT
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    /// @inheritdoc IChapterAchievementNFT
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Override tokenURI to return on-chain SVG if enabled
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        if (useOnChainSVG) {
            bytes32 achType = achievementType[tokenId];
            bytes32 chapId = tokenChapter[tokenId];
            return ChapterAchievementSVG.getSVG(achType, chapId);
        } else {
            return super.tokenURI(tokenId);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // ==================== Soulbound Implementation ====================

    /// @dev Override to prevent transfers (soulbound)
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        // Allow minting (from == address(0)) but prevent transfers
        if (from != address(0) && to != address(0)) {
            revert SoulboundTransferNotAllowed();
        }
        return super._update(to, tokenId, auth);
    }

    /// @notice ERC-165 interface support
    /// @dev Includes ERC-5192 interface ID (0xb45a3c0e)
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        // ERC-5192 interface ID: 0xb45a3c0e
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId);
    }
}
