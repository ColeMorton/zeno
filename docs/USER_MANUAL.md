# User Manual

> **Version:** 1.0
> **Status:** Active
> **Last Updated:** 2026-01-04

CLI reference for BTCNFT Protocol operations.

---

## Quick Start

```bash
# 1. Start local development environment
./btcnft setup

# 2. Mint a vault
./btcnft mint 0 100000000  # Treasure #0, 1 BTC

# 3. Check vault status
./btcnft status 0
```

**Requirements:**
- Foundry (`forge`, `cast`, `anvil`) - https://getfoundry.sh
- `jq` and `bc` utilities

---

## Network Configuration

Commands default to local Anvil. Use `--network` for other networks:

```bash
./btcnft mint 0 100000000 --network sepolia
```

| Network | RPC | Chain ID | Environment File |
|---------|-----|----------|------------------|
| `local` | http://127.0.0.1:8545 | 31337 | `cli/.env` |
| `sepolia` | https://rpc.sepolia.org | 11155111 | `cli/.env.sepolia` |
| `holesky` | https://rpc.holesky.ethpandaops.io | 17000 | `cli/.env.holesky` |
| `base` | https://mainnet.base.org | 8453 | `cli/.env.base` |

Ethereum mainnet is explicitly not supported.

---

## CLI Command Reference

### Setup

#### `./btcnft setup`

Deploys contracts to local Anvil and configures environment files.

```bash
./btcnft setup
```

**Actions:**
1. Starts Anvil (if not running)
2. Deploys Protocol contracts (VaultNFT, BtcToken for WBTC and cbBTC)
3. Deploys Issuer contracts (VaultMintController)
4. Creates `cli/.env` with contract addresses
5. Creates `apps/ascent/.env.local` for frontend
6. Seeds 5 test vaults across different wallets
7. Sets blockchain time to epoch (Jan 1 2024)

**Output:**
- Contract addresses for both WBTC and cbBTC stacks
- Test token balances
- Anvil PID for later termination

---

### Vault Operations

#### `./btcnft mint`

Creates a new Vault NFT by locking a Treasure NFT and BTC collateral.

```bash
./btcnft mint <treasure_token_id> <btc_amount_satoshis>
```

| Argument | Description |
|----------|-------------|
| `treasure_token_id` | ID of the Treasure NFT to lock |
| `btc_amount_satoshis` | Collateral amount (100000000 = 1 BTC) |

**Example:**
```bash
./btcnft mint 0 100000000  # Lock Treasure #0 with 1 BTC
```

**Withdrawal Rate:** 1.0%/month (12%/year)

---

#### `./btcnft withdraw`

Withdraws monthly collateral from a vested vault.

```bash
./btcnft withdraw <vault_token_id>
```

**Requirements:**
- Vault must be fully vested (1129 days)
- 30+ days since last withdrawal

**Amount:** 1.0% of remaining collateral

**Example:**
```bash
./btcnft withdraw 0
```

---

#### `./btcnft separate`

Mints vBTC tokens representing the vault's collateral claim.

```bash
./btcnft separate <vault_token_id>
```

After separation, vBTC can be transferred independently from the Vault NFT.

**Requirements:**
- Vault must be fully vested
- vBTC not already minted for this vault

**Example:**
```bash
./btcnft separate 0
```

---

#### `./btcnft recombine`

Returns vBTC tokens to the vault, regaining full collateral control.

```bash
./btcnft recombine <vault_token_id>
```

**Requirements:**
- Must hold the full original vBTC amount

**Example:**
```bash
./btcnft recombine 0
```

---

#### `./btcnft early-redeem`

Burns the vault and returns pro-rata collateral based on elapsed time.

```bash
./btcnft early-redeem <vault_token_id>
```

**Formula:** `returned = collateral × (elapsed_days / 1129)`

Forfeited collateral goes to the match pool.

**Example:**
```bash
./btcnft early-redeem 0
```

---

### Delegation Commands

#### `./btcnft delegate-grant`

Grants withdrawal rights to a delegate address.

```bash
./btcnft delegate-grant <vault_token_id> <delegate_address> <percentage_bps>
```

| Argument | Description |
|----------|-------------|
| `vault_token_id` | Vault to delegate |
| `delegate_address` | Ethereum address of delegate |
| `percentage_bps` | Percentage in basis points (100 = 1%, 5000 = 50%, 10000 = 100%) |

**Example:**
```bash
./btcnft delegate-grant 1 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1 5000
# Grants 50% withdrawal rights
```

---

#### `./btcnft delegate-revoke`

Revokes withdrawal rights from a delegate.

```bash
./btcnft delegate-revoke <vault_token_id> [delegate_address]
./btcnft delegate-revoke <vault_token_id> --all
```

| Option | Description |
|--------|-------------|
| `delegate_address` | Revoke specific delegate |
| `--all` | Revoke all delegates at once |

**Examples:**
```bash
./btcnft delegate-revoke 1 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1
./btcnft delegate-revoke 1 --all
```

---

#### `./btcnft delegate-withdraw`

Withdraws collateral from a vault as a delegated address.

```bash
./btcnft delegate-withdraw <vault_token_id>
```

**Requirements:**
- Must be a registered delegate
- 30+ days since last delegated withdrawal
- Vault must be vested

Amount based on your delegation percentage.

---

### Auction Commands

#### `./btcnft auction-create-dutch`

Creates a Dutch auction with linear price decay.

```bash
./btcnft auction-create-dutch <max_supply> <start_price> <floor_price> <decay_rate> <start_time> <end_time>
```

