// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentLib - Autonomous agent decision logic for swarm simulation
/// @dev Pure library. Each agent has a unique Psychology that drives decisions.
library AgentLib {
    // ==================== Enums ====================

    enum Archetype {
        DIAMOND_HANDS, // 30 agents: hold to vesting, never early redeem
        YIELD_FARMER, // 20 agents: separate vBTC, deploy to perps + vol pool
        MOMENTUM_TRADER, // 15 agents: trend-following perp positions
        VOLATILITY_PLAYER, // 10 agents: long/short vol pool
        ARBITRAGEUR, // 10 agents: match pool + dormancy hunting
        PANIC_SELLER, // 10 agents: early redeem on drawdowns
        PREDATOR // 5 agents: poke dormant vaults, claim collateral
    }

    enum Action {
        NONE,
        MINT_VAULT,
        WITHDRAW,
        EARLY_REDEEM,
        MINT_BTC_TOKEN,
        RETURN_BTC_TOKEN,
        CLAIM_MATCH,
        PROVE_ACTIVITY,
        OPEN_PERP_LONG,
        OPEN_PERP_SHORT,
        CLOSE_PERP,
        ADD_PERP_COLLATERAL,
        DEPOSIT_VOL_LONG,
        DEPOSIT_VOL_SHORT,
        WITHDRAW_VOL_LONG,
        WITHDRAW_VOL_SHORT,
        POKE_DORMANT,
        CLAIM_DORMANT,
        SWAP_VBTC_TO_WBTC,
        SWAP_WBTC_TO_VBTC,
        ADD_LIQUIDITY
    }

    // ==================== Strategy Mask Constants ====================

    uint8 constant STRAT_PERPS = 0x01;
    uint8 constant STRAT_VOL = 0x02;
    uint8 constant STRAT_EARLY_REDEEM = 0x04;
    uint8 constant STRAT_DORMANCY = 0x08;
    uint8 constant STRAT_MATCH_HUNT = 0x10;
    uint8 constant STRAT_SWAP = 0x20;

    // ==================== Structs ====================

    struct Psychology {
        // Event reaction thresholds (18 decimals, signed)
        int256 panicThreshold; // 7-tick return triggering early redeem (e.g., -1e17 = -10%)
        int256 exitThreshold; // 7-tick return triggering perp/vol exit (e.g., -5e16 = -5%)
        int256 trendEntryThreshold; // min abs(7-tick return) to open trend trade
        // Strategy permissions (bitmask)
        uint8 strategyMask; // PERPS|VOL|EARLY_REDEEM|DORMANCY|MATCH_HUNT
        // Position sizing (percentages, 1-100)
        uint8 perpAllocationPct; // % of vBTC for perps
        uint8 volAllocationPct; // % of vBTC for vol pool
        uint8 maxPerpPositions; // max concurrent perp positions (1-5)
        // Behavioral intervals (ticks)
        uint8 activityInterval; // ticks between prove-activity calls
        uint8 perpCloseInterval; // ticks between periodic perp closes
        // Directional bias
        int8 trendBias; // -1=contrarian, 0=funding-arb, 1=trend-follower
        uint256 volStrikeThreshold; // personal vol strike (18 decimals)
        // AMM swap parameters
        uint8 swapAllocationPct; // % of balance to swap (1-100)
        uint256 swapBuyThreshold; // buy vBTC when ratio below this (18 decimals)
        uint256 swapSellThreshold; // sell vBTC when ratio above this (18 decimals)
        uint8 vaultAllocationPct; // % of WBTC to deposit in vault (rest stays liquid)
    }

    struct AgentConfig {
        Archetype archetype;
        uint8 riskTolerance; // 1-100
        uint8 patience; // 1-100
        uint16 leveragePreference; // 100-500 (X100 format)
        int8 volBias; // -1=short, 0=neutral, 1=long
        uint8 rebalanceFrequency; // ticks between rebalance decisions
        uint64 initialCapitalWbtc; // satoshis (1 den = 10,000 sats = 0.0001 BTC)
        Psychology psychology; // per-agent behavioral profile
    }

    struct AgentState {
        uint256[] vaultIds;
        uint256[] perpPositionIds;
        uint256 longVolShares;
        uint256 shortVolShares;
        bool hasSeparatedVbtc;
        uint256 lastActionTick;
    }

    struct ActionParams {
        Action action;
        uint256 amount;
        uint256 targetId;
        uint16 leverage;
    }

    struct MarketSignals {
        uint256 currentPrice; // WBTC/USDC (18 decimals)
        uint256 vbtcRatio; // vBTC/WBTC (18 decimals)
        int256 priceReturn7d; // 7-tick return (18 decimals, signed)
        int256 priceReturn30d; // 30-tick return (18 decimals, signed)
        uint256 realizedVol7d; // 7-tick realized vol (18 decimals)
        uint256 matchPoolSize; // match pool balance (8 decimals)
        uint256 totalActiveCollateral; // active collateral (8 decimals)
        int256 fundingRate; // perp funding rate BPS (signed)
        uint256 currentTick; // tick number
        bool ammInitialized; // true once AMM pool has both reserves
    }

    /// @notice Portfolio state passed to decision logic
    struct Portfolio {
        uint256 wbtcBalance; // raw WBTC held
        uint256 vbtcBalance; // vBTC held
        uint256 totalVaultCollateral; // sum of vault collateral amounts
        uint256[] vaultCollaterals; // per-vault collateral (cached to avoid duplicate getVaultInfo reads)
        bool[] vaultVested; // per-vault vesting status
        bool hasVestedVault; // any vault past 1129 days
        bool hasUnvestedVault; // any vault not yet vested
        bool canWithdraw; // any vault past 30-day cooldown
        uint256 perpPositionCount; // active perp positions
        bool hasVolPosition; // has vol pool shares
        uint256 dormantTargetId; // vault ID of a dormant vault to target (0 if none)
        bool dormantClaimable; // a poked vault has passed grace period
        bool hasTreasureNft; // agent owns >= 1 Treasure NFT
        bool[] matchClaimed; // per-vault: already claimed match share
    }

    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_COLLATERAL_PERP = 1e6; // 0.01 vBTC

    // ==================== Main Decision Function ====================

    /// @notice Decide next action based on agent's individual psychology
    function decide(
        AgentConfig memory config,
        AgentState memory state,
        MarketSignals memory signals,
        Portfolio memory portfolio
    ) internal pure returns (ActionParams memory) {
        Psychology memory psy = config.psychology;

        // 1. Rebalance frequency gate
        if (signals.currentTick > 0 && signals.currentTick - state.lastActionTick < config.rebalanceFrequency) {
            return ActionParams(Action.NONE, 0, 0, 0);
        }

        // 2a. Prerequisite: mint vault if none (agents keep liquid WBTC based on vaultAllocationPct)
        if (state.vaultIds.length == 0 && portfolio.wbtcBalance > 0 && portfolio.hasTreasureNft) {
            uint256 vaultAmount = portfolio.wbtcBalance * uint256(psy.vaultAllocationPct) / 100;
            if (vaultAmount > 0) {
                return ActionParams(Action.MINT_VAULT, vaultAmount, 0, 0);
            }
        }

        // 2b. Prerequisite: separate vBTC if vested and agent needs it for DeFi/dormancy
        bool needsVbtc = (psy.strategyMask & (STRAT_PERPS | STRAT_VOL | STRAT_DORMANCY | STRAT_SWAP)) != 0;
        if (portfolio.hasVestedVault && !state.hasSeparatedVbtc && needsVbtc && state.vaultIds.length > 0) {
            return ActionParams(Action.MINT_BTC_TOKEN, 0, state.vaultIds[0], 0);
        }

        // 2c. Seed AMM pool if not yet initialized and agent has both WBTC + vBTC
        if ((psy.strategyMask & STRAT_SWAP) != 0 && !signals.ammInitialized) {
            if (portfolio.wbtcBalance > 0 && portfolio.vbtcBalance > 0) {
                return ActionParams(Action.ADD_LIQUIDITY, portfolio.vbtcBalance, 0, 0);
            }
        }

        // 3. Panic exit (early redeem on severe drawdown)
        if ((psy.strategyMask & STRAT_EARLY_REDEEM) != 0) {
            if (signals.priceReturn7d < psy.panicThreshold && state.vaultIds.length > 0) {
                return ActionParams(Action.EARLY_REDEEM, 0, state.vaultIds[0], 0);
            }
        }

        // 3.5. Panic vBTC dump — Panic Sellers sell vBTC on drawdowns (elevated priority)
        if (config.archetype == Archetype.PANIC_SELLER && (psy.strategyMask & STRAT_SWAP) != 0 && signals.ammInitialized) {
            if (signals.priceReturn7d < psy.exitThreshold && portfolio.vbtcBalance > MIN_COLLATERAL_PERP) {
                uint256 dumpAmount = portfolio.vbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (dumpAmount < MIN_COLLATERAL_PERP) dumpAmount = MIN_COLLATERAL_PERP;
                if (dumpAmount > portfolio.vbtcBalance) dumpAmount = portfolio.vbtcBalance;
                return ActionParams(Action.SWAP_VBTC_TO_WBTC, dumpAmount, 0, 0);
            }
        }

        // 4. Distressed exit (close perps/vol on moderate drawdown)
        if (signals.priceReturn7d < psy.exitThreshold) {
            if (state.perpPositionIds.length > 0) {
                return ActionParams(Action.CLOSE_PERP, 0, state.perpPositionIds[0], 0);
            }
            if (state.longVolShares > 0) {
                return ActionParams(Action.WITHDRAW_VOL_LONG, state.longVolShares, 0, 0);
            }
            if (state.shortVolShares > 0) {
                return ActionParams(Action.WITHDRAW_VOL_SHORT, state.shortVolShares, 0, 0);
            }
        }

        // 5. Dormancy actions
        if ((psy.strategyMask & STRAT_DORMANCY) != 0) {
            if (portfolio.dormantClaimable && portfolio.dormantTargetId > 0 && portfolio.vbtcBalance > 0) {
                return ActionParams(Action.CLAIM_DORMANT, 0, portfolio.dormantTargetId, 0);
            }
            if (portfolio.dormantTargetId > 0 && !portfolio.dormantClaimable) {
                return ActionParams(Action.POKE_DORMANT, 0, portfolio.dormantTargetId, 0);
            }
        }

        // 6. Withdrawal
        if (portfolio.hasVestedVault && portfolio.canWithdraw && state.vaultIds.length > 0) {
            return ActionParams(Action.WITHDRAW, 0, state.vaultIds[0], 0);
        }

        // 7. Match claiming (find first unclaimed vested vault)
        if ((psy.strategyMask & STRAT_MATCH_HUNT) != 0) {
            if (portfolio.hasVestedVault && signals.matchPoolSize > 0) {
                for (uint256 i = 0; i < state.vaultIds.length; i++) {
                    if (portfolio.vaultVested[i] && !portfolio.matchClaimed[i]) {
                        return ActionParams(Action.CLAIM_MATCH, 0, state.vaultIds[i], 0);
                    }
                }
            }
        }

        // 8. Perp management
        if ((psy.strategyMask & STRAT_PERPS) != 0) {
            // 8a. Close perps periodically
            if (state.perpPositionIds.length > 0 && psy.perpCloseInterval > 0) {
                if (signals.currentTick > 0 && signals.currentTick % uint256(psy.perpCloseInterval) == 0) {
                    return ActionParams(Action.CLOSE_PERP, 0, state.perpPositionIds[0], 0);
                }
            }

            // 8b. Open new perp position
            if (portfolio.vbtcBalance >= MIN_COLLATERAL_PERP && state.perpPositionIds.length < psy.maxPerpPositions) {
                uint256 amount = portfolio.vbtcBalance * uint256(psy.perpAllocationPct) / 100;
                if (amount < MIN_COLLATERAL_PERP) amount = MIN_COLLATERAL_PERP;
                if (amount > portfolio.vbtcBalance) amount = portfolio.vbtcBalance;

                bool goLong;
                bool shouldTrade;

                if (psy.trendBias > 0) {
                    // Trend follower: follow 7-tick return direction
                    shouldTrade = signals.priceReturn7d > psy.trendEntryThreshold
                        || signals.priceReturn7d < -psy.trendEntryThreshold;
                    goLong = signals.priceReturn7d > 0;
                } else if (psy.trendBias < 0) {
                    // Contrarian: trade against 7-tick return
                    shouldTrade = signals.priceReturn7d > psy.trendEntryThreshold
                        || signals.priceReturn7d < -psy.trendEntryThreshold;
                    goLong = signals.priceReturn7d < 0;
                } else {
                    // Funding rate arb: go long when shorts pay (negative rate)
                    shouldTrade = true;
                    goLong = signals.fundingRate < 0;
                }

                if (shouldTrade) {
                    if (goLong) {
                        return ActionParams(Action.OPEN_PERP_LONG, amount, 0, config.leveragePreference);
                    } else {
                        return ActionParams(Action.OPEN_PERP_SHORT, amount, 0, config.leveragePreference);
                    }
                }
            }
        }

        // 8.5 AMM swap logic (only when pool has liquidity)
        if ((psy.strategyMask & STRAT_SWAP) != 0 && signals.ammInitialized) {
            ActionParams memory swapAction = _decideSwap(config.archetype, psy, signals, portfolio);
            if (swapAction.action != Action.NONE) return swapAction;
        }

        // 9. Vol management
        if ((psy.strategyMask & STRAT_VOL) != 0 && portfolio.vbtcBalance >= MIN_COLLATERAL_PERP) {
            uint256 volAmount = portfolio.vbtcBalance * uint256(psy.volAllocationPct) / 100;
            if (volAmount < MIN_COLLATERAL_PERP) volAmount = MIN_COLLATERAL_PERP;
            if (volAmount > portfolio.vbtcBalance) volAmount = portfolio.vbtcBalance;

            // 9a. Rebalance: close wrong-side position if vol crossed threshold
            if (signals.realizedVol7d > psy.volStrikeThreshold) {
                // High vol: want long vol
                if (state.shortVolShares > 0) {
                    return ActionParams(Action.WITHDRAW_VOL_SHORT, state.shortVolShares, 0, 0);
                }
                if (state.longVolShares == 0) {
                    return ActionParams(Action.DEPOSIT_VOL_LONG, volAmount, 0, 0);
                }
            } else {
                // Low vol: want short vol
                if (state.longVolShares > 0) {
                    return ActionParams(Action.WITHDRAW_VOL_LONG, state.longVolShares, 0, 0);
                }
                if (state.shortVolShares == 0) {
                    return ActionParams(Action.DEPOSIT_VOL_SHORT, volAmount, 0, 0);
                }
            }

            // Vol bias override in neutral conditions
            if (config.volBias > 0 && state.longVolShares == 0) {
                return ActionParams(Action.DEPOSIT_VOL_LONG, volAmount, 0, 0);
            }
            if (config.volBias < 0 && state.shortVolShares == 0) {
                return ActionParams(Action.DEPOSIT_VOL_SHORT, volAmount, 0, 0);
            }
        }

        // 10. Activity proof
        if (state.vaultIds.length > 0 && psy.activityInterval > 0) {
            if (signals.currentTick > 0 && signals.currentTick % uint256(psy.activityInterval) == 0) {
                return ActionParams(Action.PROVE_ACTIVITY, 0, state.vaultIds[0], 0);
            }
        }

        // 11. No action
        return ActionParams(Action.NONE, 0, 0, 0);
    }

    /// @notice Public swap decision — allows orchestrator to run swap as secondary action
    function decideSwap(
        AgentConfig memory config,
        MarketSignals memory signals,
        Portfolio memory portfolio
    ) internal pure returns (ActionParams memory) {
        return _decideSwap(config.archetype, config.psychology, signals, portfolio);
    }

    // ==================== Config Generation ====================

    /// @notice Generate deterministic agent config from seed and index
    /// @param seed Base random seed
    /// @param index Agent index (0-99)
    /// @return config Agent configuration with unique psychology
    function generateConfig(uint256 seed, uint256 index) internal pure returns (AgentConfig memory config) {
        uint256 hash = uint256(keccak256(abi.encode(seed, index, "config")));

        // Assign archetype by index range
        if (index < 30) {
            config.archetype = Archetype.DIAMOND_HANDS;
        } else if (index < 50) {
            config.archetype = Archetype.YIELD_FARMER;
        } else if (index < 65) {
            config.archetype = Archetype.MOMENTUM_TRADER;
        } else if (index < 75) {
            config.archetype = Archetype.VOLATILITY_PLAYER;
        } else if (index < 85) {
            config.archetype = Archetype.ARBITRAGEUR;
        } else if (index < 95) {
            config.archetype = Archetype.PANIC_SELLER;
        } else {
            config.archetype = Archetype.PREDATOR;
        }

        // Randomize params within archetype-appropriate ranges
        config.riskTolerance = uint8(_boundedRandom(hash, "risk", 1, 100));
        config.patience = uint8(_boundedRandom(hash, "patience", 1, 100));
        config.rebalanceFrequency = uint8(_boundedRandom(hash, "rebal", 1, 14));

        // Archetype-specific overrides
        if (config.archetype == Archetype.DIAMOND_HANDS) {
            config.leveragePreference = 100; // 1x only
            config.volBias = 0;
            config.patience = uint8(_boundedRandom(hash, "patience", 70, 100));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 10, 40));
        } else if (config.archetype == Archetype.YIELD_FARMER) {
            config.leveragePreference = uint16(_boundedRandom(hash, "lev", 100, 200));
            config.volBias = int8(int256(_boundedRandom(hash, "vol", 0, 2)) - 1);
        } else if (config.archetype == Archetype.MOMENTUM_TRADER) {
            config.leveragePreference = uint16(_boundedRandom(hash, "lev", 200, 500));
            config.volBias = 0;
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 50, 100));
        } else if (config.archetype == Archetype.VOLATILITY_PLAYER) {
            config.leveragePreference = 100;
            config.volBias = int8(int256(_boundedRandom(hash, "vol", 0, 2)) - 1);
        } else if (config.archetype == Archetype.ARBITRAGEUR) {
            config.leveragePreference = 100;
            config.volBias = 0;
            config.rebalanceFrequency = 1; // check every tick
        } else if (config.archetype == Archetype.PANIC_SELLER) {
            config.leveragePreference = uint16(_boundedRandom(hash, "lev", 100, 300));
            config.volBias = 0;
            config.patience = uint8(_boundedRandom(hash, "patience", 1, 30));
            config.riskTolerance = uint8(_boundedRandom(hash, "risk", 60, 100));
        } else if (config.archetype == Archetype.PREDATOR) {
            config.leveragePreference = 100;
            config.volBias = 0;
            config.rebalanceFrequency = 1;
        }

        // Initial capital: archetype-specific ranges (in satoshis; 1 den = 10,000 sats)
        if (config.archetype == Archetype.DIAMOND_HANDS) {
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 5e6, 15e6)); // 500-1,500 d
        } else if (config.archetype == Archetype.YIELD_FARMER) {
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 3e6, 12e6)); // 300-1,200 d
        } else if (config.archetype == Archetype.MOMENTUM_TRADER) {
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 8e6)); // 100-800 d
        } else if (config.archetype == Archetype.VOLATILITY_PLAYER) {
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 8e6)); // 100-800 d
        } else if (config.archetype == Archetype.ARBITRAGEUR) {
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 2e6, 10e6)); // 200-1,000 d
        } else if (config.archetype == Archetype.PANIC_SELLER) {
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 8e6)); // 100-800 d
        } else {
            // PREDATOR
            config.initialCapitalWbtc = uint64(_boundedRandom(hash, "capital", 1e6, 5e6)); // 100-500 d
        }

        // Generate unique psychology from archetype template
        config.psychology = _generatePsychology(hash, config.archetype);
    }

    // ==================== Psychology Generation ====================

    /// @dev Generate unique psychology seeded from archetype template ranges
    function _generatePsychology(uint256 hash, Archetype archetype)
        private
        pure
        returns (Psychology memory psy)
    {
        uint256 psyHash = uint256(keccak256(abi.encode(hash, "psychology")));

        if (archetype == Archetype.DIAMOND_HANDS) {
            // Patient holders: very high panic/exit thresholds, no DeFi, match hunting only
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 30e16, 50e16)); // -30% to -50%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 25e16, 40e16)); // -25% to -40%
            psy.trendEntryThreshold = 0;
            psy.strategyMask = STRAT_MATCH_HUNT;
            psy.perpAllocationPct = 0;
            psy.volAllocationPct = 0;
            psy.maxPerpPositions = 0;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 80, 200));
            psy.perpCloseInterval = 0;
            psy.trendBias = 0;
            psy.volStrikeThreshold = 4e16;
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 90, 100));
        } else if (archetype == Archetype.YIELD_FARMER) {
            // DeFi optimizers: moderate thresholds, perps + vol, funding-rate driven
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 12e16, 25e16)); // -12% to -25%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 8e16, 18e16)); // -8% to -18%
            psy.trendEntryThreshold = int256(_boundedRandom(psyHash, "trend", 2e16, 5e16)); // 2% to 5%
            psy.strategyMask = STRAT_PERPS | STRAT_VOL | STRAT_MATCH_HUNT | STRAT_SWAP;
            psy.perpAllocationPct = uint8(_boundedRandom(psyHash, "perpPct", 20, 45));
            psy.volAllocationPct = uint8(_boundedRandom(psyHash, "volPct", 30, 60));
            psy.maxPerpPositions = uint8(_boundedRandom(psyHash, "maxPerp", 1, 3));
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 40, 100));
            psy.perpCloseInterval = uint8(_boundedRandom(psyHash, "perpClose", 15, 30));
            psy.trendBias = 0; // funding-rate arb
            psy.volStrikeThreshold = _boundedRandom(psyHash, "volStrike", 3e16, 6e16);
            psy.swapAllocationPct = uint8(_boundedRandom(psyHash, "swapPct", 15, 30));
            psy.swapBuyThreshold = _boundedRandom(psyHash, "swapBuy", 70e16, 80e16);
            psy.swapSellThreshold = _boundedRandom(psyHash, "swapSell", 85e16, 95e16);
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 40, 60));
        } else if (archetype == Archetype.MOMENTUM_TRADER) {
            // Trend followers: aggressive perps, high leverage, trend-driven
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 15e16, 30e16)); // -15% to -30%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 10e16, 25e16)); // -10% to -25%
            psy.trendEntryThreshold = int256(_boundedRandom(psyHash, "trend", 0, 3e16)); // 0% to 3%
            psy.strategyMask = STRAT_PERPS | STRAT_MATCH_HUNT | STRAT_SWAP;
            psy.perpAllocationPct = uint8(_boundedRandom(psyHash, "perpPct", 40, 90));
            psy.volAllocationPct = 0;
            psy.maxPerpPositions = uint8(_boundedRandom(psyHash, "maxPerp", 2, 5));
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 8, 28));
            psy.perpCloseInterval = uint8(_boundedRandom(psyHash, "perpClose", 8, 20));
            // 80% trend followers, 20% contrarians
            psy.trendBias = _boundedRandom(psyHash, "bias", 0, 4) == 0 ? int8(-1) : int8(1);
            psy.volStrikeThreshold = 4e16;
            psy.swapAllocationPct = uint8(_boundedRandom(psyHash, "swapPct", 40, 70));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 30, 50));
        } else if (archetype == Archetype.VOLATILITY_PLAYER) {
            // Vol surface traders: vol pool focused, varied strike sensitivity
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 12e16, 25e16)); // -12% to -25%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 8e16, 18e16)); // -8% to -18%
            psy.trendEntryThreshold = 0;
            psy.strategyMask = STRAT_VOL | STRAT_MATCH_HUNT;
            psy.perpAllocationPct = 0;
            psy.volAllocationPct = uint8(_boundedRandom(psyHash, "volPct", 40, 80));
            psy.maxPerpPositions = 0;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 15, 40));
            psy.perpCloseInterval = 0;
            psy.trendBias = 0;
            psy.volStrikeThreshold = _boundedRandom(psyHash, "volStrike", 2e16, 8e16);
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 40, 60));
        } else if (archetype == Archetype.ARBITRAGEUR) {
            // Protocol mechanics exploiters: dormancy + match hunting
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 20e16, 35e16)); // -20% to -35%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 15e16, 30e16)); // -15% to -30%
            psy.trendEntryThreshold = 0;
            psy.strategyMask = STRAT_DORMANCY | STRAT_MATCH_HUNT | STRAT_SWAP;
            psy.perpAllocationPct = 0;
            psy.volAllocationPct = 0;
            psy.maxPerpPositions = 0;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 7, 20));
            psy.perpCloseInterval = 0;
            psy.trendBias = 0;
            psy.volStrikeThreshold = 4e16;
            psy.swapAllocationPct = uint8(_boundedRandom(psyHash, "swapPct", 30, 60));
            psy.swapBuyThreshold = _boundedRandom(psyHash, "swapBuy", 70e16, 78e16);
            psy.swapSellThreshold = _boundedRandom(psyHash, "swapSell", 78e16, 88e16);
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 20, 40));
        } else if (archetype == Archetype.PANIC_SELLER) {
            // Fear-driven exits: low thresholds, will early redeem, some DeFi exposure
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 3e16, 15e16)); // -3% to -15%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 2e16, 10e16)); // -2% to -10%
            psy.trendEntryThreshold = int256(_boundedRandom(psyHash, "trend", 3e16, 8e16)); // 3% to 8%
            psy.strategyMask = STRAT_EARLY_REDEEM | STRAT_PERPS | STRAT_VOL | STRAT_SWAP;
            psy.perpAllocationPct = uint8(_boundedRandom(psyHash, "perpPct", 10, 30));
            psy.volAllocationPct = uint8(_boundedRandom(psyHash, "volPct", 10, 30));
            psy.maxPerpPositions = uint8(_boundedRandom(psyHash, "maxPerp", 1, 2));
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 60, 150));
            psy.perpCloseInterval = uint8(_boundedRandom(psyHash, "perpClose", 3, 10));
            // Panic sellers tend to be contrarian or neutral (sell into fear)
            psy.trendBias = int8(int256(_boundedRandom(psyHash, "bias", 0, 1))) - 1; // -1 or 0
            psy.volStrikeThreshold = 4e16;
            psy.swapAllocationPct = uint8(_boundedRandom(psyHash, "swapPct", 50, 80));
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 60, 80));
        } else if (archetype == Archetype.PREDATOR) {
            // Dormancy hunters: focused on poke/claim, high composure
            psy.panicThreshold = -int256(_boundedRandom(psyHash, "panic", 25e16, 40e16)); // -25% to -40%
            psy.exitThreshold = -int256(_boundedRandom(psyHash, "exit", 20e16, 35e16)); // -20% to -35%
            psy.trendEntryThreshold = 0;
            psy.strategyMask = STRAT_DORMANCY | STRAT_MATCH_HUNT;
            psy.perpAllocationPct = 0;
            psy.volAllocationPct = 0;
            psy.maxPerpPositions = 0;
            psy.activityInterval = uint8(_boundedRandom(psyHash, "activity", 7, 20));
            psy.perpCloseInterval = 0;
            psy.trendBias = 0;
            psy.volStrikeThreshold = 4e16;
            psy.vaultAllocationPct = uint8(_boundedRandom(psyHash, "vaultPct", 50, 70));
        }
    }

    // ==================== Swap Decision ====================

    function _decideSwap(
        Archetype archetype,
        Psychology memory psy,
        MarketSignals memory signals,
        Portfolio memory portfolio
    ) private pure returns (ActionParams memory) {
        uint256 minSwap = MIN_COLLATERAL_PERP;

        if (archetype == Archetype.YIELD_FARMER) {
            // Buy vBTC at discount, sell at premium (conditional, not unconditional)
            if (signals.vbtcRatio > 0 && signals.vbtcRatio < psy.swapBuyThreshold && portfolio.wbtcBalance > minSwap) {
                uint256 amount = portfolio.wbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.wbtcBalance) amount = portfolio.wbtcBalance;
                return ActionParams(Action.SWAP_WBTC_TO_VBTC, amount, 0, 0);
            }
            if (signals.vbtcRatio > psy.swapSellThreshold && portfolio.vbtcBalance > minSwap) {
                uint256 amount = portfolio.vbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.vbtcBalance) amount = portfolio.vbtcBalance;
                return ActionParams(Action.SWAP_VBTC_TO_WBTC, amount, 0, 0);
            }
        } else if (archetype == Archetype.MOMENTUM_TRADER) {
            // Directional: buy vBTC on positive momentum, sell on negative
            if (signals.priceReturn7d > psy.trendEntryThreshold && portfolio.wbtcBalance > minSwap) {
                uint256 amount = portfolio.wbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.wbtcBalance) amount = portfolio.wbtcBalance;
                return ActionParams(Action.SWAP_WBTC_TO_VBTC, amount, 0, 0);
            }
            if (signals.priceReturn7d < -psy.trendEntryThreshold && portfolio.vbtcBalance > minSwap) {
                uint256 amount = portfolio.vbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.vbtcBalance) amount = portfolio.vbtcBalance;
                return ActionParams(Action.SWAP_VBTC_TO_WBTC, amount, 0, 0);
            }
        } else if (archetype == Archetype.ARBITRAGEUR) {
            // Emergency arb: buy aggressively when ratio below extreme stress floor (0.50)
            if (signals.vbtcRatio > 0 && signals.vbtcRatio < 5e17 && portfolio.wbtcBalance > minSwap) {
                return ActionParams(Action.SWAP_WBTC_TO_VBTC, portfolio.wbtcBalance, 0, 0);
            }
            // Normal arb: buy below threshold
            if (signals.vbtcRatio > 0 && signals.vbtcRatio < psy.swapBuyThreshold && portfolio.wbtcBalance > minSwap) {
                uint256 amount = portfolio.wbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.wbtcBalance) amount = portfolio.wbtcBalance;
                return ActionParams(Action.SWAP_WBTC_TO_VBTC, amount, 0, 0);
            }
            if (signals.vbtcRatio > psy.swapSellThreshold && portfolio.vbtcBalance > minSwap) {
                uint256 amount = portfolio.vbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.vbtcBalance) amount = portfolio.vbtcBalance;
                return ActionParams(Action.SWAP_VBTC_TO_WBTC, amount, 0, 0);
            }
        } else if (archetype == Archetype.PANIC_SELLER) {
            // Sell vBTC on drawdowns
            if (signals.priceReturn7d < psy.exitThreshold && portfolio.vbtcBalance > minSwap) {
                uint256 amount = portfolio.vbtcBalance * uint256(psy.swapAllocationPct) / 100;
                if (amount < minSwap) amount = minSwap;
                if (amount > portfolio.vbtcBalance) amount = portfolio.vbtcBalance;
                return ActionParams(Action.SWAP_VBTC_TO_WBTC, amount, 0, 0);
            }
        }

        return ActionParams(Action.NONE, 0, 0, 0);
    }

    // ==================== Helpers ====================

    /// @dev Bounded random value from seed + salt
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
