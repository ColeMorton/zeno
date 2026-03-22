# Sablier Streaming Integration

Convert discrete monthly VaultNFT withdrawals into continuous Sablier streams.

## Overview

The SablierStreamWrapper converts the protocol's monthly 1% withdrawals into 30-day linear Sablier streams, providing recipients with continuous access to their collateral rather than discrete monthly lump sums.

```
VaultNFT (1% monthly)
        │
        ▼ withdrawAsDelegate()
SablierStreamWrapper
        │
        ▼ createWithDurations()
SablierV2LockupLinear
        │
        ▼ 30-day linear stream
Recipient (withdrawMax() anytime)
```

## Sablier vs Superfluid

| Aspect | Sablier | Superfluid | BTCNFT Fit |
|--------|---------|------------|------------|
| Stream Model | Finite (closed-ended) | Infinite (open-ended) | **Sablier** - 30-day chunks |
| Token Wrapping | None required | Requires wrapper tokens | **Sablier** - direct ERC-20 |
| Deposit Model | Upfront deposit | Continuous balance | **Sablier** - discrete unlocks |
| Liquidation Risk | None | Sender insolvency | **Sablier** - no complexity |
| NFT Representation | Streams are ERC-721 | None | **Sablier** - tradeable |

**Decision:** Sablier's LockupLinear matches the protocol's monthly withdrawal model. Each 30-day withdrawal becomes a 30-day linear stream.

## Contracts

### SablierStreamWrapper

**Location:** `contracts/issuer/src/SablierStreamWrapper.sol`

**Key Functions:**

```solidity
// Owner configures vault for streaming
function configureVault(
    uint256 vaultTokenId,
    address recipient,
    bool enabled
) external;

// Gelato calls to create stream
function createStreamFromVault(uint256 vaultTokenId)
    external
    returns (uint256 streamId);

// Batch create multiple streams
function batchCreateStreams(uint256[] calldata vaultTokenIds)
    external
    returns (uint256[] memory streamIds);

// Query eligibility
function canCreateStream(uint256 vaultTokenId)
    external
    view
    returns (bool canCreate, uint256 amount);
```

### Stream Configuration

Streams are created with these parameters:

```solidity
LockupLinear.CreateWithDurations({
    sender: wrapper,           // SablierStreamWrapper
    recipient: configured,     // Set via configureVault()
    totalAmount: withdrawal,   // From VaultNFT
    asset: collateralToken,    // WBTC/cbBTC
    cancelable: false,         // Non-cancellable
    transferable: true,        // NFT tradeable
    durations: Durations({
        cliff: 0,              // No cliff
        total: 30 days         // Linear unlock
    }),
    broker: Broker(0, 0)       // No fee
})
```

## Setup Guide

### 1. Deploy SablierStreamWrapper

```solidity
SablierStreamWrapper wrapper = new SablierStreamWrapper(
    vaultNFTAddress,
    sablierLockupLinearAddress
);
```

### 2. Grant Delegation

Vault owner grants 100% withdrawal delegation to wrapper:

```solidity
vaultNFT.grantWithdrawalDelegate(address(wrapper), 10000); // 100%
```

### 3. Configure Vault

Owner specifies stream recipient:

```solidity
wrapper.configureVault(vaultTokenId, recipientAddress, true);
```

### 4. Setup Gelato Automation

Create Gelato task with `streamingWithdrawalChecker.ts`:

```json
{
  "tokenId": "0",
  "streamWrapperAddress": "0x...",
  "smartAccountAddress": "0x..."
}
```

**Cron:** `0 12 1 * *` (Monthly, 1st day, 12:00 UTC)

## Sablier v2 Deployment Addresses

| Chain | SablierV2LockupLinear |
|-------|----------------------|
| Ethereum | `0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9` |
| Base | `0xFCF737582d167c7D20A336532eb8BCcA8CF8e350` |
| Arbitrum | `0xFDD9d122B451F549f48c4942c6fa6646D849e8C1` |
| Optimism | `0x4b45090152a5731b5bc71b5baF71E60e05B33867` |

## User Experience

### Recipient Flow

1. **Monthly automation:** Gelato triggers `createStreamFromVault()`
2. **Stream created:** Recipient receives Sablier stream NFT
3. **Continuous access:** Call `withdrawMax()` anytime to claim accrued amount
4. **Full unlock:** After 30 days, entire monthly amount is claimable

### Stream NFT Trading

Stream NFTs are transferable on OpenSea, Blur, etc. This enables:
- Selling time-locked BTC claims at market-determined discount
- Exit liquidity before stream completion
- Secondary market price discovery

## Gas Costs (L2)

| Operation | Base/Arbitrum |
|-----------|---------------|
| `configureVault()` | ~$0.04 |
| `createStreamFromVault()` | ~$0.15 |
| `batchCreateStreams(5)` | ~$0.70 |
| `withdrawMax()` | ~$0.05 |

## Security

| Vector | Mitigation |
|--------|------------|
| Wrapper draining vault | Only withdraws when `canDelegateWithdraw()` true |
| Malicious recipient | Only vault owner sets via `configureVault()` |
| Stream cancellation | Non-cancellable streams |
| Reentrancy | ReentrancyGuard; Sablier audited |

## Files

- `contracts/issuer/src/SablierStreamWrapper.sol` - Core wrapper
- `contracts/issuer/src/interfaces/ISablierStreamWrapper.sol` - Interface
- `contracts/issuer/src/interfaces/ISablierV2LockupLinear.sol` - Sablier interface
- `automation/gelato/streamingWithdrawalChecker.ts` - Gelato function
- `automation/gelato/streaming.schema.json` - Gelato schema
