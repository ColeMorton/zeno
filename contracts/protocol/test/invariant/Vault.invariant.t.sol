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

    /// @notice Every outstanding vBTC is backed 1:1 by stripped reserve
    function invariant_reserveBacksBtcTokenSupply() public view {
        assertEq(
            vault.totalStrippedReserve(),
            btcToken.totalSupply(),
            "totalStrippedReserve must equal vBTC total supply"
        );
    }

    /// @notice Vault token balance decomposes exactly into active + reserve + match pool
    function invariant_collateralConservation() public view {
        assertEq(
            wbtc.balanceOf(address(vault)),
            vault.totalActiveCollateral() + vault.totalStrippedReserve() + vault.matchPool(),
            "vault balance != totalActiveCollateral + totalStrippedReserve + matchPool"
        );
    }

    /// @notice Global totals equal the sum of per-vault balances
    function invariant_perVaultSumsMatchTotals() public view {
        uint256 sumActive = 0;
        uint256 sumReserve = 0;
        uint256 tokenCount = handler.getMintedTokenCount();

        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumActive += amount;
                sumReserve += vault.strippedReserve(i);
            } catch {
                // Token was burned, skip
            }
        }

        assertEq(sumActive, vault.totalActiveCollateral(), "sum of active != totalActiveCollateral");
        assertEq(sumReserve, vault.totalStrippedReserve(), "sum of reserves != totalStrippedReserve");
    }

    /// @notice Exact wBTC conservation: balance == deposits - transfers out
    function invariant_noFreeMoney() public view {
        assertEq(
            wbtc.balanceOf(address(vault)),
            handler.ghost_totalDeposited() - handler.ghost_totalWithdrawn(),
            "Vault balance must equal deposits minus withdrawals"
        );
    }

    /// @notice Call summary for debugging failed invariants
    function invariant_callSummary() public view {
        (
            uint256 mints,
            uint256 withdraws,
            uint256 redeems,
            uint256 claims,
            uint256 strips,
            uint256 recombines,
            uint256 warps
        ) = handler.getCallSummary();

        console.log("Invariant test call summary:");
        console.log("  mints:", mints);
        console.log("  withdraws:", withdraws);
        console.log("  earlyRedeems:", redeems);
        console.log("  claimMatch:", claims);
        console.log("  strips:", strips);
        console.log("  recombines:", recombines);
        console.log("  warpTime:", warps);
    }
}
