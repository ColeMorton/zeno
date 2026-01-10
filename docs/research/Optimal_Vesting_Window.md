# Optimal Vesting Window Analysis

> **Version:** 1.0
> **Status:** Research
> **Last Updated:** 2025-12-23
> **Related Documents:**
> - [Vesting Period](./Vesting_Period.md)
> - [Vision and Mission](./Vision_and_Mission.md)
> - [Quantitative Validation](../protocol/Quantitative_Validation.md)

---

> **Implementation Status:** ✅ IMPLEMENTED
>
> This document's primary recommendation (increase vesting period to 1129 days) has been implemented in the protocol. The current immutable vesting period is **1129 days**. This document is retained as historical research demonstrating the analytical basis for the 1129-day parameter.

---

## Executive Summary

This analysis identifies the optimal vesting window for the BTCNFT Protocol using four distinct optimization objectives. The analysis was conducted when the vesting window was 1093 days; the recommendation to increase to 1129 days has since been **implemented**.

**Key Findings:**

| Objective | Optimal Window | Current (1093) Status |
|-----------|----------------|----------------------|
| Conservative (100% positive) | **1129 days** | 99.7% positive |
| Practical (99.5%+, 95% BE) | **1122 days** | Does not meet BE threshold |
| Risk-adjusted (max Sharpe) | 30 days | N/A (different purpose) |
| Robustness (cross-period) | **1100 days** | Within range |

**Recommendation (IMPLEMENTED):** The protocol now uses **1129 days** (3.09 years), achieving 100% positive historical returns across all rolling windows in the 2017-2025 dataset.

---

## Methodology

### Data Source

| Metric | Value |
|--------|-------|
| Data range | 2014-09-17 to 2025-12-22 |
| Observations | 4,115 daily prices |
| Window range tested | 30 to 2,000 days |
| Step size | 7 days |
| Total windows analyzed | 282 |

### Four Optimization Objectives

1. **Conservative**: Minimize window where 100% of samples are positive
2. **Practical**: Minimize window where P(positive) ≥ 99.5% AND P(breakeven) ≥ 95%
3. **Risk-adjusted**: Maximize Sharpe ratio
4. **Robustness**: Consistent optimal across all sample periods

---

## Results

### Threshold Analysis

**Minimum window to achieve P(positive) threshold:**

| Threshold | Window (days) | Years |
|-----------|---------------|-------|
| 95.0% | 1,038 | 2.84 |
| 99.0% | 1,087 | 2.98 |
| 99.5% | 1,094 | 3.00 |
| **100.0%** | **1,129** | **3.09** |

**Minimum window to achieve P(breakeven) threshold:**

| Threshold | Window (days) | Years |
|-----------|---------------|-------|
| 90.0% | 1,017 | 2.79 |
| 95.0% | 1,122 | 3.07 |
| 99.0% | 1,346 | 3.69 |
| 100.0% | 1,367 | 3.74 |

### Optimal Windows by Objective

| Objective | Optimal Days | P(positive) | P(breakeven) | Sharpe | Confidence |
|-----------|--------------|-------------|--------------|--------|------------|
| Conservative | 1,129 | 100.0% | 96.0% | 0.51 | High |
| Practical | 1,122 | 99.8% | 95.4% | 0.52 | High |
| Risk-adjusted | 30 | 56.7% | 54.9% | 1.39 | High |
| Robustness | 1,100 | 99.8% | 93.0% | 0.53 | Low |

### Cross-Validation Across Periods

| Period | Observations | 99.5% Window | 100% Window |
|--------|--------------|--------------|-------------|
| Full (2014-2025) | 4,115 | 1,093 days | 1,107 days |
| Early (2014-2019) | 1,932 | 778 days | 792 days |
| Recent (2019-2025) | 2,548 | 1,100 days | 1,107 days |

**Key Insight:** The early period (2014-2019) requires a significantly shorter window due to extreme volatility in both directions. The recent period (2019-2025) is more representative of mature BTC behavior.

---

## Analysis of Current 1093-Day Window

### Performance Metrics

| Metric | Value |
|--------|-------|
| P(positive) | 99.70% |
| P(breakeven) | 92.52% |
| Mean return | +801% |
| Min return | -10.01% |
| Max return | +7,427% |
| Std deviation | 1,057% |

### Gap Analysis

