// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {IVaultNFT} from "../src/interfaces/IVaultNFT.sol";
import {MockTreasure} from "./mocks/MockTreasure.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";

contract SecurityTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public attacker;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1093 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;
    uint256 constant DORMANCY_THRESHOLD = 1093 days;
    uint256 constant GRACE_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address[] memory acceptedTokens = new address[](1);
        acceptedTokens[0] = address(wbtc);

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr);
        vault = new VaultNFT(address(btcToken), acceptedTokens, 0);

        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        wbtc.mint(attacker, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);
        treasure.mintBatch(bob, 10);
        treasure.mintBatch(attacker, 10);

        _approveAll(alice);
        _approveAll(bob);
        _approveAll(attacker);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function test_Security_NonOwnerCannotWithdraw() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.withdraw(tokenId);

        assertEq(vault.collateralAmount(tokenId), ONE_BTC);
    }

    function test_Security_NonOwnerCannotRedeem() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + 500 days);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.earlyRedeem(tokenId);

        assertEq(vault.ownerOf(tokenId), alice);
    }

    function test_Security_NonOwnerCannotMintBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.mintBtcToken(tokenId);

        assertEq(vault.btcTokenAmount(tokenId), 0);
    }

    function test_Security_NonOwnerCannotReturnBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(attacker, ONE_BTC);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.returnBtcToken(tokenId);

        assertEq(vault.btcTokenAmount(tokenId), ONE_BTC);
    }

    function test_Security_NonOwnerCannotProveActivity() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.proveActivity(tokenId);
    }

    function test_Security_NonOwnerCannotClaimMatch() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, bobToken));
        vault.claimMatch(bobToken);
    }

    function test_Security_CannotClaimDormantWithoutBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, 0));
        vault.claimDormantCollateral(tokenId);
    }

    function test_Security_CannotClaimDormantWithPartialBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.prank(alice);
        btcToken.transfer(attacker, ONE_BTC / 2);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(attacker);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, ONE_BTC / 2)
        );
        vault.claimDormantCollateral(tokenId);
    }

    function test_Security_DoubleClaimMatch() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        vault.claimMatch(bobToken);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.AlreadyClaimed.selector, bobToken));
        vault.claimMatch(bobToken);
    }

    function test_Security_CannotDoublePoke() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

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
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(tokenId);

        vm.prank(attacker);
        vm.expectRevert();
        vault.pokeDormant(tokenId);
    }

    function test_Security_CannotWithdrawFromBurnedVault() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

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
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(attacker);
        vm.expectRevert();
        btcToken.burnFrom(alice, ONE_BTC);
    }
}
