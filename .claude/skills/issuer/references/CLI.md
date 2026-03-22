# Issuer CLI Reference

> **Version:** 1.0.0
> **Status:** Final
> **Last Updated:** 2026-03-22
> **Entry Point:** `./cli-issuer/btcnft-issuer`

---

## Overview

The Issuer CLI (`btcnft-issuer`) provides shell-based access to all issuer-layer smart contract operations: minting, auctions, perpetuals, volatility pools, achievements, chapters, profiles, dashboards, streaming, and treasure NFTs.

```
./btcnft-issuer [--network <network>] <command> [args...]
```

**Global Options:**

| Flag | Description |
|------|-------------|
| `--network <network>` | Target network: `local`, `sepolia`, `holesky`, `base` (default: `local`) |
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show version |

The CLI extends the protocol CLI infrastructure (`cli/lib/common.sh`, `cli/lib/network.sh`) with issuer-specific helpers in `cli-issuer/lib/issuer-common.sh`.

---

## Configuration

Copy `.env.example` to `.env` (local), `.env.sepolia`, `.env.holesky`, or `.env.base`.

### Protocol Contracts (shared with protocol CLI)

| Variable | Description |
|----------|-------------|
| `PRIVATE_KEY` | Signing key (never commit) |
| `RPC_URL` | Optional — defaults to network setting |
| `WBTC` | Wrapped Bitcoin token |
| `CBBTC` | Coinbase Wrapped Bitcoin token |
| `BTC_TOKEN` | vestedBTC (vBTC) ERC-20 |
| `VAULT` | VaultNFT contract |
| `TREASURE` | Treasure NFT contract |

### Issuer Contracts

| Variable | Used By |
|----------|---------|
| `AUCTION_CONTROLLER` | auction-* commands |
| `VAULT_MINT_CONTROLLER` | mint-vault |
| `HYBRID_MINT_CONTROLLER` | mint-hybrid |
| `PERP_VAULT` | perp-* commands |
| `VOL_POOL` | vol-* commands |
| `ACHIEVEMENT_NFT` | achieve-status query |
| `ACHIEVEMENT_MINTER` | achieve-* commands |
| `CHAPTER_REGISTRY` | chapter-create, chapter-add-achievement, chapter-set-active, chapter-info |
| `CHAPTER_MINTER` | chapter-claim, chapter-claimable |
| `PROFILE_REGISTRY` | profile-create, profile-status |
| `DASHBOARD_NFT` | dashboard-features query |
| `DASHBOARD_REGISTRY` | dashboard-mint |
| `SABLIER_WRAPPER` | stream-* commands |
| `TREASURE_NFT` | treasure-* commands |

---

## Helper Functions

### `resolve_achievement_type(name) -> bytes32`

Converts achievement name to on-chain bytes32 constant via `ACHIEVEMENT_MINTER.<NAME>()(bytes32)`.

| Valid Types |
|-------------|
| `MINTER`, `MATURED`, `HODLER_SUPREME`, `FIRST_MONTH`, `QUARTER_STACK`, `HALF_YEAR`, `ANNUAL`, `DIAMOND_HANDS` |

### `resolve_feature_type(name) -> bytes32`

Converts feature name to on-chain bytes32 constant via `DASHBOARD_NFT.<NAME>()(bytes32)`.

| Valid Types |
|-------------|
| `THEME_DARK`, `THEME_NEON`, `FRAME_ANIMATED`, `AVATAR_CUSTOM`, `ANALYTICS_PRO`, `EXPORT_CSV`, `ALERTS_ADVANCED`, `PORTFOLIO_MULTI`, `FOUNDERS_BUNDLE` |

### `parse_side_arg(side) -> uint8`

| Input | Output |
|-------|--------|
| `long` / `LONG` | `0` |
| `short` / `SHORT` | `1` |

### Inherited Functions (from `cli/lib/common.sh`)

`load_env`, `require_contract_set`, `require_balance`, `approve_erc20`, `cast_send`, `cast_call`, `format_btc`, `format_timestamp`, `get_caller_address`, `get_network_name`, `confirm_non_local_action`, `print_success`, `parse_token_id_from_log`, `resolve_token_address`

**Token aliases:** `wbtc` -> WBTC, `vbtc` -> BTC_TOKEN, `cbbtc` -> CBBTC (or raw `0x` address)

---

## Commands (28 Write Operations)

### Mint Controllers

#### `mint-vault`
Mint a standard vault via the issuer's mint controller.
```
mint-vault <collateral_amount>
```
| Arg | Description |
|-----|-------------|
| `collateral_amount` | WBTC amount in satoshis (100000000 = 1 BTC) |

