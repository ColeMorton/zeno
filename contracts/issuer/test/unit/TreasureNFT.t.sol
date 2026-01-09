// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";
import {ITreasureNFT} from "../../src/interfaces/ITreasureNFT.sol";
import {MockVaultNFT} from "../mocks/MockVaultNFT.sol";

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
        treasure = new TreasureNFT("Treasure", "TREASURE", "https://example.com/", address(0));
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
        vm.expectRevert(abi.encodeWithSelector(ITreasureNFT.NotAuthorizedMinter.selector, alice));
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
        vm.expectRevert(abi.encodeWithSelector(ITreasureNFT.NotAuthorizedMinter.selector, alice));
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

    // ==================== Tier System Tests ====================

    function test_ComputeTier_NoThresholds() public view {
        // When no thresholds set (all 0), any collateral >= 0 returns Diamond
        // since collateral >= thresholds.diamond (0)
        assertEq(uint8(treasure.computeTier(0)), uint8(ITreasureNFT.Tier.Diamond));
        assertEq(uint8(treasure.computeTier(1000)), uint8(ITreasureNFT.Tier.Diamond));
    }

    function test_ComputeTier_Bronze() public {
        // Set thresholds so we can test Bronze
        vm.prank(owner);
        treasure.updateThresholds(1e8, 5e8, 10e8, 50e8);

        // Below silver threshold = Bronze
        assertEq(uint8(treasure.computeTier(0)), uint8(ITreasureNFT.Tier.Bronze));
        assertEq(uint8(treasure.computeTier(0.5e8)), uint8(ITreasureNFT.Tier.Bronze));
    }

    function test_ComputeTier_WithThresholds() public {
        // Set thresholds
        vm.prank(owner);
        treasure.updateThresholds(1e8, 5e8, 10e8, 50e8); // Silver: 1 BTC, Gold: 5, Platinum: 10, Diamond: 50

        assertEq(uint8(treasure.computeTier(0.5e8)), uint8(ITreasureNFT.Tier.Bronze));
        assertEq(uint8(treasure.computeTier(1e8)), uint8(ITreasureNFT.Tier.Silver));
        assertEq(uint8(treasure.computeTier(3e8)), uint8(ITreasureNFT.Tier.Silver));
        assertEq(uint8(treasure.computeTier(5e8)), uint8(ITreasureNFT.Tier.Gold));
        assertEq(uint8(treasure.computeTier(7e8)), uint8(ITreasureNFT.Tier.Gold));
        assertEq(uint8(treasure.computeTier(10e8)), uint8(ITreasureNFT.Tier.Platinum));
        assertEq(uint8(treasure.computeTier(30e8)), uint8(ITreasureNFT.Tier.Platinum));
        assertEq(uint8(treasure.computeTier(50e8)), uint8(ITreasureNFT.Tier.Diamond));
        assertEq(uint8(treasure.computeTier(100e8)), uint8(ITreasureNFT.Tier.Diamond));
    }

    function test_UpdateThresholds() public {
        vm.prank(owner);
        treasure.updateThresholds(1e8, 5e8, 10e8, 50e8);

        // Verify thresholds are set correctly
        (uint256 silver, uint256 gold, uint256 platinum, uint256 diamond) = treasure.thresholds();
        assertEq(silver, 1e8);
        assertEq(gold, 5e8);
        assertEq(platinum, 10e8);
        assertEq(diamond, 50e8);
    }

    function test_UpdateThresholds_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit ITreasureNFT.ThresholdsUpdated(1e8, 5e8, 10e8, 50e8);
        treasure.updateThresholds(1e8, 5e8, 10e8, 50e8);
    }

    function test_UpdateThresholds_RevertIf_NotKeeper() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ITreasureNFT.NotKeeper.selector, alice));
        treasure.updateThresholds(1e8, 5e8, 10e8, 50e8);
    }

    function test_SetKeeper() public {
        vm.prank(owner);
        treasure.setKeeper(alice);

        assertEq(treasure.keeper(), alice);

        // Alice can now update thresholds
        vm.prank(alice);
        treasure.updateThresholds(1e8, 5e8, 10e8, 50e8);
    }

    function test_LinkToVault() public {
        vm.prank(owner);
        uint256 treasureId = treasure.mint(alice);

        vm.prank(owner);
        treasure.authorizeMinter(minter);

        vm.prank(minter);
        treasure.linkToVault(treasureId, 42);

        assertEq(treasure.treasureVault(treasureId), 42);
    }

    function test_LinkToVault_EmitsEvent() public {
        vm.prank(owner);
        uint256 treasureId = treasure.mint(alice);

        vm.prank(owner);
        treasure.authorizeMinter(minter);

        vm.prank(minter);
        vm.expectEmit(true, true, false, false);
        emit ITreasureNFT.VaultLinked(treasureId, 42);
        treasure.linkToVault(treasureId, 42);
    }

    function test_LinkToVault_RevertIf_AlreadyLinked() public {
        vm.prank(owner);
        uint256 treasureId = treasure.mint(alice);

        vm.prank(owner);
        treasure.authorizeMinter(minter);

        vm.prank(minter);
        treasure.linkToVault(treasureId, 42);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(ITreasureNFT.AlreadyLinkedToVault.selector, treasureId));
        treasure.linkToVault(treasureId, 100);
    }

    function test_LinkToVault_RevertIf_NotMinter() public {
        vm.prank(owner);
        uint256 treasureId = treasure.mint(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ITreasureNFT.NotAuthorizedMinter.selector, alice));
        treasure.linkToVault(treasureId, 42);
    }

    function test_GetTier_UnlinkedTreasure() public {
        vm.prank(owner);
        uint256 treasureId = treasure.mint(alice);

        // Unlinked treasure defaults to Bronze
        assertEq(uint8(treasure.getTier(treasureId)), uint8(ITreasureNFT.Tier.Bronze));
    }

    function test_MintWithAchievement() public {
        bytes32 achievementType = keccak256("GENESIS");

        vm.prank(owner);
        uint256 tokenId = treasure.mintWithAchievement(alice, achievementType);

        assertEq(treasure.ownerOf(tokenId), alice);
        assertEq(treasure.achievementType(tokenId), achievementType);
    }

    function test_SetImageCID() public {
        bytes32 achievementType = keccak256("GENESIS");
        ITreasureNFT.Tier tier = ITreasureNFT.Tier.Diamond;
        string memory cid = "QmTestCID123";

        vm.prank(owner);
        treasure.setImageCID(achievementType, tier, cid);

        assertEq(treasure.imageCIDs(achievementType, tier), cid);
    }

    function test_TokenURI_WithImageCID() public {
        bytes32 achievementType = keccak256("GENESIS");
        ITreasureNFT.Tier tier = ITreasureNFT.Tier.Bronze;
        string memory cid = "QmTestCID123";

        // Set image CID for Bronze tier
        vm.prank(owner);
        treasure.setImageCID(achievementType, tier, cid);

        // Mint treasure with achievement type
        vm.prank(owner);
        uint256 tokenId = treasure.mintWithAchievement(alice, achievementType);

        // Token URI should be on-chain JSON
        string memory uri = treasure.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
        // Should start with data:application/json;base64,
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
    }

    function test_TokenURI_FallbackToBaseURI() public {
        vm.prank(owner);
        uint256 tokenId = treasure.mint(alice);

        // No image CID set, should fall back to base URI
        string memory uri = treasure.tokenURI(tokenId);
        assertEq(uri, "https://example.com/0");
    }

    function test_SupportsInterface_ERC4906() public view {
        // ERC-4906 interface ID
        bytes4 erc4906InterfaceId = 0x49064906;
        assertTrue(treasure.supportsInterface(erc4906InterfaceId));
    }

    // ==================== Helper ====================

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (strBytes.length < prefixBytes.length) return false;

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }
}
