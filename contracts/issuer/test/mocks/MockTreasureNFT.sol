// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Minimal mock for testing issuer contracts
contract MockTreasureNFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("Mock Treasure", "MTRSR") {}

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    function mintBatch(address to, uint256 count) external returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _nextTokenId++;
            _mint(to, tokenIds[i]);
        }
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }
}
