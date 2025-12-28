// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {VaultMath} from "@protocol/libraries/VaultMath.sol";

/// @title DormancyTest - State machine tests for dormancy mechanics
/// @notice Tests dormancy detection, poke flow, and collateral claims
contract DormancyTest is Test {
    SimulationOrchestrator public orchestrator;

    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;
    TreasureNFT public treasureNFT;

    address public alice;
    address public bob;
    address public charlie;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant DORMANCY_THRESHOLD = 1129 days;
    uint256 internal constant GRACE_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        orchestrator = new SimulationOrchestrator();
        (vault, btcToken, wbtc) = orchestrator.deployProtocol();
        orchestrator.deployIssuer("DormancyTest");

        (address treasureAddr, , , ) = orchestrator.getIssuer(0);
        treasureNFT = TreasureNFT(treasureAddr);

        // Fund actors via orchestrator (handles treasure minting authorization)
        // Alice gets treasures 0-2, Bob gets 3-5, Charlie gets 6-8
        orchestrator.fundActor(alice, 100 * ONE_BTC, 0, 3);
        orchestrator.fundActor(bob, 100 * ONE_BTC, 0, 3);
        orchestrator.fundActor(charlie, 100 * ONE_BTC, 0, 3);

        // Setup approvals
        _setupApprovals(alice);
        _setupApprovals(bob);
        _setupApprovals(charlie);
    }

    function _setupApprovals(address actor) internal {
        vm.startPrank(actor);
        wbtc.approve(address(vault), type(uint256).max);
        treasureNFT.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    // ==================== State Transitions ====================

    /// @notice Test full state transition: ACTIVE → POKE_PENDING → CLAIMABLE
    function test_StateTransition_FullFlow() public {
        // Alice mints vault
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        // Vest and mint vBTC
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        // Transfer vBTC to Bob (simulating sale/separation)
        uint256 vBtcAmount = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(bob, vBtcAmount);

        // Alice no longer holds vBTC but still owns vault
        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(vault.ownerOf(vaultId), alice);

        // Not dormant yet - hasn't been inactive long enough
        (bool eligible, IVaultNFT.DormancyState state) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "Not dormant eligible yet");

        // Warp past dormancy threshold (additional 1129 days of inactivity)
        // Use library constant to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + VaultMath.DORMANCY_THRESHOLD + 1);

        // Now dormant eligible
        (eligible, state) = vault.isDormantEligible(vaultId);
        assertTrue(eligible, "Should be dormant eligible");
        assertEq(uint8(state), uint8(IVaultNFT.DormancyState.ACTIVE), "State should be ACTIVE (not poked)");

        // Charlie (or anyone) can poke
        vm.prank(charlie);
        vault.pokeDormant(vaultId);

        // Check state is now POKE_PENDING
        (eligible, state) = vault.isDormantEligible(vaultId);
        assertTrue(eligible, "Still eligible");
        assertEq(uint8(state), uint8(IVaultNFT.DormancyState.POKE_PENDING), "State should be POKE_PENDING");

        // Cannot claim yet - grace period not expired
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, vaultId));
        vault.claimDormantCollateral(vaultId);

        // Warp past grace period
        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Now claimable
        (eligible, state) = vault.isDormantEligible(vaultId);
        assertTrue(eligible, "Still eligible");
        assertEq(uint8(state), uint8(IVaultNFT.DormancyState.CLAIMABLE), "State should be CLAIMABLE");

        // Bob (vBTC holder) can claim
        uint256 bobWbtcBefore = wbtc.balanceOf(bob);
        uint256 collateralBefore = vault.collateralAmount(vaultId);

        vm.prank(bob);
        uint256 claimed = vault.claimDormantCollateral(vaultId);

        // Bob received the collateral
        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + collateralBefore, "Bob received collateral");
        assertEq(claimed, collateralBefore, "Claimed amount matches");

        // Bob's vBTC was burned
        assertEq(btcToken.balanceOf(bob), 0, "vBTC burned");

        // Vault NFT was burned after dormancy claim
        vm.expectRevert();
        vault.ownerOf(vaultId);
    }

    /// @notice vBTC holder != vault owner - separation scenario
    function test_VbtcHolderNotOwner_SeparationScenario() public {
        // Alice mints and vests
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 50 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        uint256 vBtcAmount = btcToken.balanceOf(alice);

        // Alice sells vBTC to Bob
        vm.prank(alice);
        btcToken.transfer(bob, vBtcAmount);

        // Alice keeps the vault NFT (for treasure access)
        assertEq(vault.ownerOf(vaultId), alice);
        assertEq(btcToken.balanceOf(bob), vBtcAmount);

        // If Alice becomes inactive, Bob (vBTC holder) can eventually claim
        // Use library constant to avoid optimizer bug
        vm.warp(block.timestamp + VaultMath.DORMANCY_THRESHOLD + 1);

        // Anyone pokes
        vm.prank(charlie);
        vault.pokeDormant(vaultId);

        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Bob claims (as vBTC holder)
        vm.prank(bob);
        vault.claimDormantCollateral(vaultId);

        // Collateral transferred to Bob, vBTC burned
        // Vault NFT is burned after dormancy claim - verify by expecting revert
        vm.expectRevert();
        vault.ownerOf(vaultId);
        assertEq(btcToken.balanceOf(bob), 0);
    }

    /// @notice Activity reset during grace period
    function test_ActivityReset_DuringGracePeriod() public {
        // Alice mints, vests, and separates vBTC
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        uint256 aliceVbtc = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(bob, aliceVbtc);

        // Become dormant and get poked
        // Use double the threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        vm.prank(charlie);
        vault.pokeDormant(vaultId);

        // Verify POKE_PENDING state
        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(vaultId);
        assertEq(uint8(state), uint8(IVaultNFT.DormancyState.POKE_PENDING));

        // Alice proves activity during grace period
        vm.prank(alice);
        vault.proveActivity(vaultId);

        // State should reset - no longer dormant eligible
        (bool eligible, ) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "No longer dormant eligible after activity");

        // Bob cannot claim even after grace period would have expired
        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Not claimable anymore
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, vaultId));
        vault.claimDormantCollateral(vaultId);
    }

    /// @notice Transfer resets lastActivity
    function test_TransferResetsActivity() public {
        // Alice mints and vests
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        // Separate vBTC
        uint256 aliceVbtc = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(bob, aliceVbtc);

        // Become dormant eligible
        // Use doubled threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        (bool eligible, ) = vault.isDormantEligible(vaultId);
        assertTrue(eligible, "Should be dormant eligible");

        // Alice transfers vault to Charlie
        vm.prank(alice);
        vault.transferFrom(alice, charlie, vaultId);

        // Transfer resets activity - no longer dormant eligible
        (eligible, ) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "Transfer reset activity");

        // Need to wait dormancy period again
        // Use doubled threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        (eligible, ) = vault.isDormantEligible(vaultId);
        assertTrue(eligible, "Dormant eligible again after waiting");
    }

    /// @notice Cannot poke non-eligible vault
    function test_CannotPoke_NonEligibleVault() public {
        // Alice mints but keeps vBTC
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        // Alice still holds vBTC - not dormant eligible
        // Use library constant to avoid optimizer bug
        vm.warp(block.timestamp + VaultMath.DORMANCY_THRESHOLD + 1);

        (bool eligible, ) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "Not eligible when owner holds vBTC");

        // Cannot poke
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotDormantEligible.selector, vaultId));
        vault.pokeDormant(vaultId);
    }

    /// @notice Cannot poke already poked vault
    function test_CannotPoke_AlreadyPoked() public {
        // Setup dormant vault
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        uint256 aliceVbtc = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(bob, aliceVbtc);

        // Use doubled threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        // First poke succeeds
        vm.prank(charlie);
        vault.pokeDormant(vaultId);

        // Second poke fails
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.AlreadyPoked.selector, vaultId));
        vault.pokeDormant(vaultId);
    }

    /// @notice Claimant must hold required vBTC
    function test_ClaimRequires_VbtcHolding() public {
        // Setup dormant vault
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        uint256 aliceVbtc = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(bob, aliceVbtc);

        // Use doubled threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        vm.prank(charlie);
        vault.pokeDormant(vaultId);

        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Charlie (no vBTC) cannot claim
        vm.prank(charlie);
        vm.expectRevert(); // InsufficientBalance
        vault.claimDormantCollateral(vaultId);

        // Bob (vBTC holder) can claim
        vm.prank(bob);
        vault.claimDormantCollateral(vaultId);
    }

    /// @notice Partial vBTC holdings - requires full amount
    function test_ClaimRequires_FullVbtcAmount() public {
        // Setup dormant vault
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        uint256 vBtcAmount = btcToken.balanceOf(alice);

        // Alice splits vBTC between Bob and Charlie
        vm.prank(alice);
        btcToken.transfer(bob, vBtcAmount / 2);
        vm.prank(alice);
        btcToken.transfer(charlie, vBtcAmount / 2);

        // Use doubled threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        address anyone = makeAddr("anyone");
        vm.prank(anyone);
        vault.pokeDormant(vaultId);

        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Bob has only half - cannot claim
        vm.prank(bob);
        vm.expectRevert(); // InsufficientBalance
        vault.claimDormantCollateral(vaultId);

        // Charlie also has only half - cannot claim
        vm.prank(charlie);
        vm.expectRevert();
        vault.claimDormantCollateral(vaultId);

        // Bob acquires Charlie's half
        uint256 charlieVbtc = btcToken.balanceOf(charlie);
        vm.prank(charlie);
        btcToken.transfer(bob, charlieVbtc);

        // Now Bob has full amount - can claim
        vm.prank(bob);
        vault.claimDormantCollateral(vaultId);
    }

    /// @notice No vBTC minted - cannot be dormant
    function test_NoVbtcMinted_NotDormantEligible() public {
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        // Vest but don't mint vBTC
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Wait dormancy period
        // Use library constant to avoid optimizer bug
        vm.warp(block.timestamp + VaultMath.DORMANCY_THRESHOLD + 1);

        // Not dormant eligible without vBTC
        (bool eligible, ) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "Not eligible without vBTC minted");
    }

    /// @notice Withdrawal resets lastActivity (prevents dormancy)
    function test_WithdrawalResetsActivity() public {
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 100 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Mint vBTC and transfer
        vm.prank(alice);
        vault.mintBtcToken(vaultId);

        uint256 aliceVbtc = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(bob, aliceVbtc);

        // Wait almost dormancy threshold - compute in steps to avoid optimizer bug
        uint256 dormancyMinusOneDay = VaultMath.DORMANCY_THRESHOLD - 1 days;
        uint256 almostDormantTimestamp = block.timestamp + dormancyMinusOneDay;
        vm.warp(almostDormantTimestamp);

        (bool eligible, ) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "Not eligible yet");

        // Alice withdraws - resets activity
        vm.prank(alice);
        vault.withdraw(vaultId);

        // Now even after dormancy threshold, not eligible (activity was reset)
        uint256 shortlyAfterTimestamp = block.timestamp + 2 days;
        vm.warp(shortlyAfterTimestamp);

        (eligible, ) = vault.isDormantEligible(vaultId);
        assertFalse(eligible, "Withdrawal reset activity timer");
    }

    /// @notice Multiple vaults - each has independent dormancy state
    /// @dev Uses separate owners to test dormancy since vBTC is fungible per-owner
    function test_MultipleVaults_IndependentDormancy() public {
        // Alice mints vault1, Bob mints vault2, Charlie mints vault3
        // (each owner uses their own treasures: Alice 0, Bob 3, Charlie 6)
        vm.prank(alice);
        uint256 vault1 = vault.mint(address(treasureNFT), 0, address(wbtc), 10 * ONE_BTC);

        vm.prank(bob);
        uint256 vault2 = vault.mint(address(treasureNFT), 3, address(wbtc), 10 * ONE_BTC);

        vm.prank(charlie);
        uint256 vault3 = vault.mint(address(treasureNFT), 6, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // All mint vBTC
        vm.prank(alice);
        vault.mintBtcToken(vault1);
        vm.prank(bob);
        vault.mintBtcToken(vault2);
        vm.prank(charlie);
        vault.mintBtcToken(vault3);

        // Alice and Bob transfer their vBTC away (become dormant-eligible)
        address receiver = makeAddr("receiver");
        uint256 aliceVbtc = btcToken.balanceOf(alice);
        vm.prank(alice);
        btcToken.transfer(receiver, aliceVbtc);

        uint256 bobVbtc = btcToken.balanceOf(bob);
        vm.prank(bob);
        btcToken.transfer(receiver, bobVbtc);
        // Charlie keeps vBTC

        // Wait dormancy period
        // Use doubled threshold to avoid optimizer bug with duplicate constant values
        vm.warp(block.timestamp + 2 * VaultMath.DORMANCY_THRESHOLD + 1);

        // Vault1 (Alice) and vault2 (Bob) are dormant eligible (transferred vBTC away)
        // Vault3 (Charlie) is NOT dormant eligible (still holds vBTC)
        (bool elig1, ) = vault.isDormantEligible(vault1);
        (bool elig2, ) = vault.isDormantEligible(vault2);
        (bool elig3, ) = vault.isDormantEligible(vault3);

        assertTrue(elig1, "Vault1 dormant eligible");
        assertTrue(elig2, "Vault2 dormant eligible");
        assertFalse(elig3, "Vault3 NOT dormant eligible (Charlie holds vBTC)");
    }
}
