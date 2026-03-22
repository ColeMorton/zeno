// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ProtocolSwarmOrchestrator} from "../src/ProtocolSwarmOrchestrator.sol";
import {ProtocolAgentLib} from "../src/agents/ProtocolAgentLib.sol";
import {ProtocolInvariants} from "../src/assertions/ProtocolInvariants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";

/// @title ProtocolSwarmSimulationTest - Protocol-only 100-agent swarm simulation
/// @notice Tests VaultNFT lifecycle, delegation, dormancy, and vBTC separation in isolation
contract ProtocolSwarmSimulationTest is Test {
    ProtocolSwarmOrchestrator public orchestrator;

    VaultNFT internal _vault;
    BtcToken internal _btcToken;
    IERC20 internal _wbtc;

    uint256 constant INVARIANT_CHECK_INTERVAL = 50;

    function _simulationWeeks() internal returns (uint256 weeks_) {
        weeks_ = vm.envOr("SIMULATION_WEEKS", uint256(320));
        require(weeks_ > 0, "SIMULATION_WEEKS must be > 0");
    }

    function setUp() public {
        orchestrator = new ProtocolSwarmOrchestrator();
        orchestrator.setVm(vm);
        orchestrator.deployProtocol();
        orchestrator.deployIssuer("ProtocolSwarm");
        orchestrator.initializeAgents(42);

        (VaultNFT vault, BtcToken btcToken, MockWBTC wbtc) = orchestrator.getProtocol();
        _vault = vault;
        _btcToken = btcToken;
        _wbtc = IERC20(address(wbtc));
    }

    /// @notice Protocol-only swarm simulation (default 320, override via SIMULATION_WEEKS env var)
    /// @dev Requires reports/price_series.csv to exist (generate via scripts/generate_price_series.py)
    function test_protocolSwarm() public {
        uint256 weeks_ = _simulationWeeks();
        _loadPriceSeries();
        console.log("=== PROTOCOL SWARM SIMULATION START ===");
        console.log("Agents: 100 | Ticks: %d | Seed: 42", weeks_);
        console.log("Archetypes: Diamond Hands(25), Multi-Vault(10), Delegation Grantor(10),");
        console.log("  Delegate Withdrawer(10), Strategic Redeemer(10), Panic Seller(10),");
        console.log("  vBTC Separator(10), Predator(5), Arbitrageur(5), Passive Holder(5)");

        for (uint256 tick = 0; tick < weeks_; tick++) {
            orchestrator.executeTick();

            if (tick > 0 && tick % INVARIANT_CHECK_INTERVAL == 0) {
                _checkInvariants(tick);
            }

            if (tick % 100 == 0) {
                _logProgress(tick);
            }
        }

        console.log("=== SIMULATION COMPLETE ===");
        _logFinalResults();
    }

    /// @notice Smoke test (always 20 weeks, ignores SIMULATION_WEEKS)
    function test_protocolSwarm_smoke() public {
        _loadPriceSeries();
        for (uint256 tick = 0; tick < 20; tick++) {
            orchestrator.executeTick();
        }

        _logFinalResults();
    }

    // ==================== Invariant Checks ====================

    function _checkInvariants(uint256 tick) internal view {
        // 1. Vault solvency
        (bool vaultOk, string memory vaultMsg) = ProtocolInvariants.checkVaultSolvency(_vault, _wbtc);
        assertTrue(vaultOk, string.concat("Tick ", vm.toString(tick), ": ", vaultMsg));

        // 2. Delegation bounds (check all agents)
        address[] memory agentAddresses = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            agentAddresses[i] = orchestrator.agents(i);
        }
        (bool delOk, string memory delMsg) = ProtocolInvariants.checkDelegationBounds(_vault, agentAddresses);
        assertTrue(delOk, string.concat("Tick ", vm.toString(tick), ": ", delMsg));

        // 3. System conservation (5% tolerance for rounding)
        (bool consOk, string memory consMsg) = ProtocolInvariants.checkSystemConservation(
            orchestrator.ghost_totalDeposited(),
            orchestrator.ghost_totalWithdrawn(),
            orchestrator.ghost_totalReturned(),
            orchestrator.ghost_totalMatchClaimed(),
            _wbtc.balanceOf(address(_vault)),
            500 // 5%
        );
        assertTrue(consOk, string.concat("Tick ", vm.toString(tick), ": ", consMsg));
    }

    // ==================== Logging ====================

    function _logProgress(uint256 tick) internal view {
        console.log("--- Tick %d ---", tick);
        console.log("  Actions: %d (failed: %d)", orchestrator.ghost_totalActions(), orchestrator.ghost_totalFailedActions());
        console.log("  TVL: %d | Match Pool: %d", _wbtc.balanceOf(address(_vault)), _vault.matchPool());
    }

    // ==================== Price Series Loading ====================

    /// @notice Load pre-generated price series from reports/price_series.csv
    function _loadPriceSeries() internal {
        string memory raw = vm.readFile("reports/price_series.csv");
        string[] memory lines = vm.split(raw, "\n");

        uint256 dataLines = 0;
        for (uint256 i = 1; i < lines.length; i++) {
            if (bytes(lines[i]).length > 0) dataLines++;
        }
        require(dataLines > 0, "Empty price series CSV");

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
        console.log("Loaded %d price points from reports/price_series.csv", dataLines);
    }

    function _logFinalResults() internal view {
        console.log("");
        console.log("=== PROTOCOL SIMULATION RESULTS ===");
        console.log("Total ticks: %d", orchestrator.getTickCount());
        console.log("Total actions: %d", orchestrator.ghost_totalActions());
        console.log("Failed actions: %d", orchestrator.ghost_totalFailedActions());
        console.log("Total deposited: %d", orchestrator.ghost_totalDeposited());
        console.log("Total withdrawn: %d", orchestrator.ghost_totalWithdrawn());
        console.log("Total forfeited: %d", orchestrator.ghost_totalForfeited());
        console.log("Total match claimed: %d", orchestrator.ghost_totalMatchClaimed());
        console.log("--- Protocol-Specific ---");
        console.log("Delegation grants: %d", orchestrator.ghost_totalDelegationGrants());
        console.log("Delegation revokes: %d", orchestrator.ghost_totalDelegationRevokes());
        console.log("Delegated withdrawals: %d", orchestrator.ghost_totalDelegatedWithdrawals());
        console.log("vBTC separations: %d", orchestrator.ghost_totalSeparations());
        console.log("vBTC recombinations: %d", orchestrator.ghost_totalRecombinations());
        console.log("Final TVL: %d", _wbtc.balanceOf(address(_vault)));
        console.log("Final match pool: %d", _vault.matchPool());
    }
}