**Contract:** `VAULT_MINT_CONTROLLER.mintVault(bytes32, uint256)`
**Token:** WBTC (approval required)

#### `mint-hybrid`
Mint a hybrid vault via the issuer's hybrid mint controller.
```
mint-hybrid <cbbtc_amount>
```
| Arg | Description |
|-----|-------------|
| `cbbtc_amount` | cbBTC amount in satoshis |

**Contract:** `HYBRID_MINT_CONTROLLER.mintHybridVault(uint256)`
**Token:** CBBTC (approval required)

---

### Auctions

#### `auction-create-dutch`
Create a Dutch (declining price) auction.
```
auction-create-dutch <max_supply> <collateral_token_alias> <start_price> <end_price> <duration_seconds>
```
| Arg | Description |
|-----|-------------|
| `max_supply` | Maximum number of vaults |
| `collateral_token_alias` | Token alias (wbtc, vbtc, cbbtc) |
| `start_price` | Starting price in satoshis |
| `end_price` | Ending price in satoshis |
| `duration_seconds` | Auction duration in seconds |

**Contract:** `AUCTION_CONTROLLER.createDutchAuction(uint256, address, (uint256, uint256, uint256))`

#### `auction-create-english`
Create an English (ascending bid) auction.
```
auction-create-english <max_supply> <collateral_token_alias> <min_bid> <bid_increment> <slot_duration>
```
| Arg | Description |
|-----|-------------|
| `max_supply` | Maximum number of vaults |
| `collateral_token_alias` | Token alias (wbtc, vbtc, cbbtc) |
| `min_bid` | Minimum bid in satoshis |
| `bid_increment` | Minimum bid increment in satoshis |
| `slot_duration` | Duration per slot in seconds |

**Contract:** `AUCTION_CONTROLLER.createEnglishAuction(uint256, address, (uint256, uint256, uint256))`

#### `auction-purchase`
Purchase from a Dutch auction at the current price.
```
auction-purchase <auction_id>
```
Fetches the current price via `getCurrentPrice()`, then requires balance and approval for the auction's collateral token before calling `purchaseDutch(uint256)`.

#### `auction-bid`
Place a bid on an English auction slot.
```
auction-bid <auction_id> <slot> <amount>
```
| Arg | Description |
|-----|-------------|
| `auction_id` | ID of the English auction |
| `slot` | Slot number to bid on |
| `amount` | Bid amount in satoshis |

**Contract:** `AUCTION_CONTROLLER.placeBid(uint256, uint256, uint256)`

#### `auction-settle`
Settle a completed English auction slot.
```
auction-settle <auction_id> <slot>
```
**Contract:** `AUCTION_CONTROLLER.settleSlot(uint256, uint256)`

---

### Perpetuals

#### `perp-open`
Open a leveraged perpetual position.
```
perp-open <collateral_amount> <leverage_x100> <long|short>
```
| Arg | Description |
|-----|-------------|
| `collateral_amount` | vBTC collateral in satoshis |
| `leverage_x100` | Leverage multiplied by 100 (e.g. 200 = 2x) |
| `long\|short` | Position side |

**Contract:** `PERP_VAULT.openPosition(uint256, uint256, uint8)`
**Token:** BTC_TOKEN / vBTC (approval required)

#### `perp-close`
Close a perpetual position. Shows estimated payout via `previewClose()` before executing.
```
perp-close <position_id>
```
**Contract:** `PERP_VAULT.closePosition(uint256)`

#### `perp-add-collateral`
Add collateral to an existing perpetual position.
```
perp-add-collateral <position_id> <amount>
```
| Arg | Description |
|-----|-------------|
| `position_id` | ID of the position |
| `amount` | vBTC amount in satoshis to add |

**Contract:** `PERP_VAULT.addCollateral(uint256, uint256)`
**Token:** BTC_TOKEN / vBTC (approval required)

---

### Volatility Pool

#### `vol-deposit`
Deposit vBTC to the long or short side of the volatility pool.
```
vol-deposit <long|short> <amount>
```
**Contract:** `VOL_POOL.depositLong(uint256)` or `VOL_POOL.depositShort(uint256)`
**Token:** BTC_TOKEN / vBTC (approval required)

#### `vol-withdraw`
Withdraw from the long or short side of the volatility pool.
```
vol-withdraw <long|short> <shares>
```
| Arg | Description |
|-----|-------------|
| `long\|short` | Pool side to withdraw from |
| `shares` | Number of shares to redeem |

**Contract:** `VOL_POOL.withdrawLong(uint256)` or `VOL_POOL.withdrawShort(uint256)`

