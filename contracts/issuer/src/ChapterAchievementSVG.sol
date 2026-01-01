// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title ChapterAchievementSVG - On-chain SVG generation for chapter achievements
/// @notice Generates SVG artwork for chapter achievement NFTs
/// @dev Returns data URI with embedded SVG for on-chain rendering
library ChapterAchievementSVG {
    using Strings for uint256;
    using Strings for bytes32;

    /// @notice Generate SVG data URI for a chapter achievement
    /// @param achievementId The achievement type identifier
    /// @param chapterId The chapter the achievement belongs to
    /// @return dataURI The complete data URI with embedded SVG
    function getSVG(bytes32 achievementId, bytes32 chapterId) internal pure returns (string memory) {
        // Extract chapter number from chapterId (first byte after hash)
        // For now, generate a placeholder SVG with the achievement/chapter info

        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
                '<defs>',
                '<linearGradient id="bg" x1="0%" y1="0%" x2="0%" y2="100%">',
                '<stop offset="0%" style="stop-color:#1a1a2e"/>',
                '<stop offset="100%" style="stop-color:#16213e"/>',
                '</linearGradient>',
                '<linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">',
                '<stop offset="0%" style="stop-color:#f5af19"/>',
                '<stop offset="100%" style="stop-color:#f12711"/>',
                '</linearGradient>',
                '</defs>',
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<circle cx="200" cy="150" r="80" fill="none" stroke="url(#gold)" stroke-width="3"/>',
                '<text x="200" y="160" text-anchor="middle" fill="#f5af19" font-size="24" font-family="monospace">CH</text>',
                '<text x="200" y="280" text-anchor="middle" fill="#ffffff" font-size="14" font-family="monospace">CHAPTER ACHIEVEMENT</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#888888" font-size="10" font-family="monospace">The Ascent</text>',
                '</svg>'
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Chapter Achievement",',
                '"description":"A soulbound chapter achievement from The Ascent",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
}
