// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ApprovalVerifier} from "../../../src/verifiers/ApprovalVerifier.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ApprovalVerifierTest is Test {
    MockERC20 public token;
    ApprovalVerifier public verifier;

    address public owner = address(this);
    address public user = address(0xBEEF);
    address public spender = address(0xCAFE);

    function setUp() public {
        token = new MockERC20();
        verifier = new ApprovalVerifier(address(token), spender, 0);

        token.mint(user, 1000e18);
    }

    function test_Verify_ReturnsFalse_WhenNoApproval() public view {
        bool result = verifier.verify(user, bytes32(0), "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenHasApproval() public {
        vm.prank(user);
        token.approve(spender, 100e18);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Verify_ReturnsFalse_WhenApprovalBelowMin() public {
        // Set minimum approval amount
        verifier.setMinApprovalAmount(100e18);

        vm.prank(user);
        token.approve(spender, 50e18);

        bool result = verifier.verify(user, bytes32(0), "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenApprovalAtMin() public {
        verifier.setMinApprovalAmount(100e18);

        vm.prank(user);
        token.approve(spender, 100e18);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Verify_ReturnsTrue_WhenApprovalAboveMin() public {
        verifier.setMinApprovalAmount(100e18);

        vm.prank(user);
        token.approve(spender, 200e18);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_SetMinApprovalAmount_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setMinApprovalAmount(100e18);
    }

    function test_Constructor_RevertsOnZeroToken() public {
        vm.expectRevert(ApprovalVerifier.ZeroAddress.selector);
        new ApprovalVerifier(address(0), spender, 0);
    }

    function test_Constructor_RevertsOnZeroSpender() public {
        vm.expectRevert(ApprovalVerifier.ZeroAddress.selector);
        new ApprovalVerifier(address(token), address(0), 0);
    }

    function test_Verify_UnlimitedApproval() public {
        vm.prank(user);
        token.approve(spender, type(uint256).max);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }
}