#### `vol-settle`
Trigger variance settlement. Checks `isSettlementDue()` first; fails if settlement is not yet due.
```
vol-settle
```
**Contract:** `VOL_POOL.settle()`

---

### Achievements

#### `achieve-minter`
Claim the minter achievement for a vault.
```
achieve-minter <vault_id> <collateral_token_alias>
```
**Contract:** `ACHIEVEMENT_MINTER.claimMinterAchievement(uint256, address)`

#### `achieve-matured`
Claim the matured achievement for a vault.
```
achieve-matured <vault_id> <collateral_token_alias>
```
**Contract:** `ACHIEVEMENT_MINTER.claimMaturedAchievement(uint256, address)`

#### `achieve-duration`
Claim a duration-based achievement for a vault.
```
achieve-duration <vault_id> <collateral_token_alias> <achievement_type>
```
| Arg | Description |
|-----|-------------|
| `achievement_type` | One of: `FIRST_MONTH`, `QUARTER_STACK`, `HALF_YEAR`, `ANNUAL`, `DIAMOND_HANDS` |

**Contract:** `ACHIEVEMENT_MINTER.claimDurationAchievement(uint256, address, bytes32)`

#### `achieve-hodler-supreme`
Mint a Hodler Supreme vault (achievement + vault in one transaction).
```
achieve-hodler-supreme <collateral_token_alias> <collateral_amount>
```
**Contract:** `ACHIEVEMENT_MINTER.mintHodlerSupremeVault(address, uint256)`
**Token:** Any of WBTC/vBTC/cbBTC (approval required)

---

### Chapters

#### `chapter-claim`
Claim a chapter achievement.
```
chapter-claim <chapter_id> <achievement_id> <vault_id> <collateral_token_alias>
```
**Contract:** `CHAPTER_MINTER.claimChapterAchievement(bytes32, bytes32, uint256, address, bytes)`

#### `chapter-create` (admin)
Create a new chapter.
```
chapter-create <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>
```
| Arg | Type | Description |
|-----|------|-------------|
| `chapter_number` | uint8 | Chapter sequence number |
| `year` | uint16 | Calendar year |
| `quarter` | uint8 | Quarter (1-4) |
| `start_timestamp` | uint48 | Mint window start (unix) |
| `end_timestamp` | uint48 | Mint window end (unix) |
| `min_days` | uint256 | Minimum vault age in days |
| `max_days` | uint256 | Maximum vault age in days |
| `base_uri` | string | Metadata base URI |

**Contract:** `CHAPTER_REGISTRY.createChapter(uint8, uint16, uint8, uint48, uint48, uint256, uint256, string)`

#### `chapter-add-achievement` (admin)
Add an achievement definition to a chapter.
```
chapter-add-achievement <chapter_id> <name> [prerequisites_comma_separated]
```
Prerequisites are optional; if provided, encoded as a bytes32 array.

**Contract:** `CHAPTER_REGISTRY.addAchievement(bytes32, string, bytes32[])`

#### `chapter-set-active` (admin)
Toggle a chapter's active state.
```
chapter-set-active <chapter_id> <true|false>
```
**Contract:** `CHAPTER_REGISTRY.setChapterActive(bytes32, bool)`

---

### Profile & Dashboard

#### `profile-create`
Create an on-chain profile for the caller.
```
profile-create
```
**Contract:** `PROFILE_REGISTRY.createProfile()`

#### `dashboard-mint`
Purchase a dashboard feature (payable with ETH).
```
dashboard-mint <feature_type> <value_wei>
```
| Arg | Description |
|-----|-------------|
| `feature_type` | One of the feature type constants (see Helper Functions) |
| `value_wei` | ETH payment amount in wei |

**Contract:** `DASHBOARD_REGISTRY.purchaseFeature(bytes32)` (sent with `--value`)

---

### Streaming

#### `stream-configure`
Configure a vault for Sablier streaming.
```
stream-configure <vault_id> <recipient_address> <true|false>
```
| Arg | Description |
|-----|-------------|
| `vault_id` | Vault to configure |
| `recipient_address` | Stream recipient |
| `true\|false` | Whether the stream is cancelable |

**Contract:** `SABLIER_WRAPPER.configureVault(uint256, address, bool)`

#### `stream-create`
Create a stream from a configured vault.
```
stream-create <vault_id>
```
**Contract:** `SABLIER_WRAPPER.createStreamFromVault(uint256)`

#### `stream-batch`
Batch create streams from multiple vaults.
```
stream-batch <vault_ids_comma_separated>
```
Example: `stream-batch 1,2,3,4`

**Contract:** `SABLIER_WRAPPER.batchCreateStreams(uint256[])`

