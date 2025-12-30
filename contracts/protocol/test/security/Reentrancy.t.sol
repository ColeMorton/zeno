// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";
import {MaliciousDelegate} from "../mocks/MaliciousDelegate.sol";

contract ReentrancyTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;
    MaliciousDelegate public maliciousDelegate;

    address public alice;
    address public bob;
    address public charlie;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        // Fund alice
        wbtc.mint(alice, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();

        // Deploy malicious delegate
        maliciousDelegate = new MaliciousDelegate(vault, wbtc);
    }

    function test_WithdrawAsDelegate_NoReentrancy() public {
        // Alice mints a vault
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        // Alice grants 50% delegation to malicious delegate (wallet-level)
        vm.prank(alice);
        vault.grantWithdrawalDelegate(address(maliciousDelegate), 5000);

        // Skip to vested state
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Record balances before
        uint256 vaultBalanceBefore = wbtc.balanceOf(address(vault));
        uint256 collateralBefore = vault.collateralAmount(tokenId);

        // Malicious delegate attempts withdrawal (may try reentrancy in receive)
        maliciousDelegate.attemptWithdrawal(tokenId);

        // Verify state consistency
        uint256 vaultBalanceAfter = wbtc.balanceOf(address(vault));
        uint256 collateralAfter = vault.collateralAmount(tokenId);

        // Collateral should have decreased by withdrawal amount
        uint256 withdrawn = vaultBalanceBefore - vaultBalanceAfter;
        assertEq(collateralBefore - collateralAfter, withdrawn);

        // Malicious delegate should not have gotten extra funds
        uint256 delegateBalance = wbtc.balanceOf(address(maliciousDelegate));
        assertEq(delegateBalance, withdrawn);
    }

    function test_WithdrawAsDelegate_StateUpdateBeforeTransfer() public {
        // Verify that state is updated before external call

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 5000);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 collateralBefore = vault.collateralAmount(tokenId);

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);

        uint256 collateralAfter = vault.collateralAmount(tokenId);

        // State update should reflect withdrawal
        assertEq(collateralBefore - collateralAfter, withdrawn);
    }

    function test_EarlyRedeem_StateConsistency() public {
        // Test that early redemption maintains state consistency

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        // Warp to midpoint
        vm.warp(block.timestamp + 546 days);

        uint256 vaultBalanceBefore = wbtc.balanceOf(address(vault));
        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        uint256 vaultBalanceAfter = wbtc.balanceOf(address(vault));
        uint256 aliceBalanceAfter = wbtc.balanceOf(alice);

        // Conservation check
        assertEq(returned + forfeited, 10 * ONE_BTC);

        // Vault should have forfeited amount in match pool
        assertEq(vault.matchPool(), forfeited);

        // Alice should have received returned amount
        assertEq(aliceBalanceAfter - aliceBalanceBefore, returned);

        // Vault balance should match match pool
        assertEq(vaultBalanceAfter, forfeited);
    }

    function test_ClaimDormant_RequiresBtcToken() public {
        // Test that dormancy claim requires BTC token burn
        // Dormancy threshold: 1129 days, Grace period: 30 days

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        // Skip to vested (1129 days from mint)
        uint256 vestedTime = block.timestamp + VESTING_PERIOD;
        vm.warp(vestedTime);

        // Mint BTC token (required for dormancy eligibility)
        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        // CRITICAL: Transfer BTC token away - this makes vault dormant-eligible
        // Dormancy requires owner's BTC token balance < minted amount
        vm.prank(alice);
        btcToken.transfer(bob, 10 * ONE_BTC);

        // Skip to dormant state (1129 days from last activity which was mintBtcToken)
        uint256 dormantTime = vestedTime + VESTING_PERIOD; // VESTING_PERIOD = DORMANCY_THRESHOLD = 1129 days
        vm.warp(dormantTime);

        // Bob pokes dormancy
        vm.prank(bob);
        vault.pokeDormant(tokenId);

        // Skip grace period (30 days)
        uint256 claimableTime = dormantTime + 30 days;
        vm.warp(claimableTime);

        // Charlie tries to claim without BTC token - should fail
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, 10 * ONE_BTC, 0));
        vault.claimDormantCollateral(tokenId);

        // Bob has the BTC token, so bob can claim
        uint256 bobWbtcBefore = wbtc.balanceOf(bob);
        vm.prank(bob);
        vault.claimDormantCollateral(tokenId);
        uint256 bobWbtcAfter = wbtc.balanceOf(bob);

        assertEq(bobWbtcAfter - bobWbtcBefore, 10 * ONE_BTC);
        assertEq(btcToken.balanceOf(bob), 0); // BTC token was burned
    }

    function test_MultipleWithdrawals_NoDoubleSpend() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        // First withdrawal
        vm.prank(alice);
        uint256 first = vault.withdraw(tokenId);
        assertGt(first, 0);

        // Immediate second withdrawal should fail
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(tokenId);

        // Wait for period
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        // Now should work
        vm.prank(alice);
        uint256 second = vault.withdraw(tokenId);
        assertGt(second, 0);
        assertLt(second, first); // Less because collateral decreased
    }
}
