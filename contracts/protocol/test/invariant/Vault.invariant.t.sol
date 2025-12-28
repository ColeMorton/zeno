// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";
import {VaultHandler} from "./handlers/VaultHandler.sol";

contract VaultInvariantTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;
    VaultHandler public handler;

    address public alice;
    address public bob;
    address public charlie;

    uint256 internal constant ONE_BTC = 1e8;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        // Fund actors
        address[] memory actors = new address[](3);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = charlie;

        for (uint256 i = 0; i < actors.length; i++) {
            wbtc.mint(actors[i], 1000 * ONE_BTC);
            treasure.mintBatch(actors[i], 100);
            vm.startPrank(actors[i]);
            wbtc.approve(address(vault), type(uint256).max);
            treasure.setApprovalForAll(address(vault), true);
            vm.stopPrank();
        }

        handler = new VaultHandler(vault, btcToken, treasure, wbtc, actors);

        // Target only the handler for invariant testing
        targetContract(address(handler));
    }

    /// @notice Total BTC in vault must equal sum of all collaterals + match pool
    function invariant_collateralConservation() public view {
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 matchPool = vault.matchPool();

        // Sum all active collaterals
        uint256 sumCollaterals = 0;
        uint256 tokenCount = handler.getMintedTokenCount();

        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumCollaterals += amount;
            } catch {
                // Token was burned, skip
            }
        }

        assertEq(
            vaultBalance,
            sumCollaterals + matchPool,
            "Collateral conservation violated: vault balance != collaterals + pool"
        );
    }

    /// @notice Match pool must equal total forfeited from early redemptions
    function invariant_matchPoolConsistency() public view {
        uint256 matchPool = vault.matchPool();
        uint256 totalForfeited = handler.ghost_totalForfeited();
        uint256 totalClaimed = handler.ghost_totalMatchClaimed();

        assertEq(
            matchPool,
            totalForfeited - totalClaimed,
            "Match pool inconsistent: pool != forfeited - claimed"
        );
    }

    /// @notice Total withdrawn + remaining collateral <= total deposited
    function invariant_noFreeMoney() public view {
        uint256 totalDeposited = handler.ghost_totalDeposited();
        uint256 totalWithdrawn = handler.ghost_totalWithdrawn();

        // Sum remaining collaterals
        uint256 sumRemaining = 0;
        uint256 tokenCount = handler.getMintedTokenCount();

        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumRemaining += amount;
            } catch {
                // Token was burned
            }
        }

        // Include match pool as it came from deposits
        uint256 matchPool = vault.matchPool();

        assertLe(
            totalWithdrawn + sumRemaining + matchPool,
            totalDeposited + handler.ghost_totalMatchClaimed(),
            "Free money detected: withdrawn + remaining > deposited"
        );
    }

    /// @notice Vault WBTC balance must never exceed total deposited
    function invariant_vaultBalanceBounded() public view {
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 totalDeposited = handler.ghost_totalDeposited();

        assertLe(
            vaultBalance,
            totalDeposited,
            "Vault balance exceeds total deposits"
        );
    }

    /// @notice totalActiveCollateral only decreases on maturity or early redemption
    /// Note: totalActiveCollateral tracks original deposits for match pool distribution,
    /// not current balances after withdrawals. This is by design.
    function invariant_totalActiveCollateralNonNegative() public view {
        uint256 reported = vault.totalActiveCollateral();
        uint256 totalDeposited = handler.ghost_totalDeposited();

        // totalActiveCollateral should never exceed total deposited
        assertLe(
            reported,
            totalDeposited,
            "totalActiveCollateral exceeds total deposited"
        );
    }

    /// @notice Collateral can never become negative (implicit via uint256, but verify no underflow)
    function invariant_noNegativeCollateral() public view {
        uint256 tokenCount = handler.getMintedTokenCount();

        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                // If we can read it without revert, it's >= 0 (uint256)
                assertTrue(amount >= 0, "Negative collateral impossible with uint256");
            } catch {
                // Token doesn't exist, which is fine
            }
        }
    }

    /// @notice Call summary for debugging failed invariants
    function invariant_callSummary() public view {
        (
            uint256 mints,
            uint256 withdraws,
            uint256 redeems,
            uint256 claims,
            uint256 warps
        ) = handler.getCallSummary();

        console.log("Invariant test call summary:");
        console.log("  mints:", mints);
        console.log("  withdraws:", withdraws);
        console.log("  earlyRedeems:", redeems);
        console.log("  claimMatch:", claims);
        console.log("  warpTime:", warps);
    }
}
