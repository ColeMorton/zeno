// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SwarmOrchestrator} from "../src/SwarmOrchestrator.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";

contract DebugCooldownTest is Test {
    function test_debug_cooldown() public {
        SwarmOrchestrator orchestrator = new SwarmOrchestrator();
        orchestrator.setVm(vm);
        orchestrator.deployProtocol();
        orchestrator.deployIssuer("Test");
        orchestrator.deployDeFiStack();
        orchestrator.initializeAgents(42);

        string memory raw = vm.readFile("reports/price_series.csv");
        string[] memory lines = vm.split(raw, "\n");
        uint256 dataLines = 0;
        for (uint256 i = 1; i < lines.length; i++) {
            if (bytes(lines[i]).length > 0) dataLines++;
        }
        uint256[] memory prices = new uint256[](dataLines);
        uint8[] memory regimes = new uint8[](dataLines);
        uint256 idx = 0;
        for (uint256 i = 1; i < lines.length; i++) {
            if (bytes(lines[i]).length == 0) continue;
            string[] memory cols = vm.split(lines[i], ",");
            prices[idx] = vm.parseUint(cols[1]);
            regimes[idx] = uint8(vm.parseUint(cols[2]));
            idx++;
        }
        orchestrator.loadPriceSeries(prices, regimes);

        for (uint256 tick = 0; tick < 20; tick++) {
            orchestrator.executeTick();
        }

        for (uint256 i = 0; i < 100; i++) {
            uint256[] memory vaultIds = orchestrator.getAgentVaultIds(i);
            if (vaultIds.length > 0) {
                console.log("Agent %d has vault %d", i, vaultIds[0]);
                (VaultNFT vault, , ) = orchestrator.getProtocol();
                (bool ok, bytes memory data) = address(vault).staticcall(
                    abi.encodeWithSignature("withdrawalCooldown(uint256)", vaultIds[0])
                );
                if (ok) {
                    uint256 cooldown = abi.decode(data, (uint256));
                    console.log("Cooldown for vault %d: %d", vaultIds[0], cooldown);
                } else {
                    console.log("withdrawalCooldown reverted");
                }
                break;
            }
        }
    }
}
