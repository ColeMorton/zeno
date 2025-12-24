// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PixelArtRenderer} from "../../src/PixelArtRenderer.sol";
import {Internal4PixelArt} from "../../src/Internal4PixelArt.sol";
import {HandsDiamond128Mono} from "../../src/HandsDiamond128Mono.sol";
import {HandsDiamond256Mono} from "../../src/HandsDiamond256Mono.sol";

contract PixelArtRendererTest is Test {
    function test_RenderInternal4() public view {
        string memory svg = Internal4PixelArt.getSVG();

        // Check SVG starts correctly
        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        assertTrue(_startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "Should start with SVG tag");
        assertTrue(_endsWith(svg, "</svg>"), "Should end with closing SVG tag");

        // Log SVG length for gas estimation
        console.log("SVG length:", bytes(svg).length);
    }

    function test_RenderWithPalette() public pure {
        // Test with a simple 2x2 pattern
        bytes memory palette = new bytes(48);
        // Color 1 = red (FF0000)
        palette[3] = 0xFF;
        palette[4] = 0x00;
        palette[5] = 0x00;

        // Create bitmap: 64x64 with only 4 pixels set
        bytes memory bitmap = new bytes(2048);
        // Set pixel (0,0) to color 1
        bitmap[0] = 0x10; // High nibble = 1, low nibble = 0

        string memory svg = PixelArtRenderer.render(palette, bitmap);

        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        assertTrue(_contains(svg, 'fill="#ff0000"'), "Should contain red color");
    }

    function test_RevertInvalidPaletteSize() public {
        bytes memory palette = new bytes(47); // Invalid
        bytes memory bitmap = new bytes(2048);

        // Library calls revert inline, check via try/catch wrapper
        bool reverted = false;
        try this.renderWrapper(palette, bitmap) returns (string memory) {} catch {
            reverted = true;
        }
        assertTrue(reverted, "Should revert with invalid palette size");
    }

    function test_RevertInvalidBitmapSize() public {
        bytes memory palette = new bytes(48);
        bytes memory bitmap = new bytes(2047); // Invalid

        bool reverted = false;
        try this.renderWrapper(palette, bitmap) returns (string memory) {} catch {
            reverted = true;
        }
        assertTrue(reverted, "Should revert with invalid bitmap size");
    }

    // Wrapper for try/catch testing of library functions
    function renderWrapper(bytes memory palette, bytes memory bitmap) external pure returns (string memory) {
        return PixelArtRenderer.render(palette, bitmap);
    }

    function test_RenderDataURI() public view {
        string memory dataUri = PixelArtRenderer.renderDataURI(Internal4PixelArt.getPalette(), Internal4PixelArt.getBitmap());

        assertTrue(_startsWith(dataUri, "data:image/svg+xml;base64,"), "Should be data URI");
        console.log("Data URI length:", bytes(dataUri).length);
    }

    // Helper: check if string starts with prefix
    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (strBytes.length < prefixBytes.length) return false;

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    // Helper: check if string ends with suffix
    function _endsWith(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);

        if (strBytes.length < suffixBytes.length) return false;

        uint256 offset = strBytes.length - suffixBytes.length;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (strBytes[offset + i] != suffixBytes[i]) return false;
        }
        return true;
    }

    // Helper: check if string contains substring
    function _contains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (strBytes.length < substrBytes.length) return false;

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    // 128x128 monochrome (1-bit) rendering tests

    function test_Render1bit128WithColor() public pure {
        bytes3 color = bytes3(hex"ff0000"); // Red

        // Create bitmap: 128x128 with first 8 pixels set (first byte = 0xFF)
        bytes memory bitmap = new bytes(2048);
        bitmap[0] = 0xFF; // All 8 bits set = 8 pixels

        string memory svg = PixelArtRenderer.render1bit128(color, bitmap);

        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        assertTrue(_contains(svg, 'fill="#ff0000"'), "Should contain red color");
        assertTrue(_contains(svg, 'viewBox="0 0 128 128"'), "Should have 128x128 viewBox");
    }

    function test_Render1bit128SinglePixel() public pure {
        bytes3 color = bytes3(hex"000000"); // Black

        bytes memory bitmap = new bytes(2048);
        // Set only bit 7 (MSB) = pixel at (0,0)
        bitmap[0] = 0x80;

        string memory svg = PixelArtRenderer.render1bit128(color, bitmap);

        assertTrue(_contains(svg, 'x="0" y="0"'), "Should have pixel at (0,0)");
        assertTrue(_contains(svg, 'fill="#000000"'), "Should contain black color");
    }

    function test_RevertInvalid1bit128BitmapSize() public {
        bytes3 color = bytes3(hex"000000");
        bytes memory bitmap = new bytes(1024); // Invalid for 128x128 1-bit

        bool reverted = false;
        try this.render1bit128Wrapper(color, bitmap) returns (string memory) {} catch {
            reverted = true;
        }
        assertTrue(reverted, "Should revert with invalid bitmap size for 1-bit 128x128");
    }

    function render1bit128Wrapper(bytes3 color, bytes memory bitmap) external pure returns (string memory) {
        return PixelArtRenderer.render1bit128(color, bitmap);
    }

    function test_Render1bit128DataURI() public pure {
        bytes3 color = bytes3(hex"0000ff"); // Blue
        bytes memory bitmap = new bytes(2048);
        bitmap[0] = 0x80; // Single pixel

        string memory dataUri = PixelArtRenderer.render1bit128DataURI(color, bitmap);

        assertTrue(_startsWith(dataUri, "data:image/svg+xml;base64,"), "Should be data URI");
    }

    function test_HandsDiamond128MonoDataValidity() public pure {
        bytes3 color = HandsDiamond128Mono.getColor();
        bytes memory bitmap = HandsDiamond128Mono.getBitmap();

        assertEq(color, bytes3(hex"000000"), "Color should be black");
        assertEq(bitmap.length, 2048, "Bitmap should be 2048 bytes for 128x128 1-bit");
    }

    // 256x256 monochrome (1-bit) rendering tests

    function test_Render1bit256WithColor() public pure {
        bytes3 color = bytes3(hex"ff0000"); // Red

        // Create bitmap: 256x256 with first 8 pixels set (first byte = 0xFF)
        bytes memory bitmap = new bytes(8192);
        bitmap[0] = 0xFF; // All 8 bits set = 8 pixels

        string memory svg = PixelArtRenderer.render1bit256(color, bitmap);

        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        assertTrue(_contains(svg, 'fill="#ff0000"'), "Should contain red color");
        assertTrue(_contains(svg, 'viewBox="0 0 256 256"'), "Should have 256x256 viewBox");
    }

    function test_Render1bit256SinglePixel() public pure {
        bytes3 color = bytes3(hex"000000"); // Black

        bytes memory bitmap = new bytes(8192);
        // Set only bit 7 (MSB) = pixel at (0,0)
        bitmap[0] = 0x80;

        string memory svg = PixelArtRenderer.render1bit256(color, bitmap);

        assertTrue(_contains(svg, 'x="0" y="0"'), "Should have pixel at (0,0)");
        assertTrue(_contains(svg, 'fill="#000000"'), "Should contain black color");
    }

    function test_RevertInvalid1bit256BitmapSize() public {
        bytes3 color = bytes3(hex"000000");
        bytes memory bitmap = new bytes(4096); // Invalid for 256x256 1-bit

        bool reverted = false;
        try this.render1bit256Wrapper(color, bitmap) returns (string memory) {} catch {
            reverted = true;
        }
        assertTrue(reverted, "Should revert with invalid bitmap size for 1-bit 256x256");
    }

    function render1bit256Wrapper(bytes3 color, bytes memory bitmap) external pure returns (string memory) {
        return PixelArtRenderer.render1bit256(color, bitmap);
    }

    function test_Render1bit256DataURI() public pure {
        bytes3 color = bytes3(hex"0000ff"); // Blue
        bytes memory bitmap = new bytes(8192);
        bitmap[0] = 0x80; // Single pixel

        string memory dataUri = PixelArtRenderer.render1bit256DataURI(color, bitmap);

        assertTrue(_startsWith(dataUri, "data:image/svg+xml;base64,"), "Should be data URI");
    }

    function test_HandsDiamond256MonoDataValidity() public pure {
        bytes3 color = HandsDiamond256Mono.getColor();
        bytes memory bitmap = HandsDiamond256Mono.getBitmap();

        assertEq(color, bytes3(hex"000000"), "Color should be black");
        assertEq(bitmap.length, 8192, "Bitmap should be 8192 bytes for 256x256 1-bit");
    }
}
