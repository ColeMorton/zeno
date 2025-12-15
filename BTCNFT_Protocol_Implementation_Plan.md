# BTCNFT Protocol Implementation Plan

## Overview

Implement the BTCNFT Protocol smart contracts with CLI tooling for operational demonstration on local anvil.

**Key Decisions:**
- ERC-998: Minimal subset (top-down ERC-721 + ERC-20 composability only)
- Time Control: Anvil `evm_increaseTime` for fast-forwarding vesting/dormancy
- Deployment: Local anvil only with mock tokens

---

## Project Structure

```
zeno/                             # Project root
├── README.md
├── docs/                         # Existing protocol documentation
│   ├── protocol/
│   └── issuer/
├── foundry.toml
├── remappings.txt
├── src/
│   ├── VaultNFT.sol              # ERC-998 composable NFT (core)
│   ├── BtcToken.sol              # ERC-20 vBTC token
│   ├── interfaces/
│   │   ├── IVaultNFT.sol
│   │   └── IBtcToken.sol
│   └── libraries/
│       └── VaultMath.sol         # Withdrawal/redemption calculations
├── test/
│   ├── VaultNFT.t.sol
│   ├── BtcToken.t.sol
│   ├── Integration.t.sol
│   └── mocks/
│       ├── MockTreasure.sol      # Mock ERC-721
│       └── MockWBTC.sol          # Mock ERC-20
├── script/
│   └── Deploy.s.sol
└── cli/
    ├── setup.sh                  # Start anvil + deploy
    ├── mint.sh                   # Mint Vault NFT
    ├── withdraw.sh               # Withdraw BTC (post-vesting)
    ├── redeem.sh                 # Early redemption
    ├── separate.sh               # Mint btcToken
    ├── recombine.sh              # Return btcToken
    ├── claim-match.sh            # Claim match pool share
    ├── poke.sh                   # Poke dormant vault
    ├── prove-activity.sh         # Prove activity
    ├── claim-dormant.sh          # Claim dormant collateral
    ├── status.sh                 # View vault status
    └── time-skip.sh              # Fast-forward time (anvil)
```

---

## Implementation Phases

### Phase 1: Foundation Setup

**Tasks:**
1. Initialize Foundry project at repository root
2. Configure `foundry.toml` (Solidity 0.8.24, optimizer)
3. Install OpenZeppelin contracts dependency
4. Create mock contracts (`MockTreasure.sol`, `MockWBTC.sol`)
5. Define interfaces (`IVaultNFT.sol`, `IBtcToken.sol`)

**Files Created:**
- `foundry.toml`
- `remappings.txt`
- `test/mocks/MockTreasure.sol`
- `test/mocks/MockWBTC.sol`
- `src/interfaces/IVaultNFT.sol`
- `src/interfaces/IBtcToken.sol`

---

### Phase 2: VaultMath Library

**Tasks:**
1. Implement `VaultMath.sol` with pure calculation functions

**Functions:**
```solidity
calculateWithdrawal(collateral, tierRate) -> withdrawAmount
calculateEarlyRedemption(collateral, daysHeld) -> (returned, forfeited)
calculateMatchShare(pool, holderCollateral, totalActive) -> share
```

**Files Created:**
- `src/libraries/VaultMath.sol`

---

### Phase 3: BtcToken Contract

**Tasks:**
1. Implement ERC-20 with controlled minting/burning
2. Only VaultNFT can mint/burn

**Files Created:**
- `src/BtcToken.sol`
- `test/BtcToken.t.sol`

---

### Phase 4: VaultNFT Core (Minting + Vesting)

**Tasks:**
1. Implement ERC-721 base with minimal ERC-998 composability
2. Implement `mint()` - accept Treasure NFT + BTC collateral
3. Implement vesting period enforcement (1093 days)
4. Activity tracking

**State Variables:**
```solidity
mapping(uint256 => address) public treasureContract;
mapping(uint256 => uint256) public treasureTokenId;
mapping(uint256 => uint256) public collateralAmount;
mapping(uint256 => uint256) public mintTimestamp;
mapping(uint256 => uint8) public tier;
mapping(uint256 => uint256) public lastActivity;
```

**Files Created/Modified:**
- `src/VaultNFT.sol`
- `test/VaultNFT.t.sol`

---

### Phase 5: Withdrawal Mechanism

