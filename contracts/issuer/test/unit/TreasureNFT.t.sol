// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";

contract TreasureNFTTest is Test {
    TreasureNFT public treasure;
    address public owner;
    address public minter;
    address public alice;

    function setUp() public {
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        alice = makeAddr("alice");

        vm.prank(owner);
        treasure = new TreasureNFT("Treasure", "TREASURE", "https://example.com/");
    }

    function test_Constructor() public view {
        assertEq(treasure.name(), "Treasure");
        assertEq(treasure.symbol(), "TREASURE");
        assertEq(treasure.owner(), owner);
    }

    function test_AuthorizeMinter() public {
        vm.prank(owner);
        treasure.authorizeMinter(minter);

        assertTrue(treasure.authorizedMinters(minter));
    }

    function test_AuthorizeMinter_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit TreasureNFT.MinterAuthorized(minter);
        treasure.authorizeMinter(minter);
    }

    function test_AuthorizeMinter_RevertIf_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        treasure.authorizeMinter(minter);
    }

    function test_RevokeMinter() public {
        vm.prank(owner);
        treasure.authorizeMinter(minter);
        assertTrue(treasure.authorizedMinters(minter));

        vm.prank(owner);
        treasure.revokeMinter(minter);
        assertFalse(treasure.authorizedMinters(minter));
    }

    function test_RevokeMinter_EmitsEvent() public {
        vm.prank(owner);
        treasure.authorizeMinter(minter);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit TreasureNFT.MinterRevoked(minter);
        treasure.revokeMinter(minter);
    }

    function test_Mint_AsOwner() public {
        vm.prank(owner);
        uint256 tokenId = treasure.mint(alice);

        assertEq(treasure.ownerOf(tokenId), alice);
        assertEq(treasure.totalSupply(), 1);
    }

    function test_Mint_AsAuthorizedMinter() public {
        vm.prank(owner);
        treasure.authorizeMinter(minter);

        vm.prank(minter);
        uint256 tokenId = treasure.mint(alice);

        assertEq(treasure.ownerOf(tokenId), alice);
    }

    function test_Mint_RevertIf_NotAuthorized() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TreasureNFT.NotAuthorizedMinter.selector, alice));
        treasure.mint(alice);
    }

    function test_MintBatch() public {
        vm.prank(owner);
        uint256[] memory tokenIds = treasure.mintBatch(alice, 5);

        assertEq(tokenIds.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(tokenIds[i], i);
            assertEq(treasure.ownerOf(i), alice);
        }
        assertEq(treasure.totalSupply(), 5);
    }

    function test_MintBatch_AsAuthorizedMinter() public {
        vm.prank(owner);
        treasure.authorizeMinter(minter);

        vm.prank(minter);
        uint256[] memory tokenIds = treasure.mintBatch(alice, 3);

        assertEq(tokenIds.length, 3);
    }

    function test_MintBatch_RevertIf_NotAuthorized() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TreasureNFT.NotAuthorizedMinter.selector, alice));
        treasure.mintBatch(alice, 3);
    }

    function test_SetBaseURI() public {
        vm.prank(owner);
        treasure.mint(alice);

        vm.prank(owner);
        treasure.setBaseURI("https://newuri.com/");

        assertEq(treasure.tokenURI(0), "https://newuri.com/0");
    }

    function test_SetBaseURI_RevertIf_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        treasure.setBaseURI("https://newuri.com/");
    }

    function test_Transfer() public {
        vm.prank(owner);
        uint256 tokenId = treasure.mint(alice);

        vm.prank(alice);
        treasure.transferFrom(alice, minter, tokenId);

        assertEq(treasure.ownerOf(tokenId), minter);
    }

    function testFuzz_Mint_IncrementingTokenIds(uint8 count) public {
        vm.assume(count > 0 && count <= 100);

        for (uint8 i = 0; i < count; i++) {
            vm.prank(owner);
            uint256 tokenId = treasure.mint(alice);
            assertEq(tokenId, i);
        }

        assertEq(treasure.totalSupply(), count);
    }

    function testFuzz_MintBatch(uint8 count) public {
        vm.assume(count > 0 && count <= 100);

        vm.prank(owner);
        uint256[] memory tokenIds = treasure.mintBatch(alice, count);

        assertEq(tokenIds.length, count);
        assertEq(treasure.totalSupply(), count);
    }
}
