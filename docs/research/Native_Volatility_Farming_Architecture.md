# Native Volatility Farming for vestedBTC: Architecture Design

**Task:** Engineer Pathway C natively - vestedBTC yield enhancement without external Peapods dependency
**Status:** Architecture Design (Research)
**Date:** 2025-12-30

---

## Executive Summary

Design a **native yield-bearing vault** for vestedBTC that captures volatility farming yield through DEX liquidity provision and auto-compounding, without modifying the immutable protocol layer.

**Core Mechanism:** Users deposit vestedBTC → receive yvBTC shares → vault deploys capital to Curve LP → harvests fees/rewards → compounds → exchange rate appreciates.

---

## Part I: Architectural Analysis

### Why NOT Replicate Peapods Exactly

| Peapods Mechanic | BTCNFT Constraint | Resolution |
|------------------|-------------------|------------|
| Pod mints pTKN at dynamic CBR | `BtcToken.mint()` restricted to VaultNFT only | Use share-based vault (ERC-4626) instead |
| Governance-controlled parameters | Protocol is immutable, no governance | All parameters immutable at deployment |
| LVF leveraged positions | Introduces liquidation risk | Defer to separate lending protocol |
| Metavault capital routing | Requires governance for whitelist | Single-strategy vault, no routing |

### Why ERC-4626 Tokenized Vault

ERC-4626 is the standard for yield-bearing vaults. It provides:
1. **Share-based accounting** - No need to mint underlying
2. **Composable** - Works with any DeFi protocol expecting ERC-4626
3. **Exchange rate** - `convertToAssets(shares)` / `convertToShares(assets)`
4. **Battle-tested** - Yearn, Aave, Compound all use this pattern

```
Exchange Rate = totalAssets / totalSupply

When yield accrues:
- totalAssets increases (more vestedBTC in vault)
- totalSupply unchanged (same shares outstanding)
- Exchange rate increases (each share worth more vestedBTC)
```

---

## Part II: Native Yield Vault Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    NATIVE YIELD VAULT (yvBTC)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐ │
│  │    USER      │         │  YIELD VAULT │         │   STRATEGY   │ │
│  │              │         │   (yvBTC)    │         │              │ │
│  │ deposit(vBTC)├────────►│              │────────►│ Curve LP     │ │
│  │              │         │ ERC-4626     │         │ vBTC/WBTC    │ │
│  │◄────────────┤         │              │◄────────┤              │ │
│  │ receive yvBTC│         │ Exchange     │         │ LP tokens    │ │
│  │              │         │ Rate grows   │         │ + gauge      │ │
│  └──────────────┘         └──────────────┘         └──────────────┘ │
│                                  │                        │          │
│                                  │     harvest()          │          │
│                                  │◄───────────────────────┤          │
│                                  │  CRV rewards           │          │
│                                  │  → swap to vBTC        │          │
│                                  │  → compound            │          │
│                                                                      │
│  Yield Sources:                                                      │
│  ├─ Curve swap fees (0.04% × volume)                                │
│  ├─ CRV emissions (if gauge approved)                               │
│  └─ Arbitrage profits (implicit via LP rebalancing)                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Contract Structure

```
contracts/issuer/src/
├── vaults/
│   ├── YieldVaultVBTC.sol          # ERC-4626 vault for vestedBTC
│   └── interfaces/
│       └── IYieldVaultVBTC.sol
│
├── strategies/
│   ├── CurveLPStrategy.sol         # Curve vBTC/WBTC LP + gauge
│   └── interfaces/
│       └── IStrategy.sol
│
└── periphery/
    ├── Harvester.sol               # Permissionless harvest trigger
    └── Zap.sol                     # Single-tx deposit from WBTC
```

---

## Part III: Core Contract Design