**Tasks:**
1. Implement `withdraw()` with:
   - Vesting period check
   - 30-day interval enforcement
   - Tier-based percentage calculation (Conservative: 8.33%, Balanced: 11.40%, Aggressive: 15.90%)
   - Activity timestamp update

**Files Modified:**
- `src/VaultNFT.sol`
- `test/VaultNFT.t.sol`

---

### Phase 6: Early Redemption

**Tasks:**
1. Implement `earlyRedeem()` with:
   - Linear unlock formula: `returned = collateral × (daysHeld / 1093)`
   - Forfeited amount added to match pool
   - Burn Vault NFT (Treasure burned with it)

**Files Modified:**
- `src/VaultNFT.sol`
- `test/VaultNFT.t.sol`

---

### Phase 7: Collateral Separation (btcToken)

**Tasks:**
1. Implement `mintBtcToken()` - separate collateral into btcToken (post-vesting only)
2. Implement `returnBtcToken()` - all-or-nothing recombination
3. Lock redemption when btcToken exists

**State Variables:**
```solidity
mapping(uint256 => uint256) public btcTokenAmount;
mapping(uint256 => uint256) public originalMintedAmount;
```

**Files Modified:**
- `src/VaultNFT.sol`
- `test/VaultNFT.t.sol`

---

### Phase 8: Collateral Matching

**Tasks:**
1. Implement `claimMatch()` with:
   - Pro-rata distribution from match pool
   - Snapshot denominator before state change
   - One-time claim per token

**State Variables:**
```solidity
uint256 public matchPool;
uint256 public totalActiveCollateral;
mapping(uint256 => bool) public matured;
mapping(uint256 => bool) public matchClaimed;
```

**Files Modified:**
- `src/VaultNFT.sol`
- `test/VaultNFT.t.sol`

---

### Phase 9: Dormancy Mechanism

**Tasks:**
1. Implement `isDormantEligible()` view function
2. Implement `pokeDormant()` - initiate 30-day grace period
3. Implement `proveActivity()` - owner response
4. Implement `claimDormantCollateral()` - btcToken holder claims

**Dormancy Criteria (all must be true):**
- btcToken exists for vault
- Owner doesn't hold sufficient btcToken
- No activity for 1093+ days

**State Variables:**
```solidity
mapping(uint256 => uint256) public pokeTimestamp;
```

**Files Modified:**
- `src/VaultNFT.sol`
- `test/VaultNFT.t.sol`

---

### Phase 10: Integration Tests

**Tasks:**
1. Full lifecycle test (mint → vest → withdraw → separate → recombine)
2. Early redemption flow test
3. Dormancy claim flow test
4. Multi-user match pool test

**Files Created:**
- `test/Integration.t.sol`

---

### Phase 11: Deployment Script

**Tasks:**
1. Implement `Deploy.s.sol`:
   - Deploy MockWBTC
   - Deploy MockTreasure
   - Deploy BtcToken
   - Deploy VaultNFT
   - Mint initial WBTC and Treasure NFTs to test accounts

**Files Created:**
- `script/Deploy.s.sol`

---

### Phase 12: CLI Scripts

**Tasks:**
1. Create `setup.sh` - start anvil, deploy contracts, export addresses
2. Create operation scripts using `cast`:
   - `mint.sh` - mint Vault NFT
   - `withdraw.sh` - withdraw BTC
   - `redeem.sh` - early redemption
   - `separate.sh` - mint btcToken
   - `recombine.sh` - return btcToken
   - `claim-match.sh` - claim match share
   - `poke.sh` - poke dormant vault
   - `prove-activity.sh` - prove activity
   - `claim-dormant.sh` - claim dormant collateral
   - `status.sh` - view vault status
   - `time-skip.sh` - fast-forward blockchain time

**Files Created:**
- `cli/*.sh`

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `VESTING_PERIOD` | 1093 days | Lock period before withdrawals |
| `WITHDRAWAL_PERIOD` | 30 days | Interval between withdrawals |
| `DORMANCY_THRESHOLD` | 1093 days | Inactivity period for dormancy |
| `GRACE_PERIOD` | 30 days | Grace period after poke |
| `TIER_CONSERVATIVE` | 833 bp | 8.33% per withdrawal |
| `TIER_BALANCED` | 1140 bp | 11.40% per withdrawal |
| `TIER_AGGRESSIVE` | 1590 bp | 15.90% per withdrawal |

---

## Custom Errors

