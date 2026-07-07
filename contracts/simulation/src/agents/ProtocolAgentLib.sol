// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ProtocolAgentLib - Protocol-only agent decision logic for swarm simulation
/// @dev Pure library. 10 archetypes exercising only VaultNFT protocol actions (no issuer DeFi).
///      Decision logic uses vault-specific eligibility to minimize failed action attempts.
library ProtocolAgentLib {
    // ==================== Enums ====================

    enum Archetype {
        DIAMOND_HANDS,          // 25 agents: hold to vesting, withdraw, match hunt
        MULTI_VAULT_ACCUMULATOR,// 10 agents: mint multiple vaults, diversified holdings
        DELEGATION_GRANTOR,     // 10 agents: grant delegation to other agents
        DELEGATE_WITHDRAWER,    // 10 agents: withdraw as delegate from grantor vaults
        STRATEGIC_REDEEMER,     // 10 agents: calculated early redemption based on match pool state
        PANIC_SELLER,           // 10 agents: early redeem on drawdowns (fear-driven)
        VBTC_SEPARATOR,         // 10 agents: separate/recombine vBTC lifecycle
        PREDATOR,               // 5 agents: poke dormant vaults, claim collateral
        ARBITRAGEUR,            // 5 agents: dormancy + match pool exploitation
        PASSIVE_HOLDER          // 5 agents: mint and disappear (guaranteed dormancy targets)
    }

    enum Action {
        NONE,
        MINT_VAULT,
        WITHDRAW,
        EARLY_REDEEM,
        STRIP,
        RECOMBINE,
        CLAIM_MATCH,
        PROVE_ACTIVITY,
        POKE_DORMANT,
        CLAIM_DORMANT,
        GRANT_WALLET_DELEGATE,
        REVOKE_WALLET_DELEGATE,
        GRANT_VAULT_DELEGATE,
        REVOKE_VAULT_DELEGATE,
        WITHDRAW_AS_DELEGATE
    }

    // ==================== Strategy Mask Constants ====================

    uint8 constant STRAT_EARLY_REDEEM = 0x01;
    uint8 constant STRAT_DORMANCY = 0x02;
    uint8 constant STRAT_MATCH_HUNT = 0x04;
    uint8 constant STRAT_DELEGATION = 0x08;
    uint8 constant STRAT_MULTI_VAULT = 0x10;
    uint8 constant STRAT_VBTC_LIFECYCLE = 0x20;

    // ==================== Structs ====================

    struct Psychology {
        int256 panicThreshold;      // 7-tick return triggering early redeem (e.g., -1e17 = -10%)
        int256 exitThreshold;       // 7-tick return triggering position exit
        uint8 strategyMask;         // bitmask of enabled strategies
        uint8 activityInterval;     // ticks between prove-activity calls (0 = never prove)
        uint8 vaultAllocationPct;   // % of WBTC to deposit in vault
        uint8 mintInterval;         // ticks between additional vault mints (multi-vault only)
        uint8 delegationBps;        // BPS to delegate (delegation grantor only, /100 for uint8)
        uint8 delegationTargetCount;// number of delegates to grant to
        uint8 separateInterval;     // ticks between separate/recombine cycles
        uint256 redeemMatchThreshold; // match pool size below which strategic redeem is attractive
    }

    struct AgentConfig {
        Archetype archetype;
        uint8 riskTolerance;        // 1-100
        uint8 patience;             // 1-100
        uint8 rebalanceFrequency;   // ticks between rebalance decisions
        uint64 initialCapitalWbtc;  // satoshis
        Psychology psychology;
    }

    struct AgentState {
        uint256[] vaultIds;
        bool hasSeparatedVbtc;
        uint256 lastActionTick;
        uint256 lastMintTick;       // for multi-vault accumulator
        uint256 lastSeparateTick;   // for vBTC lifecycle
        bool vbtcRecombined;        // track separate/recombine cycle
        // Cooldown tracking
        uint256[] lastWithdrawTicks; // parallels vaultIds: tick of last withdrawal (0 = never)
    }

    struct ActionParams {
        Action action;
        uint256 amount;
        uint256 targetId;       // vault ID or agent index depending on action
        uint16 delegationBps;   // BPS for delegation grants
        uint256 durationSeconds;// for vault-level delegation expiry
    }

    struct MarketSignals {
        uint256 currentPrice;           // WBTC/USDC (18 decimals)
        int256 priceReturn7d;           // 7-tick return (18 decimals, signed)
        int256 priceReturn30d;          // 30-tick return (18 decimals, signed)
        uint256 matchPoolSize;          // match pool balance (8 decimals)
        uint256 totalActiveCollateral;  // active collateral (8 decimals)
        uint256 currentTick;            // tick number
    }

    /// @notice Portfolio with vault-specific eligibility (not just aggregates)
    struct Portfolio {
        uint256 wbtcBalance;
        uint256 vbtcBalance;
        uint256 totalVaultCollateral;
        bool hasVestedVault;
        bool hasUnvestedVault;
        // Vault-specific targets (0 = none eligible)
        uint256 withdrawableVaultId;    // specific vault ready for withdrawal (vested + cooldown passed)
        uint256 matchClaimableVaultId;  // specific vault eligible for match claim (vested + unclaimed)
        uint256 unvestedVaultId;        // specific unvested vault for early redeem
        uint256 vestedVaultId;          // specific vested vault for strip/recombine
        uint256 vestedVaultCollateral;  // active collateral in the vested vault
        uint256 anyValidVaultId;        // any existing vault for prove activity
        uint256[] nextWithdrawableTick; // per-vault: tick when withdrawal next allowed (0 = any tick)
        // Dormancy
        uint256 dormantTargetId;
        bool dormantClaimable;
        // Delegation
        uint256 delegateTargetVaultId;
        bool canDelegateWithdraw;
        uint256 delegationGrantCount;
        uint256 currentWalletDelegatedBps; // total BPS already delegated
    }

    uint256 private constant PRECISION = 1e18;

    // ==================== Main Decision Function ====================

    function decide(
        AgentConfig memory config,
        AgentState memory state,
        MarketSignals memory signals,
        Portfolio memory portfolio
    ) internal pure returns (ActionParams memory) {
        Psychology memory psy = config.psychology;

        // 1. Rebalance frequency gate
        if (signals.currentTick > 0 && signals.currentTick - state.lastActionTick < config.rebalanceFrequency) {
            return ActionParams(Action.NONE, 0, 0, 0, 0);
        }

        // 2. Passive Holder: mint vault once, then do nothing (creates dormancy targets)
        if (config.archetype == Archetype.PASSIVE_HOLDER) {
            if (state.vaultIds.length == 0 && portfolio.wbtcBalance > 0) {
                uint256 vaultAmount = portfolio.wbtcBalance * uint256(psy.vaultAllocationPct) / 100;
                if (vaultAmount > 0) {
                    return ActionParams(Action.MINT_VAULT, vaultAmount, 0, 0, 0);
                }
            }
            return ActionParams(Action.NONE, 0, 0, 0, 0);
        }

        // 3. Prerequisite: mint vault if none
        if (state.vaultIds.length == 0 && portfolio.wbtcBalance > 0) {
            uint256 vaultAmount = portfolio.wbtcBalance * uint256(psy.vaultAllocationPct) / 100;
            if (vaultAmount > 0) {
                return ActionParams(Action.MINT_VAULT, vaultAmount, 0, 0, 0);
            }
        }

        // 4. Multi-vault: mint additional vaults periodically
        if ((psy.strategyMask & STRAT_MULTI_VAULT) != 0 && portfolio.wbtcBalance > 0) {
            if (psy.mintInterval > 0 && signals.currentTick > state.lastMintTick + uint256(psy.mintInterval)) {
                uint256 vaultAmount = portfolio.wbtcBalance * uint256(psy.vaultAllocationPct) / 100;
                if (vaultAmount > 0) {
                    return ActionParams(Action.MINT_VAULT, vaultAmount, 0, 0, 0);
                }
            }
        }

        // 5. vBTC lifecycle: recombine BEFORE withdrawal for vBTC Separators
        if (config.archetype == Archetype.VBTC_SEPARATOR) {
            if ((psy.strategyMask & STRAT_VBTC_LIFECYCLE) != 0 && portfolio.vestedVaultId > 0) {
                if (psy.separateInterval > 0 && signals.currentTick > state.lastSeparateTick + uint256(psy.separateInterval)) {
                    if (state.hasSeparatedVbtc && portfolio.vbtcBalance > 0) {
                        // Recombine full vBTC balance to reactivate reserve
                        return ActionParams(Action.RECOMBINE, portfolio.vbtcBalance, portfolio.vestedVaultId, 0, 0);
                    }
                    if (!state.hasSeparatedVbtc && portfolio.vestedVaultCollateral > 0) {
                        // Strip all active collateral from vested vault
                        return ActionParams(Action.STRIP, portfolio.vestedVaultCollateral, portfolio.vestedVaultId, 0, 0);
                    }
                }
            }
        }

        // 6. Prerequisite: separate vBTC if vested and needed for dormancy
        bool needsVbtc = (psy.strategyMask & STRAT_DORMANCY) != 0;
        if (portfolio.vestedVaultId > 0 && !state.hasSeparatedVbtc && needsVbtc && portfolio.vestedVaultCollateral > 0) {
            return ActionParams(Action.STRIP, portfolio.vestedVaultCollateral, portfolio.vestedVaultId, 0, 0);
        }

        // 7. Panic exit (early redeem on severe drawdown) — use specific unvested vault
        if ((psy.strategyMask & STRAT_EARLY_REDEEM) != 0) {
            if (signals.priceReturn7d < psy.panicThreshold && portfolio.unvestedVaultId > 0) {
                return ActionParams(Action.EARLY_REDEEM, 0, portfolio.unvestedVaultId, 0, 0);
            }
        }

        // 8. Strategic early redeem — use specific unvested vault, check match pool
        if (config.archetype == Archetype.STRATEGIC_REDEEMER) {
            if (portfolio.unvestedVaultId > 0 && signals.matchPoolSize < psy.redeemMatchThreshold) {
                return ActionParams(Action.EARLY_REDEEM, 0, portfolio.unvestedVaultId, 0, 0);
            }
        }

        // 9. Dormancy actions
        if ((psy.strategyMask & STRAT_DORMANCY) != 0) {
            if (portfolio.dormantClaimable && portfolio.dormantTargetId > 0 && portfolio.vbtcBalance > 0) {
                return ActionParams(Action.CLAIM_DORMANT, 0, portfolio.dormantTargetId, 0, 0);
            }
            if (portfolio.dormantTargetId > 0 && !portfolio.dormantClaimable) {
                return ActionParams(Action.POKE_DORMANT, 0, portfolio.dormantTargetId, 0, 0);
            }
        }

        // 10. Delegate withdrawal — only when portfolio confirms eligibility
        if ((psy.strategyMask & STRAT_DELEGATION) != 0 && config.archetype == Archetype.DELEGATE_WITHDRAWER) {
            if (portfolio.canDelegateWithdraw && portfolio.delegateTargetVaultId > 0) {
                return ActionParams(Action.WITHDRAW_AS_DELEGATE, 0, portfolio.delegateTargetVaultId, 0, 0);
            }
        }

        // 11. Delegation granting — check BPS capacity before granting
        if ((psy.strategyMask & STRAT_DELEGATION) != 0 && config.archetype == Archetype.DELEGATION_GRANTOR) {
            uint16 grantBps = uint16(uint256(psy.delegationBps) * 100);
            if (portfolio.hasVestedVault && portfolio.delegationGrantCount < uint256(psy.delegationTargetCount)) {
                // Check BPS capacity before attempting
                if (portfolio.currentWalletDelegatedBps + uint256(grantBps) <= 10000) {
                    uint256 delegateAgentIdx = _pickDelegateTarget(signals.currentTick, portfolio.delegationGrantCount);
                    return ActionParams(Action.GRANT_WALLET_DELEGATE, 0, delegateAgentIdx, grantBps, 0);
                }
            }
            // Vault-level delegation (periodic, after wallet grants are done)
            if (portfolio.hasVestedVault && portfolio.vestedVaultId > 0 && portfolio.delegationGrantCount >= psy.delegationTargetCount) {
                if (signals.currentTick > 0 && signals.currentTick % 52 == 0) {
                    uint256 delegateAgentIdx = _pickDelegateTarget(signals.currentTick, portfolio.delegationGrantCount + 1);
                    return ActionParams(
                        Action.GRANT_VAULT_DELEGATE,
                        0,
                        delegateAgentIdx | (portfolio.vestedVaultId << 128),
                        grantBps,
                        180 days
                    );
                }
                // Periodic revoke (every 104 ticks = ~2 years)
                if (signals.currentTick > 0 && signals.currentTick % 104 == 0 && portfolio.delegationGrantCount > 0) {
                    uint256 revokeTarget = _pickDelegateTarget(0, 0); // deterministic first delegate
                    return ActionParams(Action.REVOKE_WALLET_DELEGATE, 0, revokeTarget, 0, 0);
                }
            }
        }

        // 12. Withdrawal — use specific withdrawable vault, respecting agent cooldown
        if (portfolio.withdrawableVaultId > 0) {
            // Explicit cooldown guard: skip if currentTick < lastWithdrawTick + 4
            bool cooldownActive = false;
            for (uint256 i = 0; i < state.vaultIds.length; i++) {
                if (state.vaultIds[i] == portfolio.withdrawableVaultId) {
                    if (state.lastWithdrawTicks[i] > 0 && signals.currentTick < state.lastWithdrawTicks[i] + 4) {
                        cooldownActive = true;
                    }
                    break;
                }
            }
            if (!cooldownActive) {
                return ActionParams(Action.WITHDRAW, 0, portfolio.withdrawableVaultId, 0, 0);
            }
        }

        // 13. Match claiming — use specific vault eligible for match claim
        if ((psy.strategyMask & STRAT_MATCH_HUNT) != 0) {
            if (portfolio.matchClaimableVaultId > 0 && signals.matchPoolSize > 0) {
                return ActionParams(Action.CLAIM_MATCH, 0, portfolio.matchClaimableVaultId, 0, 0);
            }
        }

        // 14. Activity proof — use any valid vault
        if (portfolio.anyValidVaultId > 0 && psy.activityInterval > 0) {
            if (signals.currentTick > 0 && signals.currentTick % uint256(psy.activityInterval) == 0) {
                return ActionParams(Action.PROVE_ACTIVITY, 0, portfolio.anyValidVaultId, 0, 0);
            }
        }

        // 15. No action
        return ActionParams(Action.NONE, 0, 0, 0, 0);
    }

    // ==================== Config Generation ====================

    function generateConfig(uint256 seed, uint256 index) internal pure returns (AgentConfig memory config) {
        uint256 hash = uint256(keccak256(abi.encode(seed, index, "proto_config")));

        if (index < 25) {
            config.archetype = Archetype.DIAMOND_HANDS;
        } else if (index < 35) {
            config.archetype = Archetype.MULTI_VAULT_ACCUMULATOR;
        } else if (index < 45) {
            config.archetype = Archetype.DELEGATION_GRANTOR;
        } else if (index < 55) {
            config.archetype = Archetype.DELEGATE_WITHDRAWER;
        } else if (index < 65) {
            config.archetype = Archetype.STRATEGIC_REDEEMER;
        } else if (index < 75) {
            config.archetype = Archetype.PANIC_SELLER;
        } else if (index < 85) {
            config.archetype = Archetype.VBTC_SEPARATOR;
        } else if (index < 90) {
            config.archetype = Archetype.PREDATOR;
        } else if (index < 95) {
            config.archetype = Archetype.ARBITRAGEUR;
        } else {
            config.archetype = Archetype.PASSIVE_HOLDER;
        }

        config.riskTolerance = uint8(_boundedRandom(hash, "risk", 1, 100));
        config.patience = uint8(_boundedRandom(hash, "patience", 1, 100));
        config.rebalanceFrequency = uint8(_boundedRandom(hash, "rebal", 1, 14));

        if (config.archetype == Archetype.DIAMOND_HANDS) {
            config.patience = uint8(_boundedRandom(hash, "patience", 70, 100));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 10, 40));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 5e6, 15e6));
        } else if (config.archetype == Archetype.MULTI_VAULT_ACCUMULATOR) {
            config.patience = uint8(_boundedRandom(hash, "patience", 60, 90));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 20, 50));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 10e6, 30e6));
        } else if (config.archetype == Archetype.DELEGATION_GRANTOR) {
            config.patience = uint8(_boundedRandom(hash, "patience", 50, 90));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 20, 60));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 5e6, 15e6));
        } else if (config.archetype == Archetype.DELEGATE_WITHDRAWER) {
            config.patience = uint8(_boundedRandom(hash, "patience", 40, 80));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 30, 70));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 5e6));
        } else if (config.archetype == Archetype.STRATEGIC_REDEEMER) {
            config.patience = uint8(_boundedRandom(hash, "patience", 30, 60));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 40, 80));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 3e6, 10e6));
        } else if (config.archetype == Archetype.PANIC_SELLER) {
            config.patience = uint8(_boundedRandom(hash, "patience", 1, 30));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 60, 100));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 8e6));
        } else if (config.archetype == Archetype.VBTC_SEPARATOR) {
            config.patience = uint8(_boundedRandom(hash, "patience", 40, 70));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 20, 50));
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 3e6, 10e6));
        } else if (config.archetype == Archetype.PREDATOR) {
            config.rebalanceFrequency = 1;
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 5e6));
        } else if (config.archetype == Archetype.ARBITRAGEUR) {
            config.rebalanceFrequency = 1;
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 2e6, 10e6));
        } else {
            config.patience = 100;
            config.riskTolerance = 1;
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 3e6, 8e6));
        }

        config.psychology = _generatePsychology(hash, config.archetype);
    }

    // ==================== Psychology Generation ====================

    function _generatePsychology(uint256 hash, Archetype archetype)
        private
        pure
        returns (Psychology memory psy)
    {
        uint256 psyHash = uint256(keccak256(abi.encode(hash, "proto_psychology")));

        if (archetype == Archetype.DIAMOND_HANDS) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 30e16, 50e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 25e16, 40e16));
            psy.strategyMask = STRAT_MATCH_HUNT;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 80, 200));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 90, 100));
        } else if (archetype == Archetype.MULTI_VAULT_ACCUMULATOR) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 25e16, 45e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 20e16, 35e16));
            psy.strategyMask = STRAT_MATCH_HUNT | STRAT_MULTI_VAULT;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 40, 100));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 30, 50));
            psy.mintInterval = uint8(_boundedRandom(psyHash, "mintInt", 20, 60));
        } else if (archetype == Archetype.DELEGATION_GRANTOR) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 20e16, 40e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 15e16, 30e16));
            psy.strategyMask = STRAT_MATCH_HUNT | STRAT_DELEGATION;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 30, 80));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 80, 100));
            psy.delegationBps = uint8(_boundedRandom(psyHash, "delBps", 10, 50));
            psy.delegationTargetCount = uint8(_boundedRandom(psyHash, "delCount", 1, 3));
        } else if (archetype == Archetype.DELEGATE_WITHDRAWER) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 15e16, 30e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 10e16, 25e16));
            psy.strategyMask = STRAT_DELEGATION;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 20, 60));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 70, 90));
        } else if (archetype == Archetype.STRATEGIC_REDEEMER) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 10e16, 25e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 8e16, 20e16));
            psy.strategyMask = STRAT_EARLY_REDEEM | STRAT_MATCH_HUNT;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 40, 100));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 60, 80));
            psy.redeemMatchThreshold = _boundedRandom(psyHash, "matchThr", 1e6, 5e7);
        } else if (archetype == Archetype.PANIC_SELLER) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 3e16, 15e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 2e16, 10e16));
            psy.strategyMask = STRAT_EARLY_REDEEM;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 60, 150));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 60, 80));
        } else if (archetype == Archetype.VBTC_SEPARATOR) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 20e16, 35e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 15e16, 28e16));
            psy.strategyMask = STRAT_MATCH_HUNT | STRAT_VBTC_LIFECYCLE;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 30, 80));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 70, 90));
            psy.separateInterval = uint8(_boundedRandom(psyHash, "sepInt", 30, 80));
        } else if (archetype == Archetype.PREDATOR) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 25e16, 40e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 20e16, 35e16));
            psy.strategyMask = STRAT_DORMANCY | STRAT_MATCH_HUNT;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 7, 20));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 50, 70));
        } else if (archetype == Archetype.ARBITRAGEUR) {
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 20e16, 35e16));
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 15e16, 30e16));
            psy.strategyMask = STRAT_DORMANCY | STRAT_MATCH_HUNT;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 7, 20));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 20, 40));
        } else if (archetype == Archetype.PASSIVE_HOLDER) {
            psy.panicThreshold = -int256(50e16);
            psy.exitThreshold = -int256(50e16);
            psy.strategyMask = 0;
            psy.activityInterval = 0;
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 90, 100));
        }
    }

    // ==================== Helpers ====================

    function _pickDelegateTarget(uint256 tick, uint256 offset) private pure returns (uint256) {
        uint256 hash = uint256(keccak256(abi.encode(tick, offset, "delegate_pick")));
        return 45 + (hash % 10);
    }

    function _boundedRandom(
        uint256 seed,
        bytes memory salt,
        uint256 min,
        uint256 max
    ) private pure returns (uint256) {
        uint256 raw = uint256(keccak256(abi.encode(seed, salt)));
        return min + (raw % (max - min + 1));
    }
}