| Argument | Description |
|----------|-------------|
| `max_supply` | Maximum vaults to mint |
| `start_price` | Starting price in satoshis |
| `floor_price` | Minimum price in satoshis |
| `decay_rate` | Price decrease per second (satoshis) |
| `start_time` | Unix timestamp start |
| `end_time` | Unix timestamp end |

**Requires:** `AUCTION_CONTROLLER` in environment

**Example:**
```bash
./btcnft auction-create-dutch 100 200000000 100000000 100 1735689600 1735776000
# 100 vaults, 2 BTC start, 1 BTC floor, 100 sat/sec decay
```

---

#### `./btcnft auction-create-english`

Creates an English auction with sealed bidding.

```bash
./btcnft auction-create-english <max_supply> <reserve_price> <min_bid_bps> <start_time> <end_time> <extension_window> <extension_duration>
```

| Argument | Description |
|----------|-------------|
| `max_supply` | Maximum slots |
| `reserve_price` | Minimum bid in satoshis |
| `min_bid_bps` | Minimum bid increment (100 = 1%) |
| `start_time` | Unix timestamp start |
| `end_time` | Unix timestamp end |
| `extension_window` | Seconds before end that triggers extension |
| `extension_duration` | Seconds to extend on late bid |

**Example:**
```bash
./btcnft auction-create-english 10 100000000 500 1735689600 1735776000 300 600
# 10 slots, 1 BTC reserve, 5% min increment, 5min/10min anti-snipe
```

---

#### `./btcnft auction-purchase`

Purchases from a Dutch auction at current price.

```bash
./btcnft auction-purchase <auction_id>
```

**Example:**
```bash
./btcnft auction-purchase 0
```

---

#### `./btcnft auction-bid`

Places a bid on an English auction slot.

```bash
./btcnft auction-bid <auction_id> <slot> <amount_satoshis>
```

| Argument | Description |
|----------|-------------|
| `auction_id` | Auction to bid on |
| `slot` | Slot number (0 to maxSupply-1) |
| `amount_satoshis` | Bid amount |

**Example:**
```bash
./btcnft auction-bid 0 5 150000000  # 1.5 BTC on slot 5
```

---

#### `./btcnft auction-settle`

Settles an English auction slot (mints vault to winner).

```bash
./btcnft auction-settle <auction_id> <slot>
```

**Requirements:**
- Auction must be ended (state 2 or 3)
- Slot must have a winning bid

**Example:**
```bash
./btcnft auction-settle 0 5
```

---

### Maintenance Commands

#### `./btcnft poke`

Initiates the dormancy recovery process for an inactive vault.

```bash
./btcnft poke <vault_token_id>
```

Starts a 30-day grace period for the owner to prove activity.

**Example:**
```bash
./btcnft poke 42
```

---

#### `./btcnft prove-activity`

Proves vault activity to reset the dormancy timer.

```bash
./btcnft prove-activity <vault_token_id>
```

Must be called by the vault owner.

**Example:**
```bash
./btcnft prove-activity 42
```

---

#### `./btcnft claim-dormant`

Claims collateral from a dormant vault after grace period expires.

```bash
./btcnft claim-dormant <vault_token_id>
```

**Requirements:**
- Vault must be dormant (1129 days inactive + 30 day grace expired)
- Must hold the full vBTC amount for the vault
- vBTC must have been separated first

**Example:**
```bash
./btcnft claim-dormant 42
```

---

#### `./btcnft claim-match`

Claims a pro-rata share of the match pool based on vault collateral.

```bash
./btcnft claim-match <vault_token_id>
```

Match pool is funded by early redemption forfeitures.

**Requirements:**
- Vault must be fully vested

**Example:**
```bash
./btcnft claim-match 0
```

---

## Common Workflows

### First-Time Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Start local environment
./btcnft setup

# Verify deployment
./btcnft status 0
```

### Mint and Withdraw Flow

```bash
# Mint vault with 1 BTC
./btcnft mint 0 100000000

# Wait 1129 days (or use time-skip in dev)

# Monthly withdrawal
./btcnft withdraw 0

# View status
./btcnft status 0
```

### Delegation Setup

```bash
# Grant 50% to automation service
./btcnft delegate-grant 1 0xServiceAddress 5000

# Service can withdraw their portion
./btcnft delegate-withdraw 1 --network base

# Revoke when done
./btcnft delegate-revoke 1 0xServiceAddress
```

### vBTC Separation

```bash
# Separate vBTC from vault
./btcnft separate 0

# Transfer vBTC (use cast or wallet)
cast send $BTC_TOKEN "transfer(address,uint256)" 0xRecipient 50000000

# Recombine when ready
./btcnft recombine 0
```

---

## Troubleshooting

### "Environment file not found"

Run `./btcnft setup` to deploy contracts and create environment files.

### "Vault is not yet vested"

Vesting takes 1129 days. For local testing, use Anvil time-skip:

```bash
# Skip 1129 days
cast rpc evm_increaseTime 97545600 --rpc-url http://127.0.0.1:8545
cast rpc evm_mine --rpc-url http://127.0.0.1:8545
```

### "No withdrawable amount"

- 30-day cooldown since last withdrawal has not passed
- Collateral is already depleted

### "Mainnet is not supported"

This CLI intentionally blocks Ethereum mainnet. Use Base for production deployments.

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Technical Specification](./protocol/Technical_Specification.md) | Contract mechanics |
| [Integration Guide](./issuer/Integration_Guide.md) | Issuer integration |
| [SDK README](./sdk/README.md) | TypeScript SDK |
| [GLOSSARY](./GLOSSARY.md) | Terminology |

---

## Navigation

[Documentation Home](./README.md)
