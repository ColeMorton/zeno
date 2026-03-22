// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {ExpeditionCredits} from "../../src/ExpeditionCredits.sol";
import {IExpeditionCredits} from "../../src/interfaces/IExpeditionCredits.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract ExpeditionCreditsTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    ExpeditionCredits public xbtc;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public admin;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1129 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        admin = address(this);

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        xbtc = new ExpeditionCredits(vaultAddr, admin);
        vault = new VaultNFT(address(btcToken), address(xbtc), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);
        treasure.mintBatch(bob, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();

        vm.startPrank(bob);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    // ========== Constructor ==========

    function test_constructor_setsImmutables() public view {
        assertEq(xbtc.vault(), address(vault));
        assertEq(xbtc.admin(), admin);
        assertEq(xbtc.bootstrapEnd(), block.timestamp + VESTING_PERIOD);
        assertEq(xbtc.decimals(), 8);
    }

    function test_constructor_revertsZeroVault() public {
        vm.expectRevert(IExpeditionCredits.ZeroAddress.selector);
        new ExpeditionCredits(address(0), admin);
    }

    function test_constructor_revertsZeroAdmin() public {
        vm.expectRevert(IExpeditionCredits.ZeroAddress.selector);
        new ExpeditionCredits(address(1), address(0));
    }

    function test_tokenMetadata() public view {
        assertEq(xbtc.name(), "Expedition Credits");
        assertEq(xbtc.symbol(), "xBTC");
        assertEq(xbtc.decimals(), 8);
    }

    // ========== Minting on Vault Creation ==========

    function test_mint_xbtcOnVaultCreation() public {
        uint256 collateral = 5 * ONE_BTC;

        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), collateral);

        assertEq(xbtc.balanceOf(alice), collateral);
    }

    function test_mint_multipleVaults() public {
        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 3 * ONE_BTC);

        vm.prank(alice);
        vault.mint(address(treasure), 1, address(wbtc), 2 * ONE_BTC);

        assertEq(xbtc.balanceOf(alice), 5 * ONE_BTC);
    }

    function test_mint_differentUsers() public {
        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        vm.prank(bob);
        vault.mint(address(treasure), 10, address(wbtc), 3 * ONE_BTC);

        assertEq(xbtc.balanceOf(alice), 5 * ONE_BTC);
        assertEq(xbtc.balanceOf(bob), 3 * ONE_BTC);
    }

    function test_mint_onlyVaultCanMint() public {
        vm.expectRevert(IExpeditionCredits.OnlyVault.selector);
        xbtc.mint(alice, ONE_BTC);
    }

    // ========== Bootstrap Phase Cutoff ==========

    function test_mint_duringBootstrap() public {
        // Warp to just before bootstrap end
        vm.warp(xbtc.bootstrapEnd());

        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        assertEq(xbtc.balanceOf(alice), ONE_BTC);
    }

    function test_mint_afterBootstrapNoXbtc() public {
        // Warp past bootstrap end
        vm.warp(xbtc.bootstrapEnd() + 1);

        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        // Vault minted successfully but no xBTC
        assertEq(xbtc.balanceOf(alice), 0);
    }

    // ========== Transfer Restrictions ==========

    function test_transfer_walletToWallet() public {
        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        vm.prank(alice);
        xbtc.transfer(bob, 2 * ONE_BTC);

        assertEq(xbtc.balanceOf(alice), 3 * ONE_BTC);
        assertEq(xbtc.balanceOf(bob), 2 * ONE_BTC);
    }

    function test_transfer_toWhitelistedContract() public {
        address whitelistedPool = address(new MockPool());
        xbtc.addToWhitelist(whitelistedPool);

        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        vm.prank(alice);
        xbtc.transfer(whitelistedPool, 2 * ONE_BTC);

        assertEq(xbtc.balanceOf(whitelistedPool), 2 * ONE_BTC);
    }

    function test_transfer_revertsToNonWhitelistedContract() public {
        address nonWhitelisted = address(new MockPool());

        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IExpeditionCredits.RecipientNotWhitelisted.selector, nonWhitelisted));
        xbtc.transfer(nonWhitelisted, 2 * ONE_BTC);
    }

    function test_transfer_revertsFromNonWhitelistedContract() public {
        address nonWhitelisted = address(new MockPool());
        xbtc.addToWhitelist(nonWhitelisted);

        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        // Transfer to the contract (whitelisted)
        vm.prank(alice);
        xbtc.transfer(nonWhitelisted, 2 * ONE_BTC);

        // Remove from whitelist
        xbtc.removeFromWhitelist(nonWhitelisted);

        // Contract tries to transfer out — reverts
        vm.prank(nonWhitelisted);
        vm.expectRevert(abi.encodeWithSelector(IExpeditionCredits.SenderNotWhitelisted.selector, nonWhitelisted));
        xbtc.transfer(alice, 2 * ONE_BTC);
    }

    // ========== Whitelist Management ==========

    function test_whitelist_addAndRemove() public {
        address pool = address(new MockPool());

        assertFalse(xbtc.isWhitelisted(pool));

        xbtc.addToWhitelist(pool);
        assertTrue(xbtc.isWhitelisted(pool));

        xbtc.removeFromWhitelist(pool);
        assertFalse(xbtc.isWhitelisted(pool));
    }

    function test_whitelist_onlyAdmin() public {
        address pool = address(new MockPool());

        vm.prank(alice);
        vm.expectRevert(IExpeditionCredits.OnlyAdmin.selector);
        xbtc.addToWhitelist(pool);

        vm.prank(alice);
        vm.expectRevert(IExpeditionCredits.OnlyAdmin.selector);
        xbtc.removeFromWhitelist(pool);
    }

    function test_whitelist_revertsZeroAddress() public {
        vm.expectRevert(IExpeditionCredits.ZeroAddress.selector);
        xbtc.addToWhitelist(address(0));
    }

    function test_whitelist_emitsEvents() public {
        address pool = address(new MockPool());

        vm.expectEmit(true, false, false, false);
        emit IExpeditionCredits.Whitelisted(pool);
        xbtc.addToWhitelist(pool);

        vm.expectEmit(true, false, false, false);
        emit IExpeditionCredits.RemovedFromWhitelist(pool);
        xbtc.removeFromWhitelist(pool);
    }

    // ========== Early Redemption Keeps xBTC ==========

    function test_earlyRedeem_keepsXbtc() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        uint256 xbtcBefore = xbtc.balanceOf(alice);
        assertEq(xbtcBefore, 5 * ONE_BTC);

        // Skip some time and early redeem
        vm.warp(block.timestamp + 365 days);
        vm.prank(alice);
        vault.earlyRedeem(tokenId);

        // xBTC balance unchanged after early redemption
        assertEq(xbtc.balanceOf(alice), xbtcBefore);
    }

    // ========== Supply Tracking ==========

    function test_totalSupply_tracksMintsAcrossUsers() public {
        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        vm.prank(bob);
        vault.mint(address(treasure), 10, address(wbtc), 3 * ONE_BTC);

        assertEq(xbtc.totalSupply(), 8 * ONE_BTC);
    }
}

/// @dev Simple contract to test transfer restrictions
contract MockPool {
    // Empty contract with code — used to test contract vs EOA detection
}
