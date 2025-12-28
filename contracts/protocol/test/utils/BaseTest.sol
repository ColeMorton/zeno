// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

abstract contract BaseTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public charlie;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;
    uint256 internal constant DORMANCY_THRESHOLD = 365 days;
    uint256 internal constant GRACE_PERIOD = 30 days;

    function setUp() public virtual {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        _fundUser(alice, 1000);
        _fundUser(bob, 1000);
        _fundUser(charlie, 1000);
    }

    function _fundUser(address user, uint256 btcAmount) internal {
        wbtc.mint(user, btcAmount * ONE_BTC);
        treasure.mintBatch(user, 100);
        _approveAll(user);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function _mintVault(address user, uint256 treasureId, uint256 collateral) internal returns (uint256) {
        vm.prank(user);
        return vault.mint(address(treasure), treasureId, address(wbtc), collateral);
    }

    function _skipVesting() internal {
        vm.warp(block.timestamp + VESTING_PERIOD);
    }

    function _skipWithdrawalPeriod() internal {
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
    }
}
