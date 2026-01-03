// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {HybridMintController} from "../../src/HybridMintController.sol";
import {IHybridMintController} from "../../src/interfaces/IHybridMintController.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";
import {MockProtocolHybridVaultNFT} from "../mocks/MockProtocolHybridVaultNFT.sol";
import {MockCurvePool} from "../mocks/MockCurvePool.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract HybridMintControllerTest is Test {
    HybridMintController public controller;
    MockProtocolHybridVaultNFT public hybridVault;
    TreasureNFT public treasure;
    MockWBTC public cbBTC;
    MockWBTC public vestedBTC;
    MockCurvePool public curvePool;

    address public owner;
    address public alice;
    address public bob;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant CONFIG_UPDATE_PERIOD = 30 days;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy mock tokens
        cbBTC = new MockWBTC();
        vestedBTC = new MockWBTC();

        // Deploy mock Curve pool (LP token is the pool itself in mock)
        curvePool = new MockCurvePool(address(cbBTC), address(vestedBTC));

        // Deploy mock protocol HybridVaultNFT
        hybridVault = new MockProtocolHybridVaultNFT(address(cbBTC), address(curvePool));

        // Deploy treasure NFT
        treasure = new TreasureNFT("Controller Treasure", "CT", "https://example.com/");

        // Deploy HybridMintController
        controller = new HybridMintController(
            address(hybridVault),
            address(treasure),
            address(cbBTC),
            address(curvePool), // LP token is the pool itself in mock
            address(curvePool)
        );

        // Authorize controller as treasure minter
        treasure.authorizeMinter(address(controller));

        // Fund users
        cbBTC.mint(alice, 100 * ONE_BTC);
        cbBTC.mint(bob, 100 * ONE_BTC);

        // Seed curve pool with liquidity for slippage calculation
        cbBTC.mint(address(curvePool), 1000 * ONE_BTC);
        vestedBTC.mint(address(curvePool), 1000 * ONE_BTC);
        curvePool.setBalances(1000 * ONE_BTC, 1000 * ONE_BTC);
    }

    // ==================== Minting Tests ====================

    function test_MintHybridVault_Success() public {
        vm.startPrank(alice);
        cbBTC.approve(address(controller), 10 * ONE_BTC);

        uint256 vaultId = controller.mintHybridVault(10 * ONE_BTC);
        vm.stopPrank();

        assertEq(vaultId, 0);
        // User owns the protocol vault directly
        assertEq(hybridVault.ownerOf(vaultId), alice);
    }

    function test_MintHybridVault_SplitsCollateralCorrectly() public {
        vm.startPrank(alice);
        cbBTC.approve(address(controller), 10 * ONE_BTC);

        uint256 vaultId = controller.mintHybridVault(10 * ONE_BTC);
        vm.stopPrank();

        // Get vault info from protocol
        (,, uint256 primaryAmount, uint256 secondaryAmount,) = hybridVault.getVaultInfo(vaultId);

        // LP ratio is dynamic, ranges 10-50%
        // Primary (cbBTC) should be 50-90% of input
        assertGe(primaryAmount, (10 * ONE_BTC * 5000) / 10000); // >= 50%
        assertLe(primaryAmount, (10 * ONE_BTC * 9000) / 10000); // <= 90%

        // Secondary (LP) should be > 0
        assertGt(secondaryAmount, 0);

        // Total should roughly equal input (minus any slippage)
        assertApproxEqRel(primaryAmount + secondaryAmount, 10 * ONE_BTC, 0.05e18); // 5% tolerance
    }

    function test_MintHybridVault_TreasureNFTCreated() public {
        vm.startPrank(alice);
        cbBTC.approve(address(controller), 10 * ONE_BTC);

        uint256 vaultId = controller.mintHybridVault(10 * ONE_BTC);
        vm.stopPrank();

        // Check treasure NFT was created and is held by protocol vault
        (address treasureContract, uint256 treasureId,,,) = hybridVault.getVaultInfo(vaultId);
        assertEq(treasureContract, address(treasure));
        assertEq(treasure.ownerOf(treasureId), address(hybridVault));
    }

    function test_MintHybridVault_EmitsEvent() public {
        vm.startPrank(alice);
        cbBTC.approve(address(controller), 10 * ONE_BTC);

        // Calculate expected values
        uint256 lpRatio = controller.calculateTargetLPRatio();
        uint256 expectedLP = (10 * ONE_BTC * lpRatio) / 10000;
        uint256 expectedCBBTC = 10 * ONE_BTC - expectedLP;

        vm.expectEmit(true, true, false, true);
        emit IHybridMintController.HybridVaultMinted(0, alice, expectedCBBTC, expectedLP, lpRatio);

        controller.mintHybridVault(10 * ONE_BTC);
        vm.stopPrank();
    }

    function test_MintHybridVault_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(IHybridMintController.ZeroAmount.selector);
        controller.mintHybridVault(0);
    }

    function test_MintHybridVault_MultipleMints() public {
        vm.startPrank(alice);
        cbBTC.approve(address(controller), 20 * ONE_BTC);

        uint256 id1 = controller.mintHybridVault(10 * ONE_BTC);
        uint256 id2 = controller.mintHybridVault(10 * ONE_BTC);
        vm.stopPrank();

        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(hybridVault.ownerOf(id1), alice);
        assertEq(hybridVault.ownerOf(id2), alice);
    }

    // ==================== LP Ratio Tests ====================

    function test_CalculateTargetLPRatio_DefaultConfig() public view {
        uint256 ratio = controller.calculateTargetLPRatio();

        // Should be within min/max bounds
        IHybridMintController.MonthlyConfig memory config = controller.getCurrentConfig();
        assertGe(ratio, config.minLPRatioBPS);
        assertLe(ratio, config.maxLPRatioBPS);
    }

    function test_MeasureSlippage_WithLiquidity() public view {
        uint256 slippage = controller.measureSlippage();
        // With balanced pool, slippage should be minimal
        assertLt(slippage, 100); // < 1%
    }

    function test_MeasureSlippage_EmptyPool() public {
        // Set pool balances to zero
        curvePool.setBalances(0, 0);

        uint256 slippage = controller.measureSlippage();
        assertEq(slippage, 0);
    }

    // ==================== Config Update Tests ====================

    function test_UpdateMonthlyConfig_Success() public {
        // Wait for update period
        vm.warp(block.timestamp + CONFIG_UPDATE_PERIOD + 1);

        IHybridMintController.MonthlyConfig memory newConfig = IHybridMintController.MonthlyConfig({
            baseLPRatioBPS: 3200, // +2% from default 3000
            minLPRatioBPS: 1000,
            maxLPRatioBPS: 5000,
            discountThresholdBPS: 1000,
            discountSensitivity: 2,
            targetSlippageBPS: 50,
            slippageSensitivity: 20,
            standardSwapBPS: 10,
            effectiveTimestamp: 0 // Will be set to block.timestamp
        });

        controller.updateMonthlyConfig(newConfig);

        IHybridMintController.MonthlyConfig memory current = controller.getCurrentConfig();
        assertEq(current.baseLPRatioBPS, 3200);
    }

    function test_UpdateMonthlyConfig_RevertIf_TooFrequent() public {
        // Don't wait for update period
        IHybridMintController.MonthlyConfig memory newConfig = IHybridMintController.MonthlyConfig({
            baseLPRatioBPS: 3200,
            minLPRatioBPS: 1000,
            maxLPRatioBPS: 5000,
            discountThresholdBPS: 1000,
            discountSensitivity: 2,
            targetSlippageBPS: 50,
            slippageSensitivity: 20,
            standardSwapBPS: 10,
            effectiveTimestamp: 0
        });

        vm.expectRevert(IHybridMintController.ConfigUpdateTooFrequent.selector);
        controller.updateMonthlyConfig(newConfig);
    }

    function test_UpdateMonthlyConfig_RevertIf_RateLimitExceeded() public {
        vm.warp(block.timestamp + CONFIG_UPDATE_PERIOD + 1);

        // Try to change baseLPRatioBPS by more than 5% (500 BPS)
        IHybridMintController.MonthlyConfig memory newConfig = IHybridMintController.MonthlyConfig({
            baseLPRatioBPS: 4000, // +10% from default 3000, exceeds 5% limit
            minLPRatioBPS: 1000,
            maxLPRatioBPS: 5000,
            discountThresholdBPS: 1000,
            discountSensitivity: 2,
            targetSlippageBPS: 50,
            slippageSensitivity: 20,
            standardSwapBPS: 10,
            effectiveTimestamp: 0
        });

        vm.expectRevert(abi.encodeWithSelector(IHybridMintController.RateLimitExceeded.selector, "baseLPRatioBPS"));
        controller.updateMonthlyConfig(newConfig);
    }

    function test_UpdateMonthlyConfig_RevertIf_NotOwner() public {
        vm.warp(block.timestamp + CONFIG_UPDATE_PERIOD + 1);

        IHybridMintController.MonthlyConfig memory newConfig = IHybridMintController.MonthlyConfig({
            baseLPRatioBPS: 3200,
            minLPRatioBPS: 1000,
            maxLPRatioBPS: 5000,
            discountThresholdBPS: 1000,
            discountSensitivity: 2,
            targetSlippageBPS: 50,
            slippageSensitivity: 20,
            standardSwapBPS: 10,
            effectiveTimestamp: 0
        });

        vm.prank(alice);
        vm.expectRevert();
        controller.updateMonthlyConfig(newConfig);
    }

    // ==================== Fuzz Tests ====================

    function testFuzz_MintHybridVault(uint256 amount) public {
        // Minimum amount needs to be large enough for LP portion to be non-zero
        // With 10% min LP ratio, need at least 10 units for LP > 0
        amount = bound(amount, 1000, 50 * ONE_BTC);

        cbBTC.mint(alice, amount);

        vm.startPrank(alice);
        cbBTC.approve(address(controller), amount);

        uint256 vaultId = controller.mintHybridVault(amount);
        vm.stopPrank();

        assertEq(hybridVault.ownerOf(vaultId), alice);

        (,, uint256 primary, uint256 secondary,) = hybridVault.getVaultInfo(vaultId);
        assertGt(primary, 0);
        assertGt(secondary, 0);
    }
}
