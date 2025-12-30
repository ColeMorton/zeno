// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {SablierStreamWrapper} from "../../src/SablierStreamWrapper.sol";
import {ISablierStreamWrapper} from "../../src/interfaces/ISablierStreamWrapper.sol";
import {MockSablierV2LockupLinear} from "../mocks/MockSablierV2LockupLinear.sol";
import {MockVaultNFTWithDelegation} from "../mocks/MockVaultNFTWithDelegation.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract SablierStreamWrapperTest is Test {
    SablierStreamWrapper public wrapper;
    MockSablierV2LockupLinear public sablier;
    MockVaultNFTWithDelegation public vaultNFT;
    MockWBTC public wbtc;

    address public owner;
    address public recipient;
    address public alice;

    uint256 public constant INITIAL_COLLATERAL = 100e8; // 100 WBTC
    uint256 public constant FULL_DELEGATION = 10000; // 100%

    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        alice = makeAddr("alice");

        // Deploy mocks
        wbtc = new MockWBTC();
        vaultNFT = new MockVaultNFTWithDelegation(address(wbtc));
        sablier = new MockSablierV2LockupLinear();

        // Deploy wrapper
        wrapper = new SablierStreamWrapper(address(vaultNFT), address(sablier));

        // Setup: mint WBTC to owner and create a vault
        wbtc.mint(owner, INITIAL_COLLATERAL);

        vm.startPrank(owner);
        wbtc.approve(address(vaultNFT), INITIAL_COLLATERAL);
        vaultNFT.mint(INITIAL_COLLATERAL);
        vm.stopPrank();

        // Grant delegation to wrapper
        vm.prank(owner);
        vaultNFT.grantWithdrawalDelegate(address(wrapper), FULL_DELEGATION);
    }

    function test_Constructor() public view {
        assertEq(wrapper.vaultNFT(), address(vaultNFT));
        assertEq(wrapper.sablier(), address(sablier));
        assertEq(wrapper.STREAM_DURATION(), 30 days);
    }

    function test_Constructor_RevertIf_ZeroVaultNFT() public {
        vm.expectRevert(ISablierStreamWrapper.ZeroAddress.selector);
        new SablierStreamWrapper(address(0), address(sablier));
    }

    function test_Constructor_RevertIf_ZeroSablier() public {
        vm.expectRevert(ISablierStreamWrapper.ZeroAddress.selector);
        new SablierStreamWrapper(address(vaultNFT), address(0));
    }

    function test_ConfigureVault() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        ISablierStreamWrapper.VaultStreamConfig memory config = wrapper.getVaultConfig(0);
        assertEq(config.recipient, recipient);
        assertTrue(config.streamEnabled);
    }

    function test_ConfigureVault_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit ISablierStreamWrapper.VaultConfigured(0, recipient, true);
        wrapper.configureVault(0, recipient, true);
    }

    function test_ConfigureVault_RevertIf_NotVaultOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ISablierStreamWrapper.NotVaultOwner.selector, 0));
        wrapper.configureVault(0, recipient, true);
    }

    function test_ConfigureVault_RevertIf_ZeroRecipient() public {
        vm.prank(owner);
        vm.expectRevert(ISablierStreamWrapper.ZeroAddress.selector);
        wrapper.configureVault(0, address(0), true);
    }

    function test_CreateStreamFromVault() public {
        // Configure vault for streaming
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        // Set vault as vested and withdrawable
        vaultNFT.setVested(0, true);

        // Fund VaultNFT with collateral to withdraw
        uint256 expectedWithdrawal = INITIAL_COLLATERAL / 100; // 1%
        wbtc.mint(address(vaultNFT), expectedWithdrawal);

        // Create stream
        uint256 streamId = wrapper.createStreamFromVault(0);

        // Verify stream was created
        assertEq(streamId, 0);
        assertEq(sablier.getRecipient(streamId), recipient);
        assertEq(sablier.getDepositedAmount(streamId), uint128(expectedWithdrawal));

        // Verify wrapper tracked stream
        uint256[] memory streams = wrapper.getVaultStreams(0);
        assertEq(streams.length, 1);
        assertEq(streams[0], streamId);

        // Verify config updated
        ISablierStreamWrapper.VaultStreamConfig memory config = wrapper.getVaultConfig(0);
        assertEq(config.lastStreamId, streamId);
    }

    function test_CreateStreamFromVault_EmitsEvent() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        vaultNFT.setVested(0, true);
        uint256 expectedWithdrawal = INITIAL_COLLATERAL / 100;
        wbtc.mint(address(vaultNFT), expectedWithdrawal);

        vm.expectEmit(true, true, true, true);
        emit ISablierStreamWrapper.StreamCreated(
            0,
            0,
            recipient,
            expectedWithdrawal,
            30 days
        );
        wrapper.createStreamFromVault(0);
    }

    function test_CreateStreamFromVault_RevertIf_NotConfigured() public {
        vm.expectRevert(abi.encodeWithSelector(ISablierStreamWrapper.VaultNotConfigured.selector, 0));
        wrapper.createStreamFromVault(0);
    }

    function test_CreateStreamFromVault_RevertIf_StreamingDisabled() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, false);

        vm.expectRevert(abi.encodeWithSelector(ISablierStreamWrapper.StreamingDisabled.selector, 0));
        wrapper.createStreamFromVault(0);
    }

    function test_CanCreateStream() public {
        // Not configured
        (bool canCreate, uint256 amount) = wrapper.canCreateStream(0);
        assertFalse(canCreate);
        assertEq(amount, 0);

        // Configure but not vested
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        (canCreate, amount) = wrapper.canCreateStream(0);
        assertFalse(canCreate);

        // Vested
        vaultNFT.setVested(0, true);
        (canCreate, amount) = wrapper.canCreateStream(0);
        assertTrue(canCreate);
        assertGt(amount, 0);
    }

    function test_CanCreateStream_ReturnsFalse_WhenDisabled() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, false);

        vaultNFT.setVested(0, true);

        (bool canCreate, uint256 amount) = wrapper.canCreateStream(0);
        assertFalse(canCreate);
        assertEq(amount, 0);
    }

    function test_BatchCreateStreams() public {
        // Create second vault
        wbtc.mint(owner, INITIAL_COLLATERAL);
        vm.startPrank(owner);
        wbtc.approve(address(vaultNFT), INITIAL_COLLATERAL);
        vaultNFT.mint(INITIAL_COLLATERAL);

        // Grant delegation for new vault
        vaultNFT.grantWithdrawalDelegate(address(wrapper), FULL_DELEGATION);

        // Configure both vaults
        wrapper.configureVault(0, recipient, true);
        wrapper.configureVault(1, recipient, true);
        vm.stopPrank();

        // Set both as vested
        vaultNFT.setVested(0, true);
        vaultNFT.setVested(1, true);

        // Fund VaultNFT
        uint256 expectedWithdrawal = INITIAL_COLLATERAL / 100;
        wbtc.mint(address(vaultNFT), expectedWithdrawal * 2);

        // Batch create streams
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory streamIds = wrapper.batchCreateStreams(tokenIds);

        assertEq(streamIds.length, 2);
        assertEq(streamIds[0], 0);
        assertEq(streamIds[1], 1);
    }

    function test_BatchCreateStreams_SkipsIneligible() public {
        // Create second vault
        wbtc.mint(owner, INITIAL_COLLATERAL);
        vm.startPrank(owner);
        wbtc.approve(address(vaultNFT), INITIAL_COLLATERAL);
        vaultNFT.mint(INITIAL_COLLATERAL);
        vaultNFT.grantWithdrawalDelegate(address(wrapper), FULL_DELEGATION);

        // Only configure vault 0
        wrapper.configureVault(0, recipient, true);
        vm.stopPrank();

        // Set vault 0 as vested (vault 1 not configured)
        vaultNFT.setVested(0, true);

        // Fund VaultNFT
        wbtc.mint(address(vaultNFT), INITIAL_COLLATERAL / 100);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory streamIds = wrapper.batchCreateStreams(tokenIds);

        // Only vault 0 should have a stream
        assertEq(streamIds[0], 0);
        assertEq(streamIds[1], 0); // Skipped, returns 0
    }

    function test_GetVaultStreams_MultipleStreams() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        vaultNFT.setVested(0, true);

        // Create first stream
        wbtc.mint(address(vaultNFT), INITIAL_COLLATERAL / 100);
        wrapper.createStreamFromVault(0);

        // Warp time past cooldown
        vm.warp(block.timestamp + 31 days);

        // Create second stream
        wbtc.mint(address(vaultNFT), INITIAL_COLLATERAL / 100);
        wrapper.createStreamFromVault(0);

        uint256[] memory streams = wrapper.getVaultStreams(0);
        assertEq(streams.length, 2);
        assertEq(streams[0], 0);
        assertEq(streams[1], 1);
    }

    function test_StreamLinearUnlock() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        vaultNFT.setVested(0, true);
        uint256 expectedWithdrawal = INITIAL_COLLATERAL / 100;
        wbtc.mint(address(vaultNFT), expectedWithdrawal);

        wrapper.createStreamFromVault(0);

        // Initially nothing withdrawable (time = 0)
        assertEq(sablier.withdrawableAmountOf(0), 0);

        // After 15 days, ~50% should be withdrawable
        vm.warp(block.timestamp + 15 days);
        uint256 halfwayAmount = sablier.withdrawableAmountOf(0);
        assertApproxEqAbs(halfwayAmount, expectedWithdrawal / 2, 1);

        // After 30 days, 100% should be withdrawable
        vm.warp(block.timestamp + 15 days);
        assertEq(sablier.withdrawableAmountOf(0), uint128(expectedWithdrawal));

        // Recipient can withdraw
        vm.prank(recipient);
        uint256 withdrawn = sablier.withdrawMax(0, recipient);
        assertEq(withdrawn, expectedWithdrawal);
        assertEq(wbtc.balanceOf(recipient), expectedWithdrawal);
    }

    function test_StreamNFT_Transferable() public {
        vm.prank(owner);
        wrapper.configureVault(0, recipient, true);

        vaultNFT.setVested(0, true);
        wbtc.mint(address(vaultNFT), INITIAL_COLLATERAL / 100);

        wrapper.createStreamFromVault(0);

        // Recipient owns stream NFT
        assertEq(sablier.ownerOf(0), recipient);

        // Can transfer to alice
        vm.prank(recipient);
        sablier.transferFrom(recipient, alice, 0);

        assertEq(sablier.ownerOf(0), alice);
    }
}
