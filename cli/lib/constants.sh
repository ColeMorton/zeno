#!/bin/bash
# Protocol constants for BTCNFT CLI

# Time periods
readonly VESTING_DAYS=1093
readonly WITHDRAWAL_PERIOD_DAYS=30
readonly GRACE_PERIOD_DAYS=30
readonly DORMANCY_THRESHOLD_DAYS=1093
readonly SECONDS_PER_DAY=86400

# Derived time constants (in seconds)
readonly VESTING_SECONDS=$((VESTING_DAYS * SECONDS_PER_DAY))
readonly WITHDRAWAL_PERIOD_SECONDS=$((WITHDRAWAL_PERIOD_DAYS * SECONDS_PER_DAY))
readonly GRACE_PERIOD_SECONDS=$((GRACE_PERIOD_DAYS * SECONDS_PER_DAY))

# Withdrawal tiers
readonly TIER_CONSERVATIVE=0
readonly TIER_BALANCED=1
readonly TIER_AGGRESSIVE=2

# Tier names for display
readonly TIER_NAMES=("Conservative" "Balanced" "Aggressive")

# Annual withdrawal rates for display
readonly TIER_RATES=("10.5%" "14.6%" "20.8%")

# Monthly withdrawal rates (basis points: 10000 = 100%)
readonly TIER_MONTHLY_BPS=(83 114 159)

# Delegation constants
readonly MAX_DELEGATION_BPS=10000  # 100%

# Token decimals
readonly BTC_DECIMALS=8
readonly SATOSHI_PER_BTC=100000000
