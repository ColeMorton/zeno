# BTCNFT Protocol Quantitative Validation

> **Version:** 1.5
> **Status:** Draft
> **Last Updated:** 2025-12-12
> **Related Documents:**
> - [Product Specification](./Product_Specification.md)
> - [Technical Specification](./Technical_Specification.md)
> - [Market Analysis](../issuer/Market_Analysis.md)

> **Disclaimer:** This analysis is based on historical BTC price data from 2017-2025. Past performance does not guarantee future results. The data period includes significant institutional adoption and may not be representative of future market conditions. vestedBTC is BTC-denominated (not pegged to USD). "Stability" refers to historical patterns, not a forward-looking guarantee.

---

## Table of Contents

1. [Data Source](#1-data-source)
2. [Core Stability Constraint](#2-core-stability-constraint)
3. [Historical Return Distribution](#3-historical-return-distribution)
4. [Tail-Risk Analysis](#4-tail-risk-analysis)
5. [Sensitivity Analysis](#5-sensitivity-analysis)
6. [Data Sample Limitations](#6-data-sample-limitations)
7. [Risk Acknowledgment](#7-risk-acknowledgment)

---

## 1. Data Source

**1129-Day Moving Average Analysis**

| Metric | Value |
|--------|-------|
| Data range | 2017-09-13 to 2025-09-20 |
| Total data points | 2,930 daily observations |
| Monthly samples | 96 |
| Yearly samples (rolling) | 2,565 |
| 1129-Day samples (rolling) | 1,837 |

---

## 2. Core Stability Constraint

For USD value to never decrease over window of `n` months:

```
(1-w)^n × (1+g)^n ≥ 1
```

Where:
- `w` = monthly withdrawal rate
- `g` = monthly return
- `n` = number of months in window

---

## 3. Historical Return Distribution

| Window | Samples | Mean | Min | Max |
|--------|---------|------|-----|-----|
| Monthly | 96 | 4.61% | 0.18% | 35.54% |
| Yearly | 2,565 | 63.11% | 14.75% | 346.81% |
| 1129-Day | 1,837 | 313.07% | 77.78% | 902.96% |

---

## 4. Tail-Risk Analysis

| Window | Mean | Std Dev | 1-SD Threshold | 2-SD Threshold |
|--------|------|---------|----------------|----------------|
| Monthly | 4.61% | 5.08% | -0.47% | -5.56% |
| Yearly | 63.11% | 57.25% | 5.86% | -51.39% |
| 1129-Day | 313.07% | 163.39% | 149.68% | -13.72% |

**Key Finding:** The 1129-day MA smoothing eliminates all tail events below SD thresholds for Monthly and Yearly windows.

---

## 5. Sensitivity Analysis

### What If Returns Fall Below Historical Mean?

| Scenario | Yearly Return | Conservative Tier | Impact |
|----------|---------------|-------------------|--------|
| Historical mean | +63.11% | -12% withdrawal | **Net +51.1%** |
| 50% of mean | +31.6% | -12% withdrawal | **Net +19.6%** |
| 25% of mean | +15.8% | -12% withdrawal | **Net +3.8%** |
| Breakeven | +12% | -12% withdrawal | **Net 0%** |
| Below breakeven | <+12% | -12% withdrawal | **Net negative** |

**Breakeven Analysis:**
- The fixed withdrawal rate requires **+12%** annual BTC appreciation to maintain USD value

> For tier research history, see [Withdrawal Tier Research](../research/Withdrawal_Tier.md)

### Historical Context

| Period | BTC Annual Return | Would Conservative Tier Hold Value? |
|--------|-------------------|-------------------------------------|
| 2018 (bear) | -73% | No |
| 2019 | +95% | Yes |
| 2020 | +303% | Yes |
| 2021 | +60% | Yes |
| 2022 (bear) | -64% | No |
| 2023 | +155% | Yes |
| 2024 | +121% | Yes |

**Note:** Individual years can show negative returns. The 1129-day vesting period is designed to smooth volatility across market cycles.

---

## 6. Data Sample Limitations

### Known Limitations

| Limitation | Description |
|------------|-------------|
| **Sample period** | 2017-2025 only (~8 years) |
| **Bull market bias** | Period includes unprecedented institutional adoption |
| **Survivorship** | BTC survived; other assets may not |
| **Macro environment** | Low interest rates, QE for most of period |
| **Black swan events** | COVID crash included, but limited other extreme events |

### What This Means

1. **Historical patterns may not repeat** - Future BTC performance may differ materially
2. **Correlation changes** - BTC correlation to other assets has evolved over time
3. **Regulatory risk** - Not captured in price data
4. **Technical risk** - Smart contract bugs, bridge exploits not modeled

---

## 7. Risk Acknowledgment

> **Important:** This quantitative analysis is for informational purposes only. It is based on historical data and does not constitute financial advice or a guarantee of future performance.
>
> **Key risks include:**
> - BTC price could decline more than historical patterns suggest
> - Extended bear markets could exceed the vesting period
> - Smart contract risk is separate from price risk
> - Regulatory changes could impact the protocol
>
> **Users should:**
> - Only invest what they can afford to lose
> - Understand that past performance ≠ future results
> - Consult financial advisors before participating
> - Conduct their own research
