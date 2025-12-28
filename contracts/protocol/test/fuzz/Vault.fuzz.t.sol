// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract InvariantsTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public charlie;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1129 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        wbtc.mint(alice, 1000 * ONE_BTC);
        wbtc.mint(bob, 1000 * ONE_BTC);
        wbtc.mint(charlie, 1000 * ONE_BTC);
        treasure.mintBatch(alice, 100);
        treasure.mintBatch(bob, 100);
        treasure.mintBatch(charlie, 100);

        _approveAll(alice);
        _approveAll(bob);
        _approveAll(charlie);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function testFuzz_Invariant_NoFreeMoney(
        uint256 depositAmount,
        uint256 withdrawCount,
        uint256 matchClaimAmount
    ) public {
        depositAmount = bound(depositAmount, 1e6, 100 * ONE_BTC);
        withdrawCount = bound(withdrawCount, 0, 50);
        matchClaimAmount = bound(matchClaimAmount, 0, 10 * ONE_BTC);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), depositAmount);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < withdrawCount; i++) {
            vm.prank(alice);
            uint256 withdrawn = vault.withdraw(tokenId);
            totalWithdrawn += withdrawn;
            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }

        uint256 remainingCollateral = vault.collateralAmount(tokenId);

        assertLe(
            totalWithdrawn + remainingCollateral,
            depositAmount,
            "Cannot withdraw more than deposited"
        );

        uint256 aliceWbtcAfter = wbtc.balanceOf(alice);
        uint256 aliceNetGain = aliceWbtcAfter - (aliceWbtcBefore - depositAmount);

        assertLe(aliceNetGain, depositAmount, "Net gain cannot exceed deposit");
    }

    function testFuzz_Invariant_CollateralAccounting(
        uint256 aliceDeposit,
        uint256 bobDeposit,
        uint256 charlieDeposit,
        uint256 aliceRedeemDay
    ) public {
        aliceDeposit = bound(aliceDeposit, ONE_BTC, 10 * ONE_BTC);
        bobDeposit = bound(bobDeposit, ONE_BTC, 10 * ONE_BTC);
        charlieDeposit = bound(charlieDeposit, ONE_BTC, 10 * ONE_BTC);
        aliceRedeemDay = bound(aliceRedeemDay, 1, 1092);

        uint256 vaultWbtcBefore = wbtc.balanceOf(address(vault));

        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), aliceDeposit);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 100, address(wbtc), bobDeposit);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 200, address(wbtc), charlieDeposit);

        uint256 totalDeposited = aliceDeposit + bobDeposit + charlieDeposit;

        vm.warp(block.timestamp + aliceRedeemDay * 1 days);

        vm.prank(alice);
        (uint256 aliceReturned, uint256 aliceForfeited) = vault.earlyRedeem(aliceToken);

        uint256 vaultWbtcAfter = wbtc.balanceOf(address(vault));
        uint256 sumCollaterals = vault.collateralAmount(bobToken) + vault.collateralAmount(charlieToken);
        uint256 matchPoolBalance = vault.matchPool();

        assertEq(
            sumCollaterals + matchPoolBalance,
            vaultWbtcAfter,
            "Collateral accounting mismatch"
        );

        assertEq(
            aliceReturned + aliceForfeited,
            aliceDeposit,
            "Early redemption split incorrect"
        );
    }

    function testFuzz_Invariant_Zeno(uint256 withdrawalCount) public {
        withdrawalCount = bound(withdrawalCount, 100, 500);

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        for (uint256 i = 0; i < withdrawalCount; i++) {
            uint256 remaining = vault.collateralAmount(tokenId);
            if (remaining == 0) break;

            vm.prank(alice);
            vault.withdraw(tokenId);

            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }

        uint256 finalRemaining = vault.collateralAmount(tokenId);
        assertGt(finalRemaining, 0, "Collateral should never fully deplete (Zeno's paradox)");
    }

    function testFuzz_Invariant_MatchPoolBalance(
        uint256 deposit1,
        uint256 deposit2,
        uint256 redeemDay
    ) public {
        deposit1 = bound(deposit1, ONE_BTC, 50 * ONE_BTC);
        deposit2 = bound(deposit2, ONE_BTC, 50 * ONE_BTC);
        redeemDay = bound(redeemDay, 1, 1092);

        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), deposit1);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 100, address(wbtc), deposit2);

        assertEq(vault.matchPool(), 0, "Match pool should start at 0");

        vm.warp(block.timestamp + redeemDay * 1 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        assertEq(vault.matchPool(), forfeited, "Match pool should equal forfeited amount");

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 poolBefore = vault.matchPool();
        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobToken);

        assertEq(vault.matchPool(), poolBefore - claimed, "Match pool should decrease by claimed");
        assertGe(vault.matchPool(), 0, "Match pool should never go negative");
    }

    function test_Invariant_TotalActiveCollateral_TracksCorrectly() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 2 * ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 100, address(wbtc), 3 * ONE_BTC);

        assertEq(vault.totalActiveCollateral(), 5 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        vault.claimMatch(bobToken);

        assertEq(vault.totalActiveCollateral(), 0, "Should be 0 after matured vault claims match");
    }

    function test_Invariant_BtcTokenSupply_MatchesOriginalMinted() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        assertEq(btcToken.totalSupply(), 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        assertEq(btcToken.totalSupply(), ONE_BTC);
        assertEq(btcToken.totalSupply(), vault.originalMintedAmount(tokenId));

        vm.prank(alice);
        vault.returnBtcToken(tokenId);

        assertEq(btcToken.totalSupply(), 0);
        assertEq(vault.originalMintedAmount(tokenId), 0);
    }
}
