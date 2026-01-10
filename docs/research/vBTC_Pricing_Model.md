# vBTC Option-Theoretic Pricing Model

This document develops a formal pricing framework for vestedBTC (vBTC) using option-theoretic principles. The model characterizes vBTC as a decaying forward contract and derives optimal redemption timing using risk-neutral valuation.

---

## 1. Instrument Characterization

vBTC is a **decaying forward contract** with the following properties:

| Property | Value |
|----------|-------|
| Underlying | BTC collateral in vault |
| Decay rate | 1% monthly (w = 0.01) |
| Maturity | Perpetual (no fixed expiry) |
| Redemption | At holder's discretion |
| Counterparty | Smart contract (no credit risk) |

### 1.1 Cash Flow Structure

The vBTC holder's claim evolves as:

$$C(t) = V_0 \cdot (1-w)^t$$

Where:
- $C(t)$ = Collateral available to vBTC holder at month $t$
- $V_0$ = Initial vault collateral (1.0 BTC)
- $w$ = Monthly withdrawal rate (0.01)
- $t$ = Months since separation

**Numerical example:**
```
t = 0 months:   C(0)  = 1.0 × (0.99)^0   = 1.000 BTC
t = 12 months:  C(12) = 1.0 × (0.99)^12  = 0.886 BTC
t = 36 months:  C(36) = 1.0 × (0.99)^36  = 0.698 BTC
t = 60 months:  C(60) = 1.0 × (0.99)^60  = 0.547 BTC
t = 120 months: C(120) = 1.0 × (0.99)^120 = 0.299 BTC
```

### 1.2 Fundamental Difference from Options

| Dimension | Call Option | vBTC |
|-----------|-------------|------|
| Underlying movement | Stochastic | Deterministic decay + stochastic BTC price |
| Time effect | Theta decay (value → 0 at expiry) | Collateral decay (claim → 0 asymptotically) |
| Holder's choice | Exercise or expire | Redeem or sell |
| Writer's obligation | Deliver at strike | None (withdrawals automatic) |
| Expiration | Fixed date | Perpetual |

**Key insight:** Unlike options where time value decays to zero at a fixed expiration, vBTC's underlying collateral decays continuously with no terminal date. The optimal strategy is time-dependent but not expiration-bounded.

---

## 2. Pricing Framework

### 2.1 Present Value Approach (No Optionality)

If vBTC holder plans to hold indefinitely and eventually redeem:

$$PV_{vBTC}^{hold} = \lim_{T \to \infty} V_0 \cdot (1-w)^T \cdot e^{-rT} = 0$$

The hold-to-infinity value is zero because:
- $(1-w)^T \to 0$ as $T \to \infty$ (asymptotic decay)
- The discount factor $e^{-rT}$ accelerates this convergence

**Implication:** Rational holders must redeem at some finite time, making vBTC an optimal stopping problem.

### 2.2 Optimal Stopping Problem

The vBTC holder seeks to maximize present value by choosing optimal redemption time $\tau$:

$$\max_{\tau} \mathbb{E}\left[ V_0 \cdot (1-w)^\tau \cdot e^{-r\tau} \right]$$

For deterministic decay (ignoring BTC price stochasticity in risk-neutral framework):

$$f(\tau) = V_0 \cdot (1-w)^\tau \cdot e^{-r\tau} = V_0 \cdot e^{\tau[\ln(1-w) - r]}$$

Taking derivative and setting to zero:

$$\frac{df}{d\tau} = V_0 \cdot [\ln(1-w) - r] \cdot e^{\tau[\ln(1-w) - r]} = 0$$

Since $e^{(\cdot)} > 0$ always, the derivative equals zero only when $\ln(1-w) - r = 0$, which is a boundary condition.

**Analysis:**
- If $r > -\ln(1-w)$: derivative is always negative → optimal $\tau^* = 0$ (immediate redemption)
- If $r < -\ln(1-w)$: derivative is always positive → optimal $\tau^* \to \infty$ (never redeem, contradicting Section 2.1)
- If $r = -\ln(1-w)$: derivative is zero → indifferent across all $\tau$

**Critical threshold:**
$$r^* = -\ln(1-w) = -\ln(0.99) \approx 0.01005 \text{ (monthly)}$$

Annualized: $r^*_{annual} = (1 + 0.01005)^{12} - 1 \approx 12.7\%$

### 2.3 Interpretation

