// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ZenoVault} from "../src/ZenoVault.sol";
import {VestedBTC} from "../src/VestedBTC.sol";

contract MockWBTC is ERC20 {
    constructor() ERC20("Wrapped BTC", "WBTC") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockTreasure is ERC721 {
    uint256 public nextId = 1;

    constructor() ERC721("Treasure", "TRS") {}

    function mint(address to) external returns (uint256 id) {
        id = nextId++;
        _mint(to, id);
    }
}

contract ZenoVaultTest is Test {
    uint256 constant ONE_BTC = 1e8;

    MockWBTC wbtc;
    MockTreasure treasure;
    ZenoVault vault;
    VestedBTC vbtc;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    function setUp() public {
        wbtc = new MockWBTC();
        treasure = new MockTreasure();
        vault = new ZenoVault(wbtc, "Vested WBTC", "vWBTC");
        vbtc = vault.vbtc();
        vm.warp(1_800_000_000);
    }

    function _mintVault(address who, uint256 amount) internal returns (uint256 id) {
        uint256 tid = treasure.mint(who);
        wbtc.mint(who, amount);
        vm.startPrank(who);
        treasure.approve(address(vault), tid);
        wbtc.approve(address(vault), amount);
        id = vault.mint(address(treasure), tid, amount);
        vm.stopPrank();
    }

    function _collateral(uint256 id) internal view returns (uint256 c) {
        (,, c,,,,,,) = vault.vaults(id);
    }

    function _reserve(uint256 id) internal view returns (uint256 r) {
        (,,, r,,,,,) = vault.vaults(id);
    }

    function _assertBacking() internal view {
        assertGe(wbtc.balanceOf(address(vault)), vault.totalActiveCollateral() + vault.strippedReserve());
        assertEq(vault.strippedReserve(), vbtc.totalSupply());
    }

    // ---------------------------------------------------------------- lifecycle

    function test_MintHoldsAssets() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        assertEq(vault.ownerOf(id), alice);
        assertEq(wbtc.balanceOf(address(vault)), ONE_BTC);
        assertEq(treasure.ownerOf(1), address(vault));
        assertEq(vault.totalActiveCollateral(), ONE_BTC);
    }

    function test_WithdrawRevertsDuringVesting() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days - 1);
        vm.prank(alice);
        vm.expectRevert(ZenoVault.StillVesting.selector);
        vault.withdraw(id);
    }

    function test_WithdrawOnePercentAfterVesting() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vault.withdraw(id);
        assertEq(wbtc.balanceOf(alice), ONE_BTC / 100);
        assertEq(_collateral(id), ONE_BTC - ONE_BTC / 100);

        vm.prank(alice);
        vm.expectRevert(ZenoVault.WithdrawalCooldown.selector);
        vault.withdraw(id);

        vm.warp(block.timestamp + 30 days);
        vm.prank(alice);
        vault.withdraw(id);
        // second withdrawal is 1% of the reduced balance
        assertEq(wbtc.balanceOf(alice), ONE_BTC / 100 + (ONE_BTC - ONE_BTC / 100) / 100);
    }

    function test_ZenoPropertyNeverDepletes() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        for (uint256 i = 0; i < 120; i++) {
            vm.prank(alice);
            vault.withdraw(id);
            vm.warp(block.timestamp + 30 days);
        }
        // 0.99^120 ≈ 0.2994
        assertGt(_collateral(id), (ONE_BTC * 29) / 100);
        assertLt(_collateral(id), (ONE_BTC * 31) / 100);
    }

    // ---------------------------------------------------------------- early redemption + match pool

    function test_EarlyRedeemLinearForfeit() public {
        uint256 idA = _mintVault(alice, ONE_BTC);
        _mintVault(bob, ONE_BTC);
        vm.warp(block.timestamp + 1129 days / 2);

        vm.prank(alice);
        vault.earlyRedeem(idA);

        uint256 returned = wbtc.balanceOf(alice);
        assertApproxEqAbs(returned, ONE_BTC / 2, 100);
        // forfeited half accrues entirely to bob
        assertApproxEqAbs(vault.pendingMatch(2), ONE_BTC - returned, 1);
        assertEq(treasure.ownerOf(1), address(0xdEaD));
        vm.expectRevert();
        vault.ownerOf(idA);
    }

    function test_MatchPoolConservedAcrossStaggeredClaims() public {
        uint256 idA = _mintVault(alice, 3 * ONE_BTC);
        uint256 idB = _mintVault(bob, ONE_BTC);
        uint256 idC = _mintVault(carol, ONE_BTC);

        vm.warp(block.timestamp + 500 days);
        vm.prank(alice);
        vault.earlyRedeem(idA); // forfeits ~3*(629/1129) BTC to bob+carol

        // bob settles immediately, carol later — both must get exactly half
        vault.settleMatch(idB);
        uint256 bobGain = _collateral(idB) - ONE_BTC;
        vault.settleMatch(idC);
        uint256 carolGain = _collateral(idC) - ONE_BTC;

        uint256 forfeited = 3 * ONE_BTC - wbtc.balanceOf(alice);
        assertEq(bobGain, carolGain);
        assertApproxEqAbs(bobGain + carolGain, forfeited, 2);
        // contract fully backed: balance == sum of vault collateral
        assertApproxEqAbs(wbtc.balanceOf(address(vault)), _collateral(idB) + _collateral(idC), 2);
    }

    function test_LastHolderExitsWithFullCollateral() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 100 days);
        vm.prank(alice);
        vault.earlyRedeem(id);
        assertEq(wbtc.balanceOf(alice), ONE_BTC);
    }

    // ---------------------------------------------------------------- stripping

    function test_StripFractionalRoundTrip() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);

        vm.startPrank(alice);
        vault.strip(id, ONE_BTC / 4);
        assertEq(vbtc.balanceOf(alice), ONE_BTC / 4);
        assertEq(_reserve(id), ONE_BTC / 4);
        assertEq(_collateral(id), ONE_BTC - ONE_BTC / 4);

        // repeatable
        vault.strip(id, ONE_BTC / 4);
        assertEq(vbtc.balanceOf(alice), ONE_BTC / 2);
        assertEq(_reserve(id), ONE_BTC / 2);
        assertEq(vault.strippedReserve(), ONE_BTC / 2);
        assertEq(vault.totalActiveCollateral(), ONE_BTC / 2);

        // fractional recombine, 1:1
        vault.recombine(id, ONE_BTC / 8);
        assertEq(vbtc.balanceOf(alice), ONE_BTC / 2 - ONE_BTC / 8);
        assertEq(_reserve(id), ONE_BTC / 2 - ONE_BTC / 8);
        assertEq(_collateral(id), ONE_BTC / 2 + ONE_BTC / 8);

        // full unwind restores the original position
        vault.recombine(id, _reserve(id));
        vm.stopPrank();
        assertEq(vbtc.totalSupply(), 0);
        assertEq(vault.strippedReserve(), 0);
        assertEq(_collateral(id), ONE_BTC);
        _assertBacking();
    }

    function test_StripRevertsDuringVesting() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days - 1);
        vm.prank(alice);
        vm.expectRevert(ZenoVault.StillVesting.selector);
        vault.strip(id, ONE_BTC / 2);
    }

    function test_StripRevertsOverActiveCollateral() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vm.expectRevert(ZenoVault.InsufficientCollateral.selector);
        vault.strip(id, ONE_BTC + 1);
    }

    function test_StripZeroReverts() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vm.expectRevert(ZenoVault.ZeroAmount.selector);
        vault.strip(id, 0);
    }

    function test_RecombineRevertsOverReserve() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vault.strip(id, ONE_BTC / 2);
        vm.expectRevert(ZenoVault.InsufficientReserve.selector);
        vault.recombine(id, ONE_BTC / 2 + 1);
        vm.stopPrank();
    }

    function test_StripEmitsEvents() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, true);
        emit ZenoVault.Stripped(id, ONE_BTC / 3);
        vault.strip(id, ONE_BTC / 3);
        vm.expectEmit(true, false, false, true);
        emit ZenoVault.Recombined(id, ONE_BTC / 3);
        vault.recombine(id, ONE_BTC / 3);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- reserve immunization

    function test_FullyStrippedVaultCannotWithdraw() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vault.strip(id, ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(ZenoVault.ZeroAmount.selector);
        vault.withdraw(id);

        // reserve untouched, still fully backing the vBTC supply
        assertEq(_reserve(id), ONE_BTC);
        _assertBacking();
    }

    function test_WithdrawalsNeverTouchReserve() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vault.strip(id, ONE_BTC / 2);

        for (uint256 i = 0; i < 12; i++) {
            vm.prank(alice);
            vault.withdraw(id);
            vm.warp(block.timestamp + 30 days);
            assertEq(_reserve(id), ONE_BTC / 2);
            _assertBacking();
        }
        // withdrawals were 1% of the active half only
        assertLt(wbtc.balanceOf(alice), (ONE_BTC / 2) * 12 / 100);
    }

    function test_ReserveDoesNotAccrueMatch() public {
        uint256 idA = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        // alice fully strips her vested vault: zero active collateral, so zero match participation
        vm.prank(alice);
        vault.strip(idA, ONE_BTC);

        // bob and carol mint fresh (still-vesting) vaults
        uint256 idB = _mintVault(bob, ONE_BTC);
        uint256 idC = _mintVault(carol, ONE_BTC);

        vm.warp(block.timestamp + 500 days);
        vm.prank(bob);
        vault.earlyRedeem(idB); // forfeits into the match pool

        assertEq(vault.pendingMatch(idA), 0);
        // carol (only active holder) receives the entire forfeit
        uint256 forfeited = ONE_BTC - wbtc.balanceOf(bob);
        assertApproxEqAbs(vault.pendingMatch(idC), forfeited, 1);
        assertEq(_reserve(idA), ONE_BTC);
        _assertBacking();
    }

    // ---------------------------------------------------------------- recombination before redemption

    // Note: an early-redeemable (pre-vesting) vault can never carry reserve —
    // stripping itself is vesting-gated, so earlyRedeem's StripOutstanding
    // check is defense in depth with no reachable state to test.

    function test_RedeemRevertsWithStripOutstanding() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vault.strip(id, ONE_BTC / 2);
        vm.expectRevert(ZenoVault.StripOutstanding.selector);
        vault.redeem(id);

        vault.recombine(id, ONE_BTC / 2);
        vault.redeem(id);
        vm.stopPrank();
        assertEq(wbtc.balanceOf(alice), ONE_BTC);
        assertEq(treasure.ownerOf(1), alice);
        assertEq(vbtc.totalSupply(), 0);
    }

    function test_RedeemAfterVestingReturnsEverything() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vault.redeem(id);
        assertEq(wbtc.balanceOf(alice), ONE_BTC);
        assertEq(treasure.ownerOf(1), alice);
        vm.expectRevert();
        vault.ownerOf(id);
    }

    function test_RedeemRevertsDuringVesting() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.prank(alice);
        vm.expectRevert(ZenoVault.StillVesting.selector);
        vault.redeem(id);
    }

    // ---------------------------------------------------------------- dormancy

    function test_DormancyFractionalClaimVaultSurvives() public {
        uint256 id = _mintVault(alice, 2 * ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vault.strip(id, ONE_BTC); // half stripped, half stays active
        vbtc.transfer(bob, ONE_BTC / 2); // sells to two buyers, then vanishes
        vbtc.transfer(carol, ONE_BTC / 2);
        vm.stopPrank();

        // not yet dormant
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NotDormant.selector);
        vault.pokeDormant(id);

        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vault.pokeDormant(id);

        vm.prank(bob);
        vm.expectRevert(ZenoVault.GraceNotExpired.selector);
        vault.claimDormant(id, ONE_BTC / 2);

        vm.warp(block.timestamp + 30 days);
        // fractional, multi-claimant: bob and carol each burn their vBTC 1:1
        vm.prank(bob);
        vault.claimDormant(id, ONE_BTC / 2);
        assertEq(wbtc.balanceOf(bob), ONE_BTC / 2);
        assertEq(_reserve(id), ONE_BTC / 2);
        _assertBacking();

        vm.prank(carol);
        vault.claimDormant(id, ONE_BTC / 2);
        assertEq(wbtc.balanceOf(carol), ONE_BTC / 2);

        // the vault survives: alice keeps the NFT, the treasure, and her active collateral
        assertEq(vault.ownerOf(id), alice);
        assertEq(treasure.ownerOf(1), address(vault));
        assertEq(_collateral(id), ONE_BTC);
        assertEq(_reserve(id), 0);
        _assertBacking();

        // reserve at zero ends dormancy eligibility
        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NotDormant.selector);
        vault.pokeDormant(id);
    }

    function test_ClaimDormantRevertsOverReserve() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vault.strip(id, ONE_BTC / 2);
        vbtc.transfer(bob, ONE_BTC / 2);
        vm.stopPrank();
        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vault.pokeDormant(id);
        vm.warp(block.timestamp + 30 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.InsufficientReserve.selector);
        vault.claimDormant(id, ONE_BTC / 2 + 1);
    }

    function test_PokeRevertsWhileOwnerHoldsVbtc() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(alice);
        vault.strip(id, ONE_BTC); // alice keeps her vBTC
        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NotDormant.selector);
        vault.pokeDormant(id);
    }

    function test_ProveActivityCancelsPoke() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vault.strip(id, ONE_BTC);
        vbtc.transfer(bob, ONE_BTC);
        vm.stopPrank();
        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vault.pokeDormant(id);

        vm.prank(alice);
        vault.proveActivity(id);

        vm.warp(block.timestamp + 30 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NoPendingPoke.selector);
        vault.claimDormant(id, ONE_BTC);
    }

    function test_TransferResetsActivity() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.startPrank(alice);
        vault.strip(id, ONE_BTC);
        vbtc.transfer(bob, ONE_BTC);
        vm.stopPrank();
        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vault.pokeDormant(id);

        vm.prank(alice);
        vault.transferFrom(alice, carol, id); // transfer = activity

        vm.warp(block.timestamp + 30 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NoPendingPoke.selector);
        vault.claimDormant(id, ONE_BTC);
    }

    function test_UnstrippedVaultCannotBePoked() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 3000 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NotDormant.selector);
        vault.pokeDormant(id);
    }

    // ---------------------------------------------------------------- access control

    function test_OnlyOwnerCanWithdraw() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.warp(block.timestamp + 1129 days);
        vm.prank(bob);
        vm.expectRevert(ZenoVault.NotOwner.selector);
        vault.withdraw(id);
    }

    function test_OnlyOwnerCanStripAndRecombine() public {
        uint256 id = _mintVault(alice, ONE_BTC);
        vm.startPrank(bob);
        vm.expectRevert(ZenoVault.NotOwner.selector);
        vault.strip(id, 1);
        vm.expectRevert(ZenoVault.NotOwner.selector);
        vault.recombine(id, 1);
        vm.stopPrank();
    }

    function test_OnlyVaultMintsVbtc() public {
        vm.prank(alice);
        vm.expectRevert(VestedBTC.OnlyVault.selector);
        vbtc.mint(alice, 1);
    }

    // ---------------------------------------------------------------- fuzz invariants

    /// Arbitrary interleavings of strip/recombine/withdraw/settle/warp across two vaults
    /// must never break: balance >= totalActiveCollateral + strippedReserve, and
    /// strippedReserve == vbtc.totalSupply().
    function testFuzz_BackingInvariantUnderOpSequences(uint96 a, uint96 b, bytes calldata ops) public {
        uint256 amtA = uint256(a) % (50 * ONE_BTC) + ONE_BTC;
        uint256 amtB = uint256(b) % (50 * ONE_BTC) + ONE_BTC;
        uint256 idA = _mintVault(alice, amtA);
        uint256 idB = _mintVault(bob, amtB);

        for (uint256 i = 0; i < ops.length && i < 32; i++) {
            uint8 op = uint8(ops[i]);
            (uint256 id, address who) = op % 2 == 0 ? (idA, alice) : (idB, bob);
            uint256 kind = op / 2 % 5;
            if (kind == 0) {
                // strip is vesting-gated: only attempt on vested vaults
                uint256 active = _collateral(id);
                if (vault.isVested(id) && active > 0) {
                    uint256 amt = active / (op % 3 + 1) + 1;
                    if (amt > active) amt = active;
                    vm.prank(who);
                    vault.strip(id, amt);
                }
            } else if (kind == 1) {
                uint256 res = _reserve(id);
                uint256 amt = res / (op % 3 + 1);
                if (amt > 0 && vbtc.balanceOf(who) >= amt) {
                    vm.prank(who);
                    vault.recombine(id, amt);
                }
            } else if (kind == 2) {
                if (vault.isVested(id) && _collateral(id) >= 100) {
                    vm.prank(who);
                    try vault.withdraw(id) {} catch {}
                }
            } else if (kind == 3) {
                vm.warp(block.timestamp + uint256(op) * 10 days);
            } else {
                vault.settleMatch(id);
            }
            _assertBacking();
        }
    }

    /// strip(x) then recombine(x) restores the exact starting position.
    function testFuzz_StripRecombineRoundTrip(uint96 amt, uint96 part) public {
        uint256 amount = uint256(amt) % (100 * ONE_BTC) + 1000;
        uint256 x = uint256(part) % amount + 1;
        uint256 id = _mintVault(alice, amount);
        vm.warp(block.timestamp + 1129 days);

        vm.startPrank(alice);
        vault.strip(id, x);
        assertEq(vbtc.balanceOf(alice), x);
        assertEq(vault.strippedReserve(), x);
        vault.recombine(id, x);
        vm.stopPrank();

        assertEq(_collateral(id), amount);
        assertEq(_reserve(id), 0);
        assertEq(vbtc.totalSupply(), 0);
        assertEq(vault.totalActiveCollateral(), amount);
        _assertBacking();
    }

    /// Contract balance always equals sum of live vault collateral + unsettled match dust.
    function testFuzz_Conservation(uint96 a, uint96 b, uint96 c, uint16 exitDay) public {
        uint256 amtA = uint256(a) % (100 * ONE_BTC) + 1000;
        uint256 amtB = uint256(b) % (100 * ONE_BTC) + 1000;
        uint256 amtC = uint256(c) % (100 * ONE_BTC) + 1000;
        uint256 day = uint256(exitDay) % 1128 + 1;

        uint256 idA = _mintVault(alice, amtA);
        uint256 idB = _mintVault(bob, amtB);
        uint256 idC = _mintVault(carol, amtC);

        vm.warp(block.timestamp + day * 1 days);
        vm.prank(alice);
        vault.earlyRedeem(idA);

        vault.settleMatch(idB);
        vault.settleMatch(idC);

        uint256 sum = _collateral(idB) + _collateral(idC);
        // rounding dust only, never under-backed
        assertGe(wbtc.balanceOf(address(vault)), sum);
        assertLe(wbtc.balanceOf(address(vault)) - sum, 10);
    }
}
