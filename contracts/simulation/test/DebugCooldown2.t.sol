// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SwarmOrchestrator} from "../src/SwarmOrchestrator.sol";
import {AgentLib} from "../src/agents/AgentLib.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";

contract DebugCooldown2Test is Test {
    function test_debug_withdrawals() public {
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

        for (uint256 tick = 0; tick < 320; tick++) {
            orchestrator.executeTick();
        }

        uint256 withdrawAttempts = 0;
        uint256 withdrawFailures = 0;
        uint256 logLen = orchestrator.getActionLogLength();
        for (uint256 i = 0; i < logLen; i++) {
            SwarmOrchestrator.ActionRecord memory rec = orchestrator.getActionRecord(i);
            if (rec.action == uint8(AgentLib.Action.WITHDRAW)) {
                withdrawAttempts++;
                if (!rec.success) withdrawFailures++;
            }
        }

        console.log("WITHDRAW attempts: %d", withdrawAttempts);
        console.log("WITHDRAW failures: %d", withdrawFailures);
        console.log("Total failed actions: %d", orchestrator.ghost_totalFailedActions());
        console.log("Expected failures: %d", orchestrator.ghost_expectedFailures());
    }
}
