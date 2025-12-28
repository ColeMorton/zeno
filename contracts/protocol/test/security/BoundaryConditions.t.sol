// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract BoundaryConditionsTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;
    uint256 internal constant DORMANCY_THRESHOLD = 1129 days;
    uint256 internal constant GRACE_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        wbtc.mint(alice, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    // ========== VESTING_PERIOD Boundary Tests ==========

    function test_Vesting_OneDayBefore() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 mintTime = block.timestamp;

        // 1 day before vesting
        vm.warp(mintTime + VESTING_PERIOD - 1 days);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.withdraw(tokenId);
    }

    function test_Vesting_ExactlyAt() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 mintTime = block.timestamp;

        // Exactly at vesting
        vm.warp(mintTime + VESTING_PERIOD);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_Vesting_OneDayAfter() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 mintTime = block.timestamp;

        // 1 day after vesting
        vm.warp(mintTime + VESTING_PERIOD + 1 days);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_Vesting_OneSecondBefore() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 mintTime = block.timestamp;

        // 1 second before vesting
        vm.warp(mintTime + VESTING_PERIOD - 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.withdraw(tokenId);
    }

    // ========== WITHDRAWAL_PERIOD Boundary Tests ==========

    function test_WithdrawalPeriod_OneDayBefore() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        // First withdrawal
        vm.prank(alice);
        vault.withdraw(tokenId);

        // 1 day before next period
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD - 1 days);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(tokenId);
    }

    function test_WithdrawalPeriod_ExactlyAt() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdraw(tokenId);

        // Exactly at next period
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_WithdrawalPeriod_OneDayAfter() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdraw(tokenId);

        // 1 day after next period
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD + 1 days);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    // Note: Dormancy and Grace Period boundary tests are covered in test/unit/Dormancy.t.sol
    // The dormancy eligibility has complex preconditions (BTC token minted + transferred away)

    // ========== Combined Boundary Fuzz Tests ==========

    function testFuzz_VestingBoundary(uint256 offset) public {
        offset = bound(offset, 0, 10 days);

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 mintTime = block.timestamp;

        // Test at vesting - offset
        vm.warp(mintTime + VESTING_PERIOD - offset);

        if (offset > 0) {
            vm.prank(alice);
            vm.expectRevert();
            vault.withdraw(tokenId);
        } else {
            vm.prank(alice);
            vault.withdraw(tokenId);
        }
    }

    function testFuzz_WithdrawalPeriodBoundary(uint256 offset) public {
        offset = bound(offset, 0, 10 days);

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);
        vm.prank(alice);
        vault.withdraw(tokenId);

        // Test at period - offset
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD - offset);

        if (offset > 0) {
            vm.prank(alice);
            vm.expectRevert();
            vault.withdraw(tokenId);
        } else {
            vm.prank(alice);
            vault.withdraw(tokenId);
        }
    }

    // ========== Edge Case: Zero Collateral After Withdrawals ==========

    function test_ZenoParadox_NeverReachesZero() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        // Withdraw 100 times (over 8 years)
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(alice);
            vault.withdraw(tokenId);
            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }

        // Should still have collateral (Zeno's paradox)
        uint256 remaining = vault.collateralAmount(tokenId);
        assertGt(remaining, 0);
    }

    // ========== Edge Case: Timestamp Overflow Protection ==========

    function test_TimestampOverflow_Protected() public pure {
        // Test that time calculations don't overflow
        uint256 maxTimestamp = type(uint64).max;

        // isVested shouldn't overflow
        bool vested = VaultMath.isVested(maxTimestamp - VESTING_PERIOD, maxTimestamp);
        assertTrue(vested);

        // canWithdraw shouldn't overflow
        bool canWithdraw = VaultMath.canWithdraw(maxTimestamp - WITHDRAWAL_PERIOD, maxTimestamp);
        assertTrue(canWithdraw);

        // isDormant shouldn't overflow
        bool dormant = VaultMath.isDormant(maxTimestamp - DORMANCY_THRESHOLD, maxTimestamp);
        assertTrue(dormant);
    }

    // ========== Edge Case: Minimum Collateral Amounts ==========

    function test_MinimumCollateral_Withdrawal() public {
        // Mint with minimum collateral that produces non-zero withdrawal
        // rate = 1000, basis = 100000
        // collateral * 1000 / 100000 >= 1
        // collateral >= 100 satoshis
        uint256 minCollateral = 100;

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), minCollateral);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_DustCollateral_ZeroWithdrawal() public {
        // 1 satoshi should produce 0 withdrawal
        uint256 dustCollateral = 1;

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), dustCollateral);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertEq(withdrawn, 0);
    }
}
