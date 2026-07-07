// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HybridMintController} from "../../src/HybridMintController.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {VestingEscrow} from "@protocol/VestingEscrow.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {MockCurvePool} from "../mocks/MockCurvePool.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract HybridMintControllerTest is Test {
    HybridMintController public controller;
    VaultNFT public vault;
    VestingEscrow public escrow;
    BtcToken public btcToken;
    TreasureNFT public treasure;
    MockWBTC public cbBTC;
    MockWBTC public vestedBTC;
    MockCurvePool public curvePool;

    address public owner;
    address public alice;
    address public bob;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant CONFIG_UPDATE_PERIOD = 30 days;
    uint256 constant VESTING_PERIOD = 1129 days;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy mock tokens
        cbBTC = new MockWBTC();
        vestedBTC = new MockWBTC();

        // Deploy mock Curve pool (LP token is the pool itself in mock)
        curvePool = new MockCurvePool(address(cbBTC), address(vestedBTC));

        // Deploy protocol: BtcToken needs the vault address, vault deploys next
        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-cbBTC", "vCBBTC");
        vault = new VaultNFT(address(btcToken), address(cbBTC), "Vault NFT", "VAULT");

        // VestingEscrow holds the LP leg against the vault's clock
        escrow = new VestingEscrow(address(vault), address(curvePool));

        // Deploy treasure NFT
        treasure = new TreasureNFT("Controller Treasure", "CT", "https://example.com/", address(0));

        // Deploy HybridMintController
        controller = new HybridMintController(
            address(vault),
            address(escrow),
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

    function _mint(address user, uint256 amount) internal returns (uint256 vaultId) {
        vm.startPrank(user);
        cbBTC.approve(address(controller), amount);
        vaultId = controller.mintHybridVault(amount);
        vm.stopPrank();
    }

    // ==================== Minting Tests ====================

    function test_MintHybridVault_Success() public {
        uint256 vaultId = _mint(alice, 10 * ONE_BTC);

        assertEq(vaultId, 0);
        // User owns the protocol vault directly
        assertEq(vault.ownerOf(vaultId), alice);
    }

    function test_MintHybridVault_SplitsCollateralCorrectly() public {
        uint256 vaultId = _mint(alice, 10 * ONE_BTC);

        uint256 primaryAmount = vault.collateralAmount(vaultId);
        uint256 secondaryAmount = escrow.escrowAmount(vaultId);

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
        uint256 vaultId = _mint(alice, 10 * ONE_BTC);

        // Check treasure NFT was created and is held by protocol vault
        (address treasureContract, uint256 treasureId,,,,,,) = vault.getVaultInfo(vaultId);
        assertEq(treasureContract, address(treasure));
        assertEq(treasure.ownerOf(treasureId), address(vault));
    }

    function test_MintHybridVault_BindsEscrowAsRedeemHook() public {
        uint256 vaultId = _mint(alice, 10 * ONE_BTC);

        assertEq(vault.redeemHook(vaultId), address(escrow));
        assertEq(escrow.mintTimestamp(vaultId), vault.mintTimestamp(vaultId));
    }

    function test_MintHybridVault_AtomicEarlyExit() public {
        uint256 vaultId = _mint(alice, 10 * ONE_BTC);
        uint256 lpEscrowed = escrow.escrowAmount(vaultId);

        vm.warp(block.timestamp + VESTING_PERIOD / 2);

        uint256 cbBefore = cbBTC.balanceOf(alice);
        uint256 lpBefore = curvePool.balanceOf(alice);

        vm.prank(alice);
        vault.earlyRedeem(vaultId);

        // Both legs settled in one transaction with the pro-rata curve
        assertGt(cbBTC.balanceOf(alice), cbBefore);
        uint256 lpReturned = curvePool.balanceOf(alice) - lpBefore;
        assertGt(lpReturned, 0);
        assertLt(lpReturned, lpEscrowed);
        assertEq(escrow.escrowAmount(vaultId), 0);
    }

    function test_MintHybridVault_SecondaryClaimAtVesting() public {
        uint256 vaultId = _mint(alice, 10 * ONE_BTC);
        uint256 lpEscrowed = escrow.escrowAmount(vaultId);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 claimed = escrow.claim(vaultId);
        assertEq(claimed, lpEscrowed);
    }

    function test_MintHybridVault_EmitsEvent() public {
        vm.startPrank(alice);
        cbBTC.approve(address(controller), 10 * ONE_BTC);

        // Calculate expected values
        uint256 lpRatio = controller.calculateTargetLPRatio();
        uint256 expectedLP = (10 * ONE_BTC * lpRatio) / 10000;
        uint256 expectedCBBTC = 10 * ONE_BTC - expectedLP;

        vm.expectEmit(true, true, false, true);
        emit HybridMintController.HybridVaultMinted(0, alice, expectedCBBTC, expectedLP, lpRatio);

        controller.mintHybridVault(10 * ONE_BTC);
        vm.stopPrank();
    }

    function test_MintHybridVault_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(HybridMintController.ZeroAmount.selector);
        controller.mintHybridVault(0);
    }

    function test_MintHybridVault_MultipleMints() public {
        uint256 id1 = _mint(alice, 10 * ONE_BTC);
        uint256 id2 = _mint(alice, 10 * ONE_BTC);

        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(vault.ownerOf(id1), alice);
        assertEq(vault.ownerOf(id2), alice);
    }

    // ==================== LP Ratio Tests ====================

    function test_CalculateTargetLPRatio_DefaultConfig() public view {
        uint256 ratio = controller.calculateTargetLPRatio();

        // Should be within min/max bounds
        HybridMintController.MonthlyConfig memory config = controller.getCurrentConfig();
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

    function _defaultConfig(uint256 baseLPRatioBPS) internal pure returns (HybridMintController.MonthlyConfig memory) {
        return HybridMintController.MonthlyConfig({
            baseLPRatioBPS: baseLPRatioBPS,
            minLPRatioBPS: 1000,
            maxLPRatioBPS: 5000,
            discountThresholdBPS: 1000,
            discountSensitivity: 2,
            targetSlippageBPS: 50,
            slippageSensitivity: 20,
            standardSwapBPS: 10,
            effectiveTimestamp: 0 // Will be set to block.timestamp
        });
    }

    function test_UpdateMonthlyConfig_Success() public {
        // Wait for update period
        vm.warp(block.timestamp + CONFIG_UPDATE_PERIOD + 1);

        controller.updateMonthlyConfig(_defaultConfig(3200)); // +2% from default 3000

        HybridMintController.MonthlyConfig memory current = controller.getCurrentConfig();
        assertEq(current.baseLPRatioBPS, 3200);
    }

    function test_UpdateMonthlyConfig_RevertIf_TooFrequent() public {
        // Don't wait for update period
        vm.expectRevert(HybridMintController.ConfigUpdateTooFrequent.selector);
        controller.updateMonthlyConfig(_defaultConfig(3200));
    }

    function test_UpdateMonthlyConfig_RevertIf_RateLimitExceeded() public {
        vm.warp(block.timestamp + CONFIG_UPDATE_PERIOD + 1);

        // Try to change baseLPRatioBPS by more than 5% (500 BPS)
        vm.expectRevert(abi.encodeWithSelector(HybridMintController.RateLimitExceeded.selector, "baseLPRatioBPS"));
        controller.updateMonthlyConfig(_defaultConfig(4000)); // +10% from default 3000
    }

    function test_UpdateMonthlyConfig_RevertIf_NotOwner() public {
        vm.warp(block.timestamp + CONFIG_UPDATE_PERIOD + 1);

        HybridMintController.MonthlyConfig memory newConfig = _defaultConfig(3200);
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

        uint256 vaultId = _mint(alice, amount);

        assertEq(vault.ownerOf(vaultId), alice);
        assertGt(vault.collateralAmount(vaultId), 0);
        assertGt(escrow.escrowAmount(vaultId), 0);
    }
}
