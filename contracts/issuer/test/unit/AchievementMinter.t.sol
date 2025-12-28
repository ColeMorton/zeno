// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AchievementNFT} from "../../src/AchievementNFT.sol";
import {AchievementMinter} from "../../src/AchievementMinter.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";
import {MockVaultNFT} from "../mocks/MockVaultNFT.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract AchievementMinterTest is Test {
    AchievementNFT public achievement;
    AchievementMinter public minter;
    TreasureNFT public treasure;
    MockVaultNFT public vault;
    MockWBTC public wbtc;

    address public owner;
    address public alice;
    address public bob;

    uint256 public constant COLLATERAL_AMOUNT = 1e8; // 1 WBTC

    // Cache achievement type constants to avoid consuming vm.prank
    bytes32 public MINTER;
    bytes32 public MATURED;
    bytes32 public HODLER_SUPREME;
    bytes32 public FIRST_MONTH;
    bytes32 public QUARTER_STACK;
    bytes32 public HALF_YEAR;
    bytes32 public ANNUAL;
    bytes32 public DIAMOND_HANDS;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.startPrank(owner);

        // Deploy mock protocol contracts
        vault = new MockVaultNFT();
        wbtc = new MockWBTC();

        // Deploy issuer contracts
        achievement = new AchievementNFT("Achievements", "ACH", "https://achievements.com/", true);
        treasure = new TreasureNFT("Treasure", "TREASURE", "https://treasure.com/");

        // Prepare collateral and protocol arrays (single collateral for tests)
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(wbtc);

        address[] memory protocols = new address[](1);
        protocols[0] = address(vault);

        minter = new AchievementMinter(
            address(achievement),
            address(treasure),
            collaterals,
            protocols
        );

        // Configure permissions
        achievement.authorizeMinter(address(minter));
        treasure.authorizeMinter(address(minter));

        vm.stopPrank();

        // Cache achievement type constants
        MINTER = minter.MINTER();
        MATURED = minter.MATURED();
        HODLER_SUPREME = minter.HODLER_SUPREME();
        FIRST_MONTH = minter.FIRST_MONTH();
        QUARTER_STACK = minter.QUARTER_STACK();
        HALF_YEAR = minter.HALF_YEAR();
        ANNUAL = minter.ANNUAL();
        DIAMOND_HANDS = minter.DIAMOND_HANDS();
    }

    function _mintVaultForAlice() internal returns (uint256 vaultId, uint256 treasureId) {
        // Mint treasure and collateral to alice
        vm.prank(owner);
        treasureId = treasure.mint(alice);

        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        // Alice mints vault on protocol
        vm.startPrank(alice);
        treasure.approve(address(vault), treasureId);
        wbtc.approve(address(vault), COLLATERAL_AMOUNT);
        vaultId = vault.mint(
            address(treasure),
            treasureId,
            address(wbtc),
            COLLATERAL_AMOUNT
        );
        vm.stopPrank();
    }

    // ==================== Duration Threshold Tests ====================

    function test_DurationThresholds() public view {
        assertEq(minter.getDurationThreshold(FIRST_MONTH), 30 days);
        assertEq(minter.getDurationThreshold(QUARTER_STACK), 91 days);
        assertEq(minter.getDurationThreshold(HALF_YEAR), 182 days);
        assertEq(minter.getDurationThreshold(ANNUAL), 365 days);
        assertEq(minter.getDurationThreshold(DIAMOND_HANDS), 730 days);
    }

    function test_IsDurationAchievement() public view {
        assertTrue(minter.isDurationAchievement(FIRST_MONTH));
        assertTrue(minter.isDurationAchievement(QUARTER_STACK));
        assertTrue(minter.isDurationAchievement(HALF_YEAR));
        assertTrue(minter.isDurationAchievement(ANNUAL));
        assertTrue(minter.isDurationAchievement(DIAMOND_HANDS));
        assertFalse(minter.isDurationAchievement(MINTER));
        assertFalse(minter.isDurationAchievement(MATURED));
    }

    // ==================== claimMinterAchievement Tests ====================

    function test_ClaimMinterAchievement() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        assertTrue(achievement.hasAchievement(alice, MINTER));
    }

    function test_ClaimMinterAchievement_EmitsEvent() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit AchievementMinter.MinterAchievementClaimed(alice, vaultId);
        minter.claimMinterAchievement(vaultId, address(wbtc));
    }

    function test_ClaimMinterAchievement_RevertIf_NotVaultOwner() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.NotVaultOwner.selector, vaultId, bob)
        );
        minter.claimMinterAchievement(vaultId, address(wbtc));
    }

    function test_ClaimMinterAchievement_RevertIf_WrongTreasure() public {
        // Create a different treasure contract
        vm.prank(owner);
        TreasureNFT otherTreasure = new TreasureNFT("Other", "OTHER", "https://other.com/");

        vm.prank(owner);
        uint256 treasureId = otherTreasure.mint(alice);

        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        otherTreasure.approve(address(vault), treasureId);
        wbtc.approve(address(vault), COLLATERAL_AMOUNT);
        uint256 vaultId = vault.mint(
            address(otherTreasure),
            treasureId,
            address(wbtc),
            COLLATERAL_AMOUNT
        );
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.VaultNotUsingIssuerTreasure.selector,
                vaultId,
                address(otherTreasure)
            )
        );
        minter.claimMinterAchievement(vaultId, address(wbtc));
    }

    function test_ClaimMinterAchievement_RevertIf_AlreadyClaimed() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // Mint another vault for alice
        vm.prank(owner);
        uint256 treasureId2 = treasure.mint(alice);
        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        treasure.approve(address(vault), treasureId2);
        wbtc.approve(address(vault), COLLATERAL_AMOUNT);
        uint256 vaultId2 = vault.mint(
            address(treasure),
            treasureId2,
            address(wbtc),
            COLLATERAL_AMOUNT
        );
        vm.stopPrank();

        // Cannot claim again
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementNFT.AchievementAlreadyEarned.selector,
                alice,
                MINTER
            )
        );
        minter.claimMinterAchievement(vaultId2, address(wbtc));
    }

    // ==================== claimMaturedAchievement Tests ====================

    function test_ClaimMaturedAchievement() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // Claim MINTER first
        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // Set vault as vested and match claimed
        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        // Claim MATURED
        vm.prank(alice);
        minter.claimMaturedAchievement(vaultId, address(wbtc));

        assertTrue(achievement.hasAchievement(alice, MATURED));
    }

    function test_ClaimMaturedAchievement_EmitsEvent() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit AchievementMinter.MaturedAchievementClaimed(alice, vaultId);
        minter.claimMaturedAchievement(vaultId, address(wbtc));
    }

    function test_ClaimMaturedAchievement_RevertIf_MissingMinter() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.MissingMinterAchievement.selector, alice)
        );
        minter.claimMaturedAchievement(vaultId, address(wbtc));
    }

    function test_ClaimMaturedAchievement_RevertIf_NotVested() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // NOT vested
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.VaultNotVested.selector, vaultId)
        );
        minter.claimMaturedAchievement(vaultId, address(wbtc));
    }

    function test_ClaimMaturedAchievement_RevertIf_MatchNotClaimed() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // Vested but match NOT claimed
        vault.setVested(vaultId, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.MatchNotClaimed.selector, vaultId)
        );
        minter.claimMaturedAchievement(vaultId, address(wbtc));
    }

    // ==================== claimDurationAchievement Tests ====================

    function test_ClaimDurationAchievement_FirstMonth() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);

        assertTrue(achievement.hasAchievement(alice, FIRST_MONTH));
    }

    function test_ClaimDurationAchievement_QuarterStack() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // Fast forward 91 days
        vm.warp(block.timestamp + 91 days);

        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), QUARTER_STACK);

        assertTrue(achievement.hasAchievement(alice, QUARTER_STACK));
    }

    function test_ClaimDurationAchievement_AllDurations() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // First month
        vm.warp(block.timestamp + 30 days);
        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);

        // Quarter stack
        vm.warp(block.timestamp + 61 days); // 91 total
        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), QUARTER_STACK);

        // Half year
        vm.warp(block.timestamp + 91 days); // 182 total
        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), HALF_YEAR);

        // Annual
        vm.warp(block.timestamp + 183 days); // 365 total
        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), ANNUAL);

        // Diamond hands
        vm.warp(block.timestamp + 365 days); // 730 total
        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), DIAMOND_HANDS);

        assertTrue(achievement.hasAchievement(alice, FIRST_MONTH));
        assertTrue(achievement.hasAchievement(alice, QUARTER_STACK));
        assertTrue(achievement.hasAchievement(alice, HALF_YEAR));
        assertTrue(achievement.hasAchievement(alice, ANNUAL));
        assertTrue(achievement.hasAchievement(alice, DIAMOND_HANDS));
    }

    function test_ClaimDurationAchievement_EmitsEvent() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.warp(block.timestamp + 30 days);

        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit AchievementMinter.DurationAchievementClaimed(alice, vaultId, FIRST_MONTH);
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);
    }

    function test_ClaimDurationAchievement_RevertIf_InvalidType() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        bytes32 invalidType = keccak256("INVALID");

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.InvalidDurationAchievement.selector, invalidType)
        );
        minter.claimDurationAchievement(vaultId, address(wbtc), invalidType);
    }

    function test_ClaimDurationAchievement_RevertIf_DurationNotMet() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // Only 15 days have passed, need 30
        vm.warp(block.timestamp + 15 days);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.DurationNotMet.selector,
                vaultId,
                FIRST_MONTH,
                30 days,
                15 days
            )
        );
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);
    }

    function test_ClaimDurationAchievement_RevertIf_NotVaultOwner() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.warp(block.timestamp + 30 days);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.NotVaultOwner.selector, vaultId, bob)
        );
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);
    }

    function test_ClaimDurationAchievement_RevertIf_WrongTreasure() public {
        // Create vault with different treasure
        vm.prank(owner);
        TreasureNFT otherTreasure = new TreasureNFT("Other", "OTHER", "https://other.com/");

        vm.prank(owner);
        uint256 treasureId = otherTreasure.mint(alice);

        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        otherTreasure.approve(address(vault), treasureId);
        wbtc.approve(address(vault), COLLATERAL_AMOUNT);
        uint256 vaultId = vault.mint(
            address(otherTreasure),
            treasureId,
            address(wbtc),
            COLLATERAL_AMOUNT
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.VaultNotUsingIssuerTreasure.selector,
                vaultId,
                address(otherTreasure)
            )
        );
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);
    }

    // ==================== mintHodlerSupremeVault Tests ====================

    function test_MintHodlerSupremeVault() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // Get both prerequisites
        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        minter.claimMaturedAchievement(vaultId, address(wbtc));

        // Mint collateral for Hodler Supreme vault
        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        wbtc.approve(address(minter), COLLATERAL_AMOUNT);
        uint256 newVaultId = minter.mintHodlerSupremeVault(
            address(wbtc),
            COLLATERAL_AMOUNT
        );
        vm.stopPrank();

        assertTrue(achievement.hasAchievement(alice, HODLER_SUPREME));
        assertEq(vault.ownerOf(newVaultId), alice);
    }

    function test_MintHodlerSupremeVault_EmitsEvent() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        minter.claimMaturedAchievement(vaultId, address(wbtc));

        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        wbtc.approve(address(minter), COLLATERAL_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit AchievementMinter.HodlerSupremeVaultMinted(
            alice,
            1, // second vault
            1, // second treasure
            COLLATERAL_AMOUNT
        );
        minter.mintHodlerSupremeVault(address(wbtc), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function test_MintHodlerSupremeVault_RevertIf_MissingMinter() public {
        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        wbtc.approve(address(minter), COLLATERAL_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.MissingMinterAchievement.selector, alice)
        );
        minter.mintHodlerSupremeVault(address(wbtc), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function test_MintHodlerSupremeVault_RevertIf_MissingMatured() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vm.prank(owner);
        wbtc.mint(alice, COLLATERAL_AMOUNT);

        vm.startPrank(alice);
        wbtc.approve(address(minter), COLLATERAL_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(AchievementMinter.MissingMaturedAchievement.selector, alice)
        );
        minter.mintHodlerSupremeVault(address(wbtc), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function test_MintHodlerSupremeVault_RevertIf_ZeroCollateral() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        minter.claimMaturedAchievement(vaultId, address(wbtc));

        vm.prank(alice);
        vm.expectRevert(AchievementMinter.ZeroCollateral.selector);
        minter.mintHodlerSupremeVault(address(wbtc), 0);
    }

    // ==================== View Function Tests ====================

    function test_CanClaimMinterAchievement() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        (bool canClaim, string memory reason) = minter.canClaimMinterAchievement(alice, vaultId, address(wbtc));
        assertTrue(canClaim);
        assertEq(reason, "");
    }

    function test_CanClaimMinterAchievement_AlreadyHas() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        (bool canClaim, string memory reason) = minter.canClaimMinterAchievement(alice, vaultId, address(wbtc));
        assertFalse(canClaim);
        assertEq(reason, "Already has MINTER achievement");
    }

    function test_CanClaimMinterAchievement_NotOwner() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        (bool canClaim, string memory reason) = minter.canClaimMinterAchievement(bob, vaultId, address(wbtc));
        assertFalse(canClaim);
        assertEq(reason, "Not vault owner");
    }

    function test_CanClaimMaturedAchievement() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        (bool canClaim, string memory reason) = minter.canClaimMaturedAchievement(alice, vaultId, address(wbtc));
        assertTrue(canClaim);
        assertEq(reason, "");
    }

    function test_CanClaimMaturedAchievement_MissingMinter() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        (bool canClaim, string memory reason) = minter.canClaimMaturedAchievement(alice, vaultId, address(wbtc));
        assertFalse(canClaim);
        assertEq(reason, "Missing MINTER achievement");
    }

    function test_CanClaimDurationAchievement() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.warp(block.timestamp + 30 days);

        (bool canClaim, string memory reason) = minter.canClaimDurationAchievement(alice, vaultId, address(wbtc), FIRST_MONTH);
        assertTrue(canClaim);
        assertEq(reason, "");
    }

    function test_CanClaimDurationAchievement_DurationNotMet() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        // Only 15 days elapsed
        vm.warp(block.timestamp + 15 days);

        (bool canClaim, string memory reason) = minter.canClaimDurationAchievement(alice, vaultId, address(wbtc), FIRST_MONTH);
        assertFalse(canClaim);
        assertEq(reason, "Duration not met");
    }

    function test_CanClaimDurationAchievement_InvalidType() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        (bool canClaim, string memory reason) = minter.canClaimDurationAchievement(alice, vaultId, address(wbtc), keccak256("INVALID"));
        assertFalse(canClaim);
        assertEq(reason, "Invalid duration achievement");
    }

    function test_CanMintHodlerSupremeVault() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        vault.setVested(vaultId, true);
        vault.setMatchClaimed(vaultId, true);

        vm.prank(alice);
        minter.claimMaturedAchievement(vaultId, address(wbtc));

        (bool canMint, string memory reason) = minter.canMintHodlerSupremeVault(alice, address(wbtc));
        assertTrue(canMint);
        assertEq(reason, "");
    }

    function test_CanMintHodlerSupremeVault_MissingMinter() public view {
        (bool canMint, string memory reason) = minter.canMintHodlerSupremeVault(alice, address(wbtc));
        assertFalse(canMint);
        assertEq(reason, "Missing MINTER achievement");
    }

    function test_CanMintHodlerSupremeVault_MissingMatured() public {
        (uint256 vaultId,) = _mintVaultForAlice();

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        (bool canMint, string memory reason) = minter.canMintHodlerSupremeVault(alice, address(wbtc));
        assertFalse(canMint);
        assertEq(reason, "Missing MATURED achievement");
    }
}
