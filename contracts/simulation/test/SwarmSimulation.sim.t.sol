// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {SwarmOrchestrator} from "../src/SwarmOrchestrator.sol";
import {AgentLib} from "../src/agents/AgentLib.sol";
import {DataExport} from "../src/libraries/DataExport.sol";
import {SwarmInvariants} from "../src/assertions/SwarmInvariants.sol";
import {IPerpetualVault} from "@issuer/perpetual/interfaces/IPerpetualVault.sol";
import {IVolatilityPool} from "@issuer/volatility/interfaces/IVolatilityPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";

/// @title SwarmSimulationTest - 100-agent autonomous swarm simulation
/// @notice Runs weekly ticks with 100 agents making autonomous decisions.
///         Report generation (HTML dashboard) is handled by scripts/generate_report.py.
contract SwarmSimulationTest is Test {
    SwarmOrchestrator public orchestrator;

    VaultNFT internal _vault;
    BtcToken internal _btcToken;
    IERC20 internal _wbtc;

    uint256 constant INVARIANT_CHECK_INTERVAL = 50;

    function _simulationWeeks() internal returns (uint256 weeks_) {
        weeks_ = vm.envOr("SIMULATION_WEEKS", uint256(320));
        require(weeks_ > 0, "SIMULATION_WEEKS must be > 0");
    }

    function setUp() public {
        orchestrator = new SwarmOrchestrator();
        orchestrator.setVm(vm);
        orchestrator.deployProtocol();
        orchestrator.deployIssuer("Swarm");
        orchestrator.deployDeFiStack();
        orchestrator.initializeAgents(42);

        (VaultNFT vault, BtcToken btcToken, MockWBTC wbtc) = orchestrator.getProtocol();
        _vault = vault;
        _btcToken = btcToken;
        _wbtc = IERC20(address(wbtc));
    }

    /// @notice Swarm simulation with dynamic tick count (default 320, override via SIMULATION_WEEKS env var)
    /// @dev Requires reports/price_series.csv to exist (generate via scripts/generate_price_series.py)
    function test_swarm() public {
        uint256 weeks_ = _simulationWeeks();
        _loadPriceSeries();

        console.log("=== SWARM SIMULATION START ===");
        console.log("Agents: 100 | Ticks: %d | Seed: 42", weeks_);

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
        _exportData();
        console.log("Reports written to reports/");
    }

    /// @notice Smoke test (always 20 weeks, ignores SIMULATION_WEEKS)
    function test_swarm_smoke() public {
        _loadPriceSeries();
        for (uint256 tick = 0; tick < 20; tick++) {
            orchestrator.executeTick();
        }
        _checkInvariants(20);
        _exportData();
    }

    // ==================== Invariant Checks ====================

    function _checkInvariants(uint256 tick) internal {
        uint256 vaultBalance = _wbtc.balanceOf(address(_vault));
        uint256 matchPool = _vault.matchPool();
        assertTrue(vaultBalance >= matchPool, string.concat("Tick ", vm.toString(tick), ": vault balance < match pool"));

        (bool perpValid,) = SwarmInvariants.checkPerpVaultSolvency(
            IPerpetualVault(address(orchestrator.perpVault())),
            IERC20(address(_btcToken)),
            orchestrator.getAllPerpPositionIds()
        );
        if (!perpValid) {
            console.log("WARNING Tick %d: perp vault insolvent", tick);
        }

        (bool volValid,) = SwarmInvariants.checkVolPoolSolvency(
            IVolatilityPool(address(orchestrator.volPool())),
            IERC20(address(_btcToken))
        );
        assertTrue(volValid, string.concat("Tick ", vm.toString(tick), ": vol pool insolvent"));
    }

    // ==================== Console Analytics ====================

    function _logProgress(uint256 tick) internal view {
        (uint256 price,,) = orchestrator.priceState();
        uint256 vbtcRatio = orchestrator.curvePool().initialized()
            ? orchestrator.curvePool().spotPrice()
            : 0;
        console.log("Tick %d | Price: %d | vBTC ratio: %d", tick, price / 1e18, vbtcRatio * 100 / 1e18);
    }

    function _logFinalResults() internal view {
        console.log("Total actions: %d", orchestrator.ghost_totalActions());
        console.log("Failed actions: %d", orchestrator.ghost_totalFailedActions());
        console.log("Total deposited: %d sats", orchestrator.ghost_totalDeposited());
        console.log("Total withdrawn: %d sats", orchestrator.ghost_totalWithdrawn());
        console.log("Total forfeited: %d sats", orchestrator.ghost_totalForfeited());
        console.log("Match pool remaining: %d sats", _vault.matchPool());
    }

    // ==================== Structured Data Export (Incremental Writes) ====================

    function _exportData() internal {
        uint256 tickCount = orchestrator.getTickCount();
        _exportMarketData(tickCount);
        _exportAgentNetWorth(tickCount);
        _exportAgentActions();
        _exportAgentConfigs();
        _exportSimulationSummary(tickCount);
        _exportSummaryMarkdown(tickCount);
    }

    /// @notice Write market_data.csv: tick,price,vbtcRatio,tvl,matchPool,regime
    function _exportMarketData(uint256 tickCount) internal {
        vm.writeFile("reports/market_data.csv", "tick,price,vbtcRatio,tvl,matchPool,regime\n");

        for (uint256 t = 0; t < tickCount; t++) {
            vm.writeLine("reports/market_data.csv", string.concat(
                vm.toString(t), ",",
                vm.toString(orchestrator.priceSnapshots(t)), ",",
                vm.toString(orchestrator.vbtcRatioSnapshots(t)), ",",
                vm.toString(orchestrator.tvlSnapshots(t)), ",",
                vm.toString(orchestrator.matchPoolSnapshots(t)), ",",
                vm.toString(uint256(orchestrator.regimeSnapshots(t)))
            ));
        }
    }

    /// @notice Write agent_net_worth.csv: tick,agent_0,...,agent_99 (wide format)
    function _exportAgentNetWorth(uint256 tickCount) internal {
        // Build header
        string memory header = "tick";
        for (uint256 i = 0; i < 100; i++) {
            header = string.concat(header, ",agent_", vm.toString(i));
        }
        vm.writeFile("reports/agent_net_worth.csv", string.concat(header, "\n"));

        // Write rows incrementally
        for (uint256 t = 0; t < tickCount; t++) {
            string memory row = vm.toString(t);
            for (uint256 i = 0; i < 100; i++) {
                row = string.concat(row, ",", vm.toString(orchestrator.getNetWorthAt(t, i)));
            }
            vm.writeLine("reports/agent_net_worth.csv", row);
        }
    }

    /// @notice Write agent_actions.csv: tick,agentId,action,actionName,amount,success
    function _exportAgentActions() internal {
        vm.writeFile("reports/agent_actions.csv", "tick,agentId,action,actionName,amount,success\n");

        uint256 logLen = orchestrator.getActionLogLength();
        for (uint256 i = 0; i < logLen; i++) {
            SwarmOrchestrator.ActionRecord memory rec = orchestrator.getActionRecord(i);
            vm.writeLine("reports/agent_actions.csv", string.concat(
                vm.toString(rec.tick), ",",
                vm.toString(rec.agentId), ",",
                vm.toString(uint256(rec.action)), ",",
                DataExport.actionName(rec.action), ",",
                vm.toString(rec.amount), ",",
                rec.success ? "true" : "false"
            ));
        }
    }

    /// @notice Write agent_configs.json: array of 100 agent config objects
    function _exportAgentConfigs() internal {
        vm.writeFile("reports/agent_configs.json", "[\n");

        for (uint256 i = 0; i < 100; i++) {
            (
                AgentLib.Archetype archetype,
                uint8 riskTolerance,
                uint8 patience,
                uint16 leveragePreference,
                int8 volBias,
                uint8 rebalanceFrequency,
                uint64 initialCap,
            ) = orchestrator.configs(i);

            string memory entry = string.concat(
                '  {"agentId":', vm.toString(i),
                ',"archetype":"', DataExport.archetypeName(uint8(archetype)),
                '","riskTolerance":', vm.toString(uint256(riskTolerance)),
                ',"patience":', vm.toString(uint256(patience)),
                ',"leveragePreference":', vm.toString(uint256(leveragePreference)),
                ',"volBias":', vm.toString(volBias),
                ',"rebalanceFrequency":', vm.toString(uint256(rebalanceFrequency)),
                ',"initialCapitalWbtc":', vm.toString(uint256(initialCap)),
                "}"
            );

            string memory suffix = i < 99 ? "," : "";
            vm.writeLine("reports/agent_configs.json", string.concat(entry, suffix));
        }

        vm.writeLine("reports/agent_configs.json", "]");
    }

    /// @notice Write simulation_summary.json: ghost vars, params, final state
    function _exportSimulationSummary(uint256 tickCount) internal {
        uint256 finalPrice = tickCount > 0 ? orchestrator.priceSnapshots(tickCount - 1) : 0;
        uint256 finalVbtcRatio = tickCount > 0 ? orchestrator.vbtcRatioSnapshots(tickCount - 1) : 0;
        uint256 finalTvl = tickCount > 0 ? orchestrator.tvlSnapshots(tickCount - 1) : 0;

        string memory json = string.concat(
            '{\n  "seed":42,\n  "agentCount":100,\n  "tickCount":', vm.toString(tickCount),
            ',\n  "tickDuration":"1 week",'
        );

        json = string.concat(
            json,
            '\n  "ghostVariables":{\n',
            '    "totalDeposited":"', vm.toString(orchestrator.ghost_totalDeposited()), '",\n',
            '    "totalWithdrawn":"', vm.toString(orchestrator.ghost_totalWithdrawn()), '",\n',
            '    "totalForfeited":"', vm.toString(orchestrator.ghost_totalForfeited()), '",\n',
            '    "totalMatchClaimed":"', vm.toString(orchestrator.ghost_totalMatchClaimed()), '",\n',
            '    "totalActions":"', vm.toString(orchestrator.ghost_totalActions()), '",\n',
            '    "totalFailedActions":"', vm.toString(orchestrator.ghost_totalFailedActions()), '",\n',
            '    "totalSwaps":"', vm.toString(orchestrator.ghost_totalSwaps()), '"\n  },'
        );

        json = string.concat(
            json,
            '\n  "finalState":{\n',
            '    "price":"', vm.toString(finalPrice), '",\n',
            '    "vbtcRatio":"', vm.toString(finalVbtcRatio), '",\n',
            '    "tvl":"', vm.toString(finalTvl), '",\n',
            '    "matchPool":"', vm.toString(_vault.matchPool()), '"\n  }\n}'
        );

        vm.writeFile("reports/simulation_summary.json", json);
    }

    /// @notice Write summary.md: human-readable simulation overview
    function _exportSummaryMarkdown(uint256 tickCount) internal {
        vm.writeFile("reports/summary.md", "# Simulation Summary\n\n");

        // Parameters
        vm.writeLine("reports/summary.md", string.concat(
            "## Parameters\n\n",
            "| Parameter | Value |\n",
            "|-----------|-------|\n",
            "| Seed | 42 |\n",
            "| Agents | 100 |\n",
            "| Ticks | ", vm.toString(tickCount), " |\n",
            "| Tick Duration | 1 week |\n"
        ));

        // Ghost variables
        vm.writeLine("reports/summary.md", string.concat(
            "\n## Ghost Variables\n\n",
            "| Variable | Value |\n",
            "|----------|------|\n",
            "| Total Deposited | ", _formatBtc(orchestrator.ghost_totalDeposited()), " |\n",
            "| Total Withdrawn | ", _formatBtc(orchestrator.ghost_totalWithdrawn()), " |\n",
            "| Total Forfeited | ", _formatBtc(orchestrator.ghost_totalForfeited()), " |\n",
            "| Total Match Claimed | ", _formatBtc(orchestrator.ghost_totalMatchClaimed()), " |\n",
            "| Total Actions | ", vm.toString(orchestrator.ghost_totalActions()), " |\n",
            "| Failed Actions | ", vm.toString(orchestrator.ghost_totalFailedActions()), " |\n",
            "| Total Swaps | ", vm.toString(orchestrator.ghost_totalSwaps()), " |"
        ));

        // Final state
        uint256 finalPrice = tickCount > 0 ? orchestrator.priceSnapshots(tickCount - 1) : 0;
        uint256 finalVbtcRatio = tickCount > 0 ? orchestrator.vbtcRatioSnapshots(tickCount - 1) : 0;

        vm.writeLine("reports/summary.md", string.concat(
            "\n## Final State\n\n",
            "| Metric | Value |\n",
            "|--------|-------|\n",
            "| Price | ", vm.toString(finalPrice / 1e18), " USDC |\n",
            "| vBTC Ratio | ", _formatPct(finalVbtcRatio), " |\n",
            "| Match Pool | ", _formatBtc(_vault.matchPool()), " |"
        ));

        // Leaderboard (top 20 by final net worth)
        vm.writeLine("reports/summary.md", "\n## Leaderboard (Top 20)\n");
        vm.writeLine("reports/summary.md", "| Rank | Agent | Archetype | Initial (BTC) | Final NW (BTC) |");
        vm.writeLine("reports/summary.md", "|------|-------|-----------|---------------|----------------|");

        // Build simple leaderboard via selection sort
        uint256[100] memory nw;
        uint256[100] memory idx;
        for (uint256 i = 0; i < 100; i++) {
            nw[i] = tickCount > 0 ? orchestrator.getNetWorthAt(tickCount - 1, i) : 0;
            idx[i] = i;
        }
        for (uint256 i = 0; i < 20; i++) {
            for (uint256 j = i + 1; j < 100; j++) {
                if (nw[j] > nw[i]) {
                    (nw[i], nw[j]) = (nw[j], nw[i]);
                    (idx[i], idx[j]) = (idx[j], idx[i]);
                }
            }
        }

        for (uint256 i = 0; i < 20; i++) {
            (AgentLib.Archetype archetype,,,,,,uint64 initialCap,) = orchestrator.configs(idx[i]);
            vm.writeLine("reports/summary.md", string.concat(
                "| ", vm.toString(i + 1),
                " | #", vm.toString(idx[i]),
                " | ", DataExport.archetypeName(uint8(archetype)),
                " | ", _formatBtc(uint256(initialCap)),
                " | ", _formatBtc(nw[i]),
                " |"
            ));
        }
    }

    // ==================== Formatting Helpers ====================

    function _formatBtc(uint256 sats) internal pure returns (string memory) {
        uint256 whole = sats / 1e8;
        uint256 frac = (sats % 1e8) / 1e4; // 4 decimal places (1e4 sats = 1 den)
        string memory fracStr;
        if (frac == 0) {
            fracStr = "0000";
        } else if (frac < 10) {
            fracStr = string.concat("000", vm.toString(frac));
        } else if (frac < 100) {
            fracStr = string.concat("00", vm.toString(frac));
        } else if (frac < 1000) {
            fracStr = string.concat("0", vm.toString(frac));
        } else {
            fracStr = vm.toString(frac);
        }
        return string.concat(vm.toString(whole), ".", fracStr, " BTC");
    }

    function _formatPct(uint256 ratio18) internal pure returns (string memory) {
        uint256 scaled = ratio18 * 10000 / 1e18;
        uint256 whole = scaled / 100;
        uint256 frac = scaled % 100;
        string memory fracStr = frac < 10
            ? string.concat("0", vm.toString(frac))
            : vm.toString(frac);
        return string.concat(vm.toString(whole), ".", fracStr, "%");
    }

    // ==================== Price Series Loading ====================

    /// @notice Load pre-generated price series from reports/price_series.csv
    function _loadPriceSeries() internal {
        string memory raw = vm.readFile("reports/price_series.csv");
        string[] memory lines = vm.split(raw, "\n");

        // Skip header (line 0) and any trailing empty line
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
            // CSV format: tick,price,regime
            prices[idx] = vm.parseUint(cols[1]);
            regimes[idx] = uint8(vm.parseUint(cols[2]));
            idx++;
        }

        orchestrator.loadPriceSeries(prices, regimes);
        console.log("Loaded %d price points from reports/price_series.csv", dataLines);
    }
}
