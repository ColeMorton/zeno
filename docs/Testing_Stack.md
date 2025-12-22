# Smart Contract Testing Stack

> **Version:** 1.0
> **Status:** Final
> **Last Updated:** 2025-12-21
> **Related Documents:**
> - [Technical Specification](./protocol/Technical_Specification.md)
> - [Glossary](./GLOSSARY.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Testing Framework](#2-testing-framework)
3. [Testing Methodology Hierarchy](#3-testing-methodology-hierarchy)
4. [Test Organization Structure](#4-test-organization-structure)
5. [Branch Coverage Patterns](#5-branch-coverage-patterns)
6. [Tooling](#6-tooling)
7. [Industry Best Practices](#7-industry-best-practices)

---

## 1. Overview

Comprehensive testing is critical for DeFi protocols where bugs directly translate to financial loss. This document defines the testing methodology, frameworks, and structure for smart contract development.

**Core Principle:** 100% branch coverage for core protocol logic, validated by invariant tests for critical properties.

---

## 2. Testing Framework

### 2.1 Foundry (Forge)

Foundry is the industry standard for serious DeFi protocol development.

| Capability | Description |
|------------|-------------|
| **Native Solidity** | Write tests in the same language as contracts |
| **Speed** | 10-100x faster than JavaScript-based alternatives |
| **Built-in Fuzzing** | Randomized input generation with `vm.assume()` and `bound()` |
| **Invariant Testing** | Stateful property-based testing |
| **Fork Testing** | Test against mainnet state with `vm.createFork()` |
| **Cheatcodes** | `vm.prank()`, `vm.warp()`, `vm.roll()` for state manipulation |

### 2.2 Alternative Frameworks

| Framework | Use Case |
|-----------|----------|
| **Hardhat** | JavaScript/TypeScript ecosystem, plugin-rich |
| **Ape** | Python-based, Vyper support |

---

## 3. Testing Methodology Hierarchy

```
┌─────────────────────────────────────────────────┐
│  Formal Verification (Certora, Halmos)          │  ← Mathematical proofs
├─────────────────────────────────────────────────┤
│  Invariant/Stateful Fuzz Testing                │  ← Property-based
├─────────────────────────────────────────────────┤
│  Fuzz Testing (Stateless)                       │  ← Randomized inputs
├─────────────────────────────────────────────────┤
│  Integration Tests                              │  ← Multi-contract flows
├─────────────────────────────────────────────────┤
│  Unit Tests                                     │  ← Individual functions
└─────────────────────────────────────────────────┘
```

### 3.1 Testing Levels

| Level | Purpose | Coverage Target |
|-------|---------|-----------------|
| **Unit** | Test individual functions in isolation | All branches, edge cases |
| **Integration** | Test multi-contract interactions | Critical user flows |
| **Fuzz** | Discover edge cases with random inputs | Boundary conditions |
| **Invariant** | Assert properties that must always hold | Protocol-level guarantees |
| **Formal** | Mathematical proofs of correctness | Security-critical logic |

---

## 4. Test Organization Structure

### 4.1 Directory Structure

```
test/
├── unit/                    # Isolated function tests
│   ├── Vault.t.sol
│   └── Token.t.sol
├── integration/             # Multi-contract flows
│   ├── DepositFlow.t.sol
│   └── WithdrawFlow.t.sol
├── fuzz/                    # Stateless fuzz tests
│   └── Vault.fuzz.t.sol
├── invariant/               # Stateful invariant tests
│   ├── handlers/            # Actor contracts
│   │   └── VaultHandler.sol
│   └── Vault.invariant.t.sol
├── fork/                    # Mainnet fork tests
│   └── MainnetIntegration.t.sol
└── utils/                   # Shared test utilities
    ├── BaseTest.sol
    └── Mocks.sol
```

### 4.2 File Naming Conventions

| Pattern | Example | Purpose |
|---------|---------|---------|
| `Contract.t.sol` | `Vault.t.sol` | Unit tests |
| `Contract.fuzz.t.sol` | `Vault.fuzz.t.sol` | Fuzz tests |
| `Contract.invariant.t.sol` | `Vault.invariant.t.sol` | Invariant tests |
| `Flow.t.sol` | `DepositFlow.t.sol` | Integration tests |
| `ContractHandler.sol` | `VaultHandler.sol` | Invariant handlers |

---

## 5. Branch Coverage Patterns

### 5.1 Unit Test Patterns

Test every function path explicitly:

```solidity
contract VaultTest is Test {
    function test_deposit_success() public {
        // Happy path
    }

    function test_deposit_revertsWhenPaused() public {
        vm.expectRevert(Vault.Paused.selector);
        vault.deposit(100);
    }

    function test_deposit_revertsWhenZeroAmount() public {
        vm.expectRevert(Vault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_deposit_revertsWhenExceedsMax() public {
        vm.expectRevert(Vault.ExceedsMaxDeposit.selector);
        vault.deposit(type(uint256).max);
    }
}
```

### 5.2 Fuzz Testing

Discover edge cases with bounded random inputs:

```solidity
function testFuzz_withdraw(uint256 amount) public {
    // Bound to valid range
    amount = bound(amount, 1, vault.maxWithdraw(user));

    uint256 balanceBefore = token.balanceOf(user);
    vault.withdraw(amount);
    uint256 balanceAfter = token.balanceOf(user);

    assertEq(balanceAfter - balanceBefore, amount);
}
```

### 5.3 Invariant Testing

Assert properties that must always hold across all state transitions:

```solidity
contract VaultInvariantTest is Test {
    VaultHandler handler;

    function setUp() public {
        handler = new VaultHandler(vault);
        targetContract(address(handler));
    }

    function invariant_solvency() public {
        assertGe(
            vault.totalAssets(),
            vault.totalLiabilities(),
            "Vault must remain solvent"
        );
    }

    function invariant_supplyMatchesBalances() public {
        assertEq(
            token.totalSupply(),
            sumOfAllBalances(),
            "Supply must match sum of balances"
        );
    }
}
```

### 5.4 Handler Pattern

Handlers define valid actor behaviors for invariant testing:

```solidity
contract VaultHandler is Test {
    Vault vault;

    constructor(Vault _vault) {
        vault = _vault;
    }

    function deposit(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);
        deal(address(token), msg.sender, amount);
        vault.deposit(amount);
    }

    function withdraw(uint256 amount) public {
        uint256 max = vault.maxWithdraw(msg.sender);
        if (max == 0) return;
        amount = bound(amount, 1, max);
        vault.withdraw(amount);
    }
}
```

### 5.5 Scenario Matrix

| Category | Test Cases |
|----------|------------|
| **Edge Values** | 0, 1, max-1, max, overflow attempts |
| **Access Control** | Every role permutation, unauthorized access |
| **Time-Dependent** | Before/after vesting, boundary timestamps |
| **Reentrancy** | Malicious callback contracts |
| **State Transitions** | Every valid state change, invalid transitions |
| **Modifiers** | Each require/revert path |

---

## 6. Tooling

### 6.1 Coverage

```bash
# Generate coverage report
forge coverage --report lcov

# HTML visualization
genhtml lcov.info -o coverage
```

### 6.2 Static Analysis

| Tool | Purpose |
|------|---------|
| **Slither** | Vulnerability detection, code quality |
| **Aderyn** | Security analysis |

```bash
slither src/
```

### 6.3 Formal Verification

| Tool | Approach |
|------|----------|
| **Certora** | Specification-based verification |
| **Halmos** | Symbolic execution |

### 6.4 Additional Fuzzing

| Tool | Strength |
|------|----------|
| **Echidna** | Property-based fuzzing, corpus persistence |
| **Medusa** | Parallel fuzzing |

---

## 7. Industry Best Practices

### 7.1 Coverage Targets

| Metric | Target |
|--------|--------|
| **Line Coverage** | 100% for core logic |
| **Branch Coverage** | 100% for core logic |
| **Invariant Tests** | All protocol-level guarantees |

### 7.2 Protocol Patterns

Top-tier DeFi protocols (Uniswap, Aave, Morpho) use:

1. **Foundry** for unit/fuzz/invariant tests
2. **Certora** or **Halmos** for formal verification
3. **Echidna** for additional fuzzing
4. **Slither** for static analysis

### 7.3 Test Execution

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_deposit_success

# Run invariant tests with more runs
forge test --match-contract Invariant --fuzz-runs 10000
```
