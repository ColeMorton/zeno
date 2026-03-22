// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {SimulationOrchestrator, ProtocolDeployment, IssuerDeployment, MockWBTC} from "./SimulationOrchestrator.sol";
import {PriceSimulator} from "./libraries/PriceSimulator.sol";
import {ProtocolAgentLib} from "./agents/ProtocolAgentLib.sol";

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";
import {IVaultNFTDormancy} from "@protocol/interfaces/IVaultNFTDormancy.sol";
import {IVaultNFTDelegation} from "@protocol/interfaces/IVaultNFTDelegation.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ProtocolSwarmOrchestrator - Protocol-only 100-agent simulation orchestrator
/// @notice Tests VaultNFT protocol actions in isolation: vault lifecycle, delegation, dormancy, vBTC lifecycle
/// @dev No issuer DeFi contracts (PerpetualVault, VolatilityPool, CurvePool)
contract ProtocolSwarmOrchestrator is SimulationOrchestrator {
    using ProtocolAgentLib for ProtocolAgentLib.AgentConfig;

    // ==================== Constants ====================

    uint256 public constant AGENT_COUNT = 100;
    uint256 public constant INITIAL_PRICE = 60000e18;
    uint256 public constant TREASURES_PER_AGENT = 10;

    // ==================== Simulation State ====================

    PriceSimulator.PriceState public priceState;
    uint256 public currentTick;

    uint256[30] public priceHistory;
    uint256 public priceHistoryIndex;

    // Agent state
    address[100] public agents;
    ProtocolAgentLib.AgentConfig[100] public configs;

    // Agent mutable state
    mapping(uint256 => uint256[]) internal _agentVaultIds;
    mapping(uint256 => bool) internal _agentHasSeparatedVbtc;
    mapping(uint256 => uint256) internal _agentLastActionTick;
    mapping(uint256 => uint256) internal _agentLastMintTick;
    mapping(uint256 => uint256) internal _agentLastSeparateTick;
    mapping(uint256 => bool) internal _agentVbtcRecombined;
    mapping(uint256 => bool) internal _vaultMatchClaimed; // vaultId => already claimed match

    // Delegation tracking
    mapping(uint256 => uint256) internal _agentDelegationGrantCount; // agentId => count of delegates granted
    mapping(uint256 => uint256[]) internal _delegatedToAgents; // grantor agentId => delegate agent indices
    mapping(uint256 => uint256[]) internal _delegatedFromAgents; // delegate agentId => grantor agent indices

    // Ghost variables
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalForfeited;
    uint256 public ghost_totalReturned;
    uint256 public ghost_totalMatchClaimed;
    uint256 public ghost_totalActions;
    uint256 public ghost_totalFailedActions;
    uint256 public ghost_totalDelegatedWithdrawals;
    uint256 public ghost_totalDelegationGrants;
    uint256 public ghost_totalDelegationRevokes;
    uint256 public ghost_totalSeparations;
    uint256 public ghost_totalRecombinations;

    // Net worth snapshots
    mapping(uint256 => mapping(uint256 => uint256)) public netWorthAt;

    // Tick snapshots
    uint256[] public priceSnapshots;
    uint256[] public tvlSnapshots;
    uint256[] public matchPoolSnapshots;
    uint8[] public regimeSnapshots;

    // Per-agent action counts
    mapping(uint256 => mapping(uint8 => uint256)) public agentActionCounts;

    // Action log
    struct ActionRecord {
        uint256 tick;
        uint256 agentId;
        uint8 action;
        uint256 amount;
        bool success;
    }

    ActionRecord[] internal _actionLog;

    // Pre-loaded price series
    uint256[] internal _priceOverrides;
    uint8[] internal _regimeOverrides;

    // ==================== Events ====================

    event TickComplete(uint256 indexed tick, uint256 price, uint256 tvl, uint256 matchPool);
    event AgentAction(uint256 indexed tick, uint256 indexed agentId, ProtocolAgentLib.Action action, uint256 amount, bool success);
    event AgentNetWorth(uint256 indexed tick, uint256 indexed agentId, uint256 netWorth);
    event SimulationComplete(uint256 totalTicks, uint256 totalActions, uint256 totalFailedActions);

    // ==================== Vm Interface ====================

    Vm internal _vm;

    function setVm(Vm vm_) external {
        _vm = vm_;
    }

    // ==================== Initialization ====================

    function initializeAgents(uint256 seed) external {
        require(address(protocol.vault) != address(0), "Deploy protocol first");
        require(issuers.length > 0, "Deploy issuer first");

        // Price state is populated from CSV via loadPriceSeries() before first executeTick()

        for (uint256 i = 0; i < AGENT_COUNT; i++) {
            agents[i] = _vm.addr(seed + i + 1);
            configs[i] = ProtocolAgentLib.generateConfig(seed, i);

            protocol.wbtc.mint(agents[i], configs[i].initialCapitalWbtc);

            IssuerDeployment storage issuer = issuers[0];
            for (uint256 j = 0; j < TREASURES_PER_AGENT; j++) {
                issuer.treasureNFT.mint(agents[i]);
            }

            _vm.startPrank(agents[i]);
            protocol.wbtc.approve(address(protocol.vault), type(uint256).max);
            protocol.btcToken.approve(address(protocol.vault), type(uint256).max);
            _vm.stopPrank();
        }
    }

    // ==================== Tick Execution ====================

    function executeTick() external {
        _vm.warp(block.timestamp + 7 days);

        require(_priceOverrides.length > 0, "Price series not loaded");
        require(currentTick < _priceOverrides.length, "Price series exhausted");
        priceState.price = _priceOverrides[currentTick];
        priceState.regime = _regimeOverrides[currentTick];

        priceHistory[priceHistoryIndex % 30] = priceState.price;
        priceHistoryIndex++;

        ProtocolAgentLib.MarketSignals memory signals = _computeMarketSignals();

        for (uint256 i = 0; i < AGENT_COUNT; i++) {
            _executeAgent(i, signals);
        }

        uint256 tvl = IERC20(address(protocol.wbtc)).balanceOf(address(protocol.vault));
        uint256 mp = protocol.vault.matchPool();

        priceSnapshots.push(priceState.price);
        tvlSnapshots.push(tvl);
        matchPoolSnapshots.push(mp);
        regimeSnapshots.push(priceState.regime);

        emit TickComplete(currentTick, priceState.price, tvl, mp);
        currentTick++;
    }

    // ==================== Agent Execution ====================

    function _executeAgent(uint256 agentId, ProtocolAgentLib.MarketSignals memory signals) internal {
        ProtocolAgentLib.AgentState memory state = ProtocolAgentLib.AgentState({
            vaultIds: _agentVaultIds[agentId],
            hasSeparatedVbtc: _agentHasSeparatedVbtc[agentId],
            lastActionTick: _agentLastActionTick[agentId],
            lastMintTick: _agentLastMintTick[agentId],
            lastSeparateTick: _agentLastSeparateTick[agentId],
            vbtcRecombined: _agentVbtcRecombined[agentId]
        });

        ProtocolAgentLib.Portfolio memory portfolio = _buildPortfolio(agentId, state);

        ProtocolAgentLib.ActionParams memory action = ProtocolAgentLib.decide(configs[agentId], state, signals, portfolio);

        uint256 nw = _computeNetWorth(agentId);
        netWorthAt[currentTick][agentId] = nw;
        emit AgentNetWorth(currentTick, agentId, nw);

        if (action.action == ProtocolAgentLib.Action.NONE) return;

        bool success = _executeAction(agentId, action);

        emit AgentAction(currentTick, agentId, action.action, action.amount, success);
        ghost_totalActions++;
        if (!success) ghost_totalFailedActions++;

        _actionLog.push(ActionRecord({
            tick: currentTick,
            agentId: agentId,
            action: uint8(action.action),
            amount: action.amount,
            success: success
        }));

        if (success) {
            if (action.action != ProtocolAgentLib.Action.MINT_VAULT) {
                _agentLastActionTick[agentId] = currentTick;
            }
            agentActionCounts[agentId][uint8(action.action)]++;
        }
    }

    function _executeAction(uint256 agentId, ProtocolAgentLib.ActionParams memory action) internal returns (bool) {
        address agent = agents[agentId];

        if (action.action == ProtocolAgentLib.Action.MINT_VAULT) {
            return _execMintVault(agentId, agent, action.amount);
        } else if (action.action == ProtocolAgentLib.Action.WITHDRAW) {
            return _execWithdraw(agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.EARLY_REDEEM) {
            return _execEarlyRedeem(agentId, agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.MINT_BTC_TOKEN) {
            return _execMintBtcToken(agentId, agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.RETURN_BTC_TOKEN) {
            return _execReturnBtcToken(agentId, agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.CLAIM_MATCH) {
            return _execClaimMatch(agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.PROVE_ACTIVITY) {
            return _execProveActivity(agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.POKE_DORMANT) {
            return _execPokeDormant(agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.CLAIM_DORMANT) {
            return _execClaimDormant(agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.GRANT_WALLET_DELEGATE) {
            return _execGrantWalletDelegate(agentId, agent, action.targetId, action.delegationBps);
        } else if (action.action == ProtocolAgentLib.Action.GRANT_VAULT_DELEGATE) {
            return _execGrantVaultDelegate(agentId, agent, action.targetId, action.delegationBps, action.durationSeconds);
        } else if (action.action == ProtocolAgentLib.Action.REVOKE_WALLET_DELEGATE) {
            return _execRevokeWalletDelegate(agent, action.targetId);
        } else if (action.action == ProtocolAgentLib.Action.WITHDRAW_AS_DELEGATE) {
            return _execWithdrawAsDelegate(agent, action.targetId);
        }

        return false;
    }

    // ==================== Action Executors ====================

    function _execMintVault(uint256 agentId, address agent, uint256 amount) internal returns (bool) {
        TreasureNFT treasure = issuers[0].treasureNFT;
        uint256 treasureBalance = treasure.balanceOf(agent);
        if (treasureBalance == 0 || amount == 0) return false;

        uint256 treasureId = _findOwnedToken(treasure, agent);
        if (treasureId == type(uint256).max) return false;

        _vm.startPrank(agent);
        try treasure.approve(address(protocol.vault), treasureId) {} catch { _vm.stopPrank(); return false; }

        try protocol.vault.mint(
            address(treasure),
            treasureId,
            address(protocol.wbtc),
            amount
        ) returns (uint256 vaultId) {
            _vm.stopPrank();
            _agentVaultIds[agentId].push(vaultId);
            _agentLastMintTick[agentId] = currentTick;
            ghost_totalDeposited += amount;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execWithdraw(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.withdraw(vaultId) returns (uint256 amount) {
            _vm.stopPrank();
            ghost_totalWithdrawn += amount;
            return true;
        } catch {
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
            _removeVaultId(agentId, vaultId);
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execMintBtcToken(uint256 agentId, address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.mintBtcToken(vaultId) returns (uint256) {
            _vm.stopPrank();
            _agentHasSeparatedVbtc[agentId] = true;
            _agentLastSeparateTick[agentId] = currentTick;
            _agentVbtcRecombined[agentId] = false;
            ghost_totalSeparations++;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execReturnBtcToken(uint256 agentId, address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.returnBtcToken(vaultId) {
            _vm.stopPrank();
            _agentHasSeparatedVbtc[agentId] = false;
            _agentVbtcRecombined[agentId] = true;
            _agentLastSeparateTick[agentId] = currentTick;
            ghost_totalRecombinations++;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execClaimMatch(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.claimMatch(vaultId) returns (uint256 amount) {
            _vm.stopPrank();
            ghost_totalMatchClaimed += amount;
            _vaultMatchClaimed[vaultId] = true;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execProveActivity(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.proveActivity(vaultId) {
            _vm.stopPrank();
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execPokeDormant(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.pokeDormant(vaultId) {
            _vm.stopPrank();
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execClaimDormant(address agent, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(agent);
        try protocol.vault.claimDormantCollateral(vaultId) returns (uint256) {
            _vm.stopPrank();
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execGrantWalletDelegate(
        uint256 agentId,
        address agent,
        uint256 delegateAgentIdx,
        uint16 bps
    ) internal returns (bool) {
        if (delegateAgentIdx >= AGENT_COUNT) return false;
        address delegate = agents[delegateAgentIdx];
        if (delegate == agent) return false;

        _vm.startPrank(agent);
        try IVaultNFTDelegation(address(protocol.vault)).grantWithdrawalDelegate(delegate, uint256(bps)) {
            _vm.stopPrank();
            _agentDelegationGrantCount[agentId]++;
            _delegatedToAgents[agentId].push(delegateAgentIdx);
            _delegatedFromAgents[delegateAgentIdx].push(agentId);
            ghost_totalDelegationGrants++;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execGrantVaultDelegate(
        uint256 agentId,
        address agent,
        uint256 packed,
        uint16 bps,
        uint256 durationSeconds
    ) internal returns (bool) {
        uint256 delegateAgentIdx = packed & ((1 << 128) - 1);
        uint256 vaultId = packed >> 128;
        if (delegateAgentIdx >= AGENT_COUNT) return false;
        address delegate = agents[delegateAgentIdx];
        if (delegate == agent) return false;

        _vm.startPrank(agent);
        try IVaultNFTDelegation(address(protocol.vault)).grantVaultDelegate(
            vaultId, delegate, uint256(bps), durationSeconds
        ) {
            _vm.stopPrank();
            ghost_totalDelegationGrants++;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execRevokeWalletDelegate(address agent, uint256 delegateAgentIdx) internal returns (bool) {
        if (delegateAgentIdx >= AGENT_COUNT) return false;
        address delegate = agents[delegateAgentIdx];

        _vm.startPrank(agent);
        try IVaultNFTDelegation(address(protocol.vault)).revokeWithdrawalDelegate(delegate) {
            _vm.stopPrank();
            ghost_totalDelegationRevokes++;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    function _execWithdrawAsDelegate(address delegate, uint256 vaultId) internal returns (bool) {
        _vm.startPrank(delegate);
        try IVaultNFTDelegation(address(protocol.vault)).withdrawAsDelegate(vaultId) returns (uint256 amount) {
            _vm.stopPrank();
            ghost_totalDelegatedWithdrawals += amount;
            ghost_totalWithdrawn += amount;
            return true;
        } catch {
            _vm.stopPrank();
            return false;
        }
    }

    // ==================== Portfolio & Signal Computation ====================

    function _buildPortfolio(uint256 agentId, ProtocolAgentLib.AgentState memory state)
        internal
        view
        returns (ProtocolAgentLib.Portfolio memory p)
    {
        address agent = agents[agentId];
        p.wbtcBalance = protocol.wbtc.balanceOf(agent);
        p.vbtcBalance = protocol.btcToken.balanceOf(agent);

        // Vault-specific eligibility scan
        for (uint256 i = 0; i < state.vaultIds.length; i++) {
            uint256 vid = state.vaultIds[i];

            // Verify vault still exists (ownership check)
            try protocol.vault.ownerOf(vid) returns (address owner) {
                if (owner != agent) continue; // stale vault ID
            } catch {
                continue; // vault burned/nonexistent
            }

            p.anyValidVaultId = vid; // at least one valid vault

            (,,, uint256 collateral,,,,,) = protocol.vault.getVaultInfo(vid);
            p.totalVaultCollateral += collateral;

            if (protocol.vault.isVested(vid)) {
                p.hasVestedVault = true;
                if (p.vestedVaultId == 0) p.vestedVaultId = vid;

                // Check withdrawable (specific vault with cooldown passed)
                try protocol.vault.getWithdrawableAmount(vid) returns (uint256 amt) {
                    if (amt > 0 && p.withdrawableVaultId == 0) {
                        p.withdrawableVaultId = vid;
                    }
                } catch {}

                // Check match claimable (specific vault, not yet claimed)
                if (!_vaultMatchClaimed[vid] && p.matchClaimableVaultId == 0) {
                    p.matchClaimableVaultId = vid;
                }
            } else {
                p.hasUnvestedVault = true;
                if (p.unvestedVaultId == 0) p.unvestedVaultId = vid;
            }
        }

        // Dormancy scanning (for agents with STRAT_DORMANCY)
        if ((configs[agentId].psychology.strategyMask & ProtocolAgentLib.STRAT_DORMANCY) != 0) {
            p.dormantTargetId = _findDormantTarget(agentId);
            if (p.dormantTargetId > 0) {
                try protocol.vault.isDormantEligible(p.dormantTargetId) returns (bool, IVaultNFTDormancy.DormancyState dState) {
                    if (dState == IVaultNFTDormancy.DormancyState.CLAIMABLE) {
                        p.dormantClaimable = true;
                    }
                } catch {}
            }
        }

        // Delegation scanning (for Delegate Withdrawers)
        if (configs[agentId].archetype == ProtocolAgentLib.Archetype.DELEGATE_WITHDRAWER) {
            uint256[] storage grantors = _delegatedFromAgents[agentId];
            for (uint256 i = 0; i < grantors.length; i++) {
                uint256 grantorId = grantors[i];
                uint256[] storage grantorVaults = _agentVaultIds[grantorId];
                for (uint256 j = 0; j < grantorVaults.length; j++) {
                    try IVaultNFTDelegation(address(protocol.vault)).canDelegateWithdraw(
                        grantorVaults[j], agent
                    ) returns (bool canW, uint256, IVaultNFTDelegation.DelegationType) {
                        if (canW) {
                            p.delegateTargetVaultId = grantorVaults[j];
                            p.canDelegateWithdraw = true;
                            return p;
                        }
                    } catch {}
                }
            }
        }

        // Delegation grant count + current BPS (for Delegation Grantors)
        if (configs[agentId].archetype == ProtocolAgentLib.Archetype.DELEGATION_GRANTOR) {
            p.delegationGrantCount = _agentDelegationGrantCount[agentId];
            try IVaultNFTDelegation(address(protocol.vault)).walletTotalDelegatedBPS(agent) returns (uint256 bps) {
                p.currentWalletDelegatedBps = bps;
            } catch {}
        }
    }

    function _computeMarketSignals() internal view returns (ProtocolAgentLib.MarketSignals memory signals) {
        signals.currentPrice = priceState.price;
        signals.currentTick = currentTick;
        signals.matchPoolSize = protocol.vault.matchPool();
        signals.totalActiveCollateral = protocol.vault.totalActiveCollateral();

        if (priceHistoryIndex >= 7) {
            signals.priceReturn7d = _computeReturn(7);
        }
        if (priceHistoryIndex >= 30) {
            signals.priceReturn30d = _computeReturn(30);
        }
    }

    function _computeNetWorth(uint256 agentId) internal view returns (uint256) {
        address agent = agents[agentId];
        uint256 nw = protocol.wbtc.balanceOf(agent);

        // Add vault collateral
        uint256[] storage vaults = _agentVaultIds[agentId];
        for (uint256 i = 0; i < vaults.length; i++) {
            (,,, uint256 collateral,,,,,) = protocol.vault.getVaultInfo(vaults[i]);
            nw += collateral;
        }

        // Add vBTC (1:1 with collateral for protocol-only sim)
        nw += protocol.btcToken.balanceOf(agent);

        return nw;
    }

    // ==================== Helpers ====================

    function _computeReturn(uint256 lookback) internal view returns (int256) {
        uint256 currentIdx = (priceHistoryIndex - 1) % 30;
        uint256 pastIdx = (priceHistoryIndex - lookback) % 30;
        uint256 current = priceHistory[currentIdx];
        uint256 past = priceHistory[pastIdx];
        if (past == 0) return 0;

        if (current >= past) {
            return int256(((current - past) * 1e18) / past);
        } else {
            return -int256(((past - current) * 1e18) / past);
        }
    }

    function _findDormantTarget(uint256 excludeAgent) internal view returns (uint256) {
        for (uint256 i = 0; i < AGENT_COUNT; i++) {
            if (i == excludeAgent) continue;
            uint256[] storage vaults = _agentVaultIds[i];
            for (uint256 j = 0; j < vaults.length; j++) {
                try protocol.vault.isDormantEligible(vaults[j]) returns (bool eligible, IVaultNFTDormancy.DormancyState) {
                    if (eligible) return vaults[j];
                } catch {}
            }
        }
        return 0;
    }

    function _findOwnedToken(TreasureNFT treasure, address owner) internal view returns (uint256) {
        uint256 maxId = 100 * TREASURES_PER_AGENT;
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

    // ==================== View Functions ====================

    function getAgentVaultIds(uint256 agentId) external view returns (uint256[] memory) {
        return _agentVaultIds[agentId];
    }

    function getNetWorthAt(uint256 tick, uint256 agentId) external view returns (uint256) {
        return netWorthAt[tick][agentId];
    }

    function getProtocol() external view returns (VaultNFT vault, BtcToken btcToken, MockWBTC wbtc) {
        return (protocol.vault, protocol.btcToken, protocol.wbtc);
    }

    function getAgentActionCount(uint256 agentId, uint8 action) external view returns (uint256) {
        return agentActionCounts[agentId][action];
    }

    function getTickCount() external view returns (uint256) {
        return currentTick;
    }

    function getSnapshotCount() external view returns (uint256) {
        return priceSnapshots.length;
    }

    function getActionLogLength() external view returns (uint256) {
        return _actionLog.length;
    }

    function getActionRecord(uint256 index) external view returns (ActionRecord memory) {
        return _actionLog[index];
    }

    function getDelegatedFromAgents(uint256 agentId) external view returns (uint256[] memory) {
        return _delegatedFromAgents[agentId];
    }

    function getDelegatedToAgents(uint256 agentId) external view returns (uint256[] memory) {
        return _delegatedToAgents[agentId];
    }

    function loadPriceSeries(uint256[] calldata prices, uint8[] calldata regimes) external {
        require(prices.length == regimes.length, "Length mismatch");
        _priceOverrides = prices;
        _regimeOverrides = regimes;
    }
}