### YieldVaultVBTC.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title YieldVaultVBTC
/// @notice ERC-4626 yield-bearing vault for vestedBTC
/// @dev Deploys vestedBTC to Curve LP strategy, auto-compounds yields
contract YieldVaultVBTC is ERC4626 {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Strategy contract that manages LP positions
    IStrategy public immutable strategy;

    /// @notice Performance fee in basis points (e.g., 1000 = 10%)
    uint256 public immutable performanceFeeBps;

    /// @notice Fee recipient address
    address public immutable feeRecipient;

    /// @notice WBTC token for paired liquidity
    IERC20 public immutable wbtc;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant BPS = 10000;
    uint256 private constant MAX_PERFORMANCE_FEE = 2000; // 20% cap

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        IERC20 _vestedBTC,
        IStrategy _strategy,
        uint256 _performanceFeeBps,
        address _feeRecipient,
        IERC20 _wbtc
    ) ERC4626(_vestedBTC) ERC20("Yield vestedBTC", "yvBTC") {
        if (_performanceFeeBps > MAX_PERFORMANCE_FEE) revert FeeTooHigh();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        strategy = _strategy;
        performanceFeeBps = _performanceFeeBps;
        feeRecipient = _feeRecipient;
        wbtc = _wbtc;

        // Approve strategy to pull vestedBTC
        _vestedBTC.approve(address(_strategy), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE VAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Total assets under management (vestedBTC)
    function totalAssets() public view override returns (uint256) {
        return strategy.totalValue();
    }

    /// @notice Deposit vestedBTC, receive yvBTC shares
    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);

        // Deploy to strategy immediately
        strategy.deposit(assets);
    }

    /// @notice Withdraw vestedBTC by burning yvBTC shares
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        returns (uint256 shares)
    {
        shares = super.withdraw(assets, receiver, owner);

        // Withdraw from strategy
        strategy.withdraw(assets, receiver);
    }

    /*//////////////////////////////////////////////////////////////
                           HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Harvest yields from strategy, compound, and take fees
    /// @dev Permissionless - anyone can call
    /// @return yielded Amount of vestedBTC yielded after fees
    function harvest() external returns (uint256 yielded) {
        uint256 beforeBalance = IERC20(asset()).balanceOf(address(this));

        // Claim rewards from strategy (CRV, etc.)
        strategy.harvest();

        uint256 afterBalance = IERC20(asset()).balanceOf(address(this));
        uint256 grossYield = afterBalance - beforeBalance;

        if (grossYield == 0) return 0;

        // Calculate and transfer performance fee
        uint256 fee = (grossYield * performanceFeeBps) / BPS;
        if (fee > 0) {
            IERC20(asset()).safeTransfer(feeRecipient, fee);
        }

        yielded = grossYield - fee;

        // Compound: redeploy to strategy
        if (yielded > 0) {
            strategy.deposit(yielded);
        }

        emit Harvested(grossYield, fee, yielded);
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Harvested(uint256 grossYield, uint256 fee, uint256 compounded);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error FeeTooHigh();
    error ZeroAddress();
}
```

### CurveLPStrategy.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CurveLPStrategy
/// @notice Manages Curve vBTC/WBTC LP position with gauge staking
contract CurveLPStrategy is IStrategy {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Vault that owns this strategy
    address public immutable vault;

    /// @notice vestedBTC token
    IERC20 public immutable vestedBTC;

    /// @notice WBTC token
    IERC20 public immutable wbtc;

    /// @notice Curve pool (vBTC/WBTC)
    ICurvePool public immutable curvePool;

    /// @notice Curve LP token
    IERC20 public immutable curveLPToken;

    /// @notice Curve gauge for staking LP
    ICurveGauge public immutable curveGauge;

    /// @notice CRV token
    IERC20 public immutable crv;

    /// @notice DEX router for swapping rewards
    ISwapRouter public immutable swapRouter;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _vault,
        IERC20 _vestedBTC,
        IERC20 _wbtc,
        ICurvePool _curvePool,
        IERC20 _curveLPToken,
        ICurveGauge _curveGauge,
        IERC20 _crv,
        ISwapRouter _swapRouter
    ) {
        vault = _vault;
        vestedBTC = _vestedBTC;
        wbtc = _wbtc;
        curvePool = _curvePool;
        curveLPToken = _curveLPToken;
        curveGauge = _curveGauge;
        crv = _crv;
        swapRouter = _swapRouter;

        // Approvals
        _vestedBTC.approve(address(_curvePool), type(uint256).max);
        _wbtc.approve(address(_curvePool), type(uint256).max);
        _curveLPToken.approve(address(_curveGauge), type(uint256).max);
        _crv.approve(address(_swapRouter), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          STRATEGY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Total value in vestedBTC terms
    function totalValue() external view returns (uint256) {
        uint256 lpBalance = curveGauge.balanceOf(address(this));
        if (lpBalance == 0) return 0;

        // Calculate vBTC value of LP position
        return curvePool.calc_withdraw_one_coin(lpBalance, 0); // index 0 = vBTC
    }

    /// @notice Deposit vestedBTC into Curve LP
    function deposit(uint256 amount) external onlyVault {
        vestedBTC.safeTransferFrom(vault, address(this), amount);

        // Add single-sided liquidity to Curve
        uint256[2] memory amounts = [amount, 0];
        uint256 minLP = _calculateMinLP(amount);

        uint256 lpReceived = curvePool.add_liquidity(amounts, minLP);

        // Stake LP in gauge
        curveGauge.deposit(lpReceived);

        emit Deposited(amount, lpReceived);
    }

    /// @notice Withdraw vestedBTC from Curve LP
    function withdraw(uint256 amount, address recipient) external onlyVault {
        uint256 lpNeeded = _calculateLPForWithdraw(amount);

        curveGauge.withdraw(lpNeeded);

        uint256 minOut = (amount * 9900) / 10000; // 1% slippage tolerance
        uint256 received = curvePool.remove_liquidity_one_coin(lpNeeded, 0, minOut);

        vestedBTC.safeTransfer(recipient, received);

        emit Withdrawn(amount, lpNeeded, received);
    }

    /// @notice Harvest CRV rewards and swap to vestedBTC
    function harvest() external onlyVault returns (uint256 yielded) {
        curveGauge.claim_rewards();

        uint256 crvBalance = crv.balanceOf(address(this));
        if (crvBalance == 0) return 0;

        // Swap CRV → WBTC → vBTC
        uint256 wbtcReceived = _swapCRVtoWBTC(crvBalance);
        yielded = _swapWBTCtoVBTC(wbtcReceived);

        vestedBTC.safeTransfer(vault, yielded);

        emit Harvested(crvBalance, yielded);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _calculateMinLP(uint256 vbtcAmount) internal view returns (uint256) {
        uint256 virtualPrice = curvePool.get_virtual_price();
        return (vbtcAmount * 1e18 * 9900) / (virtualPrice * 10000);
    }

    function _calculateLPForWithdraw(uint256 vbtcAmount) internal view returns (uint256) {
        return curvePool.calc_token_amount([vbtcAmount, 0], false);
    }

    function _swapCRVtoWBTC(uint256 crvAmount) internal returns (uint256) {
        bytes memory path = abi.encodePacked(
            address(crv),
            uint24(3000),
            WETH,
            uint24(500),
            address(wbtc)
        );

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: crvAmount,
            amountOutMinimum: 0
        });

        return swapRouter.exactInput(params);
    }

    function _swapWBTCtoVBTC(uint256 wbtcAmount) internal returns (uint256) {
        return curvePool.exchange(1, 0, wbtcAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(uint256 vbtcAmount, uint256 lpReceived);
    event Withdrawn(uint256 vbtcRequested, uint256 lpBurned, uint256 vbtcReceived);
    event Harvested(uint256 crvClaimed, uint256 vbtcYielded);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyVault();
}
```

---

## Part IV: Key Design Decisions

### 1. Single Immutable Strategy (No Governance)

**Decision:** One strategy per vault, set at deployment, immutable.

**Rationale:**
- Aligns with BTCNFT protocol philosophy
- No governance attack surface
- Users know exactly what strategy they're in
- Different strategies = different vault deployments

**Trade-off:** Cannot upgrade strategy. Mitigation: Deploy new vault, users migrate voluntarily.

### 2. Performance Fee Only (No Management Fee)

**Decision:** 10% of harvested yield, no AUM-based fee.

**Rationale:**
- YAGNI - management fees add complexity
- Aligns incentives: fee recipient only profits when yield is generated
- Simpler accounting

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Performance Fee | 10% | Industry standard (Yearn uses 10-20%) |
| Management Fee | 0% | KISS principle |
| Fee Recipient | Immutable | Set at deployment |

### 3. Permissionless Harvesting

**Decision:** Anyone can call `harvest()`.

**Rationale:**
- No keeper dependency
- MEV searchers incentivized to harvest (they capture arbitrage)
- Gas cost is small relative to yield on large vaults

### 4. Single-Sided Liquidity Provision

**Decision:** Deposit only vestedBTC, not 50/50 with WBTC.

**Rationale:**
- Users have vestedBTC, may not have WBTC
- Curve handles imbalanced deposits efficiently
- Slight IL is acceptable given yield capture

### 5. Exchange Rate Mechanics (ERC-4626 Standard)

```
shares = assets * totalSupply / totalAssets

On deposit:
- User deposits 100 vBTC
- totalAssets = 1000, totalSupply = 1000
- User gets 100 shares

After yield accrual (10 vBTC harvested):
- totalAssets = 1010, totalSupply = 1000
- Exchange rate = 1.01 vBTC per share

User's 100 shares now worth:
- 100 * 1010 / 1000 = 101 vBTC
```

---

## Part V: Yield Sources & Economics

### Yield Stack

| Source | Estimated APY | Dependency |
|--------|---------------|------------|
| Curve swap fees | 0.5-2% | Trading volume |
| CRV emissions | 3-10% | Gauge approval |
| Arbitrage (implicit) | Variable | Market volatility |
| **Base withdrawal** | **12%** | **Retained by Vault holder** |

**Total Potential:** 12% base + 5-10% vault yield = **17-22% combined**

### Important: Base Yield Retention

The vault holder **retains withdrawal rights** on the underlying Vault NFT. The yield vault only captures the yield on the **separated vestedBTC**:

```
User's Vault NFT (1 BTC collateral)
├─ Withdrawal rights: 12% annually (USER KEEPS THIS)
│
└─ Separation: mintBtcToken() → 1 vestedBTC
    │
    └─ Deposit to YieldVault → yvBTC shares
        │
        └─ Captures: LP fees + CRV rewards (ADDITIONAL YIELD)
```

**Net Position:**
- User owns Vault NFT (withdrawal rights)
- User owns yvBTC (yield-bearing vestedBTC)
- User earns 12% + LP yield

---

## Part VI: Risk Analysis

### Smart Contract Risk

| Risk | Severity | Mitigation |
|------|----------|------------|
| Vault contract bug | HIGH | Audit, formal verification |
| Strategy contract bug | HIGH | Audit, use battle-tested Curve interfaces |
| Curve pool exploit | HIGH | Curve has 5+ year Lindy, $3B+ TVL |
| Oracle manipulation | LOW | No oracle - uses on-chain Curve pricing |

### Economic Risk

| Risk | Severity | Mitigation |
|------|----------|------------|
| Impermanent loss | MEDIUM | CryptoSwap profit-offset rule minimizes IL (~2% expected) |
| CRV price crash | MEDIUM | Harvest frequently, minimize CRV exposure |
| vestedBTC discount widening | MEDIUM | LP position rebalances naturally |
| Low trading volume | LOW | Accept lower yield, maintain position |

### Operational Risk

| Risk | Severity | Mitigation |
|------|----------|------------|
| Harvest never called | LOW | Permissionless - MEV bots incentivized |
| Strategy becomes suboptimal | MEDIUM | Deploy new vault, users migrate |
| Curve gauge not approved | MEDIUM | LP only (no CRV emissions) |

---

## Part VII: Implementation Phases

### Phase 1: Core Vault
- [ ] YieldVaultVBTC.sol (ERC-4626)
- [ ] IStrategy.sol interface
- [ ] Unit tests for vault mechanics

### Phase 2: Curve Strategy
- [ ] CurveLPStrategy.sol
- [ ] Integration with Curve vBTC/WBTC pool
- [ ] Gauge staking (if available)
- [ ] Harvest swap logic

### Phase 3: Periphery
- [ ] Harvester.sol (optional bounty)
- [ ] Zap.sol (WBTC → vBTC → yvBTC)
- [ ] Multicall helper

### Phase 4: Testing & Audit
- [ ] Fork tests against mainnet Curve
- [ ] Fuzz testing for edge cases
- [ ] Security audit

---

## Part VIII: Comparison to Peapods

| Aspect | Peapods | Native yvBTC |
|--------|---------|--------------|
| **Token Mechanic** | pTKN with dynamic CBR | ERC-4626 share token |
| **Yield Source** | VF fees, arbitrage | Curve LP fees, CRV |
| **Leverage** | LVF (liquidatable) | None (can use separate lending) |
| **Governance** | vlPEAS voting | None (immutable) |
| **Complexity** | High (Pods, LVF, Metavaults) | Low (single vault + strategy) |
| **Protocol Dependency** | Peapods contracts | Standard Curve |
| **Lindy** | 1-2 years | Curve: 5+ years |

**Conclusion:** Native yvBTC is simpler, more aligned with BTCNFT philosophy, and relies on battle-tested infrastructure rather than newer protocol dependencies.

---

## Final Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Performance Fee** | 10% | Industry standard, aligns incentives |
| **Strategy** | Curve-only | Simpler, fewer dependencies, lower audit surface |
| **Convex Integration** | Deferred | Can add in future vault deployment if needed |
| **Multi-collateral** | Separate vaults | One yvWBTC, one yvCBBTC - maintains risk isolation |

---

## Summary

This architecture design provides a **native volatility farming solution** for vestedBTC that:

1. **Respects protocol immutability** - No changes to VaultNFT or BtcToken
2. **Uses battle-tested infrastructure** - ERC-4626, Curve CryptoSwap V2 (3+ year Lindy)
3. **Aligns with BTCNFT philosophy** - No governance, all parameters immutable
4. **Captures yield efficiently** - LP fees + CRV emissions auto-compounded

**Expected Combined Yield:** 12% base (withdrawal rights) + 5-10% vault yield = **17-22% total APY**

---

## Related Documents

- [Peapods Finance Analysis](./Peapods_Finance_Analysis.md) - External protocol research
- [Curve Liquidity Pool](../defi/Curve_Liquidity_Pool.md) - Base LP design
- [Leveraged Lending Protocol](../defi/Leveraged_Lending_Protocol.md) - CDP design (separate from vault)
