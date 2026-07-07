// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {BaseTest} from "../utils/BaseTest.sol";

contract SecurityTest is BaseTest {
    address public attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        _fundUser(attacker, 100); // treasures 300-399
    }

    function test_Security_NonOwnerCannotWithdraw() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.withdraw(tokenId);

        assertEq(vault.collateralAmount(tokenId), ONE_BTC);
    }

    function test_Security_NonOwnerCannotRedeem() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.earlyRedeem(tokenId);

        assertEq(vault.ownerOf(tokenId), alice);
    }

    function test_Security_NonOwnerCannotStrip() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.strip(tokenId, ONE_BTC);

        assertEq(vault.strippedReserve(tokenId), 0);
    }

    function test_Security_NonOwnerCannotRecombine() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        // Attacker even holds the vBTC: still cannot recombine someone else's vault
        vm.prank(alice);
        btcToken.transfer(attacker, ONE_BTC);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.recombine(tokenId, ONE_BTC);

        assertEq(vault.strippedReserve(tokenId), ONE_BTC);
    }

    function test_Security_NonOwnerCannotProveActivity() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.proveActivity(tokenId);
    }

    function test_Security_NonOwnerCannotClaimMatch() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, bobToken));
        vault.claimMatch(bobToken);
    }

    function test_Security_CannotClaimDormantWithoutBtcToken() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, 0));
        vault.claimDormantCollateral(tokenId, ONE_BTC);
    }

    function test_Security_DormantClaimCappedByBtcTokenBalance() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        // Attacker holds only half the float: cannot claim the full reserve
        vm.startPrank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);
        btcToken.transfer(attacker, ONE_BTC / 2);
        vm.stopPrank();

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(attacker);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, ONE_BTC / 2)
        );
        vault.claimDormantCollateral(tokenId, ONE_BTC);

        // But the fractional claim up to their balance succeeds
        vm.prank(attacker);
        uint256 claimed = vault.claimDormantCollateral(tokenId, ONE_BTC / 2);
        assertEq(claimed, ONE_BTC / 2);
    }

    function test_Security_SecondClaimMatchReturnsZero() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.prank(bob);
        uint256 first = vault.claimMatch(bobToken);
        assertGt(first, 0);

        // Settlement is idempotent: no double-claim possible
        vm.prank(bob);
        assertEq(vault.claimMatch(bobToken), 0);
    }

    function test_Security_CannotDoublePoke() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(attacker);
        vault.pokeDormant(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.AlreadyPoked.selector, tokenId));
        vault.pokeDormant(tokenId);
    }

    function test_Security_CannotPokeBurnedVault() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(tokenId);

        vm.prank(attacker);
        vm.expectRevert();
        vault.pokeDormant(tokenId);
    }

    function test_Security_CannotWithdrawFromBurnedVault() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.earlyRedeem(tokenId);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(tokenId);
    }

    function test_Security_OnlyVaultCanMintBtcToken() public {
        vm.prank(attacker);
        vm.expectRevert();
        btcToken.mint(attacker, ONE_BTC);
    }

    function test_Security_OnlyVaultCanBurnBtcToken() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(attacker);
        vm.expectRevert();
        btcToken.burnFrom(alice, ONE_BTC);
    }
}