| Target | Required | Current | Gap |
|--------|----------|---------|-----|
| 100% positive | 1,129 days | 1,093 days | +36 days |
| 95% breakeven | 1,122 days | 1,093 days | +29 days |
| 99% breakeven | 1,346 days | 1,093 days | +253 days |

---

## Findings by Objective

### 1. Conservative (100% Positive)

**Optimal: 1,129 days (3.09 years)**

To achieve zero negative historical windows, the vesting period must increase by 36 days from the current 1,093.

```
Current:    1093 days → 99.70% positive (9 negative windows)
Optimal:    1129 days → 100.00% positive (0 negative windows)
Difference: +36 days (+3.3%)
```

**Implication:** The 36-day gap represents the buffer needed to absorb the worst early-period volatility (2014-2017 Mt. Gox era).

### 2. Practical (99.5% Positive + 95% Breakeven)

**Optimal: 1,122 days (3.07 years)**

Balancing user experience with safety, a 1,122-day window achieves both thresholds:
- P(positive) = 99.83%
- P(breakeven) = 95.42%

The current 1,093-day window fails the breakeven threshold (92.5% < 95%).

### 3. Risk-Adjusted (Max Sharpe)

**Optimal: 30 days (1 month)**

The Sharpe ratio is maximized at very short windows due to BTC's high short-term volatility and return potential. However, this objective conflicts with the protocol's mission of volatility smoothing.

**This objective is informational only and not recommended for protocol design.**

### 4. Robustness (Cross-Period Consistency)

**Optimal: 1,100 days (3.01 years)**

The robust window is derived by taking the maximum optimal window across all sample periods. However, confidence is **Low** due to significant variation:

| Period | Optimal (99.5%) |
|--------|-----------------|
| Early (2014-2019) | 778 days |
| Recent (2019-2025) | 1,100 days |
| **Range** | **322 days** |

The 322-day range indicates sample-period sensitivity. The early period's extreme volatility both up and down leads to a shorter optimal window.

---

## Recommendations

### Primary Recommendation

For **absolute safety** consistent with the protocol's vision:

```
Recommended: 1,129 days (3.09 years)

Change from current: +36 days (+3.3%)
Benefit: 100% historical positive returns
Cost: Minimal UX impact (+1.2 months)
```

### Alternative: Status Quo with Disclosure

If maintaining 1,093 days:

```
Disclosure: "99.7% of historical 1093-day windows showed positive returns.
            9 out of 3,022 windows showed negative returns, all from
            entries during the 2014-2017 early adoption period."
```

### Alternative: Practical Compromise

For balance between safety and UX:

```
Compromise: 1,094 days (exactly 3 years × 365.33)

Achieves: 99.5% positive, 93% breakeven
Trade-off: +1 day from current, significant breakeven improvement
```

---

## Sensitivity Analysis

### Impact of Sample Period

The 1093-day window achieves **100% positive** when analyzed with 2017-2025 data (as in original documentation). The 9 negative windows all originate from entries during 2014-2017.

| Sample Period | 1093-Day Positive % |
|---------------|---------------------|
| 2014-2025 (full) | 99.70% |
| 2017-2025 (docs) | 100.00% |
| 2019-2025 (recent) | 99.93% |

**Implication:** If the protocol launches with BTC at mature-phase valuations, the 1093-day window is effectively optimal. The 9 negative windows are artifacts of the extreme early-adoption period.

### Forward-Looking Adjustment

If BTC returns compress toward gold equilibrium (~8% CAGR), longer windows may be required. However, this analysis uses historical data only and does not incorporate forward projections.

---

## Conclusion

The current 1093-day vesting period is **near-optimal** for the 2014-2025 dataset:

| Criterion | 1093 Days | 1129 Days | Delta |
|-----------|-----------|-----------|-------|
| P(positive) | 99.70% | 100.00% | +0.30% |
| P(breakeven) | 92.52% | 96.00% | +3.48% |
| UX (wait time) | 2.99 years | 3.09 years | +36 days |

**For absolute safety:** Increase to **1,129 days**
**For practical balance:** Current 1,093 days is acceptable with appropriate disclosure

---

## Data Sources

All analysis performed using:
- `analysis/results/window_sweep.json` - Full sweep statistics
- `analysis/results/threshold_windows.json` - Threshold analysis
- `analysis/results/cross_validation.json` - Period robustness
- `analysis/results/optimal_window_report.json` - Final report

Generated by: `analysis/scripts/optimize_vesting.py`
