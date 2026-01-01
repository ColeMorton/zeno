// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @title MockTreasure - Mock TreasureNFT for local development
/// @notice Mints treasure NFTs with achievement types that can be locked into vaults
/// @dev Supports both generic treasures and achievement-linked treasures
contract MockTreasure is ERC721Enumerable {
    using Strings for uint256;

    uint256 private _nextTokenId;

    /// @notice Achievement type for each token (bytes32(0) = generic treasure)
    mapping(uint256 => bytes32) public achievementType;

    constructor() ERC721("Treasure", "TREASURE") {}

    /// @notice Get the achievement name for a given type
    function _achievementTypeName(bytes32 achType) internal pure returns (string memory) {
        if (achType == keccak256("TRAILHEAD")) return "Trailhead";
        if (achType == keccak256("FIRST_STEPS")) return "First Steps";
        if (achType == keccak256("WALLET_WARMED")) return "Wallet Warmed";
        if (achType == keccak256("IDENTIFIED")) return "Identified";
        if (achType == keccak256("STEADY_PACE")) return "Steady Pace";
        if (achType == keccak256("EXPLORER")) return "Explorer";
        if (achType == keccak256("GUIDE")) return "Guide";
        if (achType == keccak256("PREPARED")) return "Prepared";
        if (achType == keccak256("REGULAR")) return "Regular";
        if (achType == keccak256("COMMITTED")) return "Committed";
        if (achType == keccak256("RESOLUTE")) return "Resolute";
        if (achType == keccak256("STUDENT")) return "Student";
        if (achType == keccak256("CHAPTER_COMPLETE")) return "Chapter Complete";
        return "";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        bytes32 achType = achievementType[tokenId];
        string memory name;
        string memory description;

        if (achType == bytes32(0)) {
            // Generic treasure
            name = string(abi.encodePacked("Treasure #", tokenId.toString()));
            description = "A treasure NFT that can be locked into a vault.";
        } else {
            // Achievement-linked treasure
            name = _achievementTypeName(achType);
            description = string(abi.encodePacked("Achievement treasure: ", name));
        }

        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                name,
                '","description":"',
                description,
                '"}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            )
        );
    }

    /// @notice Mint a generic treasure
    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }

    /// @notice Mint a treasure with a specific achievement type
    function mintWithAchievement(address to, bytes32 achievementType_) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        achievementType[tokenId] = achievementType_;
        _mint(to, tokenId);
        return tokenId;
    }

    /// @notice Mint multiple generic treasures
    function mintBatch(address to, uint256 count) external returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _nextTokenId++;
            _mint(to, tokenIds[i]);
        }
        return tokenIds;
    }
}
