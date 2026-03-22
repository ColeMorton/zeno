# Solidity Gas Optimization Reference

Comprehensive techniques for reducing gas costs in smart contracts.

## Table of Contents
1. [Storage Optimization](#1-storage-optimization)
2. [Function Optimization](#2-function-optimization)
3. [Data Location](#3-data-location)
4. [Arithmetic](#4-arithmetic)
5. [Control Flow](#5-control-flow)
6. [Error Handling](#6-error-handling)
7. [Events vs Storage](#7-events-vs-storage)
8. [Assembly Optimization](#8-assembly-optimization)
9. [Deployment Optimization](#9-deployment-optimization)

---

## 1. Storage Optimization

### Storage Packing
Variables < 32 bytes that are read/written together should be adjacent in declaration:
```solidity
// 3 slots (bad — 60,000 gas for cold writes)
struct Order {
    uint256 price;     // slot 0
    uint8 status;      // slot 1
    uint256 quantity;  // slot 2
    uint8 priority;    // slot 3
}

// 2 slots (good — 40,000 gas for cold writes)
struct Order {
    uint256 price;     // slot 0
    uint256 quantity;  // slot 1
    uint8 status;      // slot 2 (packed)
    uint8 priority;    // slot 2 (packed)
}
```

### Constants and Immutables
- `constant`: value embedded in bytecode at compile time. Zero runtime cost.
- `immutable`: value set in constructor, embedded in deployed bytecode. Zero runtime cost after deployment.
```solidity
uint256 public constant MAX_SUPPLY = 10_000;        // free to read
address public immutable FACTORY = msg.sender;       // free to read
```
Both save ~2,100 gas per read vs storage variables (SLOAD cost).

### Cache Storage Reads
Each `SLOAD` costs 2,100 gas (cold) or 100 gas (warm). Cache in local variable:
```solidity
// Bad: 3 SLOADs
function bad() external view returns (uint256) {
    return stateVar + stateVar + stateVar;
}

// Good: 1 SLOAD
function good() external view returns (uint256) {
    uint256 cached = stateVar;
    return cached + cached + cached;
}
```

### Clear Storage for Refunds
Setting a non-zero storage slot to zero refunds 4,800 gas. Delete unused mappings/state.

### Transient Storage (0.8.24+)
`TSTORE`/`TLOAD` cost ~100 gas vs 2,100-20,000 for `SSTORE`/`SLOAD`. Use for:
- Reentrancy locks
- Callback flags
- Any state that only needs to persist within a transaction

---

## 2. Function Optimization

### Visibility
- `external`: calldata stays in calldata (cheapest for external-facing functions)
- `public`: copies calldata to memory (unnecessary overhead for external-only functions)
- `internal`/`private`: inlined by compiler when possible (cheapest for internal calls)

### Payable Functions
`payable` functions save ~24 gas by skipping the compiler-inserted msg.value == 0 check. Only add to functions that intentionally receive Ether.

### Short-Circuit Evaluation
Place cheaper or more likely-to-fail conditions first:
```solidity
// If isActive is a storage read and amount > 0 is a stack comparison,
// put the cheaper check first
if (amount > 0 && isActive) { ... }
```

### Function Selector Ordering
Functions with lower selector values (first 4 bytes of keccak256) are checked first in the function dispatcher. High-frequency functions with low selectors save gas. This is a micro-optimization — only relevant for extreme cases.

---

## 3. Data Location

### Calldata vs Memory
For external functions with read-only array/struct/bytes/string params, use `calldata`:
```solidity
// Saves gas: no copy from calldata to memory
function process(bytes calldata data) external { ... }
```

### Memory Expansion
Memory cost grows quadratically. Avoid allocating large memory arrays. Use `calldata` slicing instead of copying to memory:
```solidity
function parseHeader(bytes calldata data) external pure returns (bytes4) {
    return bytes4(data[:4]); // no memory allocation
}
```

### Storage References
Use storage pointers to avoid copying entire structs:
```solidity
function updateOrder(uint256 id) internal {
    Order storage order = orders[id]; // reference, not copy
    order.status = Status.Filled;     // direct write, no copy overhead
}
```

---

## 4. Arithmetic

### Unchecked Blocks
Skip overflow checks when mathematically safe (~30-40 gas per operation):
```solidity
// Loop counter: i < length prevents overflow
for (uint256 i; i < length;) {
    unchecked { ++i; }
}

// Difference where a >= b is guaranteed
unchecked { uint256 diff = a - b; }
```

### Pre-increment vs Post-increment
`++i` is slightly cheaper than `i++` (avoids temporary variable). Marginal savings.

### Bitwise Operations
Bit shifts for power-of-2 multiplication/division:
```solidity
x << 1  // x * 2
x >> 1  // x / 2
```

---

## 5. Control Flow

### Revert Early
Put cheapest failure conditions first to minimize gas on revert paths:
```solidity
function withdraw(uint256 amount) external {
    if (amount == 0) revert ZeroAmount();              // stack check: cheap
    if (amount > balances[msg.sender]) revert Insufficient(); // SLOAD: expensive
}
```

### Avoid Redundant Checks
Don't re-check conditions the EVM or Solidity already enforces:
```solidity
// Redundant: Solidity 0.8+ already checks overflow
require(a + b >= a, "overflow");

// Redundant: transfer already reverts on insufficient balance
require(balanceOf(msg.sender) >= amount);
token.transferFrom(msg.sender, to, amount);
```

---

## 6. Error Handling

### Custom Errors vs Require Strings
Custom errors save ~50 bytes of deployment bytecode per error site and reduce revert gas:
```solidity
// Expensive: stores string in bytecode
require(amount > 0, "Amount must be greater than zero");

// Cheap: 4-byte selector + encoded params
error InvalidAmount(uint256 amount);
if (amount == 0) revert InvalidAmount(amount);
```

---

## 7. Events vs Storage

Events (LOG opcodes) are ~8x cheaper than storage writes for data you only need off-chain:
- LOG0: 375 gas base + 8 gas per byte
- SSTORE: 20,000 gas (new) or 5,000 gas (update)

Use events for historical records, audit trails, and notifications. Use storage only for data the contract needs to read.

---

## 8. Assembly Optimization

Use only when measurably beneficial — assembly bypasses safety checks:

### Efficient Hashing
```solidity
assembly {
    let ptr := mload(0x40)
    mstore(ptr, value1)
    mstore(add(ptr, 0x20), value2)
    result := keccak256(ptr, 0x40)
}
```

### Efficient Ether Transfer
```solidity
assembly {
    let success := call(gas(), recipient, amount, 0, 0, 0, 0)
    if iszero(success) { revert(0, 0) }
}
```

### Efficient Revert with Custom Error
```solidity
assembly {
    mstore(0x00, 0x<4-byte-selector>)
    mstore(0x04, arg1)
    revert(0x00, 0x24)
}
```

---

## 9. Deployment Optimization

### Constructor vs Initializer
Constructors produce smaller runtime bytecode (initialization code is discarded). Use constructors for non-upgradeable contracts.

### Dead Code Elimination
Remove unused functions, imports, and state variables. The compiler doesn't always eliminate them.

### Optimizer Settings
- `optimizer: true` with `runs: 200` (default) balances deployment and runtime cost
- High `runs` value (e.g., 10000): optimizes for runtime gas (larger deployment)
- Low `runs` value (e.g., 1): optimizes for deployment gas (larger runtime cost)
- For frequently-called contracts (tokens, DEXs): use higher `runs`

### Contract Size
24KB bytecode limit (EIP-170). Approaches when near limit:
- Split into multiple contracts with well-defined interfaces
- Use libraries for shared logic
- Diamond proxy pattern for extreme cases
- Remove public getters by making variables internal
