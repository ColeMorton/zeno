// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultMintController} from "../../src/VaultMintController.sol";
import {IVaultMintController} from "../../src/interfaces/IVaultMintController.sol";
import {TreasureNFT} from "../../src/TreasureNFT.sol";
import {MockVaultNFT} from "../mocks/MockVaultNFT.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract VaultMintControllerTest is Test {
    VaultMintController public controller;
    TreasureNFT public treasure;
    MockVaultNFT public vault;
    MockWBTC public wbtc;

    address public owner;
    address public alice;

    uint256 public constant COLLATERAL_AMOUNT = 1e8; // 1 WBTC
    bytes32 public constant TRAILHEAD = keccak256("TRAILHEAD");

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");

        vm.startPrank(owner);

        // Deploy mock protocol contracts
        vault = new MockVaultNFT();
        wbtc = new MockWBTC();

        // Deploy issuer contracts
        treasure = new TreasureNFT("Treasure", "TREASURE", "https://treasure.com/", address(0));

        // Deploy controller
        controller = new VaultMintController(
            address(treasure),
            address(vault),
            address(wbtc)
        );

        // Authorize controller as minter
        treasure.authorizeMinter(address(controller));

        vm.stopPrank();

        // Fund alice with WBTC
        wbtc.mint(alice, COLLATERAL_AMOUNT * 10);
    }

    function test_mintVault_succeeds() public {
        vm.startPrank(alice);
        wbtc.approve(address(controller), COLLATERAL_AMOUNT);

        uint256 vaultId = controller.mintVault(TRAILHEAD, COLLATERAL_AMOUNT);

        // Verify vault ownership
        assertEq(vault.ownerOf(vaultId), alice);

        // Verify collateral transferred
        assertEq(wbtc.balanceOf(alice), COLLATERAL_AMOUNT * 9);

        vm.stopPrank();
    }

    function test_mintVault_setsAchievementType() public {
        vm.startPrank(alice);
        wbtc.approve(address(controller), COLLATERAL_AMOUNT);

        controller.mintVault(TRAILHEAD, COLLATERAL_AMOUNT);

        // Controller minted treasure ID 0
        assertEq(treasure.achievementType(0), TRAILHEAD);

        vm.stopPrank();
    }

    function test_mintVault_emitsEvent() public {
        vm.startPrank(alice);
        wbtc.approve(address(controller), COLLATERAL_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit IVaultMintController.VaultMinted(alice, 0, 0, TRAILHEAD, COLLATERAL_AMOUNT);

        controller.mintVault(TRAILHEAD, COLLATERAL_AMOUNT);

        vm.stopPrank();
    }

    function test_mintVault_revertsWhen_zeroCollateral() public {
        vm.startPrank(alice);

        vm.expectRevert(IVaultMintController.ZeroCollateral.selector);
        controller.mintVault(TRAILHEAD, 0);

        vm.stopPrank();
    }

    function test_mintVault_revertsWhen_insufficientAllowance() public {
        vm.startPrank(alice);
        // No approval

        vm.expectRevert();
        controller.mintVault(TRAILHEAD, COLLATERAL_AMOUNT);

        vm.stopPrank();
    }

    function test_mintVault_revertsWhen_insufficientBalance() public {
        address bob = makeAddr("bob");
        vm.startPrank(bob);
        wbtc.approve(address(controller), COLLATERAL_AMOUNT);

        vm.expectRevert();
        controller.mintVault(TRAILHEAD, COLLATERAL_AMOUNT);

        vm.stopPrank();
    }

    function test_mintVault_multipleVaults() public {
        vm.startPrank(alice);
        wbtc.approve(address(controller), COLLATERAL_AMOUNT * 3);

        uint256 vaultId1 = controller.mintVault(TRAILHEAD, COLLATERAL_AMOUNT);
        uint256 vaultId2 = controller.mintVault(keccak256("FIRST_STEPS"), COLLATERAL_AMOUNT);
        uint256 vaultId3 = controller.mintVault(keccak256("WALLET_WARMED"), COLLATERAL_AMOUNT);

        assertEq(vault.ownerOf(vaultId1), alice);
        assertEq(vault.ownerOf(vaultId2), alice);
        assertEq(vault.ownerOf(vaultId3), alice);

        // Each vault has unique treasure with correct achievement
        assertEq(treasure.achievementType(0), TRAILHEAD);
        assertEq(treasure.achievementType(1), keccak256("FIRST_STEPS"));
        assertEq(treasure.achievementType(2), keccak256("WALLET_WARMED"));

        vm.stopPrank();
    }

    function testFuzz_mintVault_anyCollateralAmount(uint256 amount) public {
        amount = bound(amount, 1, COLLATERAL_AMOUNT * 10);

        vm.startPrank(alice);
        wbtc.approve(address(controller), amount);

        uint256 vaultId = controller.mintVault(TRAILHEAD, amount);
        assertEq(vault.ownerOf(vaultId), alice);

        vm.stopPrank();
    }

    function test_immutableAddresses() public view {
        assertEq(controller.treasureNFT(), address(treasure));
        assertEq(controller.vaultNFT(), address(vault));
        assertEq(controller.collateralToken(), address(wbtc));
    }
}
