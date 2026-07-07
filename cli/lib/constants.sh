#!/bin/bash
# Protocol constants for BTCNFT CLI

# Time periods
readonly VESTING_DAYS=1129
readonly WITHDRAWAL_PERIOD_DAYS=30
readonly SECONDS_PER_DAY=86400

# Derived time constants (in seconds)
readonly VESTING_SECONDS=$((VESTING_DAYS * SECONDS_PER_DAY))
readonly WITHDRAWAL_PERIOD_SECONDS=$((WITHDRAWAL_PERIOD_DAYS * SECONDS_PER_DAY))

# Withdrawal rate (fixed)
readonly WITHDRAWAL_RATE_ANNUAL="12%"
readonly WITHDRAWAL_RATE_MONTHLY="1.0%"

# Delegation constants
readonly MAX_DELEGATION_BPS=10000  # 100%

# Token decimals
readonly SATOSHI_PER_BTC=100000000