---

### Treasure NFT

#### `treasure-mint`
Mint treasure NFT(s) to a recipient.
```
treasure-mint <recipient_address> [count]
```
Count defaults to 1. Uses `mint(address)` for single, `mintBatch(address, uint256)` for multiple.

**Contract:** `TREASURE_NFT`

#### `treasure-authorize` (admin)
Authorize or revoke a minter on the Treasure NFT contract.
```
treasure-authorize <grant|revoke> <minter_address>
```
**Contract:** `TREASURE_NFT.authorizeMinter(address)` or `TREASURE_NFT.revokeMinter(address)`

---

## Queries (13 Read Operations)

### `auction-status`
Query auction details including state, current price (Dutch), or config (English).
```
auction-status <auction_id>
```
**Calls:** `getAuction()`, `getAuctionState()`, `getCurrentPrice()`, `getDutchConfig()`, `getEnglishConfig()`

### `perp-position`
Show perpetual position details and close PnL preview.
```
perp-position <position_id>
```
**Calls:** `getPosition()`, `getPositionOwner()`, `previewClose()`

### `perp-market`
Show current BTC price and funding rate.
```
perp-market
```
**Calls:** `getCurrentPrice()`, `getCurrentFundingRate()`

### `vol-pool-status`
Show volatility pool assets, shares, variance, and settlement status.
```
vol-pool-status
```
**Calls:** `longPoolAssets()`, `shortPoolAssets()`, `longPoolShares()`, `shortPoolShares()`, `getCurrentVariance()`, `isSettlementDue()`, `nextSettlementTime()`

### `vol-position`
Show a user's volatility pool shares and preview values.
```
vol-position [address]
```
Defaults to caller address if omitted.

**Calls:** `longSharesOf()`, `shortSharesOf()`, `previewWithdrawLong()`, `previewWithdrawShort()`

### `achieve-check`
Check achievement eligibility for a vault.
```
achieve-check <minter|matured|duration> <vault_id> <collateral_token_alias> [achievement_name]
```
`achievement_name` is required for `duration` type.

**Calls:** `canClaimMinterAchievement()`, `canClaimMaturedAchievement()`, `canClaimDurationAchievement()`

### `achieve-status`
Show whether a wallet holds an achievement and its count.
```
achieve-status <wallet_address> <achievement_type>
```
**Calls:** `hasAchievement()`, `achievementCount()`

### `chapter-claimable`
Show claimable achievements for a chapter given a vault.
```
chapter-claimable <chapter_id> <vault_id> <collateral_token_alias>
```
**Calls:** `getClaimableAchievements()`

### `chapter-info`
Show chapter details, mint window status, and achievements.
```
chapter-info <chapter_id>
```
**Calls:** `getChapter()`, `isWithinMintWindow()`, `getChapterAchievements()`

### `profile-status`
Show profile registration status and days registered.
```
profile-status [address]
```
Defaults to caller address if omitted.

**Calls:** `hasProfile()`, `registeredAt()`, `getDaysRegistered()`

### `dashboard-features`
Show dashboard feature ownership, price, and active status.
```
dashboard-features <wallet_address> <feature_type>
```
**Calls:** `hasFeature()`, `mintPrice()`, `featureActive()`

### `stream-status`
Show stream configuration and existing streams for a vault.
```
stream-status <vault_id>
```
**Calls:** `canCreateStream()`, `getVaultConfig()`, `getVaultStreams()`

### `treasure-status`
Show treasure NFT tier, associated vault, and total supply.
```
treasure-status <token_id>
```
**Calls:** `getTier()`, `treasureVault()`, `totalSupply()`

---

## Command Patterns

### Write Flow

```
source issuer-common.sh → load_env → require_contract_set → parse args
→ confirm_non_local_action → require_balance → approve_erc20 → cast_send → print_success
```

### Read Flow

```
source issuer-common.sh → load_env → require_contract_set → cast_call → formatted output
```

### Examples

```bash
./btcnft-issuer mint-vault 100000000                         # Mint vault with 1 WBTC
./btcnft-issuer --network sepolia perp-open 50000000 200 long  # Open 2x long perp on Sepolia
./btcnft-issuer vol-deposit long 100000000                   # Deposit 1 vBTC to long pool
./btcnft-issuer achieve-duration 1 wbtc DIAMOND_HANDS        # Claim Diamond Hands achievement
./btcnft-issuer auction-purchase 1                           # Purchase from Dutch auction
./btcnft-issuer stream-batch 1,2,3,4                         # Batch create streams
./btcnft-issuer treasure-mint 0xABC... 5                     # Mint 5 treasure NFTs
```
