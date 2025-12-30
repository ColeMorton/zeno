// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DashboardNFT} from "../../src/DashboardNFT.sol";

contract DashboardNFTTest is Test {
    DashboardNFT public dashboard;
    address public owner;
    address public receiver;
    address public alice;
    address public bob;

    uint256 constant THEME_PRICE = 0.002 ether;
    uint256 constant ANALYTICS_PRICE = 0.01 ether;
    uint96 constant ROYALTY_BPS = 500; // 5%

    function setUp() public {
        owner = makeAddr("owner");
        receiver = makeAddr("receiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        vm.prank(owner);
        dashboard = new DashboardNFT(
            "Dashboard NFT",
            "DASH",
            "https://example.com/",
            receiver,
            ROYALTY_BPS
        );

        // Configure features
        vm.startPrank(owner);
        dashboard.setMintPrice(dashboard.THEME_DARK(), THEME_PRICE);
        dashboard.setMintPrice(dashboard.ANALYTICS_PRO(), ANALYTICS_PRICE);
        dashboard.setFeatureActive(dashboard.THEME_DARK(), true);
        dashboard.setFeatureActive(dashboard.ANALYTICS_PRO(), true);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Constructor() public view {
        assertEq(dashboard.name(), "Dashboard NFT");
        assertEq(dashboard.symbol(), "DASH");
        assertEq(dashboard.owner(), owner);
        assertEq(dashboard.revenueReceiver(), receiver);
    }

    function test_Constructor_SetsDefaultRoyalty() public view {
        (address royaltyReceiver, uint256 royaltyAmount) = dashboard.royaltyInfo(0, 1 ether);
        assertEq(royaltyReceiver, receiver);
        assertEq(royaltyAmount, 0.05 ether); // 5% of 1 ether
    }

    function test_Constructor_RevertIf_ZeroReceiver() public {
        vm.prank(owner);
        vm.expectRevert(DashboardNFT.ZeroAddress.selector);
        new DashboardNFT("Dashboard NFT", "DASH", "https://example.com/", address(0), ROYALTY_BPS);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FEATURE CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SetMintPrice() public {
        bytes32 feature = dashboard.THEME_NEON();
        uint256 price = 0.003 ether;

        vm.prank(owner);
        dashboard.setMintPrice(feature, price);

        assertEq(dashboard.mintPrice(feature), price);
    }

    function test_SetMintPrice_EmitsEvent() public {
        bytes32 feature = dashboard.THEME_NEON();
        uint256 price = 0.003 ether;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DashboardNFT.FeaturePriceSet(feature, price);
        dashboard.setMintPrice(feature, price);
    }

    function test_SetMintPrice_RevertIf_NotOwner() public {
        bytes32 feature = dashboard.THEME_NEON();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        dashboard.setMintPrice(feature, 0.003 ether);
    }

    function test_SetFeatureActive() public {
        bytes32 feature = dashboard.THEME_NEON();

        vm.prank(owner);
        dashboard.setFeatureActive(feature, true);

        assertTrue(dashboard.featureActive(feature));
    }

    function test_SetFeatureActive_EmitsEvent() public {
        bytes32 feature = dashboard.THEME_NEON();

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DashboardNFT.FeatureActiveSet(feature, true);
        dashboard.setFeatureActive(feature, true);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // MINTING
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Mint() public {
        bytes32 feature = dashboard.THEME_DARK();

        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(feature);

        assertEq(dashboard.ownerOf(tokenId), alice);
        assertEq(dashboard.featureType(tokenId), feature);
        assertEq(dashboard.totalSupply(), 1);
        assertTrue(dashboard.hasFeature(alice, feature));
    }

    function test_Mint_EmitsEvent() public {
        bytes32 feature = dashboard.THEME_DARK();

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit DashboardNFT.FeatureMinted(alice, 0, feature, THEME_PRICE);
        dashboard.mint{value: THEME_PRICE}(feature);
    }

    function test_Mint_RefundsExcess() public {
        bytes32 feature = dashboard.THEME_DARK();
        uint256 excess = 0.001 ether;
        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        dashboard.mint{value: THEME_PRICE + excess}(feature);

        // Alice paid exact price (excess refunded)
        assertEq(alice.balance, aliceBalanceBefore - THEME_PRICE);
    }

    function test_Mint_RevertIf_FeatureNotActive() public {
        bytes32 feature = dashboard.THEME_NEON();
        vm.prank(owner);
        dashboard.setMintPrice(feature, THEME_PRICE);
        // Feature not activated

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(DashboardNFT.FeatureNotActive.selector, feature));
        dashboard.mint{value: THEME_PRICE}(feature);
    }

    function test_Mint_RevertIf_FeatureNotConfigured() public {
        bytes32 feature = dashboard.THEME_NEON();
        vm.prank(owner);
        dashboard.setFeatureActive(feature, true);
        // Price not set (0)

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(DashboardNFT.FeatureNotConfigured.selector, feature));
        dashboard.mint{value: THEME_PRICE}(feature);
    }

    function test_Mint_RevertIf_InsufficientPayment() public {
        bytes32 feature = dashboard.THEME_DARK();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(DashboardNFT.InsufficientPayment.selector, THEME_PRICE, THEME_PRICE - 1)
        );
        dashboard.mint{value: THEME_PRICE - 1}(feature);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FEATURE OWNERSHIP
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_HasFeature_TrueAfterMint() public {
        bytes32 feature = dashboard.THEME_DARK();

        vm.prank(alice);
        dashboard.mint{value: THEME_PRICE}(feature);

        assertTrue(dashboard.hasFeature(alice, feature));
        assertFalse(dashboard.hasFeature(bob, feature));
    }

    function test_HasFeature_FalseAfterTransferLastToken() public {
        bytes32 feature = dashboard.THEME_DARK();

        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(feature);

        vm.prank(alice);
        dashboard.transferFrom(alice, bob, tokenId);

        assertFalse(dashboard.hasFeature(alice, feature));
        assertTrue(dashboard.hasFeature(bob, feature));
    }

    function test_HasFeature_TrueAfterTransferIfMultipleTokens() public {
        bytes32 feature = dashboard.THEME_DARK();

        // Alice mints 2 tokens of same feature
        vm.startPrank(alice);
        uint256 tokenId1 = dashboard.mint{value: THEME_PRICE}(feature);
        dashboard.mint{value: THEME_PRICE}(feature);
        vm.stopPrank();

        assertEq(dashboard.featureOwnershipCount(alice, feature), 2);

        // Transfer one away
        vm.prank(alice);
        dashboard.transferFrom(alice, bob, tokenId1);

        // Alice still has feature (owns 1 token)
        assertTrue(dashboard.hasFeature(alice, feature));
        assertEq(dashboard.featureOwnershipCount(alice, feature), 1);

        // Bob also has feature now
        assertTrue(dashboard.hasFeature(bob, feature));
        assertEq(dashboard.featureOwnershipCount(bob, feature), 1);
    }

    function test_FeatureOwnershipCount() public {
        bytes32 feature = dashboard.THEME_DARK();

        assertEq(dashboard.featureOwnershipCount(alice, feature), 0);

        vm.startPrank(alice);
        dashboard.mint{value: THEME_PRICE}(feature);
        assertEq(dashboard.featureOwnershipCount(alice, feature), 1);

        dashboard.mint{value: THEME_PRICE}(feature);
        assertEq(dashboard.featureOwnershipCount(alice, feature), 2);

        dashboard.mint{value: THEME_PRICE}(feature);
        assertEq(dashboard.featureOwnershipCount(alice, feature), 3);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TRANSFERS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Transfer() public {
        bytes32 feature = dashboard.THEME_DARK();

        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(feature);

        vm.prank(alice);
        dashboard.transferFrom(alice, bob, tokenId);

        assertEq(dashboard.ownerOf(tokenId), bob);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ROYALTIES
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_RoyaltyInfo() public {
        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        (address royaltyReceiver, uint256 royaltyAmount) = dashboard.royaltyInfo(tokenId, 1 ether);

        assertEq(royaltyReceiver, receiver);
        assertEq(royaltyAmount, 0.05 ether); // 5%
    }

    function test_SupportsInterface_ERC2981() public view {
        // ERC-2981 interface ID
        assertTrue(dashboard.supportsInterface(0x2a55205a));
    }

    function test_SupportsInterface_ERC721() public view {
        // ERC-721 interface ID
        assertTrue(dashboard.supportsInterface(0x80ac58cd));
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ADMIN - REVENUE
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Withdraw() public {
        // Mint some tokens to accumulate funds
        vm.prank(alice);
        dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        vm.prank(bob);
        dashboard.mint{value: ANALYTICS_PRICE}(dashboard.ANALYTICS_PRO());

        uint256 expectedBalance = THEME_PRICE + ANALYTICS_PRICE;
        assertEq(address(dashboard).balance, expectedBalance);

        uint256 receiverBalanceBefore = receiver.balance;

        vm.prank(owner);
        dashboard.withdraw();

        assertEq(address(dashboard).balance, 0);
        assertEq(receiver.balance, receiverBalanceBefore + expectedBalance);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(alice);
        dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DashboardNFT.FundsWithdrawn(receiver, THEME_PRICE);
        dashboard.withdraw();
    }

    function test_Withdraw_RevertIf_NoFunds() public {
        vm.prank(owner);
        vm.expectRevert(DashboardNFT.NoFundsToWithdraw.selector);
        dashboard.withdraw();
    }

    function test_Withdraw_RevertIf_NotOwner() public {
        vm.prank(alice);
        dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        vm.prank(alice);
        vm.expectRevert();
        dashboard.withdraw();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ADMIN - CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SetRevenueReceiver() public {
        address newReceiver = makeAddr("newReceiver");

        vm.prank(owner);
        dashboard.setRevenueReceiver(newReceiver);

        assertEq(dashboard.revenueReceiver(), newReceiver);
    }

    function test_SetRevenueReceiver_UpdatesRoyalty() public {
        address newReceiver = makeAddr("newReceiver");

        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        vm.prank(owner);
        dashboard.setRevenueReceiver(newReceiver);

        (address royaltyReceiver, ) = dashboard.royaltyInfo(tokenId, 1 ether);
        assertEq(royaltyReceiver, newReceiver);
    }

    function test_SetRevenueReceiver_EmitsEvent() public {
        address newReceiver = makeAddr("newReceiver");

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit DashboardNFT.RevenueReceiverUpdated(receiver, newReceiver);
        dashboard.setRevenueReceiver(newReceiver);
    }

    function test_SetRevenueReceiver_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DashboardNFT.ZeroAddress.selector);
        dashboard.setRevenueReceiver(address(0));
    }

    function test_SetBaseURI() public {
        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        vm.prank(owner);
        dashboard.setBaseURI("https://newuri.com/");

        assertEq(dashboard.tokenURI(tokenId), "https://newuri.com/0");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FEATURE CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_FeatureConstants() public view {
        // Verify feature constants are properly set
        assertEq(dashboard.THEME_DARK(), keccak256("THEME_DARK"));
        assertEq(dashboard.THEME_NEON(), keccak256("THEME_NEON"));
        assertEq(dashboard.FRAME_ANIMATED(), keccak256("FRAME_ANIMATED"));
        assertEq(dashboard.AVATAR_CUSTOM(), keccak256("AVATAR_CUSTOM"));
        assertEq(dashboard.ANALYTICS_PRO(), keccak256("ANALYTICS_PRO"));
        assertEq(dashboard.EXPORT_CSV(), keccak256("EXPORT_CSV"));
        assertEq(dashboard.ALERTS_ADVANCED(), keccak256("ALERTS_ADVANCED"));
        assertEq(dashboard.PORTFOLIO_MULTI(), keccak256("PORTFOLIO_MULTI"));
        assertEq(dashboard.FOUNDERS_BUNDLE(), keccak256("FOUNDERS_BUNDLE"));
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function testFuzz_Mint_CorrectTokenIds(uint8 count) public {
        vm.assume(count > 0 && count <= 50);
        bytes32 feature = dashboard.THEME_DARK();

        for (uint8 i = 0; i < count; i++) {
            vm.prank(alice);
            uint256 tokenId = dashboard.mint{value: THEME_PRICE}(feature);
            assertEq(tokenId, i);
        }

        assertEq(dashboard.totalSupply(), count);
        assertEq(dashboard.featureOwnershipCount(alice, feature), count);
    }

    function testFuzz_RoyaltyCalculation(uint256 salePrice) public {
        vm.assume(salePrice <= 1_000_000 ether);

        vm.prank(alice);
        uint256 tokenId = dashboard.mint{value: THEME_PRICE}(dashboard.THEME_DARK());

        (, uint256 royaltyAmount) = dashboard.royaltyInfo(tokenId, salePrice);

        uint256 expectedRoyalty = (salePrice * ROYALTY_BPS) / 10000;
        assertEq(royaltyAmount, expectedRoyalty);
    }
}
