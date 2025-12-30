# Cross-Chain vWBTC Bridge (LayerZero OFT)

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Curve Liquidity Pool](./Curve_Liquidity_Pool.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [L2 Deployment Viability](../research/L2_Deployment_Viability.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Contract Specification](#3-contract-specification)
4. [Cross-Chain Flow](#4-cross-chain-flow)
5. [Security Analysis](#5-security-analysis)
6. [Deployment Configuration](#6-deployment-configuration)
7. [Integration Guide](#7-integration-guide)

---

## 1. Overview

### Problem

vWBTC (vestedBTC backed by wBTC) exists on both Ethereum and Arbitrum but is isolated per chain. Users cannot move vWBTC between chains, resulting in:

- **Fragmented Liquidity:** Curve pools on each chain have separate liquidity depth
- **Limited DeFi Composability:** Arbitrum-minted vWBTC cannot access Ethereum-native protocols
- **User Friction:** Holders must choose deployment chain at mint time

**Note:** vCBBTC is Base-only (native cbBTC) and does not benefit from cross-chain bridging.

### Solution

LayerZero v2 OFTAdapter wrapper enabling permissionless vWBTC transfers between Ethereum and Arbitrum.

### Integration Layer

| Aspect | Value |
|--------|-------|
| Layer | Issuer layer (optional infrastructure) |
| Protocol Changes | None required |
| Pattern | OFTAdapter (lock/unlock) |
| Chains | Ethereum ↔ Arbitrum |

### Lindy Score

| Component | Age | Score |
|-----------|-----|-------|
| LayerZero Protocol | 3+ years | MEDIUM-HIGH |
| OFT/OFTAdapter Standard | 2+ years | MEDIUM |
| Wrapper Pattern | 8+ years | HIGH |
| DVN Security Model | 1+ year | MEDIUM |

**Overall:** MEDIUM — Production-tested infrastructure with configurable security.

---

## 2. Architecture

### 2.1 Design Pattern: OFTAdapter

The standard OFT pattern uses burn/mint: burn tokens on source, mint on destination. However, `BtcToken.sol` restricts mint/burn to VaultNFT only:

```solidity
// BtcToken.sol:12-15
modifier onlyVault() {
    if (msg.sender != vault) revert OnlyVault();
    _;
}
```

**Solution:** Use `OFTAdapter` which implements lock/unlock:

| Pattern | Source Chain | Destination Chain | Use Case |
|---------|--------------|-------------------|----------|
| OFT (burn/mint) | Burn tokens | Mint tokens | Token has public mint/burn |
| **OFTAdapter (lock/unlock)** | Lock in adapter | Release from adapter | **Token has restricted mint** |

### 2.2 Cross-Chain Flow Diagram

```
Ethereum (L1)                              Arbitrum (L2)
┌─────────────────┐                        ┌─────────────────┐
│   User Wallet   │                        │   User Wallet   │
│    (vWBTC)      │                        │    (vWBTC)      │
└────────┬────────┘                        └────────▲────────┘
         │                                          │
         │ 1. approve(adapter, amount)              │ 6. receive vWBTC
         │ 2. wrap(amount)                          │
         ▼                                          │
┌─────────────────┐                        ┌─────────────────┐
│  VestedBTCOFT   │                        │  VestedBTCOFT   │
│    Adapter      │                        │    Adapter      │
│                 │    LayerZero v2        │                 │
│ 3. lock vWBTC   │ ─────────────────────► │ 5. release vWBTC│
│ 4. send()       │       Message          │                 │
│                 │                        │                 │
│ [holds vWBTC]   │                        │ [holds vWBTC]   │
└─────────────────┘                        └─────────────────┘

Supply Invariant:
  Total OFT in flight + vWBTC locked (ETH) + vWBTC locked (ARB) = constant
```

### 2.3 Component Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                         PROTOCOL LAYER                          │
│                        (Immutable Core)                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  VaultNFT   │───►│  BtcToken   │◄───│  VaultMath  │         │
│  │  (ERC-998)  │    │   (vWBTC)   │    │  (Library)  │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                            ▲                                    │
│                            │ ERC-20 standard interface          │
└────────────────────────────┼────────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────────┐
│                         ISSUER LAYER                            │
│                     (Optional Extensions)                       │
│                            │                                    │
│  ┌─────────────────────────┴─────────────────────────┐         │
│  │              VestedBTCOFT (OFTAdapter)             │         │
│  │  - wrap(): lock vWBTC in adapter                  │         │
│  │  - unwrap(): release vWBTC from adapter           │         │
│  │  - send(): cross-chain transfer via LayerZero     │         │
│  │  - lzReceive(): receive cross-chain transfer      │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Contract Specification

### 3.1 Interface: IVestedBTCOFT

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/// @title IVestedBTCOFT - Cross-chain vestedBTC bridge interface
/// @notice LayerZero v2 OFTAdapter for permissionless vWBTC bridging
interface IVestedBTCOFT is IOFT {
    // ==================== Events ====================

    /// @notice Emitted when user wraps vWBTC
    /// @param user Address of the user
    /// @param amount Amount of vWBTC wrapped
    event Wrapped(address indexed user, uint256 amount);

    /// @notice Emitted when user unwraps vWBTC
    /// @param user Address of the user
    /// @param amount Amount of vWBTC unwrapped
    event Unwrapped(address indexed user, uint256 amount);

    // ==================== Errors ====================

    /// @notice Thrown when requested amount exceeds available balance
    /// @param required Amount requested
    /// @param available Amount available
    error InsufficientBalance(uint256 required, uint256 available);

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    // ==================== Functions ====================

    /// @notice Wrap vWBTC to prepare for cross-chain transfer
    /// @dev User must approve adapter before calling
    /// @param amount Amount of vWBTC to wrap
    /// @return Amount wrapped (1:1)
    function wrap(uint256 amount) external returns (uint256);

    /// @notice Unwrap to receive vWBTC after cross-chain transfer
    /// @dev Only callable if adapter has sufficient locked vWBTC
    /// @param amount Amount to unwrap
    /// @return Amount unwrapped (1:1)
    function unwrap(uint256 amount) external returns (uint256);

    /// @notice Get the underlying vWBTC token address
    /// @return Address of the BtcToken contract
    function vestedBTC() external view returns (address);

    /// @notice Get total vWBTC locked in this adapter
    /// @return Total locked amount
    function totalLocked() external view returns (uint256);
}
```

### 3.2 Contract: VestedBTCOFT

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVestedBTCOFT} from "./interfaces/IVestedBTCOFT.sol";

/// @title VestedBTCOFT - Cross-chain vWBTC bridge using LayerZero v2
/// @notice OFTAdapter wrapper enabling permissionless cross-L2 vWBTC transfers
/// @dev Implements lock/unlock pattern since BtcToken mint is VaultNFT-restricted
contract VestedBTCOFT is OFTAdapter, IVestedBTCOFT {
    using SafeERC20 for IERC20;

    // ==================== Immutables ====================

    /// @notice Reference to underlying vWBTC token
    IERC20 public immutable vestedBTCToken;

    // ==================== Constructor ====================

    /// @param _vestedBTC Address of the vWBTC token (BtcToken)
    /// @param _lzEndpoint LayerZero v2 EndpointV2 address
    /// @param _owner Owner address for OApp configuration
    constructor(
        address _vestedBTC,
        address _lzEndpoint,
        address _owner
    ) OFTAdapter(_vestedBTC, _lzEndpoint, _owner) Ownable(_owner) {
        vestedBTCToken = IERC20(_vestedBTC);
    }

    // ==================== External Functions ====================

    /// @inheritdoc IVestedBTCOFT
    function wrap(uint256 amount) external returns (uint256) {
        if (amount == 0) revert ZeroAmount();

        uint256 balance = vestedBTCToken.balanceOf(msg.sender);
        if (balance < amount) revert InsufficientBalance(amount, balance);

        // Lock vWBTC in adapter
        vestedBTCToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Wrapped(msg.sender, amount);
        return amount;
    }

    /// @inheritdoc IVestedBTCOFT
    function unwrap(uint256 amount) external returns (uint256) {
        if (amount == 0) revert ZeroAmount();

        uint256 locked = vestedBTCToken.balanceOf(address(this));
        if (locked < amount) revert InsufficientBalance(amount, locked);

        // Release vWBTC from adapter
        vestedBTCToken.safeTransfer(msg.sender, amount);

        emit Unwrapped(msg.sender, amount);
        return amount;
    }

    /// @inheritdoc IVestedBTCOFT
    function vestedBTC() external view returns (address) {
        return address(vestedBTCToken);
    }

    /// @inheritdoc IVestedBTCOFT
    function totalLocked() external view returns (uint256) {
        return vestedBTCToken.balanceOf(address(this));
    }

    // ==================== Overrides ====================

    /// @notice Token decimals (8 for Bitcoin alignment)
    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
```

### 3.3 Inheritance Hierarchy

```
                    ┌─────────────────┐
                    │     Ownable     │
                    │  (OpenZeppelin) │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │     OAppCore    │
                    │   (LayerZero)   │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
     ┌────────┴────────┐           ┌────────┴────────┐
     │    OAppSender   │           │   OAppReceiver  │
     │   (LayerZero)   │           │   (LayerZero)   │
     └────────┬────────┘           └────────┬────────┘
              │                             │
              └──────────────┬──────────────┘
                             │
                    ┌────────┴────────┐
                    │       OFT       │
                    │   (LayerZero)   │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │   OFTAdapter    │
                    │   (LayerZero)   │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │  VestedBTCOFT   │
                    │    (Custom)     │
                    └─────────────────┘
```

---

## 4. Cross-Chain Flow

### 4.1 User Flow: Ethereum → Arbitrum

| Step | Action | Contract | Gas Cost |
|------|--------|----------|----------|
| 1 | `vWBTC.approve(adapter, amount)` | BtcToken | ~46k |
| 2 | `adapter.wrap(amount)` | VestedBTCOFT | ~65k |
| 3 | `adapter.send(dstEid, to, amount, ...)` | VestedBTCOFT | ~150k + LZ fee |
| 4 | *LayerZero message delivery* | — | — |
| 5 | `adapter.lzReceive(...)` | VestedBTCOFT (Arb) | ~100k |
| 6 | `adapter.unwrap(amount)` | VestedBTCOFT (Arb) | ~55k |

### 4.2 send() Parameters

```solidity
struct SendParam {
    uint32 dstEid;           // Destination endpoint ID (30110 for Arbitrum)
    bytes32 to;              // Recipient address (bytes32 encoded)
    uint256 amountLD;        // Amount in local decimals (8 for vWBTC)
    uint256 minAmountLD;     // Minimum amount after fees
    bytes extraOptions;      // Additional LayerZero options
    bytes composeMsg;        // Compose message (empty for simple transfer)
    bytes oftCmd;            // OFT command (empty for standard)
}

// Example call
adapter.send(
    SendParam({
        dstEid: 30110,                                    // Arbitrum
        to: bytes32(uint256(uint160(recipientAddress))),  // Recipient
        amountLD: 1e8,                                    // 1 vWBTC
        minAmountLD: 1e8,                                 // No slippage
        extraOptions: "",                                  // Default options
        composeMsg: "",                                   // No compose
        oftCmd: ""                                        // Standard send
    }),
    MessagingFee({
        nativeFee: msg.value,                             // ETH for gas
        lzTokenFee: 0                                     // No LZ token
    }),
    msg.sender                                            // Refund address
);
```

### 4.3 Fee Estimation

```solidity
// Get quote before sending
(MessagingFee memory fee, ) = adapter.quoteSend(sendParam, false);
uint256 requiredNative = fee.nativeFee;

// Send with exact fee
adapter.send{value: requiredNative}(sendParam, fee, msg.sender);
```

---

## 5. Security Analysis

### 5.1 Risk Matrix

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| LayerZero Security | CRITICAL | LOW | DVN multi-sig, configurable security |
| Single Adapter Constraint | HIGH | MEDIUM | Documentation, deployment process |
| Insufficient Liquidity | MEDIUM | MEDIUM | Pre-seed adapters on both chains |
| Message Failure | LOW | LOW | Automatic retry, manual recovery |
| Smart Contract Bug | HIGH | LOW | Minimal custom code, battle-tested base |

### 5.2 Single Adapter Constraint

**CRITICAL INVARIANT:** Only ONE VestedBTCOFT adapter can exist per chain for each vWBTC token. Multiple adapters break the supply invariant:

```
Scenario: Two adapters exist on Ethereum

Adapter A: locks 100 vWBTC, sends to Arbitrum
Adapter B: locks 50 vWBTC, sends to Arbitrum

Arbitrum Adapter: receives 150 OFT messages
  - Can only release from its own locked balance
  - If Adapter A locked 100, Adapter B locked 50
  - But destination only has ONE adapter

Result: 50 vWBTC permanently unrecoverable
```

**Enforcement:**
- Deployment process must verify no existing adapter
- Documentation must emphasize single-adapter requirement
- No on-chain enforcement (would require registry contract)

### 5.3 DVN Security Configuration

LayerZero v2 uses Decentralized Verifier Networks (DVNs) for message verification:

| Configuration | Security | Cost | Recommendation |
|---------------|----------|------|----------------|
| 1 DVN (LayerZero) | Basic | Low | Development only |
| 2 DVNs (LZ + Google) | Standard | Medium | **Production default** |
| 3+ DVNs | High | High | High-value deployments |

```solidity
// Example DVN configuration (set by owner)
SetConfigParam memory param = SetConfigParam({
    eid: 30110,  // Arbitrum
    configType: 2,  // ULN_CONFIG_TYPE
    config: abi.encode(UlnConfig({
        confirmations: 15,
        requiredDVNCount: 2,
        optionalDVNCount: 0,
        optionalDVNThreshold: 0,
        requiredDVNs: [
            0x...,  // LayerZero DVN
            0x...   // Google Cloud DVN
        ],
        optionalDVNs: []
    }))
});
endpoint.setConfig(address(adapter), address(sendLib), [param]);
```

### 5.4 Attack Vectors

| Vector | Feasibility | Impact | Status |
|--------|-------------|--------|--------|
| Adapter Draining | Infeasible | N/A | Only unlocks for valid LZ messages |
| Message Spoofing | Infeasible | N/A | DVN verification prevents |
| Replay Attack | Infeasible | N/A | Nonce tracking by LZ |
| Front-running | Low | Low | Race condition on unwrap() only |
| Griefing | Low | Low | Requires ETH for failed messages |

---

## 6. Deployment Configuration

### 6.1 LayerZero Endpoint Addresses

| Chain | Endpoint ID | EndpointV2 Address |
|-------|-------------|-------------------|
| Ethereum | 30101 | `0x1a44076050125825900e736c501f859c50fE728c` |
| Arbitrum | 30110 | `0x1a44076050125825900e736c501f859c50fE728c` |

### 6.2 Deployment Script

```solidity
// DeployVestedBTCOFT.s.sol
contract DeployVestedBTCOFT is Script {
    function run() external {
        address vestedBTC = vm.envAddress("VESTED_BTC");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        VestedBTCOFT adapter = new VestedBTCOFT(
            vestedBTC,
            lzEndpoint,
            owner
        );

        vm.stopBroadcast();

        console.log("VestedBTCOFT:", address(adapter));
    }
}
```

### 6.3 Environment Variables

```bash
# Ethereum deployment
VESTED_BTC=0x...        # BtcToken address on Ethereum
LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
OWNER=0x...             # Multisig for OApp configuration
PRIVATE_KEY=0x...       # Deployer key

# Arbitrum deployment
VESTED_BTC=0x...        # BtcToken address on Arbitrum
LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
OWNER=0x...             # Same multisig recommended
PRIVATE_KEY=0x...       # Deployer key
```

### 6.4 Post-Deployment: Peer Configuration

After deploying on both chains, configure peers:

```solidity
// On Ethereum adapter, set Arbitrum peer
ethereumAdapter.setPeer(
    30110,  // Arbitrum endpoint ID
    bytes32(uint256(uint160(arbitrumAdapterAddress)))
);

// On Arbitrum adapter, set Ethereum peer
arbitrumAdapter.setPeer(
    30101,  // Ethereum endpoint ID
    bytes32(uint256(uint160(ethereumAdapterAddress)))
);
```

### 6.5 Deployment Checklist

#### Pre-Deployment

- [ ] Verify vWBTC (BtcToken) addresses on both chains
- [ ] Confirm no existing VestedBTCOFT adapter exists
- [ ] Prepare deployment wallet with ETH on both chains
- [ ] Configure multisig for owner role

#### Ethereum Deployment

- [ ] Deploy VestedBTCOFT with correct constructor args
- [ ] Verify contract on Etherscan
- [ ] Record deployed address

#### Arbitrum Deployment

- [ ] Deploy VestedBTCOFT with correct constructor args
- [ ] Verify contract on Arbiscan
- [ ] Record deployed address

#### Peer Configuration

- [ ] Set Arbitrum peer on Ethereum adapter
- [ ] Set Ethereum peer on Arbitrum adapter
- [ ] Test with small amount (0.001 vWBTC)

#### DVN Configuration

- [ ] Configure send DVN settings (2 required DVNs)
- [ ] Configure receive DVN settings
- [ ] Verify configuration via endpoint read functions

---

## 7. Integration Guide

### 7.1 Frontend Integration

```typescript
// TypeScript example using viem
import { parseUnits } from 'viem';

const ADAPTER_ABI = [...]; // VestedBTCOFT ABI
const VESTED_BTC_ABI = [...]; // BtcToken ABI

async function bridgeToArbitrum(
  amount: bigint,
  recipient: `0x${string}`
) {
  const adapter = getContract({
    address: ADAPTER_ADDRESS,
    abi: ADAPTER_ABI,
  });

  const vestedBTC = getContract({
    address: VESTED_BTC_ADDRESS,
    abi: VESTED_BTC_ABI,
  });

  // 1. Approve
  await vestedBTC.write.approve([ADAPTER_ADDRESS, amount]);

  // 2. Wrap
  await adapter.write.wrap([amount]);

  // 3. Quote fee
  const sendParam = {
    dstEid: 30110n, // Arbitrum
    to: `0x${recipient.slice(2).padStart(64, '0')}` as `0x${string}`,
    amountLD: amount,
    minAmountLD: amount,
    extraOptions: '0x',
    composeMsg: '0x',
    oftCmd: '0x',
  };

  const [fee] = await adapter.read.quoteSend([sendParam, false]);

  // 4. Send
  await adapter.write.send([sendParam, fee, recipient], {
    value: fee.nativeFee,
  });
}
```

### 7.2 Monitoring

Track bridge activity via events:

```solidity
// VestedBTCOFT events
event Wrapped(address indexed user, uint256 amount);
event Unwrapped(address indexed user, uint256 amount);

// OFT events (inherited)
event OFTSent(
    bytes32 indexed guid,
    uint32 dstEid,
    address indexed fromAddress,
    uint256 amountSentLD,
    uint256 amountReceivedLD
);

event OFTReceived(
    bytes32 indexed guid,
    uint32 srcEid,
    address indexed toAddress,
    uint256 amountReceivedLD
);
```

### 7.3 Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `ZeroAmount` | wrap/unwrap with 0 | Validate amount > 0 |
| `InsufficientBalance` | Insufficient vWBTC | Check balance before wrap |
| `InvalidEndpointCall` | Non-endpoint caller | Only LZ endpoint can call lzReceive |
| `NoPeer` | Peer not configured | Call setPeer() first |

---

## Navigation

← [DeFi Documentation](./README.md) | [Curve Liquidity Pool](./Curve_Liquidity_Pool.md)
