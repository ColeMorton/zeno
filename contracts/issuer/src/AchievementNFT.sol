// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementNFT} from "./interfaces/IAchievementNFT.sol";
import {AchievementSVG} from "./AchievementSVG.sol";
import {AchievementTypes} from "./libraries/AchievementTypes.sol";

/// @title AchievementNFT - Unified soulbound achievement tokens
/// @notice ERC-5192 compliant non-transferable NFT for all achievement types
/// @dev Handles both regular (personal journey) and chapter (calendar-based) achievements
///      Regular achievements use chapterId = bytes32(0)
///      Achievement type constants available via AchievementTypes library
contract AchievementNFT is ERC721, Ownable, IAchievementNFT {
    // ==================== State Variables ====================

    uint256 private _nextTokenId;

    /// @notice Whether to use on-chain SVG (true) or baseURI (false)
    bool public useOnChainSVG;
    string private _baseTokenURI;

    /// @notice Maps tokenId to its achievement type
    mapping(uint256 => bytes32) public achievementType;

    /// @notice Maps tokenId to its chapter (bytes32(0) for regular achievements)
    mapping(uint256 => bytes32) public tokenChapter;

    /// @notice Tracks which achievements a wallet has earned
    mapping(address => mapping(bytes32 => bool)) private _hasAchievement;

    /// @notice Tracks how many times a wallet has earned each achievement
    mapping(address => mapping(bytes32 => uint256)) private _achievementCount;

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

    /// @inheritdoc IAchievementNFT
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /// @inheritdoc IAchievementNFT
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /// @notice Update the base URI for token metadata
    /// @param baseURI_ New base URI
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    /// @inheritdoc IAchievementNFT
    function setUseOnChainSVG(bool useOnChain) external onlyOwner {
        useOnChainSVG = useOnChain;
    }

    // ==================== Core Functions ====================

    /// @inheritdoc IAchievementNFT
    function mint(
        address to,
        bytes32 achievementId,
        bytes32 chapterId,
        bool isStackable
    ) external onlyAuthorizedMinter returns (uint256 tokenId) {
        // For non-stackable: revert if already earned
        if (!isStackable && _hasAchievement[to][achievementId]) {
            revert AchievementAlreadyEarned(to, achievementId);
        }

        tokenId = _nextTokenId++;
        achievementType[tokenId] = achievementId;
        tokenChapter[tokenId] = chapterId;

        _hasAchievement[to][achievementId] = true;
        _achievementCount[to][achievementId]++;

        _mint(to, tokenId);

        emit Locked(tokenId);
        emit AchievementEarned(to, tokenId, achievementId, chapterId);
    }

    // ==================== View Functions ====================

    /// @inheritdoc IAchievementNFT
    function hasAchievement(address wallet, bytes32 achievementId) external view returns (bool) {
        return _hasAchievement[wallet][achievementId];
    }

    /// @inheritdoc IAchievementNFT
    function achievementCount(address wallet, bytes32 achievementId) external view returns (uint256) {
        return _achievementCount[wallet][achievementId];
    }

    /// @inheritdoc IAchievementNFT
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    /// @inheritdoc IAchievementNFT
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Override tokenURI to return on-chain SVG if enabled
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        if (useOnChainSVG) {
            bytes32 achType = achievementType[tokenId];
            bytes32 chapId = tokenChapter[tokenId];
            return AchievementSVG.getSVG(achType, chapId);
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
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        // ERC-5192 interface ID: 0xb45a3c0e
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId);
    }
}