```solidity
error NotTokenOwner(uint256 tokenId);
error StillVesting(uint256 tokenId);
error WithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed);
error InvalidTier(uint8 tier);
error ZeroCollateral();
error BtcTokenAlreadyMinted(uint256 tokenId);
error BtcTokenRequired(uint256 tokenId);
error InsufficientBtcToken(uint256 required, uint256 available);
error NotVested(uint256 tokenId);
error AlreadyClaimed(uint256 tokenId);
error NoPoolAvailable();
error NotDormantEligible(uint256 tokenId);
error AlreadyPoked(uint256 tokenId);
error NotClaimable(uint256 tokenId);
```

---

## CLI Usage Examples

```bash
# Start local environment
./cli/setup.sh

# Mint a vault with Treasure #1, 1 WBTC, Conservative tier
./cli/mint.sh 1 1000000000000000000 0

# Skip 1093 days (vesting period)
./cli/time-skip.sh 1093

# Withdraw from vault #1
./cli/withdraw.sh 1

# View vault status
./cli/status.sh 1

# Separate collateral into btcToken
./cli/separate.sh 1

# Skip 1093 more days and test dormancy
./cli/time-skip.sh 1093
./cli/poke.sh 1
./cli/time-skip.sh 30
./cli/claim-dormant.sh 1
```

---

## Critical Source Files

**Reference Documentation (existing):**
- `docs/protocol/Technical_Specification.md` - Complete function signatures and behavior
- `docs/protocol/Collateral_Matching.md` - Match pool mechanics and formulas
- `docs/protocol/Product_Specification.md` - Withdrawal tiers and dormancy flow

**Implementation Files (created):**
- `src/VaultNFT.sol` - Core ERC-998 composable NFT contract
- `src/BtcToken.sol` - ERC-20 vBTC token contract
- `src/libraries/VaultMath.sol` - Calculation library
- `test/Integration.t.sol` - Full lifecycle tests
- `cli/setup.sh` - Deployment and environment setup

---

## Implementation Summary

**Status:** All 12 phases completed.

**Files Created:**
| Path | Description |
|------|-------------|
| `foundry.toml` | Foundry configuration (Solidity 0.8.24, optimizer) |
| `remappings.txt` | Import remappings for OpenZeppelin |
| `src/VaultNFT.sol` | Core ERC-998 composable NFT (540 lines) |
| `src/BtcToken.sol` | ERC-20 vBTC token with controlled minting |
| `src/libraries/VaultMath.sol` | Pure calculation functions |
| `src/interfaces/IVaultNFT.sol` | Vault interface with events/errors |
| `src/interfaces/IBtcToken.sol` | btcToken interface |
| `test/VaultNFT.t.sol` | Unit tests (35 tests) |
| `test/BtcToken.t.sol` | btcToken unit tests (11 tests) |
| `test/Integration.t.sol` | Full lifecycle integration tests (12 tests) |
| `test/mocks/MockTreasure.sol` | Mock ERC-721 for testing |
| `test/mocks/MockWBTC.sol` | Mock ERC-20 WBTC for testing |
| `script/Deploy.s.sol` | Foundry deployment script |
| `cli/setup.sh` | Start anvil + deploy contracts |
| `cli/mint.sh` | Mint Vault NFT |
| `cli/withdraw.sh` | Post-vesting withdrawal |
| `cli/redeem.sh` | Early redemption |
| `cli/separate.sh` | Mint btcToken (vBTC) |
| `cli/recombine.sh` | Return btcToken |
| `cli/claim-match.sh` | Claim match pool share |
| `cli/poke.sh` | Initiate dormancy claim |
| `cli/prove-activity.sh` | Owner proves activity |
| `cli/claim-dormant.sh` | Claim dormant collateral |
| `cli/status.sh` | View vault status |
| `cli/time-skip.sh` | Fast-forward blockchain time |

**Features Implemented:**
- Vault NFT minting with Treasure NFT + BTC collateral
- 1093-day vesting period enforcement
- Tier-based withdrawals (Conservative/Balanced/Aggressive)
- 30-day withdrawal cooldown
- Early redemption with linear unlock
- Match pool for forfeited collateral
- btcToken (vBTC) separation and recombination
- Dormancy detection and claiming mechanism
- Activity tracking across all operations

**Prerequisites to Run:**
1. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
2. Install dependencies: `forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge install foundry-rs/forge-std --no-commit`
3. Run tests: `forge test`
4. Start CLI demo: `./cli/setup.sh`
