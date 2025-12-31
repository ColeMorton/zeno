// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MockTreasure is ERC721Enumerable {
    using Strings for uint256;

    uint256 private _nextTokenId;

    constructor() ERC721("Mock Treasure", "MTREASURE") {}

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory tokenIdStr = tokenId.toString();
        string memory json = string(
            abi.encodePacked(
                '{"name":"Climber #',
                tokenIdStr,
                '","description":"The Ascent Achievement - Your journey begins"}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            )
        );
    }

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }

    function mintBatch(address to, uint256 count) external returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _nextTokenId++;
            _mint(to, tokenIds[i]);
        }
        return tokenIds;
    }
}