At $r = 5\%$ annual (0.407% monthly) and $w = 1\%$ monthly:
- $r_{monthly} = 0.00407$
- $-\ln(1-w) = -\ln(0.99) = 0.01005$

Since $0.01005 > 0.00407$, we have $r < r^*$, meaning:
- The decay rate exceeds the discount rate
- Holding longer always increases present value (in the deterministic model)
- The "optimal strategy is to hold" conclusion from naive calculus

**Resolution:** This apparent paradox arises because we ignored the market price. In reality, vBTC trades at a discount $D < 1$. The relevant comparison is:

$$\text{Redeem at } \tau: V_0 \cdot (1-w)^\tau \cdot e^{-r\tau}$$
$$\text{Sell now}: V_0 \cdot D$$

### 2.4 Break-Even Holding Period

Solve for $\tau$ where holding beats immediate sale:

$$V_0 \cdot (1-w)^\tau \cdot e^{-r\tau} > V_0 \cdot D$$

$$(1-w)^\tau \cdot e^{-r\tau} > D$$

Taking logs:

$$\tau \cdot \ln(1-w) - r\tau > \ln(D)$$

$$\tau \cdot [\ln(1-w) - r] > \ln(D)$$

Since $\ln(1-w) - r < 0$ (decay + discount both reduce value), dividing flips the inequality:

$$\tau < \frac{\ln(D)}{\ln(1-w) - r}$$

**Numerical example at $D = 0.85$, $w = 0.01$, $r_{monthly} = 0.00407$:**

$$\tau < \frac{\ln(0.85)}{\ln(0.99) - 0.00407} = \frac{-0.1625}{-0.01005 - 0.00407} = \frac{-0.1625}{-0.01412} = 11.5 \text{ months}$$

**Result:** vBTC buyer should redeem within ~12 months to beat the 85% purchase price.

### 2.5 Break-Even Period Sensitivity Table

| Market Discount (D) | Break-Even Period | Annualized Threshold |
|--------------------|-------------------|---------------------|
| 0.95 (5% discount) | 3.6 months | N/A |
| 0.90 (10% discount) | 7.5 months | N/A |
| 0.85 (15% discount) | 11.5 months | ~1 year |
| 0.80 (20% discount) | 15.8 months | ~1.3 years |
| 0.70 (30% discount) | 25.3 months | ~2.1 years |
| 0.50 (50% discount) | 49.1 months | ~4.1 years |

**Key insight:** Wider discounts give buyers more time to profitably redeem. The relationship is approximately logarithmic.

---

## 3. Market Price Decomposition

### 3.1 Component Framework

The market price of vBTC can be decomposed as:

$$P_{vBTC} = PV_{residual} + \Pi_{liquidity} + \Pi_{speculation}$$

Where:
- $PV_{residual}$ = Present value of collateral claim (calculable)
- $\Pi_{liquidity}$ = Liquidity premium/discount (observable from market data)
- $\Pi_{speculation}$ = Speculative premium (residual, not directly observable)

### 3.2 Residual Value Calculation

For a rational buyer planning to redeem at optimal $\tau^*$:

$$PV_{residual} = V_0 \cdot (1-w)^{\tau^*} \cdot e^{-r \cdot \tau^*/12}$$

At $\tau^* = 12$ months (from break-even analysis):
$$PV_{residual} = 1.0 \cdot (0.99)^{12} \cdot e^{-0.05} = 0.886 \cdot 0.951 = 0.842 \text{ BTC}$$

### 3.3 Liquidity Premium Estimation

From Curve pool empirical data (illustrative):
- Bid-ask spread component: ~1-2%
- Slippage for large trades (>10 BTC): ~2-5%
- Expected liquidity premium: $\Pi_{liquidity} \approx -0.03$ to $-0.05$ BTC

The negative sign indicates a discount (illiquidity penalty).

### 3.4 Implied Speculation Premium

$$\Pi_{speculation} = P_{market} - PV_{residual} - \Pi_{liquidity}$$

At $P_{market} = 0.85$ BTC:
$$\Pi_{speculation} = 0.85 - 0.842 - (-0.04) = 0.048 \text{ BTC}$$

**Interpretation:** Market prices in ~5% speculative premium, reflecting:
- Expected protocol adoption growth
- BTC price appreciation during holding period
- Optionality value of flexible redemption timing

### 3.5 Decomposition Sensitivity

