// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AchievementSVG} from "./AchievementSVG.sol";

/// @title AchievementNFT - Soulbound achievement attestations
/// @notice ERC-5192 compliant non-transferable NFT representing wallet achievements
/// @dev Achievements are earned by verifying on-chain protocol state, not granted as entry tickets
///      Uses bytes32 identifiers for extensibility without contract redeployment
contract AchievementNFT is ERC721, Ownable {
    /// @notice Achievement type constants
    bytes32 public constant MINTER = keccak256("MINTER");
    bytes32 public constant MATURED = keccak256("MATURED");
    bytes32 public constant HODLER_SUPREME = keccak256("HODLER_SUPREME");
    bytes32 public constant FIRST_MONTH = keccak256("FIRST_MONTH");
    bytes32 public constant QUARTER_STACK = keccak256("QUARTER_STACK");
    bytes32 public constant HALF_YEAR = keccak256("HALF_YEAR");
    bytes32 public constant ANNUAL = keccak256("ANNUAL");
    bytes32 public constant DIAMOND_HANDS = keccak256("DIAMOND_HANDS");

    uint256 private _nextTokenId;

    /// @notice Whether to use on-chain SVG (true) or baseURI (false)
    bool public useOnChainSVG;
    string private _baseTokenURI;

    /// @notice Maps tokenId to its achievement type
    mapping(uint256 => bytes32) public achievementType;

    /// @notice Tracks which achievements a wallet has earned
    /// @dev O(1) lookup for achievement eligibility checks
    mapping(address => mapping(bytes32 => bool)) public hasAchievement;

    /// @notice Addresses authorized to mint achievements
    mapping(address => bool) public authorizedMinters;

    event Locked(uint256 indexed tokenId);
    event AchievementEarned(
        address indexed wallet,
        uint256 indexed tokenId,
        bytes32 indexed achievementType
    );
    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);

    error SoulboundTransferNotAllowed();
    error NotAuthorizedMinter(address caller);
    error AchievementAlreadyEarned(address wallet, bytes32 achievementType);

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender]) {
            revert NotAuthorizedMinter(msg.sender);
        }
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        bool useOnChainSVG_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = baseURI_;
        useOnChainSVG = useOnChainSVG_;
    }

    /// @notice Authorize an address to mint achievements
    /// @param minter Address to authorize (typically AchievementMinter contract)
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

    /// @notice Mint an achievement to a wallet
    /// @dev Can only be called by authorized minters (AchievementMinter contract)
    /// @param to Wallet earning the achievement
    /// @param type_ Type of achievement being earned (bytes32 identifier)
    /// @return tokenId The minted token ID
    function mint(address to, bytes32 type_) external onlyAuthorizedMinter returns (uint256 tokenId) {
        if (hasAchievement[to][type_]) {
            revert AchievementAlreadyEarned(to, type_);
        }

        tokenId = _nextTokenId++;
        achievementType[tokenId] = type_;
        hasAchievement[to][type_] = true;

        _mint(to, tokenId);

        emit Locked(tokenId);
        emit AchievementEarned(to, tokenId, type_);
    }

    /// @notice ERC-5192: Check if a token is locked (soulbound)
    /// @dev All tokens are locked - this is a soulbound implementation
    /// @param tokenId The token to check
    /// @return True (always locked)
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    /// @notice Get the total number of achievements minted
    /// @return Total supply
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Check if a wallet has a specific achievement
    /// @param wallet Address to check
    /// @param type_ Achievement type to query
    /// @return Whether the wallet has this achievement
    function hasAchievementOfType(address wallet, bytes32 type_) external view returns (bool) {
        return hasAchievement[wallet][type_];
    }

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

    /// @notice Override tokenURI to return on-chain SVG if enabled
    /// @param tokenId The token ID
    /// @return The token URI (either on-chain SVG or external URI)
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        
        if (useOnChainSVG) {
            bytes32 achType = achievementType[tokenId];
            return AchievementSVG.getSVG(achType);
        } else {
            return super.tokenURI(tokenId);
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

    /// @notice Toggle between on-chain SVG and external URI
    /// @param useOnChain Whether to use on-chain SVG
    function setUseOnChainSVG(bool useOnChain) external onlyOwner {
        useOnChainSVG = useOnChain;
    }

    /// @notice ERC-165 interface support
    /// @dev Includes ERC-5192 interface ID (0xb45a3c0e)
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        // ERC-5192 interface ID: 0xb45a3c0e
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId);
    }
}
