// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {SimulationOrchestrator, ProtocolDeployment, IssuerDeployment, MockWBTC} from "./SimulationOrchestrator.sol";
import {PriceSimulator} from "./libraries/PriceSimulator.sol";
import {NetWorthLib} from "./libraries/NetWorthLib.sol";
import {AgentLib} from "./agents/AgentLib.sol";
import {SimCurvePool} from "./mocks/SimCurvePool.sol";
import {MockTWAPOracle} from "./mocks/MockTWAPOracle.sol";

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";
import {IPerpetualVault} from "@issuer/perpetual/interfaces/IPerpetualVault.sol";
import {IVolatilityPool} from "@issuer/volatility/interfaces/IVolatilityPool.sol";
import {PerpetualVault} from "@issuer/perpetual/PerpetualVault.sol";
import {VolatilityPool} from "@issuer/volatility/VolatilityPool.sol";
import {VarianceOracle} from "@issuer/volatility/VarianceOracle.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SwarmOrchestrator - 100-agent autonomous simulation orchestrator
/// @notice Deploys protocol + DeFi stack, manages agents, executes weekly ticks
/// @dev Must be called from a Foundry Test contract for vm.prank/vm.warp access
contract SwarmOrchestrator is SimulationOrchestrator {
    using AgentLib for AgentLib.AgentConfig;

    // ==================== Constants ====================

    uint256 public constant AGENT_COUNT = 100;
    uint256 public constant INITIAL_PRICE = 60000e18; // $60,000 WBTC/USDC
    uint256 public constant INITIAL_VBTC_RATIO = 75e16; // 0.75 vBTC/WBTC
    uint256 public constant TREASURES_PER_AGENT = 10;
    uint256 public constant MIN_DORMANCY_TICKS = 162; // 1129 days / 7 days ≈ 161.3, rounded up

    // ==================== DeFi Stack ====================

    PerpetualVault public perpVault;
    VolatilityPool public volPool;
    VarianceOracle public varianceOracle;
    SimCurvePool public curvePool;
    MockTWAPOracle public twapOracle;

    // ==================== Simulation State ====================

    PriceSimulator.PriceState public priceState;
    uint256 public currentTick;

    // Price history for signal computation (rolling 30-tick window)
    uint256[30] public priceHistory;
    uint256 public priceHistoryIndex;

    // Agent state
    address[100] public agents;
    AgentLib.AgentConfig[100] public configs;

    // Agent mutable state stored as mappings (dynamic arrays can't be in fixed arrays)
    mapping(uint256 => uint256[]) internal _agentVaultIds;
    mapping(uint256 => uint256[]) internal _agentPerpIds;
    mapping(uint256 => uint256) internal _agentLongVolShares;
    mapping(uint256 => uint256) internal _agentShortVolShares;
    mapping(uint256 => uint256) internal _agentLongVolCostBasis;
    mapping(uint256 => uint256) internal _agentShortVolCostBasis;
    mapping(uint256 => bool) internal _agentHasSeparatedVbtc;
    mapping(uint256 => uint256) internal _agentLastActionTick;

    // Per-agent per-vault last withdrawal tick (cooldown tracking)
    mapping(uint256 => mapping(uint256 => uint256)) internal _agentLastWithdrawTick; // agentId => vaultId => tick

    // Ghost variables for invariant tracking
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalForfeited;
    uint256 public ghost_totalReturned;
    uint256 public ghost_totalMatchClaimed;
    uint256 public ghost_totalActions;
    uint256 public ghost_totalFailedActions;
    uint256 public ghost_expectedFailures;
    uint256 public ghost_unexpectedFailures;
    uint256 public ghost_totalSwaps;

    // All active perp position IDs (for solvency checks)
    uint256[] public allPerpPositionIds;

    // Net worth snapshots
    mapping(uint256 => mapping(uint256 => uint256)) public netWorthAt; // tick => agentId => netWorth

    // Tick snapshots for report charts
    uint256[] public priceSnapshots;
    uint256[] public vbtcRatioSnapshots;
    uint256[] public tvlSnapshots;
    uint256[] public matchPoolSnapshots;
    uint8[] public regimeSnapshots;
    uint256[] public perpVaultBalanceSnapshots;
    uint256[] public perpTotalCollateralSnapshots;
    uint256[] public volPoolBalanceSnapshots;
    uint256[] public volPoolAssetsSnapshots;

    // Per-agent action counts: agentId => Action enum => count
    mapping(uint256 => mapping(uint8 => uint256)) public agentActionCounts;

    // Cached dormancy target per tick (computed once, shared by all dormancy agents)
    uint256 internal _cachedDormantTarget;

    // Last error type captured by _classifyAndCountFailure (transient, cleared per action)
    string internal _lastErrorType;

    // Per-tick action log for structured export
    struct ActionRecord {
        uint256 tick;
        uint256 agentId;
        uint8 action;
        uint256 amount;
        bool success;
        string errorType;
    }

    ActionRecord[] internal _actionLog;

    // Pre-loaded price series (optional override for decoupled price generation)
    uint256[] internal _priceOverrides;
    uint8[] internal _regimeOverrides;

    // ==================== Events ====================

    event TickComplete(
        uint256 indexed tick,
        uint256 price,
        uint256 vbtcRatio,
        uint256 tvl,
        uint256 matchPool
    );

    event AgentAction(
        uint256 indexed tick,
        uint256 indexed agentId,
        AgentLib.Action action,
        uint256 amount,
        bool success
    );

    event AgentNetWorth(
        uint256 indexed tick,
        uint256 indexed agentId,
        uint256 netWorth
    );

    event SimulationComplete(
        uint256 totalTicks,
        uint256 totalActions,
        uint256 totalFailedActions
    );

    // ==================== Vm Interface ====================

    // The test contract sets this so we can use vm.prank/vm.warp
    Vm internal _vm;

    function setVm(Vm vm_) external {
        _vm = vm_;
    }

    // ==================== Deployment ====================

    /// @notice Deploy the DeFi stack (PerpetualVault, VolatilityPool, AMM, oracles)
    /// @dev Must be called after deployProtocol() and deployIssuer()
    function deployDeFiStack() external {
        require(address(protocol.vault) != address(0), "Deploy protocol first");
        require(issuers.length > 0, "Deploy issuer first");

        // Deploy SimCurvePool (empty — agents will seed it after first vesting)
        curvePool = new SimCurvePool(
            address(protocol.wbtc),
            address(protocol.btcToken)
        );
        twapOracle = new MockTWAPOracle(INITIAL_VBTC_RATIO);

        // Deploy PerpetualVault: uses vBTC + Curve pool for pricing
        perpVault = new PerpetualVault(
            address(protocol.btcToken),
            address(curvePool)
        );

        // Deploy VarianceOracle: 1-week interval, 604800s TWAP, 4-week staleness
        varianceOracle = new VarianceOracle(
            address(twapOracle),
            7 days,        // minObservationInterval
            604800,        // twapPeriod (1 week)
            28 days,       // maxStaleness
            5e17,          // minPriceRatio (0.50)
            1e18           // maxPriceRatio (1.00)
        );

        // Deploy VolatilityPool: 4% strike, weekly settlement, 4-week window
        volPool = new VolatilityPool(
            address(protocol.btcToken),
            address(varianceOracle),
            4e16,          // strikeVariance (4%)
            7 days,        // settlementInterval
            28 days,       // varianceWindow
            1e6            // minDeposit (0.01 vBTC)
        );

        // Price state is populated from CSV via loadPriceSeries() before first executeTick()
    }

    /// @notice Initialize 100 agents with deterministic configs and funding
    /// @param seed Base random seed for reproducibility
    function initializeAgents(uint256 seed) external {
        require(address(protocol.vault) != address(0), "Deploy protocol first");
        require(issuers.length > 0, "Deploy issuer first");

        for (uint256 i = 0; i < AGENT_COUNT; i++) {
            // Generate deterministic address
            agents[i] = _vm.addr(seed + i + 1);

            // Generate config
            configs[i] = AgentLib.generateConfig(seed, i);

            // Fund with WBTC
            protocol.wbtc.mint(agents[i], configs[i].initialCapitalWbtc);
            ghost_totalDeposited; // tracking happens at mint time

            // Mint treasures
            IssuerDeployment storage issuer = issuers[0];
            for (uint256 j = 0; j < TREASURES_PER_AGENT; j++) {
                issuer.treasureNFT.mint(agents[i]);
            }

            // Approve protocol contracts + AMM
            _vm.startPrank(agents[i]);
            protocol.wbtc.approve(address(protocol.vault), type(uint256).max);
            protocol.btcToken.approve(address(protocol.vault), type(uint256).max);
            protocol.btcToken.approve(address(perpVault), type(uint256).max);
            protocol.btcToken.approve(address(volPool), type(uint256).max);
            protocol.wbtc.approve(address(curvePool), type(uint256).max);
            protocol.btcToken.approve(address(curvePool), type(uint256).max);
            _vm.stopPrank();
        }
    }

    // ==================== Tick Execution ====================

    /// @notice Execute one simulation tick (1 week)
    function executeTick() external {
        // 1. Advance time by 1 week
        _vm.warp(block.timestamp + 7 days);

        // 2. Update WBTC/USDC price from pre-loaded CSV series
        require(_priceOverrides.length > 0, "Price series not loaded");
        require(currentTick < _priceOverrides.length, "Price series exhausted");
        priceState.price = _priceOverrides[currentTick];
        priceState.regime = _regimeOverrides[currentTick];

        // 3. Update price history
        priceHistory[priceHistoryIndex % 30] = priceState.price;
        priceHistoryIndex++;

        // 4. Compute market signals (reads vbtcRatio from AMM)
        AgentLib.MarketSignals memory signals = _computeMarketSignals();

        // 5. Cache dormancy target once per tick (skip before MIN_DORMANCY_TICKS)
        if (currentTick >= MIN_DORMANCY_TICKS) {
            _cachedDormantTarget = _findDormantTarget(type(uint256).max);
        } else {
            _cachedDormantTarget = 0;
        }

        // 6. Execute each agent
        for (uint256 i = 0; i < AGENT_COUNT; i++) {
            _executeAgent(i, signals);
        }

        // 6. Read emergent vBTC ratio from AMM (0 if pool not yet initialized)
        uint256 vbtcRatio = curvePool.initialized() ? curvePool.spotPrice() : 0;

        // 7. Feed TWAP oracle from AMM (skip if out of bounds [0.50, 1.00])
        if (vbtcRatio >= 5e17 && vbtcRatio <= 1e18) {
            twapOracle.setTWAP(vbtcRatio);
        }

        // 8. Record oracle observation (may fail if too soon on first tick)
        try varianceOracle.observe() {} catch {}

        // 9. Settle volatility pool if due
        try volPool.settle() {} catch {}

        // 10. Snapshot + emit tick summary
        uint256 tvl = IERC20(address(protocol.wbtc)).balanceOf(address(protocol.vault));
        uint256 mp = protocol.vault.matchPool();

        priceSnapshots.push(priceState.price);
        vbtcRatioSnapshots.push(vbtcRatio);
        tvlSnapshots.push(tvl);
        matchPoolSnapshots.push(mp);
        regimeSnapshots.push(priceState.regime);

        // Perp / Vol solvency snapshots
        uint256 perpBal = protocol.btcToken.balanceOf(address(perpVault));
        uint256 volBal = protocol.btcToken.balanceOf(address(volPool));
        IPerpetualVault.GlobalState memory perpState = perpVault.getGlobalState();
        uint256 volAssets = volPool.longPoolAssets() + volPool.shortPoolAssets();

        perpVaultBalanceSnapshots.push(perpBal);
        perpTotalCollateralSnapshots.push(perpState.longCollateral + perpState.shortCollateral);
        volPoolBalanceSnapshots.push(volBal);
        volPoolAssetsSnapshots.push(volAssets);

        emit TickComplete(currentTick, priceState.price, vbtcRatio, tvl, mp);

        currentTick++;
    }

    // ==================== Agent Execution ====================

    function _executeAgent(uint256 agentId, AgentLib.MarketSignals memory signals) internal {
        // Build agent state
        uint256[] memory vaultIds = _agentVaultIds[agentId];
        uint256[] memory lastWithdrawTicks = new uint256[](vaultIds.length);
        for (uint256 i = 0; i < vaultIds.length; i++) {
            lastWithdrawTicks[i] = _agentLastWithdrawTick[agentId][vaultIds[i]];
        }

        AgentLib.AgentState memory state = AgentLib.AgentState({
            vaultIds: vaultIds,
            perpPositionIds: _agentPerpIds[agentId],
            longVolShares: _agentLongVolShares[agentId],
            shortVolShares: _agentShortVolShares[agentId],
            hasSeparatedVbtc: _agentHasSeparatedVbtc[agentId],
            lastActionTick: _agentLastActionTick[agentId],
            prevNetWorth: 0,
            lastFailedAction: AgentLib.Action.NONE,
            consecutiveFailures: 0,
            failureSuppressTick: 0,
            lastWithdrawTicks: lastWithdrawTicks
        });

        // Build portfolio view
        AgentLib.Portfolio memory portfolio = _buildPortfolio(agentId, state);

        // Decide action
        AgentLib.ActionParams memory action = AgentLib.decide(configs[agentId], state, signals, portfolio);

        // Compute and store net worth (reuse cached vault data from portfolio)
        uint256 nw = _computeNetWorth(agentId, state, portfolio);
        netWorthAt[currentTick][agentId] = nw;
        emit AgentNetWorth(currentTick, agentId, nw);

        if (action.action == AgentLib.Action.NONE) return;

        // Execute action
        bool success = _executeAction(agentId, action);

        emit AgentAction(currentTick, agentId, action.action, action.amount, success);
        ghost_totalActions++;
        if (!success) ghost_totalFailedActions++;

        // Record action for structured export
        _actionLog.push(ActionRecord({
            tick: currentTick,
            agentId: agentId,
            action: uint8(action.action),
            amount: action.amount,
            success: success,
            errorType: _lastErrorType
        }));

        if (success) {
            // Don't treat MINT_VAULT as a rebalance action — it's a prerequisite,
            // not a strategic decision. Agents should act immediately after minting.
            if (action.action != AgentLib.Action.MINT_VAULT) {
                _agentLastActionTick[agentId] = currentTick;
            }
            agentActionCounts[agentId][uint8(action.action)]++;
        }

        // Secondary action: swap opportunity for STRAT_SWAP agents
        // Models real users who can withdraw AND trade in the same block
        if ((configs[agentId].psychology.strategyMask & AgentLib.STRAT_SWAP) != 0 && signals.ammInitialized) {
            // Build lightweight portfolio for swap decision (needs token balances + pool depth)
            address swapAgent = agents[agentId];
            AgentLib.Portfolio memory swapPortfolio;
            swapPortfolio.wbtcBalance = protocol.wbtc.balanceOf(swapAgent);
            swapPortfolio.vbtcBalance = protocol.btcToken.balanceOf(swapAgent);
            swapPortfolio.poolInitialized = true;
            swapPortfolio.poolWbtcReserve = curvePool.balances(0);
            swapPortfolio.poolVbtcReserve = curvePool.balances(1);

            AgentLib.ActionParams memory swapAction = AgentLib.decideSwap(configs[agentId], signals, swapPortfolio);
            if (swapAction.action != AgentLib.Action.NONE) {
                bool swapSuccess = _executeAction(agentId, swapAction);
                emit AgentAction(currentTick, agentId, swapAction.action, swapAction.amount, swapSuccess);
                ghost_totalActions++;
                if (!swapSuccess) ghost_totalFailedActions++;
                _actionLog.push(ActionRecord({
                    tick: currentTick,
                    agentId: agentId,
                    action: uint8(swapAction.action),
                    amount: swapAction.amount,
                    success: swapSuccess,
                    errorType: _lastErrorType
                }));
                if (swapSuccess) {
                    agentActionCounts[agentId][uint8(swapAction.action)]++;
                }
            }
        }
    }

    function _executeAction(uint256 agentId, AgentLib.ActionParams memory action) internal returns (bool) {
        _lastErrorType = "";
        address agent = agents[agentId];
        bool success;

        if (action.action == AgentLib.Action.MINT_VAULT) {
            success = _execMintVault(agentId, agent, action.amount);
        } else if (action.action == AgentLib.Action.WITHDRAW) {
            success = _execWithdraw(agentId, agent, action.targetId);
        } else if (action.action == AgentLib.Action.EARLY_REDEEM) {
            success = _execEarlyRedeem(agentId, agent, action.targetId);
        } else if (action.action == AgentLib.Action.STRIP) {
            success = _execStrip(agentId, agent, action.targetId, action.amount);
        } else if (action.action == AgentLib.Action.RECOMBINE) {
            success = _execRecombine(agent, action.targetId, action.amount);
        } else if (action.action == AgentLib.Action.CLAIM_MATCH) {
            success = _execClaimMatch(agent, action.targetId);
        } else if (action.action == AgentLib.Action.PROVE_ACTIVITY) {
            success = _execProveActivity(agent, action.targetId);
        } else if (action.action == AgentLib.Action.OPEN_PERP_LONG) {
            success = _execOpenPerp(agentId, agent, action.amount, action.leverage, IPerpetualVault.Side.LONG, action.action);
        } else if (action.action == AgentLib.Action.OPEN_PERP_SHORT) {
            success = _execOpenPerp(agentId, agent, action.amount, action.leverage, IPerpetualVault.Side.SHORT, action.action);
        } else if (action.action == AgentLib.Action.CLOSE_PERP) {
            success = _execClosePerp(agentId, agent, action.targetId);
        } else if (action.action == AgentLib.Action.DEPOSIT_VOL_LONG) {
            success = _execDepositVol(agentId, agent, action.amount, true, action.action);
        } else if (action.action == AgentLib.Action.DEPOSIT_VOL_SHORT) {
            success = _execDepositVol(agentId, agent, action.amount, false, action.action);
        } else if (action.action == AgentLib.Action.WITHDRAW_VOL_LONG) {
            success = _execWithdrawVol(agentId, agent, action.amount, true, action.action);
        } else if (action.action == AgentLib.Action.WITHDRAW_VOL_SHORT) {
            success = _execWithdrawVol(agentId, agent, action.amount, false, action.action);
        } else if (action.action == AgentLib.Action.POKE_DORMANT) {
            success = _execPokeDormant(agent, action.targetId);
        } else if (action.action == AgentLib.Action.CLAIM_DORMANT) {
            success = _execClaimDormant(agent, action.targetId, action.amount);
        } else if (action.action == AgentLib.Action.SWAP_VBTC_TO_WBTC) {
            success = _execSwap(agent, 1, 0, action.amount, action.action);
        } else if (action.action == AgentLib.Action.SWAP_WBTC_TO_VBTC) {
            success = _execSwap(agent, 0, 1, action.amount, action.action);
        } else if (action.action == AgentLib.Action.ADD_LIQUIDITY) {
            success = _execAddLiquidity(agent, action.amount);
        } else {
            success = false;
        }

        if (!success && bytes(_lastErrorType).length == 0) {
            _lastErrorType = "PreconditionFailed";
        }
        return success;
    }

    
    // ==================== Failure Classification ====================

    /// @notice Classify a revert reason and return the error type string
    function _classifyError(bytes4 selector, AgentLib.Action action) internal pure returns (string memory) {
        if (selector == 0x4118819e) return "WithdrawalTooSoon";
        if (selector == 0xb3167bfa) return "AlreadyClaimed";
        if (selector == 0x28630f73) return "AlreadyPoked";
        if (selector == 0xc3230ab1) return "NoPoolAvailable";
        if (selector == 0x87138d5c) return "NotInitialized";
        if (selector == 0xa4395c9e) {
            if (action == AgentLib.Action.WITHDRAW) return "StillVesting";
            return "Unexpected_StillVesting";
        }
        if (selector == 0x8df4b45e) return "RatioBoundsExceeded";
        return "Unexpected";
    }

    /// @notice Classify a revert reason as expected or unexpected failure
    /// @dev Expected failures: cooldown retries, race conditions, one-shot semantics
    ///      Unexpected failures: genuine bugs or protocol violations
    function _countFailure(AgentLib.Action action, bytes memory reason) internal {
        string memory errType;
        if (reason.length < 4) {
            ghost_unexpectedFailures++;
            _lastErrorType = "Unexpected";
            return;
        }
        bytes4 selector;
        assembly {
            selector := mload(add(reason, 32))
        }
        errType = _classifyError(selector, action);
        _lastErrorType = errType;

        // WithdrawalTooSoon -> expected (cooldown retry)
        if (selector == 0x4118819e) {
            ghost_expectedFailures++;
        // MatchClaimed -> expected (race condition, replaced by accumulator but keeping for compat)
        } else if (selector == 0xb3167bfa) {
            ghost_expectedFailures++;
        // AlreadyPoked -> expected (race condition)
        } else if (selector == 0x28630f73) {
            ghost_expectedFailures++;
        // NoPoolAvailable -> expected (pool drained)
        } else if (selector == 0xc3230ab1) {
            ghost_expectedFailures++;
        // NotInitialized -> expected (AMM not yet seeded)
        } else if (selector == 0x87138d5c) {
            ghost_expectedFailures++;
        // StillVesting -> expected only on withdraw (agent tries before vesting)
        } else if (selector == 0xa4395c9e) {
            if (action == AgentLib.Action.WITHDRAW) {
                ghost_expectedFailures++;
            } else {
                ghost_unexpectedFailures++;
            }
        // RatioBoundsExceeded -> expected (AMM guardrail, agents race toward boundary)
        } else if (selector == 0x8df4b45e) {
            ghost_expectedFailures++;
        // InsufficientCollateral -> expected for strip if vault balance depleted
        } else if (selector == 0x80a30d8c) {
            if (action == AgentLib.Action.STRIP) {
                ghost_expectedFailures++;
            } else {
                ghost_unexpectedFailures++;
            }
        // InsufficientReserve -> expected for recombine/claimDormant if reserve depleted
        } else if (selector == 0xf8c69f0d) {
            if (action == AgentLib.Action.RECOMBINE || action == AgentLib.Action.CLAIM_DORMANT) {
                ghost_expectedFailures++;
            } else {
                ghost_unexpectedFailures++;
            }
        } else {
            ghost_unexpectedFailures++;
        }
    }

// ==================== Action Executors ====================

    function _execMintVault(uint256 agentId, address agent, uint256 amount) internal returns (bool) {
        // Need a treasure NFT
        TreasureNFT treasure = issuers[0].treasureNFT;
        uint256 treasureBalance = treasure.balanceOf(agent);
        if (treasureBalance == 0 || amount == 0) return false;

        // Find first owned treasure token
        uint256 treasureId = _findOwnedToken(treasure, agent);
        if (treasureId == type(uint256).max) return false;

        _vm.startPrank(agent);
        try treasure.approve(address(protocol.vault), treasureId) {} catch (bytes memory reason) { _countFailure(AgentLib.Action.MINT_VAULT, reason); _vm.stopPrank(); return false; }

        try protocol.vault.mint(
            address(treasure),
            treasureId,
            address(protocol.wbtc),
            amount
        ) returns (uint256 vaultId) {
            _vm.stopPrank();
            _agentVaultIds[agentId].push(vaultId);
            ghost_totalDeposited += amount;
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.MINT_VAULT, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execWithdraw(uint256 agentId, address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.withdraw(vaultId) returns (uint256 amount) {
            _vm.stopPrank();
            ghost_totalWithdrawn += amount;
            _agentLastWithdrawTick[agentId][vaultId] = currentTick;
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.WITHDRAW, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execEarlyRedeem(uint256 agentId, address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.earlyRedeem(vaultId) returns (uint256 returned, uint256 forfeited) {
            _vm.stopPrank();
            ghost_totalForfeited += forfeited;
            ghost_totalReturned += returned;
            // Remove vault from agent's list
            _removeVaultId(agentId, vaultId);
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.EARLY_REDEEM, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execStrip(uint256 agentId, address agent, uint256 vaultId, uint256 amount) internal returns (bool) {
        if (amount == 0) return false;
        _vm.startPrank(agent);
        try protocol.vault.strip(vaultId, amount) {
            _vm.stopPrank();
            _agentHasSeparatedVbtc[agentId] = true;
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.STRIP, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execRecombine(address agent, uint256 vaultId, uint256 amount) internal returns (bool) {
        if (amount == 0) return false;
        _vm.startPrank(agent);
        try protocol.vault.recombine(vaultId, amount) {
            _vm.stopPrank();
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.RECOMBINE, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execClaimMatch(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.claimMatch(vaultId) returns (uint256 amount) {
            _vm.stopPrank();
            ghost_totalMatchClaimed += amount;
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.CLAIM_MATCH, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execProveActivity(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.proveActivity(vaultId) {
            _vm.stopPrank();
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.PROVE_ACTIVITY, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execOpenPerp(
        uint256 agentId,
        address agent,
        uint256 amount,
        uint16 leverage,
        IPerpetualVault.Side side,
        AgentLib.Action action
    ) internal returns (bool) {
        _vm.startPrank(agent);
        try perpVault.openPosition(amount, leverage, side) returns (uint256 positionId) {
            _vm.stopPrank();
            _agentPerpIds[agentId].push(positionId);
            allPerpPositionIds.push(positionId);
            return true;
        } catch (bytes memory reason) {
            _countFailure(action, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execClosePerp(uint256 agentId, address agent, uint256 positionId) internal returns (bool) {
        _vm.startPrank(agent);
        try perpVault.closePosition(positionId) returns (uint256) {
            _vm.stopPrank();
            _removePerpId(agentId, positionId);
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.CLOSE_PERP, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execDepositVol(uint256 agentId, address agent, uint256 amount, bool isLong, AgentLib.Action action) internal returns (bool) {
        _vm.startPrank(agent);
        if (isLong) {
            try volPool.depositLong(amount) returns (uint256 shares) {
                _vm.stopPrank();
                _agentLongVolShares[agentId] += shares;
                _agentLongVolCostBasis[agentId] += amount;
                return true;
            } catch (bytes memory reason) {
                _countFailure(action, reason);
                _vm.stopPrank();
                return false;
            }
        } else {
            try volPool.depositShort(amount) returns (uint256 shares) {
                _vm.stopPrank();
                _agentShortVolShares[agentId] += shares;
                _agentShortVolCostBasis[agentId] += amount;
                return true;
            } catch (bytes memory reason) {
                _countFailure(action, reason);
                _vm.stopPrank();
                return false;
            }
        }
    }

    function _execWithdrawVol(uint256 agentId, address agent, uint256 shares, bool isLong, AgentLib.Action action) internal returns (bool) {
        _vm.startPrank(agent);
        if (isLong) {
            try volPool.withdrawLong(shares) returns (uint256) {
                _vm.stopPrank();
                _agentLongVolShares[agentId] = 0;
                _agentLongVolCostBasis[agentId] = 0;
                return true;
            } catch (bytes memory reason) {
                _countFailure(action, reason);
                _vm.stopPrank();
                return false;
            }
        } else {
            try volPool.withdrawShort(shares) returns (uint256) {
                _vm.stopPrank();
                _agentShortVolShares[agentId] = 0;
                _agentShortVolCostBasis[agentId] = 0;
                return true;
            } catch (bytes memory reason) {
                _countFailure(action, reason);
                _vm.stopPrank();
                return false;
            }
        }
    }

    function _execPokeDormant(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.pokeDormant(vaultId) {
            _vm.stopPrank();
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.POKE_DORMANT, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execClaimDormant(address agent, uint256 vaultId, uint256 amount) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.claimDormantCollateral(vaultId, amount) returns (uint256) {
            _vm.stopPrank();
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.CLAIM_DORMANT, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execAddLiquidity(address agent, uint256 vbtcAmount) internal returns (bool) {
        uint256 wbtcBalance = protocol.wbtc.balanceOf(agent);
        if (wbtcBalance == 0 || vbtcAmount == 0) return false;

        uint256 wbtcAmount;
        if (curvePool.initialized()) {
            // Match current pool ratio so liquidity is balanced
            uint256 spot = curvePool.spotPrice(); // WBTC per vBTC (18 dec)
            wbtcAmount = (vbtcAmount * spot) / 1e18;
        } else {
            // First seed: use INITIAL_VBTC_RATIO as bootstrap price
            wbtcAmount = (vbtcAmount * INITIAL_VBTC_RATIO) / 1e18;
        }
        // Scale vbtcAmount proportionally if wbtcAmount exceeds balance
        if (wbtcAmount > wbtcBalance) {
            uint256 originalWbtc = wbtcAmount;
            wbtcAmount = wbtcBalance;
            vbtcAmount = (vbtcAmount * wbtcBalance) / originalWbtc;
        }
        if (wbtcAmount == 0 || vbtcAmount == 0) return false;

        _vm.startPrank(agent);
        uint256[2] memory amounts = [wbtcAmount, vbtcAmount];
        try curvePool.add_liquidity(amounts, 0) {
            _vm.stopPrank();
            return true;
        } catch (bytes memory reason) {
            _countFailure(AgentLib.Action.ADD_LIQUIDITY, reason);
            _vm.stopPrank();
            return false;
        }
    }

    function _execSwap(address agent, int128 i, int128 j, uint256 amount, AgentLib.Action action) internal returns (bool) {
        // Pre-flight: check if swap would succeed without breaching ratio bounds
        uint256 dy = curvePool.get_dy(i, j, amount);
        if (dy == 0) return false;

        _vm.startPrank(agent);
        try curvePool.exchange(i, j, amount, 0) returns (uint256) {
            _vm.stopPrank();
            ghost_totalSwaps++;
            return true;
        } catch (bytes memory reason) {
            _countFailure(action, reason);
            _vm.stopPrank();
            return false;
        }
    }

    // ==================== Portfolio & Signal Computation ====================

    function _buildPortfolio(uint256 agentId, AgentLib.AgentState memory state)
        internal
        view
        returns (AgentLib.Portfolio memory p)
    {
        address agent = agents[agentId];
        p.wbtcBalance = protocol.wbtc.balanceOf(agent);
        p.vbtcBalance = protocol.btcToken.balanceOf(agent);
        p.perpPositionCount = state.perpPositionIds.length;
        p.hasVolPosition = state.longVolShares > 0 || state.shortVolShares > 0;
        p.hasTreasureNft = issuers[0].treasureNFT.balanceOf(agent) > 0;

        // AMM pool state
        p.poolInitialized = curvePool.initialized();
        if (p.poolInitialized) {
            p.poolWbtcReserve = curvePool.balances(0);
            p.poolVbtcReserve = curvePool.balances(1);
        }

        // Eligibility: can mint vault if has treasure + WBTC
        p.eligibleMintVault = p.hasTreasureNft && p.wbtcBalance > 0;
        p.eligibleOpenPerp = p.vbtcBalance >= 1e6; // MIN_COLLATERAL_PERP

        uint256 matchPool = protocol.vault.matchPool();
        p.walletTotalDelegatedBps = protocol.vault.walletTotalDelegatedBPS(agent);
        p.eligibleGrantWalletDelegate = p.walletTotalDelegatedBps < 10000;

        uint256 vaultCount = state.vaultIds.length;
        p.vaultCollaterals = new uint256[](vaultCount);
        p.vaultVested = new bool[](vaultCount);
        p.matchClaimed = new bool[](vaultCount);
        p.nextWithdrawableTick = new uint256[](vaultCount);

        for (uint256 i = 0; i < vaultCount; i++) {
            uint256 vid = state.vaultIds[i];
            (,,, uint256 collateral, uint256 reserve,,,) = protocol.vault.getVaultInfo(vid);
            p.vaultCollaterals[i] = collateral;
            p.totalVaultCollateral += collateral;

            bool vested = protocol.vault.isVested(vid);
            p.vaultVested[i] = vested;

            // Check pending match pool share instead of matchClaimed flag
            uint256 pendingMatch = 0;
            try protocol.vault.pendingMatch(vid) returns (uint256 pm) {
                pendingMatch = pm;
            } catch {}
            p.matchClaimed[i] = pendingMatch == 0; // ponytail: reuse bool array name; true means "no pending", false means "has pending"

            if (vested) {
                p.hasVestedVault = true;

                // First vested vault is eligible for strip (changed from mintBtcToken)
                if (p.mintBtcTokenVaultId == 0) {
                    p.mintBtcTokenVaultId = vid;
                }

                // Match claim eligibility: vested + has pending match + match pool available
                if (pendingMatch > 0 && matchPool > 0) {
                    p.eligibleClaimMatch = true;
                    if (p.matchClaimVaultId == 0) {
                        p.matchClaimVaultId = vid;
                    }
                }

                // Compute cooldown using vault's withdrawalCooldown()
                uint256 nextWithdrawTick = 0;
                uint256 cooldownExpires = protocol.vault.withdrawalCooldown(vid);
                if (cooldownExpires > block.timestamp) {
                    uint256 remaining = cooldownExpires - block.timestamp;
                    nextWithdrawTick = currentTick + (remaining + 7 days - 1) / (7 days);
                }
                p.nextWithdrawableTick[i] = nextWithdrawTick;

                // Only consider this vault withdrawable if cooldown has passed
                if (nextWithdrawTick == 0 || nextWithdrawTick <= currentTick) {
                    try protocol.vault.getWithdrawableAmount(vid) returns (uint256 amt) {
                        if (amt > 0) {
                            p.canWithdraw = true;
                            if (p.withdrawableVaultId == 0) {
                                p.withdrawableVaultId = vid;
                            }
                        }
                    } catch {}
                }
            } else {
                p.hasUnvestedVault = true;

                // Early redeem eligibility: no outstanding reserve, or agent has enough vBTC to recombine
                if (reserve == 0 || p.vbtcBalance >= reserve) {
                    p.eligibleEarlyRedeem = true;
                    if (p.earlyRedeemVaultId == 0) {
                        p.earlyRedeemVaultId = vid;
                    }
                }
            }
        }

        // Match pool share estimate (for dust-threshold filtering in decision logic)
        uint256 totalActive = protocol.vault.totalActiveCollateral();
        if (totalActive > 0 && matchPool > 0 && p.totalVaultCollateral > 0) {
            p.matchPoolShareEstimate = (matchPool * p.totalVaultCollateral) / totalActive;
        }
        // Apply dust threshold retroactively
        if (p.matchPoolShareEstimate <= 1e4) {
            p.eligibleClaimMatch = false;
        }

        // Dormancy scanning (for agents with STRAT_DORMANCY)
        // Skip entirely before MIN_DORMANCY_TICKS — no vault can be dormant yet
        if (currentTick >= MIN_DORMANCY_TICKS && (configs[agentId].psychology.strategyMask & AgentLib.STRAT_DORMANCY) != 0) {
            p.dormantTargetId = _cachedDormantTarget;
            // Check if a previously poked vault is now claimable or pokable
            if (p.dormantTargetId > 0) {
                try protocol.vault.isDormantEligible(p.dormantTargetId) returns (bool eligible, IVaultNFT.DormancyState dState) {
                    if (dState == IVaultNFT.DormancyState.CLAIMABLE) {
                        p.dormantClaimable = true;
                    } else if (eligible && dState == IVaultNFT.DormancyState.ACTIVE) {
                        p.eligiblePokeDormant = true;
                    }
                } catch {}
            }
        }
    }

    function _computeMarketSignals() internal view returns (AgentLib.MarketSignals memory signals) {
        signals.currentPrice = priceState.price;
        signals.ammInitialized = curvePool.initialized();
        signals.vbtcRatio = signals.ammInitialized ? curvePool.spotPrice() : 0;
        signals.currentTick = currentTick;
        signals.matchPoolSize = protocol.vault.matchPool();
        signals.totalActiveCollateral = protocol.vault.totalActiveCollateral();

        // Funding rate
        try perpVault.getCurrentFundingRate() returns (int256 rate) {
            signals.fundingRate = rate;
        } catch {}

        // Price returns and vol (need at least some history)
        if (priceHistoryIndex >= 7) {
            signals.priceReturn7d = _computeReturn(7);
            signals.realizedVol7d = _computeVol(7);
        }
        if (priceHistoryIndex >= 30) {
            signals.priceReturn30d = _computeReturn(30);
        }
    }

    function _computeNetWorth(uint256 agentId, AgentLib.AgentState memory state, AgentLib.Portfolio memory portfolio)
        internal
        view
        returns (uint256)
    {
        NetWorthLib.Contracts memory contracts = NetWorthLib.Contracts({
            vault: protocol.vault,
            wbtc: IERC20(address(protocol.wbtc)),
            btcToken: IERC20(address(protocol.btcToken)),
            perpVault: IPerpetualVault(address(perpVault)),
            volPool: IVolatilityPool(address(volPool))
        });

        return NetWorthLib.calculateNetWorth(
            agents[agentId],
            state.vaultIds,
            state.perpPositionIds,
            state.longVolShares,
            state.shortVolShares,
            contracts,
            curvePool.initialized() ? curvePool.spotPrice() : 0,
            portfolio.vaultCollaterals,
            portfolio.vaultVested
        );
    }

    // ==================== Helpers ====================

    function _computeReturn(uint256 lookback) internal view returns (int256) {
        uint256 currentIdx = (priceHistoryIndex - 1) % 30;
        uint256 pastIdx = (priceHistoryIndex - lookback) % 30;
        uint256 current = priceHistory[currentIdx];
        uint256 past = priceHistory[pastIdx];
        if (past == 0) return 0;

        // Return as fraction of 1e18: (current - past) / past
        if (current >= past) {
            return int256(((current - past) * 1e18) / past);
        } else {
            return -int256(((past - current) * 1e18) / past);
        }
    }

    function _computeVol(uint256 lookback) internal view returns (uint256) {
        // Simplified: sum of absolute daily returns / lookback
        uint256 sumAbsReturns = 0;
        for (uint256 d = 1; d < lookback && d < priceHistoryIndex; d++) {
            uint256 idx = (priceHistoryIndex - d) % 30;
            uint256 prevIdx = (priceHistoryIndex - d - 1) % 30;
            uint256 p1 = priceHistory[idx];
            uint256 p0 = priceHistory[prevIdx];
            if (p0 > 0) {
                uint256 absReturn = p1 > p0
                    ? ((p1 - p0) * 1e18) / p0
                    : ((p0 - p1) * 1e18) / p0;
                sumAbsReturns += absReturn;
            }
        }
        // Annualize: daily vol * sqrt(365) ≈ daily vol * 19.1
        uint256 dailyVol = lookback > 1 ? sumAbsReturns / (lookback - 1) : 0;
        return dailyVol * 19; // Approximate annualization
    }

    function _findDormantTarget(uint256 excludeAgent) internal view returns (uint256) {
        // Scan other agents' vaults for dormancy eligibility
        for (uint256 i = 0; i < AGENT_COUNT; i++) {
            if (i == excludeAgent) continue;
            uint256[] storage vaults = _agentVaultIds[i];
            for (uint256 j = 0; j < vaults.length; j++) {
                try protocol.vault.isDormantEligible(vaults[j]) returns (bool eligible, IVaultNFT.DormancyState) {
                    if (eligible) return vaults[j];
                } catch {}
            }
        }
        return 0;
    }

    function _findOwnedToken(TreasureNFT treasure, address owner) internal view returns (uint256) {
        // Simple linear scan up to a reasonable max
        uint256 maxId = 100 * TREASURES_PER_AGENT; // upper bound
        for (uint256 i = 0; i < maxId; i++) {
            try treasure.ownerOf(i) returns (address tokenOwner) {
                if (tokenOwner == owner) return i;
            } catch {}
        }
        return type(uint256).max;
    }

    function _removeVaultId(uint256 agentId, uint256 vaultId) internal {
        uint256[] storage vaults = _agentVaultIds[agentId];
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == vaultId) {
                vaults[i] = vaults[vaults.length - 1];
                vaults.pop();
                return;
            }
        }
    }

    function _removePerpId(uint256 agentId, uint256 positionId) internal {
        uint256[] storage perps = _agentPerpIds[agentId];
        for (uint256 i = 0; i < perps.length; i++) {
            if (perps[i] == positionId) {
                perps[i] = perps[perps.length - 1];
                perps.pop();
                return;
            }
        }
    }

    // ==================== View Functions ====================

    /// @notice Get agent's vault IDs
    function getAgentVaultIds(uint256 agentId) external view returns (uint256[] memory) {
        return _agentVaultIds[agentId];
    }

    /// @notice Get agent's perp position IDs
    function getAgentPerpIds(uint256 agentId) external view returns (uint256[] memory) {
        return _agentPerpIds[agentId];
    }

    /// @notice Get agent's long vol pool shares
    function getAgentLongVolShares(uint256 agentId) external view returns (uint256) {
        return _agentLongVolShares[agentId];
    }

    /// @notice Get agent's short vol pool shares
    function getAgentShortVolShares(uint256 agentId) external view returns (uint256) {
        return _agentShortVolShares[agentId];
    }

    /// @notice Get agent's long vol cost basis (vBTC deposited)
    function getAgentLongVolCostBasis(uint256 agentId) external view returns (uint256) {
        return _agentLongVolCostBasis[agentId];
    }

    /// @notice Get agent's short vol cost basis (vBTC deposited)
    function getAgentShortVolCostBasis(uint256 agentId) external view returns (uint256) {
        return _agentShortVolCostBasis[agentId];
    }

    /// @notice Get agent's net worth at a specific tick
    function getNetWorthAt(uint256 tick, uint256 agentId) external view returns (uint256) {
        return netWorthAt[tick][agentId];
    }

    /// @notice Get all active perp position IDs
    function getAllPerpPositionIds() external view returns (uint256[] memory) {
        return allPerpPositionIds;
    }

    /// @notice Get protocol deployment (returns struct for external callers)
    function getProtocol() external view returns (VaultNFT vault, BtcToken btcToken, MockWBTC wbtc) {
        return (protocol.vault, protocol.btcToken, protocol.wbtc);
    }

    /// @notice Get agent action count for a specific action type
    function getAgentActionCount(uint256 agentId, uint8 action) external view returns (uint256) {
        return agentActionCounts[agentId][action];
    }

    /// @notice Get completed tick count
    function getTickCount() external view returns (uint256) {
        return currentTick;
    }

    /// @notice Get snapshot array lengths
    function getSnapshotCount() external view returns (uint256) {
        return priceSnapshots.length;
    }

    /// @notice Get action log length
    function getActionLogLength() external view returns (uint256) {
        return _actionLog.length;
    }

    /// @notice Get action record at index
    function getActionRecord(uint256 index) external view returns (ActionRecord memory) {
        return _actionLog[index];
    }

    /// @notice Load a pre-generated price series to use instead of live GBM
    function loadPriceSeries(uint256[] calldata prices, uint8[] calldata regimes) external {
        require(prices.length == regimes.length, "Length mismatch");
        _priceOverrides = prices;
        _regimeOverrides = regimes;
    }

    /// @notice Check if price overrides are loaded
    function hasPriceOverrides() external view returns (bool) {
        return _priceOverrides.length > 0;
    }
}