| Discount Rate | PV_residual | Liquidity | Speculation | Market Price |
|---------------|-------------|-----------|-------------|--------------|
| 3% | 0.867 BTC | -0.04 | 0.023 | 0.85 |
| 5% | 0.842 BTC | -0.04 | 0.048 | 0.85 |
| 8% | 0.808 BTC | -0.04 | 0.082 | 0.85 |
| 12% | 0.763 BTC | -0.04 | 0.127 | 0.85 |
| 15% | 0.730 BTC | -0.04 | 0.160 | 0.85 |

**Insight:** At higher discount rates, more of the market price is attributed to speculation rather than fundamental residual value.

---

## 4. Comparative Statics

### 4.1 Sensitivity to Withdrawal Rate

How does optimal behavior change if the protocol used different withdrawal rates?

| Monthly w | Annual Equivalent | Break-Even at D=0.85 | Critical Discount Rate |
|-----------|-------------------|---------------------|----------------------|
| 0.5% | 6% | 22.9 months | 6.2% annual |
| 1.0% | 12% | 11.5 months | 12.7% annual |
| 1.5% | 18% | 7.7 months | 19.7% annual |
| 2.0% | 24% | 5.8 months | 27.1% annual |

**Pattern:** Higher withdrawal rates shorten the break-even period but require higher discount rates to make holding attractive.

### 4.2 Sensitivity to Discount Rate

| Discount Rate | Break-Even at D=0.85 | PV of 12-Month Claim |
|---------------|---------------------|---------------------|
| 3% | 10.2 months | 0.867 BTC |
| 5% | 11.5 months | 0.842 BTC |
| 8% | 13.5 months | 0.808 BTC |
| 12% | 16.8 months | 0.763 BTC |
| 15% | 19.5 months | 0.730 BTC |

**Pattern:** Higher discount rates extend break-even periods (future redemption worth less) and reduce present values.

---

## 5. Model Limitations

### 5.1 Assumptions

1. **Rational redemption timing** — Actual holders may sub-optimize due to behavioral factors, transaction costs, or tax timing
2. **Risk-neutral framework** — Model ignores BTC price volatility and risk preferences
3. **Static liquidity premium** — In reality, liquidity varies with market conditions and pool depth
4. **No credit risk** — Assumes smart contract functions perfectly with no exploits
5. **Constant discount rate** — Real discount rates vary across market participants and over time

### 5.2 Extensions Not Covered

- **P-measure (real-world) pricing** incorporating BTC volatility
- **Jump-diffusion models** for BTC price dynamics
- **Liquidity-adjusted pricing** with endogenous spread determination
- **Game-theoretic equilibrium** between vault holders and vBTC buyers

---

## 6. Practical Applications

### 6.1 For vBTC Buyers

1. **Calculate break-even period** given current discount
2. **Compare to holding horizon** — if planning to hold longer than break-even, reconsider purchase
3. **Factor in transaction costs** — redemption requires gas; factor into net PV
4. **Monitor discount movements** — narrowing discount may justify early exit via sale rather than redemption

### 6.2 For Vault Holders (vBTC Sellers)

1. **Time separation strategically** — wider discounts mean selling patience at higher prices
2. **Consider partial sales** — sell portion of vBTC, retain optionality on remainder
3. **Factor in withdrawal stream** — vBTC sale is additive to ongoing 1% monthly withdrawals

### 6.3 For Market Makers / LPs

1. **Price vBTC near fair value** using PV_residual as anchor
2. **Widen spreads** when uncertainty about redemption behavior increases
3. **Manage inventory decay** — vBTC inventory loses value at 1% monthly regardless of BTC price

---

## 7. Conclusion

vBTC is a novel financial instrument best characterized as a **perpetual decaying forward contract**. Key findings:

1. **Optimal redemption timing** is finite and calculable given market discount and discount rate
2. **Break-even period** scales approximately logarithmically with discount depth
3. **Market price** decomposes into residual value, liquidity premium, and speculation premium
4. **At typical discounts (15%)**, buyers should redeem within ~12 months to capture value

The model provides a framework for rational pricing and behavior, though real-world application requires adjusting for transaction costs, taxes, and behavioral factors not captured in the risk-neutral framework.

---

## Further Reading

- [Time-Preference Primer](./Time_Preference_Primer.md) — Foundational concepts and sensitivity analysis
- [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md) — Multi-decade strategy projections
- [Bitcoin Holder Conversation Script](./Bitcoin_Holder_Conversation_Script.md) — Practical explanations for Bitcoin-native audiences
