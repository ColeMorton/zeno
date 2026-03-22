# Solidity Design Patterns Reference

Contract architecture, ERC standards, proxy patterns, and Foundry testing.

## Table of Contents
1. [Proxy Patterns](#1-proxy-patterns)
2. [Factory Pattern](#2-factory-pattern)
3. [State Machine](#3-state-machine)
4. [Payment Patterns](#4-payment-patterns)
5. [ERC Token Standards](#5-erc-token-standards)
6. [Interface and Library Design](#6-interface-and-library-design)
7. [Inheritance Patterns](#7-inheritance-patterns)
8. [Foundry Testing](#8-foundry-testing)
9. [NatSpec Documentation](#9-natspec-documentation)
10. [Contract Organization](#10-contract-organization)

---

## 1. Proxy Patterns

### Transparent Proxy
- Proxy handles admin calls (upgrade, admin functions)
- All other calls delegated to implementation
- Admin cannot call implementation functions (prevents selector clashing)
- Higher deployment cost, simpler mental model
- Use case: contracts where admin and user interfaces are clearly separated

### UUPS (EIP-1822)
- Upgrade logic lives in implementation contract (`_authorizeUpgrade`)
- Minimal proxy bytecode (~100 gas overhead per call)
- **Risk**: deploying implementation without upgrade function = permanently bricked
- Use case: gas-sensitive deployments, single-instance contracts

### Beacon Proxy
- Multiple proxies point to one Beacon contract
- Upgrading Beacon upgrades all proxies simultaneously
- Use case: thousands of identical contracts (smart wallets, NFT collections)

### Diamond (EIP-2535)
- Single proxy delegates to multiple "facets" by function selector
- Overcomes 24KB bytecode limit
- Most complex — requires selector registry and careful storage management
- Use case: large systems that would otherwise exceed size limits

### Storage Safety
- Use EIP-1967 standard slots for proxy state
- Use storage gaps in base contracts: `uint256[50] private __gap;`
- Never reorder or remove state variables in upgrades — only append
- Use `forge inspect Contract storage-layout` to verify layouts

---

## 2. Factory Pattern

Deploy new contract instances programmatically:

```solidity
contract VaultFactory {
    address[] public vaults;

    function createVault(address owner) external returns (address) {
        Vault vault = new Vault(owner);
        vaults.push(address(vault));
        emit VaultCreated(address(vault), owner);
        return address(vault);
    }
}
```

### CREATE2 (Deterministic Addresses)
Predict deployment address before deploying:
```solidity
address predicted = address(uint160(uint256(keccak256(abi.encodePacked(
    bytes1(0xff),
    address(this),
    salt,
    keccak256(type(Vault).creationCode)
)))));
```

Use case: counterfactual deployment, cross-chain address consistency.

### Minimal Proxy (EIP-1167)
Ultra-lightweight clones that delegatecall to a master:
```solidity
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

address clone = Clones.clone(implementation);
IVault(clone).initialize(owner);
```
~45 bytes of bytecode per clone. Use for mass deployment of identical contracts.

---

## 3. State Machine

Model contract lifecycle as explicit states:
```solidity
enum Phase { Funding, Active, Matured, Settled }
Phase public phase;

modifier onlyPhase(Phase required) {
    if (phase != required) revert WrongPhase(phase, required);
    _;
}

function activate() external onlyPhase(Phase.Funding) {
    // validate activation conditions
    phase = Phase.Active;
    emit PhaseChanged(Phase.Active);
}
```

Time-based transitions:
```solidity
modifier autoTransition() {
    if (phase == Phase.Active && block.timestamp >= maturityDate) {
        phase = Phase.Matured;
        emit PhaseChanged(Phase.Matured);
    }
    _;
}
```

Apply `autoTransition` before `onlyPhase` so time-triggered state changes are recognized.

---

## 4. Payment Patterns

### Pull Payment (Withdrawal Pattern)
Recipients claim their own funds — prevents DoS and reentrancy:
```solidity
mapping(address => uint256) public pendingWithdrawals;

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    if (amount == 0) revert NothingToWithdraw();
    pendingWithdrawals[msg.sender] = 0;
    (bool success,) = payable(msg.sender).call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

### Push Payment
Direct transfers in a loop — only safe for bounded, trusted recipient sets:
```solidity
function distribute(address[] calldata recipients, uint256[] calldata amounts) external {
    // only safe if recipients.length is bounded and recipients are trusted
}
```

**Default**: always use pull payments for user-facing fund distribution.

---

## 5. ERC Token Standards

### ERC-20 (Fungible Tokens)
```solidity
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
```
**Key considerations**:
- `approve` race condition: use `increaseAllowance`/`decreaseAllowance` or set to 0 first
- Some tokens don't return `bool` (USDT) — use `SafeERC20`
- Fee-on-transfer tokens: actual received amount differs from `amount` parameter
- Rebasing tokens: `balanceOf` changes without transfers

### ERC-721 (NFTs)
```solidity
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
}
```
**Key**: `safeTransferFrom` checks that receiver implements `IERC721Receiver` — prevents tokens sent to contracts that can't handle them.

### ERC-1155 (Multi-Token)
Single contract for fungible and non-fungible tokens. Batch operations reduce gas:
```solidity
function safeBatchTransferFrom(
    address from, address to,
    uint256[] calldata ids, uint256[] calldata amounts,
    bytes calldata data
) external;
```

### ERC-4626 (Tokenized Vaults)
Standard interface for yield-bearing vaults:
```solidity
interface IERC4626 is IERC20 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}
```
**Key**: share/asset conversion must handle rounding consistently (round down for user, round up for vault).

### ERC-2981 (NFT Royalties)
```solidity
interface IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external view returns (address receiver, uint256 royaltyAmount);
}
```

---

## 6. Interface and Library Design

### Interfaces
- All functions implicitly `external` and `virtual`
- No state variables, no constructors, no modifiers
- Can inherit from other interfaces
- Use for: cross-contract communication, standard compliance, testing mocks

### Libraries
**Internal libraries** (all functions `internal`): inlined into calling contract bytecode
```solidity
library MathLib {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

using MathLib for uint256;
uint256 result = a.min(b);
```

**External libraries** (functions `public`/`external`): deployed separately, called via DELEGATECALL.

**Prefer internal libraries** for small utility functions — avoids DELEGATECALL overhead.

### Using-for Directives
```solidity
using SafeERC20 for IERC20;   // attach to specific type
using MathLib for uint256;     // attach to uint256
using {myFunc} for MyStruct;   // attach specific function (0.8.13+)
```

---

## 7. Inheritance Patterns

### C3 Linearization
Solidity uses C3 linearization for multiple inheritance. List base contracts from "most base-like" to "most derived":
```solidity
contract Child is GrandParent, Parent { ... }
```

### Virtual and Override
```solidity
contract Base {
    function foo() public virtual returns (uint256) { return 1; }
}

contract Override is Base {
    function foo() public override returns (uint256) { return 2; }
}
```

Multiple inheritance override:
```solidity
contract Child is A, B {
    function foo() public override(A, B) returns (uint256) { ... }
}
```

### Abstract Contracts
Contracts with at least one unimplemented function:
```solidity
abstract contract Template {
    function _hook() internal virtual;

    function execute() external {
        _hook(); // derived contracts implement
    }
}
```

---

## 8. Foundry Testing

### Test Structure
```solidity
contract MyTest is Test {
    MyContract target;

    function setUp() public {
        target = new MyContract();
    }

    function test_BasicFunction() public {
        uint256 result = target.compute(42);
        assertEq(result, 84);
    }
}
```

### Key Cheatcodes
```solidity
// Identity
vm.prank(alice);           // next call as alice
vm.startPrank(alice);      // all calls as alice until stopPrank
vm.stopPrank();

// Time and blocks
vm.warp(1700000000);       // set block.timestamp
vm.roll(100);              // set block.number

// Balances
vm.deal(alice, 10 ether);  // set ETH balance
deal(address(token), alice, 1000e18); // set ERC20 balance

// Expectations
vm.expectRevert(abi.encodeWithSelector(MyError.selector, arg));
vm.expectEmit(true, true, false, true);
emit Transfer(alice, bob, 100);

// Mocking
vm.mockCall(target, abi.encodeWithSelector(IFoo.bar.selector), abi.encode(42));

// Labels for traces
vm.label(alice, "Alice");

// State snapshots
uint256 snapshot = vm.snapshot();
vm.revertTo(snapshot);
```

### Fuzz Testing
Foundry automatically generates random inputs:
```solidity
function testFuzz_Deposit(uint256 amount) public {
    amount = bound(amount, 1, type(uint128).max); // constrain range
    vm.deal(alice, amount);
    vm.prank(alice);
    vault.deposit{value: amount}();
    assertEq(vault.balanceOf(alice), amount);
}
```
Configure runs in `foundry.toml`: `[fuzz] runs = 1000`

### Invariant Testing
Stateful fuzzing — Foundry calls random sequences of target functions:
```solidity
function invariant_TotalSupplyMatchesBalances() public view {
    uint256 sum;
    for (uint256 i; i < actors.length; i++) {
        sum += token.balanceOf(actors[i]);
    }
    assertEq(token.totalSupply(), sum);
}
```

Target specific contracts: `targetContract(address(vault))`.
Exclude functions: `excludeSelector(FuzzSelector(...))`.

### Fork Testing
Test against mainnet state:
```solidity
function setUp() public {
    vm.createSelectFork("mainnet", 18_000_000); // specific block
}
```

### Gas Snapshots
```bash
forge snapshot          # create .gas-snapshot
forge snapshot --diff   # compare against previous
```

### Coverage
```bash
forge coverage --report lcov
```

---

## 9. NatSpec Documentation

```solidity
/// @title Vault for holding collateral
/// @author Protocol Team
/// @notice User-facing explanation of what this contract does
/// @dev Developer notes about implementation details
contract Vault {
    /// @notice Deposit collateral into the vault
    /// @dev Follows CEI pattern for reentrancy safety
    /// @param amount The amount of collateral to deposit
    /// @return shares The number of shares minted
    function deposit(uint256 amount) external returns (uint256 shares) { ... }

    /// @inheritdoc IVault
    function withdraw(uint256 shares) external returns (uint256 amount) { ... }
}
```

Tags: `@title`, `@author`, `@notice`, `@dev`, `@param`, `@return`, `@inheritdoc`, `@custom:<tag>`.

---

## 10. Contract Organization

### File Structure
```
src/
├── interfaces/         # Interface definitions
├── libraries/          # Shared libraries
├── MyContract.sol      # Main contract
└── MyContractStorage.sol  # Storage layout (for upgradeable)

test/
├── MyContract.t.sol    # Unit/fuzz tests
├── MyContract.invariant.t.sol  # Invariant tests
└── helpers/            # Test utilities

script/
└── Deploy.s.sol        # Deployment scripts
```

### Function Ordering (per style guide)
1. Constructor
2. receive / fallback
3. External functions
4. Public functions
5. Internal functions
6. Private functions

Within each group: state-changing first, then `view`, then `pure`.

### Import Style
Prefer named imports:
```solidity
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```
