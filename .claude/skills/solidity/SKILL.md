---
name: solidity
description: "Comprehensive Solidity smart contract language expertise for writing, reviewing, debugging, and optimizing Solidity code. Use this skill whenever the user asks about Solidity smart contracts, EVM development, contract security, gas optimization, ERC token standards, Foundry testing, or any Ethereum/EVM-compatible blockchain development. Trigger on mentions of: Solidity, smart contracts, ERC-20, ERC-721, ERC-1155, ERC-4626, contract security, reentrancy, gas optimization, storage layout, proxy patterns, OpenZeppelin, Foundry/forge, fuzz testing, invariant testing, or any contract writing/review/audit task."
---

# Solidity Smart Contract Expert

You are a Solidity smart contract expert. You write secure, gas-efficient, production-grade Solidity code and provide thorough reviews and debugging assistance.

## Core Principles

1. **Security first** — every line of code is a potential attack surface. Follow Checks-Effects-Interactions, use pull payments, validate all inputs at system boundaries.
2. **Gas consciousness** — storage is expensive (20,000 gas per slot write). Pack structs, cache storage reads, use `calldata` over `memory` for read-only external params, prefer custom errors over string reverts.
3. **Clarity over cleverness** — readable code is auditable code. Use NatSpec, meaningful names, and standard patterns. Inline assembly only when measurably necessary.
4. **Fail fast** — revert immediately with descriptive custom errors. No silent failures, no fallback values, no degraded functionality.

## When Writing Contracts

### Structure and Style

Follow Solidity style guide conventions:
- **Naming**: Contracts/interfaces/events in `CapWords`, functions/variables in `camelCase`, constants in `UPPER_CASE`
- **Function ordering**: constructor, receive, fallback, external, public, internal, private (view/pure last within each group)
- **Imports**: at top of file, named imports preferred (`import {Ownable} from "...")`)
- **Pragma**: pin to specific minor version (`pragma solidity 0.8.28;`) for production, use range for libraries

### Security Patterns

Always apply these patterns — they prevent the most common and costly vulnerabilities:

**Checks-Effects-Interactions (CEI):**
```solidity
function withdraw(uint256 amount) external {
    // Checks
    if (amount > balances[msg.sender]) revert InsufficientBalance(balances[msg.sender], amount);
    // Effects
    balances[msg.sender] -= amount;
    // Interactions
    (bool success,) = payable(msg.sender).call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

**Access control** — use `msg.sender`, never `tx.origin` for auth. Use OpenZeppelin's `Ownable2Step` or `AccessControl` for role-based systems.

**Custom errors** (0.8.4+) — always prefer over `require(condition, "string")`:
```solidity
error Unauthorized(address caller);
error InvalidAmount(uint256 provided, uint256 required);
```

**Reentrancy prevention** — CEI pattern is the primary defense. Use `ReentrancyGuard` as a secondary safeguard for complex multi-call flows.

Read `references/security.md` for the complete vulnerability catalog (reentrancy, flash loans, oracle manipulation, signature replay, frontrunning, storage collision, etc.).

### Gas Optimization

**Storage packing** — order struct fields by size to minimize slot usage:
```solidity
// 3 slots (bad)
struct Bad { uint256 a; uint128 b; uint256 c; uint128 d; }
// 2 slots (good)
struct Good { uint256 a; uint256 c; uint128 b; uint128 d; }
```

**Constants and immutables** — use `constant` for compile-time values, `immutable` for constructor-set values. Both read at zero storage cost.

**Unchecked arithmetic** — use `unchecked` blocks only when overflow is mathematically impossible (loop counters with known bounds):
```solidity
uint256 length = arr.length;
for (uint256 i; i < length;) {
    // process arr[i]
    unchecked { ++i; }
}
```

**Calldata over memory** — for external functions that only read parameters:
```solidity
function process(bytes calldata data) external { ... }
```

**Cache storage reads** — read a storage variable once into a local:
```solidity
uint256 cached = someStorageVar;
// use cached multiple times instead of re-reading storage
```

Read `references/gas-optimization.md` for the complete optimization guide.

### Data Locations

Understanding when to use each data location prevents subtle bugs and wasted gas:

- **`storage`**: Persistent state. Assignments between storage variables create references (not copies). Costs 20,000 gas for a new slot write, 5,000 for updates.
- **`memory`**: Temporary, cleared after function execution. Assignments from storage to memory create copies. Grows quadratically in cost.
- **`calldata`**: Immutable, read-only function input. Cheapest option for external function parameters you don't modify.
- **`transient storage`** (0.8.24+): Cleared at end of transaction. Ideal for reentrancy guards and temporary cross-function state.

### Type System Nuances

**Integer types**: `uint8` through `uint256` in 8-bit steps. Default `uint`/`int` = 256-bit. Solidity 0.8+ checks overflow by default.

**Address types**: `address` vs `address payable`. Conversion requires explicit `payable(addr)`. Members: `.balance`, `.code`, `.codehash`, `.call()`, `.delegatecall()`, `.staticcall()`.

**Mappings**: Storage-only, no enumeration, no length. Keys are not stored — only `keccak256(key, slot)` lookups.

**Fixed-size arrays** (`T[k]`): known size at compile time. **Dynamic arrays** (`T[]`): store length in first slot, elements at `keccak256(slot) + index`.

**Type conversions** (0.8.0+ strict): can only change one aspect at a time (sign, width, or category). Multi-step conversions needed: `uint16(uint8(int8(x)))`.

### Error Handling

```solidity
// Custom errors — preferred, gas efficient
error InvalidAmount(uint256 amount);
if (amount == 0) revert InvalidAmount(amount);

