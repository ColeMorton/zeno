// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PixelArtRenderer
 * @dev On-chain SVG renderer for pixel art
 * @notice Generates SVG from packed bitmap data
 *
 * Supported formats:
 * - 64×64 16-color: Palette (48B) + Bitmap (2,048B) = 2,096 bytes
 * - 128×128 monochrome: Color (3B) + Bitmap (2,048B) = 2,051 bytes
 * - 256×256 monochrome: Color (3B) + Bitmap (8,192B) = 8,195 bytes
 */
library PixelArtRenderer {
    uint256 private constant SIZE_64 = 64;
    uint256 private constant SIZE_128 = 128;
    uint256 private constant SIZE_256 = 256;

    // SVG header and footer
    bytes private constant SVG_HEADER =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" shape-rendering="crispEdges">';
    bytes private constant SVG_FOOTER = "</svg>";

    // Hex characters for color encoding
    bytes16 private constant HEX_CHARS = "0123456789abcdef";

    /**
     * @notice Render pixel art as SVG string
     * @param palette 48 bytes: 16 RGB colors (index 0 is transparent)
     * @param bitmap 2048 bytes: 64x64 pixels, 4-bit indexed (2 pixels per byte)
     * @return SVG string
     */
    function render(bytes memory palette, bytes memory bitmap) internal pure returns (string memory) {
        require(palette.length == 48, "Invalid palette size");
        require(bitmap.length == 2048, "Invalid bitmap size");

        // Pre-convert palette to hex color strings
        bytes6[16] memory hexColors;
        for (uint256 i = 0; i < 16; i++) {
            uint256 offset = i * 3;
            hexColors[i] = _rgbToHex(uint8(palette[offset]), uint8(palette[offset + 1]), uint8(palette[offset + 2]));
        }

        // Build SVG
        bytes memory svg = abi.encodePacked(SVG_HEADER);

        for (uint256 y = 0; y < SIZE_64; y++) {
            for (uint256 x = 0; x < SIZE_64; x++) {
                uint256 pixelIndex = y * SIZE_64 + x;
                uint256 byteIndex = pixelIndex / 2;
                uint8 byteValue = uint8(bitmap[byteIndex]);

                // High nibble for even pixels, low nibble for odd
                uint8 colorIndex;
                if (pixelIndex % 2 == 0) {
                    colorIndex = byteValue >> 4;
                } else {
                    colorIndex = byteValue & 0x0F;
                }

                // Skip transparent pixels (index 0)
                if (colorIndex == 0) continue;

                // Append rect element
                svg = abi.encodePacked(
                    svg,
                    '<rect x="',
                    _uint8ToString(uint8(x)),
                    '" y="',
                    _uint8ToString(uint8(y)),
                    '" width="1" height="1" fill="#',
                    hexColors[colorIndex],
                    '"/>'
                );
            }
        }

        svg = abi.encodePacked(svg, SVG_FOOTER);

        return string(svg);
    }

    /**
     * @notice Render pixel art as base64-encoded SVG data URI
     * @param palette 48 bytes: 16 RGB colors
     * @param bitmap 2048 bytes: 64x64 pixels
     * @return Data URI string
     */
    function renderDataURI(bytes memory palette, bytes memory bitmap) internal pure returns (string memory) {
        string memory svg = render(palette, bitmap);
        return string(abi.encodePacked("data:image/svg+xml;base64,", _base64Encode(bytes(svg))));
    }

    /**
     * @notice Render 128×128 monochrome pixel art as SVG string
     * @param color 3 bytes: RGB foreground color
     * @param bitmap 2048 bytes: 128x128 pixels, 1-bit (8 pixels per byte, MSB first)
     * @return SVG string
     */
    function render1bit128(bytes3 color, bytes memory bitmap) internal pure returns (string memory) {
        require(bitmap.length == 2048, "Invalid bitmap size");

        bytes6 hexColor = _rgbToHex(uint8(color[0]), uint8(color[1]), uint8(color[2]));

        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" shape-rendering="crispEdges">'
        );

        for (uint256 y = 0; y < SIZE_128; y++) {
            for (uint256 x = 0; x < SIZE_128; x++) {
                uint256 pixelIndex = y * SIZE_128 + x;
                uint256 byteIndex = pixelIndex / 8;
                uint8 bitPosition = uint8(7 - (pixelIndex % 8));

                bool isSet = ((uint8(bitmap[byteIndex]) >> bitPosition) & 0x01) == 1;

                if (!isSet) continue;

                svg = abi.encodePacked(
                    svg,
                    '<rect x="',
                    _uint8ToString(uint8(x)),
                    '" y="',
                    _uint8ToString(uint8(y)),
                    '" width="1" height="1" fill="#',
                    hexColor,
                    '"/>'
                );
            }
        }

        svg = abi.encodePacked(svg, SVG_FOOTER);
        return string(svg);
    }

    /**
     * @notice Render 128×128 monochrome pixel art as base64-encoded SVG data URI
     * @param color 3 bytes: RGB foreground color
     * @param bitmap 2048 bytes: 128x128 pixels, 1-bit
     * @return Data URI string
     */
    function render1bit128DataURI(bytes3 color, bytes memory bitmap) internal pure returns (string memory) {
        string memory svg = render1bit128(color, bitmap);
        return string(abi.encodePacked("data:image/svg+xml;base64,", _base64Encode(bytes(svg))));
    }

    /**
     * @notice Render 256×256 monochrome pixel art as SVG string
     * @param color 3 bytes: RGB foreground color
     * @param bitmap 8192 bytes: 256x256 pixels, 1-bit (8 pixels per byte, MSB first)
     * @return SVG string
     */
    function render1bit256(bytes3 color, bytes memory bitmap) internal pure returns (string memory) {
        require(bitmap.length == 8192, "Invalid bitmap size");

        bytes6 hexColor = _rgbToHex(uint8(color[0]), uint8(color[1]), uint8(color[2]));

        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" shape-rendering="crispEdges">'
        );

        for (uint256 y = 0; y < SIZE_256; y++) {
            for (uint256 x = 0; x < SIZE_256; x++) {
                uint256 pixelIndex = y * SIZE_256 + x;
                uint256 byteIndex = pixelIndex / 8;
                uint8 bitPosition = uint8(7 - (pixelIndex % 8));

                bool isSet = ((uint8(bitmap[byteIndex]) >> bitPosition) & 0x01) == 1;

                if (!isSet) continue;

                svg = abi.encodePacked(
                    svg,
                    '<rect x="',
                    _uint16ToString(uint16(x)),
                    '" y="',
                    _uint16ToString(uint16(y)),
                    '" width="1" height="1" fill="#',
                    hexColor,
                    '"/>'
                );
            }
        }

        svg = abi.encodePacked(svg, SVG_FOOTER);
        return string(svg);
    }

    /**
     * @notice Render 256×256 monochrome pixel art as base64-encoded SVG data URI
     * @param color 3 bytes: RGB foreground color
     * @param bitmap 8192 bytes: 256x256 pixels, 1-bit
     * @return Data URI string
     */
    function render1bit256DataURI(bytes3 color, bytes memory bitmap) internal pure returns (string memory) {
        string memory svg = render1bit256(color, bitmap);
        return string(abi.encodePacked("data:image/svg+xml;base64,", _base64Encode(bytes(svg))));
    }

    /**
     * @dev Convert RGB bytes to 6-character hex string
     */
    function _rgbToHex(uint8 r, uint8 g, uint8 b) private pure returns (bytes6) {
        bytes memory hex6 = new bytes(6);
        hex6[0] = HEX_CHARS[r >> 4];
        hex6[1] = HEX_CHARS[r & 0x0F];
        hex6[2] = HEX_CHARS[g >> 4];
        hex6[3] = HEX_CHARS[g & 0x0F];
        hex6[4] = HEX_CHARS[b >> 4];
        hex6[5] = HEX_CHARS[b & 0x0F];
        return bytes6(hex6);
    }

    /**
     * @dev Convert uint8 to string (0-255)
     */
    function _uint8ToString(uint8 value) private pure returns (bytes memory) {
        if (value == 0) {
            return "0";
        }

        uint8 temp = value;
        uint8 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return buffer;
    }

    /**
     * @dev Convert uint16 to string (0-65535)
     */
    function _uint16ToString(uint16 value) private pure returns (bytes memory) {
        if (value == 0) {
            return "0";
        }

        uint16 temp = value;
        uint8 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return buffer;
    }

    /**
     * @dev Base64 encode bytes
     */
    function _base64Encode(bytes memory data) private pure returns (string memory) {
        bytes memory TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        if (data.length == 0) return "";

        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        bytes memory result = new bytes(encodedLen);

        uint256 i = 0;
        uint256 j = 0;

        while (i < data.length) {
            uint256 a = i < data.length ? uint8(data[i++]) : 0;
            uint256 b = i < data.length ? uint8(data[i++]) : 0;
            uint256 c = i < data.length ? uint8(data[i++]) : 0;

            uint256 triple = (a << 16) | (b << 8) | c;

            result[j++] = TABLE[(triple >> 18) & 0x3F];
            result[j++] = TABLE[(triple >> 12) & 0x3F];
            result[j++] = TABLE[(triple >> 6) & 0x3F];
            result[j++] = TABLE[triple & 0x3F];
        }

        // Add padding
        uint256 mod = data.length % 3;
        if (mod == 1) {
            result[encodedLen - 2] = "=";
            result[encodedLen - 1] = "=";
        } else if (mod == 2) {
            result[encodedLen - 1] = "=";
        }

        return string(result);
    }
}
