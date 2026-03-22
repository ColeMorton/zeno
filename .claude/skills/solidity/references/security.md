# Solidity Security Reference

Complete vulnerability catalog for smart contract security review and development.

## Table of Contents
1. [Reentrancy](#1-reentrancy)
2. [Integer Overflow/Underflow](#2-integer-overflowunderflow)
3. [Access Control](#3-access-control)
4. [Delegatecall and Proxy Storage Collision](#4-delegatecall-and-proxy-storage-collision)
5. [Front-Running and MEV](#5-front-running-and-mev)
6. [Signature Replay](#6-signature-replay)
7. [Flash Loan Attacks](#7-flash-loan-attacks)
8. [Oracle Manipulation](#8-oracle-manipulation)
9. [Denial of Service](#9-denial-of-service)
10. [Unchecked Return Values](#10-unchecked-return-values)
11. [Randomness](#11-randomness)
12. [Selfdestruct](#12-selfdestruct)
13. [Private Data Exposure](#13-private-data-exposure)

---

## 1. Reentrancy

**Attack**: External call allows callback before state update completes. Attacker re-enters the function and exploits stale state.

**Vulnerable pattern**:
```solidity
function withdraw() public {
    (bool success,) = msg.sender.call{value: shares[msg.sender]}("");
    require(success);
    shares[msg.sender] = 0; // state updated AFTER call
}
```

**Defenses** (in order of importance):
1. **CEI pattern** — update state before external calls
2. **ReentrancyGuard** — mutex lock for complex flows
3. **Transient storage** (0.8.24+) — cheaper reentrancy lock that auto-clears per transaction

**Cross-function reentrancy**: attacker re-enters a different function that reads the stale state. CEI still prevents this if all state updates happen before any external call in the entire contract.

**Read-only reentrancy**: attacker calls a `view` function during reentrancy to get stale data from another protocol. Defense: use reentrancy guards on view functions that external protocols depend on.

---

## 2. Integer Overflow/Underflow

**Solidity 0.8.0+**: Arithmetic is checked by default — overflow/underflow reverts.

**Still vulnerable in 0.8.0+**:
- **Type casts**: `uint8(uint256(256))` silently truncates to `0`
- **Shift operations**: not checked for overflow
- **Inline assembly**: Yul has no overflow protection
- **`unchecked` blocks**: explicitly disables checks

**Defense**: Use 0.8.0+, validate type casts explicitly, audit all `unchecked` blocks.

---

## 3. Access Control

**tx.origin phishing**:
```
User -> Malicious Contract -> Victim Contract
tx.origin = User (passes check)
msg.sender = Malicious Contract (would fail check)
```
Always use `msg.sender` for authorization.

**Missing access control**: Functions that modify critical state (ownership, balances, parameters) must have explicit access restrictions.

**Initialization attacks**: Uninitialized proxy implementations can be taken over. Always use `initializer` modifier and consider `_disableInitializers()` in constructors.

**Patterns**:
- `Ownable2Step` — two-step ownership transfer (prevents accidental transfer to wrong address)
- `AccessControl` — role-based with hierarchy, multiple accounts per role
- `AccessManager` — centralized access control across multiple contracts

---

## 4. Delegatecall and Proxy Storage Collision

**Storage collision**: Proxy and implementation share storage. If layouts don't match, writes corrupt unrelated slots.

```
Proxy storage:       Implementation storage:
  Slot 0: admin        Slot 0: owner     <- COLLISION
  Slot 1: impl         Slot 1: balance
```

**Defenses**:
- **EIP-1967**: standardized storage slots at pseudo-random locations
- **Unstructured storage**: use `keccak256("eip1967.proxy.implementation") - 1` for proxy state
- **Storage gap**: reserve slots in base contracts for future variables
- **Never** allow delegatecall to arbitrary addresses

**Proxy patterns**:
- **Transparent Proxy**: admin calls go to proxy, user calls delegated to impl
- **UUPS**: upgrade logic in implementation (cheaper deployment, risk of bricking)
- **Beacon**: multiple proxies share one upgradeable implementation pointer
- **Diamond (EIP-2535)**: single proxy delegates to multiple facets by selector

---

## 5. Front-Running and MEV

**Attack**: observer sees pending transaction in mempool, submits competing transaction with higher gas.

**Sandwich attack**: attacker front-runs and back-runs a trade to extract value.

**Defenses**:
- **Slippage limits**: let users set max acceptable price impact
- **Commit-reveal**: hide action details until settlement
- **Private order flow**: Flashbots Protect, MEV-Share
- **Batch auctions**: settle all trades at uniform price
- **TWAP**: time-weighted prices resist single-block manipulation

---

## 6. Signature Replay

**Attack**: valid signature reused to execute same action multiple times or on different chains.

**Required protections**:
1. **Nonce**: incrementing counter per signer, included in signed message
2. **Chain ID**: prevents cross-chain replay
3. **Contract address**: prevents cross-contract replay (part of EIP-712 domain)
4. **Deadline/expiry**: time-bound signatures

**EIP-712**: structured typed data signing with domain separator. Use OpenZeppelin's `EIP712` base contract.

```solidity
bytes32 public constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);
```

---

## 7. Flash Loan Attacks

**Attack**: borrow massive funds with zero collateral, manipulate state, repay in single transaction.

**Common exploits**: price oracle manipulation, governance takeover, liquidity pool drain.

**Real-world losses**: Euler Finance ($197M), Beanstalk ($182M), Pancake Bunny ($45M).

**Defenses**:
- **TWAP oracles**: require sustained manipulation across blocks
- **Chainlink price feeds**: off-chain aggregated data, immune to on-chain manipulation
- **Circuit breakers**: pause on abnormal price movements (>5% for stables, >20-30% for volatile)
- **Multi-block validation**: require state to persist across blocks
- **Governance timelocks**: prevent single-transaction governance attacks

---

## 8. Oracle Manipulation

**Attack**: manipulate price feed to trigger unauthorized liquidations, withdrawals, or swaps.

**Spot price vulnerability**: DEX spot prices (e.g., Uniswap reserves) are manipulable within a single transaction.

**Defenses**:
- **Multiple oracle sources**: aggregate and cross-validate
- **TWAP**: time-weighted average over multiple blocks
- **Chainlink**: decentralized node operators, 50+ off-chain sources
- **Price bounds**: reject values outside reasonable range
- **Staleness checks**: verify oracle data is recent (`updatedAt` timestamp)

---

## 9. Denial of Service

**Unbounded loops**: arrays that grow with user count can exceed block gas limit.
```solidity
// DANGEROUS: loop size unbounded
for (uint i; i < userAddresses.length; i++) { ... }
```

**Mitigation**: pagination, batch processing, pull payment pattern.

**Gas griefing**: caller provides just enough gas for outer call but not subcalls.

**External call DoS**: pushing funds to a contract that reverts in receive/fallback blocks the entire function.

**Mitigation**: pull payments — let recipients withdraw their own funds.

---

## 10. Unchecked Return Values

`call()` and `send()` return `bool` — if unchecked, execution continues after failure.

```solidity
// BAD: unchecked
payable(recipient).send(amount);

// GOOD: checked
(bool success,) = payable(recipient).call{value: amount}("");
if (!success) revert TransferFailed();
```

`transfer()` auto-reverts but is limited to 2300 gas — insufficient for contracts with non-trivial receive logic.

**Recommendation**: use `call{value: amount}("")` with explicit success check.

---

## 11. Randomness

**Not random** (manipulable by validators):
- `block.timestamp`
- `blockhash` (only 256 recent blocks)
- `block.prevrandao`

**Solutions**: Chainlink VRF, commit-reveal schemes, or off-chain randomness with on-chain verification.

---

## 12. Selfdestruct

**Post-Cancun (EIP-6780)**: `selfdestruct` only sends Ether, no longer destroys contract (except in same transaction as creation). Deprecated — do not use.

**Forced Ether**: `selfdestruct` and coinbase rewards can force Ether into contracts. Never use `address(this).balance == expectedAmount` for logic — use internal accounting.

---

## 13. Private Data Exposure

`private` variables are hidden from other contracts but **publicly readable on-chain**. All storage is visible via `eth_getStorageAt`.

Never store secrets, passwords, or randomness seeds in contract storage.
