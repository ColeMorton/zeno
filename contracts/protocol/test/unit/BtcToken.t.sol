// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BtcToken} from "../../src/BtcToken.sol";

contract BtcTokenTest is Test {
    BtcToken public btcToken;
    address public vault;
    address public user;

    function setUp() public {
        vault = makeAddr("vault");
        user = makeAddr("user");
        btcToken = new BtcToken(vault);
    }

    function test_Name() public view {
        assertEq(btcToken.name(), "vBTC");
    }

    function test_Symbol() public view {
        assertEq(btcToken.symbol(), "vBTC");
    }

    function test_Decimals() public view {
        assertEq(btcToken.decimals(), 8);
    }

    function test_VaultAddress() public view {
        assertEq(btcToken.vault(), vault);
    }

    function test_Mint_AsVault() public {
        uint256 amount = 1e8;

        vm.prank(vault);
        btcToken.mint(user, amount);

        assertEq(btcToken.balanceOf(user), amount);
        assertEq(btcToken.totalSupply(), amount);
    }

    function test_Mint_RevertIf_NotVault() public {
        vm.prank(user);
        vm.expectRevert(BtcToken.OnlyVault.selector);
        btcToken.mint(user, 1e8);
    }

    function test_BurnFrom_AsVault() public {
        uint256 mintAmount = 1e8;
        uint256 burnAmount = 5e7;

        vm.prank(vault);
        btcToken.mint(user, mintAmount);

        vm.prank(vault);
        btcToken.burnFrom(user, burnAmount);

        assertEq(btcToken.balanceOf(user), mintAmount - burnAmount);
        assertEq(btcToken.totalSupply(), mintAmount - burnAmount);
    }

    function test_BurnFrom_RevertIf_NotVault() public {
        vm.prank(vault);
        btcToken.mint(user, 1e8);

        vm.prank(user);
        vm.expectRevert(BtcToken.OnlyVault.selector);
        btcToken.burnFrom(user, 1e8);
    }

    function test_Transfer() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1e8;

        vm.prank(vault);
        btcToken.mint(user, amount);

        vm.prank(user);
        btcToken.transfer(recipient, amount);

        assertEq(btcToken.balanceOf(user), 0);
        assertEq(btcToken.balanceOf(recipient), amount);
    }

    function testFuzz_Mint(uint256 amount) public {
        vm.assume(amount <= type(uint256).max / 2);

        vm.prank(vault);
        btcToken.mint(user, amount);

        assertEq(btcToken.balanceOf(user), amount);
    }

    function testFuzz_BurnFrom(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount <= type(uint256).max / 2);
        vm.assume(burnAmount <= mintAmount);

        vm.prank(vault);
        btcToken.mint(user, mintAmount);

        vm.prank(vault);
        btcToken.burnFrom(user, burnAmount);

        assertEq(btcToken.balanceOf(user), mintAmount - burnAmount);
    }
}
