// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AuctionController} from "../../src/AuctionController.sol";
import {IAuctionController} from "../../src/interfaces/IAuctionController.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";
import {MockVaultNFT} from "../mocks/MockVaultNFT.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract AuctionControllerTest is Test {
    AuctionController public controller;
    TreasureNFT public treasure;
    MockVaultNFT public vault;
    MockWBTC public wbtc;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    uint256 constant ONE_BTC = 1e8;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy contracts
        treasure = new TreasureNFT("Test Treasure", "TT", "https://example.com/", address(0));
        vault = new MockVaultNFT();
        wbtc = new MockWBTC();

        // Prepare collateral and protocol arrays (single collateral for tests)
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(wbtc);

        address[] memory protocols = new address[](1);
        protocols[0] = address(vault);

        controller = new AuctionController(address(treasure), collaterals, protocols);

        // Authorize controller as minter
        treasure.authorizeMinter(address(controller));

        // Fund users
        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        wbtc.mint(charlie, 100 * ONE_BTC);

        // Approve controller for users
        vm.prank(alice);
        wbtc.approve(address(controller), type(uint256).max);

        vm.prank(bob);
        wbtc.approve(address(controller), type(uint256).max);

        vm.prank(charlie);
        wbtc.approve(address(controller), type(uint256).max);
    }

    // ==================== Dutch Auction Tests ====================

    function test_CreateDutchAuction() public {
        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600, // 1 BTC per hour
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        assertEq(auctionId, 0);

        IAuctionController.Auction memory auction = controller.getAuction(auctionId);
        assertEq(uint8(auction.auctionType), uint8(IAuctionController.AuctionType.DUTCH));
        assertEq(auction.maxSupply, 5);
        assertEq(auction.mintedCount, 0);
        assertEq(auction.collateralToken, address(wbtc));
    }

    function test_CreateDutchAuction_RevertIf_ZeroSupply() public {
        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 10 hours
        });

        vm.expectRevert(IAuctionController.ZeroMaxSupply.selector);
        controller.createDutchAuction(0, address(wbtc), config);
    }

    function test_CreateDutchAuction_RevertIf_InvalidTimeWindow() public {
        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: block.timestamp + 10 hours,
            endTime: block.timestamp + 1 hours // End before start
        });

        vm.expectRevert(IAuctionController.InvalidTimeWindow.selector);
        controller.createDutchAuction(5, address(wbtc), config);
    }

    function test_GetCurrentPrice_BeforeStart() public {
        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        uint256 price = controller.getCurrentPrice(auctionId);
        assertEq(price, 10 * ONE_BTC); // Should be start price before auction starts
    }

    function test_GetCurrentPrice_LinearDecay() public {
        uint256 startTime = block.timestamp;
        // Use clean decay rate: 1 unit per second
        uint256 decayRate = 1;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10000, // 10000 units
            floorPrice: 1000,  // floor at 1000
            decayRate: decayRate,
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        // After 1 hour (3600 seconds): decay = 3600, price = 10000 - 3600 = 6400
        vm.warp(startTime + 1 hours);
        assertEq(controller.getCurrentPrice(auctionId), 6400);

        // After 9000 seconds (2.5 hours): decay = 9000, 10000 <= 9000 + 1000 = true -> floor
        vm.warp(startTime + 9000);
        assertEq(controller.getCurrentPrice(auctionId), 1000);
    }

    function test_GetCurrentPrice_AtFloor() public {
        uint256 startTime = block.timestamp;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        // After 20 hours (way past floor)
        vm.warp(startTime + 20 hours);
        uint256 price = controller.getCurrentPrice(auctionId);
        assertEq(price, 1 * ONE_BTC); // Should be floor price
    }

    function test_PurchaseDutch() public {
        uint256 startTime = block.timestamp;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        vm.prank(alice);
        uint256 vaultId = controller.purchaseDutch(auctionId);

        assertEq(vaultId, 0);
        assertEq(vault.ownerOf(vaultId), alice);

        IAuctionController.Auction memory auction = controller.getAuction(auctionId);
        assertEq(auction.mintedCount, 1);
    }

    function test_PurchaseDutch_RevertIf_NotActive() public {
        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAuctionController.AuctionNotActive.selector, auctionId));
        controller.purchaseDutch(auctionId);
    }

    function test_PurchaseDutch_RevertIf_SoldOut() public {
        uint256 startTime = block.timestamp;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 2 * ONE_BTC, // Must be > floorPrice
            floorPrice: 1 * ONE_BTC,
            decayRate: 0,
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(2, address(wbtc), config);

        // Purchase 2 (max supply)
        vm.prank(alice);
        controller.purchaseDutch(auctionId);

        vm.prank(bob);
        controller.purchaseDutch(auctionId);

        // Third should fail
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IAuctionController.AuctionSoldOut.selector, auctionId));
        controller.purchaseDutch(auctionId);
    }

    // ==================== English Auction Tests ====================

    function test_CreateEnglishAuction() public {
        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100, // 1%
            startTime: block.timestamp + 1 hours,
            endTime: block.timestamp + 24 hours,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        assertEq(auctionId, 0);

        IAuctionController.Auction memory auction = controller.getAuction(auctionId);
        assertEq(uint8(auction.auctionType), uint8(IAuctionController.AuctionType.ENGLISH));
        assertEq(auction.maxSupply, 3);
    }

    function test_PlaceBid_Initial() public {
        uint256 startTime = block.timestamp;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: startTime + 24 hours,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        vm.prank(alice);
        controller.placeBid(auctionId, 0, 2 * ONE_BTC);

        IAuctionController.Bid memory bid = controller.getHighestBid(auctionId, 0);
        assertEq(bid.bidder, alice);
        assertEq(bid.amount, 2 * ONE_BTC);
    }

    function test_PlaceBid_Outbid() public {
        uint256 startTime = block.timestamp;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: startTime + 24 hours,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        controller.placeBid(auctionId, 0, 2 * ONE_BTC);

        vm.prank(bob);
        controller.placeBid(auctionId, 0, 3 * ONE_BTC);

        // Alice should be refunded
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore);

        IAuctionController.Bid memory bid = controller.getHighestBid(auctionId, 0);
        assertEq(bid.bidder, bob);
        assertEq(bid.amount, 3 * ONE_BTC);
    }

    function test_PlaceBid_RevertIf_TooLow() public {
        uint256 startTime = block.timestamp;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 2 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: startTime + 24 hours,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAuctionController.BidTooLow.selector, 1 * ONE_BTC, 2 * ONE_BTC));
        controller.placeBid(auctionId, 0, 1 * ONE_BTC);
    }

    function test_PlaceBid_ExtendsAuction() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 24 hours;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: endTime,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        // Warp to 5 minutes before end (within extension window)
        vm.warp(endTime - 5 minutes);

        vm.prank(alice);
        controller.placeBid(auctionId, 0, 2 * ONE_BTC);

        // Auction should be extended
        IAuctionController.EnglishAuctionConfig memory updatedConfig = controller.getEnglishConfig(auctionId);
        assertEq(updatedConfig.endTime, block.timestamp + 5 minutes);
    }

    function test_SettleSlot() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 hours;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: endTime,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        vm.prank(alice);
        controller.placeBid(auctionId, 0, 5 * ONE_BTC);

        // Warp past end
        vm.warp(endTime + 1);

        uint256 vaultId = controller.settleSlot(auctionId, 0);

        assertEq(vault.ownerOf(vaultId), alice);
        assertTrue(controller.isSlotSettled(auctionId, 0));
    }

    function test_SettleSlot_RevertIf_NotEnded() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 hours;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: endTime,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        vm.prank(alice);
        controller.placeBid(auctionId, 0, 5 * ONE_BTC);

        vm.expectRevert(abi.encodeWithSelector(IAuctionController.AuctionNotEnded.selector, auctionId));
        controller.settleSlot(auctionId, 0);
    }

    function test_SettleSlot_RevertIf_NoBids() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 hours;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: endTime,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        // Warp past end without any bids
        vm.warp(endTime + 1);

        vm.expectRevert(abi.encodeWithSelector(IAuctionController.NoBidsOnSlot.selector, auctionId, 0));
        controller.settleSlot(auctionId, 0);
    }

    function test_SettleSlot_RevertIf_AlreadySettled() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 hours;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: endTime,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(3, address(wbtc), config);

        vm.prank(alice);
        controller.placeBid(auctionId, 0, 5 * ONE_BTC);

        vm.warp(endTime + 1);

        controller.settleSlot(auctionId, 0);

        vm.expectRevert(abi.encodeWithSelector(IAuctionController.AlreadySettled.selector, auctionId, 0));
        controller.settleSlot(auctionId, 0);
    }

    // ==================== Common Function Tests ====================

    function test_GetAuctionState_Dutch() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = block.timestamp + 10 hours;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 10 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: ONE_BTC / 3600,
            startTime: startTime,
            endTime: endTime
        });

        uint256 auctionId = controller.createDutchAuction(5, address(wbtc), config);

        // Before start
        assertEq(uint8(controller.getAuctionState(auctionId)), uint8(IAuctionController.AuctionState.PENDING));

        // During auction
        vm.warp(startTime + 1 hours);
        assertEq(uint8(controller.getAuctionState(auctionId)), uint8(IAuctionController.AuctionState.ACTIVE));

        // After end
        vm.warp(endTime + 1);
        assertEq(uint8(controller.getAuctionState(auctionId)), uint8(IAuctionController.AuctionState.ENDED));
    }

    function test_FinalizeAuction() public {
        uint256 startTime = block.timestamp;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 2 * ONE_BTC, // Must be > floorPrice
            floorPrice: 1 * ONE_BTC,
            decayRate: 0,
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(1, address(wbtc), config);

        vm.prank(alice);
        controller.purchaseDutch(auctionId);

        controller.finalizeAuction(auctionId);

        assertEq(uint8(controller.getAuctionState(auctionId)), uint8(IAuctionController.AuctionState.FINALIZED));
    }

    function test_FinalizeAuction_RevertIf_AlreadyFinalized() public {
        uint256 startTime = block.timestamp;

        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 2 * ONE_BTC, // Must be > floorPrice
            floorPrice: 1 * ONE_BTC,
            decayRate: 0,
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(1, address(wbtc), config);

        controller.finalizeAuction(auctionId);

        vm.expectRevert(abi.encodeWithSelector(IAuctionController.AuctionAlreadyFinalized.selector, auctionId));
        controller.finalizeAuction(auctionId);
    }

    // ==================== Integration Tests ====================

    function test_FullDutchAuctionLifecycle() public {
        uint256 startTime = block.timestamp;

        // Use fixed price (no decay) for simpler test
        IAuctionController.DutchAuctionConfig memory config = IAuctionController.DutchAuctionConfig({
            startPrice: 2 * ONE_BTC,
            floorPrice: 1 * ONE_BTC,
            decayRate: 0, // No decay - constant price
            startTime: startTime,
            endTime: startTime + 10 hours
        });

        uint256 auctionId = controller.createDutchAuction(3, address(wbtc), config);

        // Alice buys at 2 BTC
        vm.prank(alice);
        uint256 vaultId1 = controller.purchaseDutch(auctionId);

        // Bob buys at 2 BTC
        vm.prank(bob);
        uint256 vaultId2 = controller.purchaseDutch(auctionId);

        // Charlie buys at 2 BTC
        vm.prank(charlie);
        uint256 vaultId3 = controller.purchaseDutch(auctionId);

        // Verify ownership
        assertEq(vault.ownerOf(vaultId1), alice);
        assertEq(vault.ownerOf(vaultId2), bob);
        assertEq(vault.ownerOf(vaultId3), charlie);

        // Verify auction is sold out
        IAuctionController.Auction memory auction = controller.getAuction(auctionId);
        assertEq(auction.mintedCount, 3);

        // Finalize
        controller.finalizeAuction(auctionId);
        assertEq(uint8(controller.getAuctionState(auctionId)), uint8(IAuctionController.AuctionState.FINALIZED));
    }

    function test_FullEnglishAuctionLifecycle() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 hours;

        IAuctionController.EnglishAuctionConfig memory config = IAuctionController.EnglishAuctionConfig({
            reservePrice: 1 * ONE_BTC,
            minBidIncrement: 100,
            startTime: startTime,
            endTime: endTime,
            extensionWindow: 10 minutes,
            extensionDuration: 5 minutes
        });

        uint256 auctionId = controller.createEnglishAuction(2, address(wbtc), config);

        // Slot 0: Alice bids, Bob outbids
        vm.prank(alice);
        controller.placeBid(auctionId, 0, 2 * ONE_BTC);

        vm.prank(bob);
        controller.placeBid(auctionId, 0, 3 * ONE_BTC);

        // Slot 1: Charlie bids
        vm.prank(charlie);
        controller.placeBid(auctionId, 1, 5 * ONE_BTC);

        // Warp past end
        vm.warp(endTime + 1);

        // Settle slots
        uint256 vaultId0 = controller.settleSlot(auctionId, 0);
        uint256 vaultId1 = controller.settleSlot(auctionId, 1);

        // Verify winners
        assertEq(vault.ownerOf(vaultId0), bob);
        assertEq(vault.ownerOf(vaultId1), charlie);

        // Finalize
        controller.finalizeAuction(auctionId);
    }
}
