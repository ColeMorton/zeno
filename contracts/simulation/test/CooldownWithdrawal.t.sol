// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentLib} from "../src/agents/AgentLib.sol";

/// @title CooldownWithdrawalTest - Unit tests for cooldown-aware withdrawal logic
/// @dev Tests AgentLib.decide() directly to verify withdrawal frequency constraints
contract CooldownWithdrawalTest is Test {

    /// @notice Verify that decide() blocks withdrawal when currentTick < lastWithdrawTick + 4
    function test_decide_blocks_withdrawal_during_cooldown() public pure {
        AgentLib.AgentConfig memory config;
        config.rebalanceFrequency = 1; // can act every tick

        AgentLib.Psychology memory psy;
        psy.strategyMask = 0; // no side strategies
        psy.panicThreshold = -1e18; // very low, won't trigger
        psy.exitThreshold = -1e18;
        psy.activityInterval = 0; // disable activity proof
        config.psychology = psy;

        AgentLib.AgentState memory state;
        state.vaultIds = new uint256[](1);
        state.vaultIds[0] = 1;
        state.lastWithdrawTicks = new uint256[](1);
        state.lastWithdrawTicks[0] = 10; // withdrew at tick 10
        state.lastActionTick = 0; // frequency gate passes for all ticks > 0

        AgentLib.MarketSignals memory signals;
        signals.currentTick = 11;

        AgentLib.Portfolio memory portfolio;
        portfolio.withdrawableVaultId = 1;
        portfolio.canWithdraw = true;
        portfolio.eligibleMintVault = false;
        portfolio.eligibleEarlyRedeem = false;

        // Ticks 11, 12, 13 should be blocked (11 < 14, 12 < 14, 13 < 14)
        for (uint256 tick = 11; tick <= 13; tick++) {
            signals.currentTick = tick;
            AgentLib.ActionParams memory action = AgentLib.decide(config, state, signals, portfolio);
            assertEq(
                uint256(action.action),
                uint256(AgentLib.Action.NONE),
                string.concat("Withdrawal should be blocked at tick ", vm.toString(tick))
            );
        }

        // Tick 14 should be allowed (14 < 14 is false)
        signals.currentTick = 14;
        AgentLib.ActionParams memory action = AgentLib.decide(config, state, signals, portfolio);
        assertEq(
            uint256(action.action),
            uint256(AgentLib.Action.WITHDRAW),
            "Withdrawal should be allowed at tick 14"
        );
        assertEq(action.targetId, 1, "Should target vault 1");
    }

    /// @notice Verify that a 1-week rebalance agent attempts withdrawal <=1 time per 4 ticks
    /// @dev Simulates 20 consecutive ticks and counts withdrawals
    function test_withdraw_frequency_at_most_one_per_four_ticks() public pure {
        AgentLib.AgentConfig memory config;
        config.rebalanceFrequency = 1; // act every tick

        AgentLib.Psychology memory psy;
        psy.strategyMask = 0;
        psy.panicThreshold = -1e18;
        psy.exitThreshold = -1e18;
        psy.activityInterval = 0;
        config.psychology = psy;

        AgentLib.AgentState memory state;
        state.vaultIds = new uint256[](1);
        state.vaultIds[0] = 1;
        state.lastWithdrawTicks = new uint256[](1);
        state.lastWithdrawTicks[0] = 0; // never withdrawn
        state.lastActionTick = 0;

        AgentLib.MarketSignals memory signals;

        AgentLib.Portfolio memory portfolio;
        portfolio.withdrawableVaultId = 1;
        portfolio.canWithdraw = true;
        portfolio.eligibleMintVault = false;
        portfolio.eligibleEarlyRedeem = false;

        uint256[20] memory withdrawTicks;
        uint256 withdrawCount = 0;

        for (uint256 tick = 1; tick <= 20; tick++) {
            signals.currentTick = tick;
            AgentLib.ActionParams memory action = AgentLib.decide(config, state, signals, portfolio);

            if (action.action == AgentLib.Action.WITHDRAW) {
                withdrawTicks[withdrawCount] = tick;
                withdrawCount++;
                // Simulate the withdrawal happening: update lastWithdrawTick
                state.lastWithdrawTicks[0] = tick;
                // Also update lastActionTick (non-mint actions count as rebalance)
                state.lastActionTick = tick;
            }
        }

        // With rebalanceFrequency=1 and starting at tick 1, the agent would withdraw
        // at tick 1, then be blocked until tick 5, then at tick 5, blocked until 9, etc.
        // Expected withdrawals: ticks 1, 5, 9, 13, 17 = 5 withdrawals.
        assertEq(withdrawCount, 5, "Should withdraw exactly 5 times in 20 ticks");

        // Verify each withdrawal is at least 4 ticks apart
        for (uint256 i = 1; i < withdrawCount; i++) {
            uint256 gap = withdrawTicks[i] - withdrawTicks[i - 1];
            assertGe(gap, 4, "Withdrawals must be at least 4 ticks apart");
        }
    }

    /// @notice Verify that _buildPortfolio-style cooldown (withdrawableVaultId=0) prevents attempts
    function test_no_withdraw_attempt_when_withdrawableVaultId_zero() public pure {
        AgentLib.AgentConfig memory config;
        config.rebalanceFrequency = 1;

        AgentLib.Psychology memory psy;
        psy.strategyMask = 0;
        psy.panicThreshold = -1e18;
        psy.exitThreshold = -1e18;
        psy.activityInterval = 0;
        config.psychology = psy;

        AgentLib.AgentState memory state;
        state.vaultIds = new uint256[](1);
        state.vaultIds[0] = 1;
        state.lastWithdrawTicks = new uint256[](1);
        state.lastWithdrawTicks[0] = 0;
        state.lastActionTick = 0;

        AgentLib.MarketSignals memory signals;
        signals.currentTick = 5;

        AgentLib.Portfolio memory portfolio;
        portfolio.withdrawableVaultId = 0; // no vault ready
        portfolio.canWithdraw = true; // canWithdraw is true but no specific vault
        portfolio.eligibleMintVault = false;
        portfolio.eligibleEarlyRedeem = false;

        AgentLib.ActionParams memory action = AgentLib.decide(config, state, signals, portfolio);
        assertEq(
            uint256(action.action),
            uint256(AgentLib.Action.NONE),
            "Should not attempt withdrawal when withdrawableVaultId is 0"
        );
    }
}