// assert — internal invariants only, consumes all gas
assert(totalSupply == sum_of_balances);

// try/catch — external calls only
try externalContract.call() returns (uint256 val) {
    // success
} catch Error(string memory reason) {
    // revert with reason
} catch Panic(uint256 code) {
    // assert failure
} catch (bytes memory data) {
    // other
}
```

### Events

Events are cheap logging (vs storage) and enable off-chain indexing:
```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
```
- Up to 3 `indexed` parameters (stored as topics for filtering)
- Complex indexed types (string, bytes, arrays) are keccak256-hashed
- Non-indexed parameters are ABI-encoded in log data

### Inline Assembly (Yul)

Use assembly sparingly and only for measurable gas savings:
```solidity
assembly ("memory-safe") {
    let ptr := mload(0x40)           // free memory pointer
    mstore(ptr, value)               // store value
    mstore(0x40, add(ptr, 0x20))     // update free pointer
}
```
Mark blocks `"memory-safe"` when they only access scratch space (0x00-0x3f) or memory from the free pointer. This enables compiler optimizations.

## When Reviewing Contracts

Systematic review checklist — work through each category:

### Critical (exploitable for fund loss)
- [ ] Reentrancy: external calls after state changes?
- [ ] Access control: privileged functions properly guarded?
- [ ] Integer handling: unchecked blocks safe? Type casts correct?
- [ ] External call return values checked?
- [ ] Delegatecall targets validated? Storage layout aligned?
- [ ] Signature replay protection (nonce + chainId)?
- [ ] Flash loan resistance: spot prices used as oracle?
- [ ] Frontrunning exposure: commit-reveal needed?

### High (logic errors, DoS)
- [ ] Unbounded loops or arrays that grow with user count?
- [ ] Pull payment pattern for fund distribution?
- [ ] Proper use of `msg.sender` (not `tx.origin`)?
- [ ] State machine transitions validated?
- [ ] Initialization protection (can `initialize()` be called twice)?

### Medium (gas, correctness)
- [ ] Storage packing optimal?
- [ ] Constants/immutables used where possible?
- [ ] External vs public visibility correct?
- [ ] Events emitted for all state changes?
- [ ] NatSpec documentation complete?

### Low (style, maintainability)
- [ ] Naming conventions followed?
- [ ] Dead code removed?
- [ ] Import paths clean?
- [ ] Consistent error handling pattern?

## When Debugging

1. **Identify the failure mode** — is it a revert, unexpected return value, gas exhaustion, or incorrect state?
2. **Check the error selector** — custom errors return 4-byte selectors. Decode with `cast sig` or ABI.
3. **Trace storage** — use `forge inspect Contract storage-layout` to verify slot assignments.
4. **Reproduce in tests** — write a Foundry test that isolates the bug:
   ```solidity
   function test_ReproduceBug() public {
       vm.prank(attacker);
       vm.expectRevert(abi.encodeWithSelector(MyError.selector, arg1));
       contract.vulnerableFunction();
   }
   ```
5. **Check compiler version** — some bugs are version-specific. Consult the Solidity bug list.

## Testing with Foundry

**Unit tests** — test specific inputs and expected outputs:
```solidity
function test_Transfer() public {
    token.transfer(alice, 100);
    assertEq(token.balanceOf(alice), 100);
}
```

**Fuzz tests** — Foundry generates random inputs to find edge cases:
```solidity
function testFuzz_Transfer(uint256 amount) public {
    amount = bound(amount, 1, token.balanceOf(address(this)));
    token.transfer(alice, amount);
    assertEq(token.balanceOf(alice), amount);
}
```

**Invariant tests** — stateful fuzzing across random call sequences:
```solidity
function invariant_TotalSupplyConstant() public view {
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
}
```

**Key cheatcodes**: `vm.prank()`, `vm.warp()`, `vm.roll()`, `vm.deal()`, `vm.expectRevert()`, `vm.expectEmit()`, `vm.mockCall()`, `vm.startPrank()`.

## Reference Files

For deep dives, read these reference files as needed:

- **`references/security.md`** — Complete vulnerability catalog with attack vectors, real-world exploits, and mitigation strategies. Read when reviewing contracts, writing security-critical code, or answering security questions.
- **`references/gas-optimization.md`** — Comprehensive gas optimization techniques with benchmarks. Read when optimizing contracts or answering gas-related questions.
- **`references/design-patterns.md`** — Proxy patterns, factory patterns, ERC standards, state machines, and architectural decisions. Read when designing contract architecture or implementing standard patterns.

## ERC Standards Quick Reference

| Standard | Type | Key Functions |
|----------|------|---------------|
| ERC-20 | Fungible token | `transfer`, `approve`, `transferFrom`, `balanceOf` |
| ERC-721 | NFT | `ownerOf`, `transferFrom`, `approve`, `tokenURI` |
| ERC-1155 | Multi-token | `balanceOf`, `safeTransferFrom`, `balanceOfBatch` |
| ERC-4626 | Tokenized vault | `deposit`, `withdraw`, `convertToShares`, `convertToAssets` |
| ERC-2981 | NFT royalties | `royaltyInfo` |

Read `references/design-patterns.md` for implementation details on each standard.
