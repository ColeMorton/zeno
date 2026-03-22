# Personal Brand: The Ascent Campaign Design

> **Version:** 3.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [The Ascent Design](../../The_Ascent_Design.md) - Conceptual framework and visual design
> - [Achievements Specification](../../Achievements_Specification.md) - Technical implementation details
> - [Brand Design](./Brand_Design.md) - Visual identity and series model

---

## Table of Contents

1. [Overview](#1-overview)
2. [Achievement Quick Reference](#2-achievement-quick-reference)
3. [Launch Window Strategy](#3-launch-window-strategy)
4. [Communication Templates](#4-communication-templates)
5. [Referral Program](#5-referral-program)
6. [Key Performance Indicators](#6-key-performance-indicators)
7. [Configuration Checklist](#7-configuration-checklist)

---

## 1. Overview

This document provides the campaign implementation guide for a Personal Brand issuer launching **The Ascent** on the BTCNFT Protocol.

> *"The mountain has always been here. It will always be here. The only question is: when do you begin your climb?"*

For the complete conceptual framework, see [The Ascent Design](../../The_Ascent_Design.md). For technical achievement definitions and contract interfaces, see [Achievements Specification](../../Achievements_Specification.md).

---

## 2. Achievement Quick Reference

| Layer | Achievement | Trigger |
|-------|-------------|---------|
| **1: Personal Journey** | CLIMBER | Mint vault |
| | TRAIL_HEAD | 30 days held |
| | BASE_CAMP | 91 days held |
| | RIDGE_WALKER | 182 days held |
| | HIGH_CAMP | 365 days held |
| | SUMMIT_PUSH | 730 days held |
| | SUMMIT | 1129 days held |
| | SUMMITER | Vested + match |
| | MOUNTAINEER | Composite |
| **3: Launch Exclusives** | FIRST_ASCENT | vaultId < 100 |
| | DAWN_CLIMBER | Days 1-7 |
| | SECOND_PARTY | Days 8-14 |
| | SPRING_EXPEDITION | Days 1-30 |
| | ACCLIMATIZED | Held 90 days |
| **4: Community** | FIRST_CAIRN | TVL 10 BTC |
| | GROWING_PARTY | TVL 50 BTC |
| | GRAND_EXPEDITION | TVL 100 BTC |
| | SHERPA | 1 referral |
| | EXPEDITION_LEADER | 5 referrals |
| | LEGENDARY_GUIDE | 10 referrals |

> **Full Details:** [Achievements Specification](../../Achievements_Specification.md)

---

## 3. Launch Window Strategy

### Week 1: The Expedition Departs (Days 1-7)

**Narrative:** *"The expedition departs at first light."*

**Actions:**
- Announce launch across all channels
- First 100 mints earn FIRST_ASCENT achievement
- DAWN_CLIMBER window opens

**Message Template:**
> "The mountain has always been here. Today, you begin your climb. First 100 minters earn FIRST_ASCENT—among the pioneering party."

### Week 2: The Second Wave (Days 8-14)

**Narrative:** *"DAWN_CLIMBER window closes tonight. The second wave begins tomorrow."*

**Actions:**
- DAWN_CLIMBER window closes (Day 7)
- SECOND_PARTY window opens
- Announce first-week metrics

### Days 15-30: Establishing Camp

**Narrative:** *"The expedition establishes its foothold."*

**Actions:**
- Continue SPRING_EXPEDITION window
- Monitor TVL for FIRST_CAIRN threshold (10 BTC)
- Build community engagement

### Day 30: First Milestone

**Narrative:** *"Our earliest holders just claimed TRAIL_HEAD—first steps proven."*

**Actions:**
- SPRING_EXPEDITION window closes
- Earliest minters claim TRAIL_HEAD
- Announce holder count and retention stats

### Days 31-60: The Climb Continues

**Narrative:** *"New climbers continue arriving, each starting their own ascent."*

**Actions:**
- New monthly cohort forms (Month 2)
- Focus on retention and community
- SHERPA achievements accumulate via referrals

### Days 61-90: Acclimatization

**Narrative:** *"30 days until ACCLIMATIZED. The mountain tests resolve."*

**Actions:**
- ACCLIMATIZED eligibility builds for launch holders
- Continue welcoming new monthly cohorts
- Prepare for launch window close

### Day 90: Launch Complete

**Narrative:** *"The launch window closes. Launch exclusives are sealed in history."*

**Actions:**
- ACCLIMATIZED claimable for launch holders who held 90 days
- Launch exclusive achievements close permanently
- All future minters start personal journey without launch exclusives

---

## 4. Communication Templates

### For New Minters (Any Month)

**Welcome Message:**
> "Welcome to the mountain. Your climb begins today. In 30 days, you'll claim TRAIL_HEAD. In 91 days, BASE_CAMP. In 1129 days—the summit is yours."

**Cohort Assignment:**
> "You've joined the [MONTH YEAR] Climbing Party. [X] fellow climbers started with you this month. Look up—earlier parties mark the path ahead."

### For Existing Holders (Monthly Update)

**Progress Update:**
> "Day [X] of your climb. You're at [ALTITUDE]m ([ZONE NAME]). Next milestone: [NEXT_ACHIEVEMENT] in [DAYS] days."

**Cohort Update:**
> "Your climbing party ([COHORT]): [X]% still climbing. [Y] have reached [ZONE]. [Z] turned back."

### TVL Milestones

**FIRST_CAIRN (10 BTC):**
> "The first cairn is placed. 10 BTC—the expedition has established its first waypoint. All current holders can claim FIRST_CAIRN."

**GROWING_PARTY (50 BTC):**
> "The expedition swells. 50 BTC—what started as a few has become many."

**GRAND_EXPEDITION (100 BTC):**
> "A movement becomes legend. 100 BTC—the mountain has never seen an expedition this strong."

---

## 5. Referral Program

### Program Overview

Referrers earn achievements for bringing new climbers to the mountain:

| Achievement | Referrals | Tagline |
|-------------|-----------|---------|
| **SHERPA** | 1 | *"Guided another to the mountain"* |
| **EXPEDITION_LEADER** | 5 | *"Led a party upward"* |
| **LEGENDARY_GUIDE** | 10 | *"Many summits owe their success to you"* |

### Communication Templates

**Launch Message:**
> "Guide others to the mountain. Earn SHERPA with your first referral. Lead a party of 5 to become EXPEDITION_LEADER."

**First SHERPA:**
> "Our first guide has earned their badge. The path is being shared."

**First EXPEDITION_LEADER:**
> "[Name] has led 5 climbers to the trailhead. A true leader emerges."

**First LEGENDARY_GUIDE:**
> "[Name] has guided 10 to the mountain. Legend status achieved."

---

## 6. Key Performance Indicators

### Launch Window (First 90 Days)

| KPI | Target | Measurement |
|-----|--------|-------------|
| Vault Mints | 50+ | `VaultMinted` event count |
| Early Redemption Rate | <5% | `EarlyRedemption` / total mints |
| CLIMBER Claim Rate | >80% | CLIMBER claims / eligible vaults |
| 30-Day Retention | >90% | Holders at day 30 / total minters |

### Ongoing (Monthly)

| KPI | Target | Measurement |
|-----|--------|-------------|
| Monthly New Mints | 10+ | New vaults per month |
| Monthly Cohort Survival | >85% | Active / minted per cohort |
| Achievement Claim Rate | >70% | Claims / eligible |
| Referral Activity | Growing | SHERPA claims trend |

---

## 7. Configuration Checklist

### Pre-Launch Setup

- [ ] Deploy AchievementMinter contract
- [ ] Deploy LaunchMinter contract with 90-day window
- [ ] Authorize both minters on AchievementNFT
- [ ] Configure TVL milestone thresholds (10/50/100 BTC)
- [ ] Set genesis vault cap (100)
- [ ] Configure referral tracking
- [ ] Prepare keeper for TVL recording

### Launch Day

- [ ] Verify all contracts active
- [ ] Confirm achievement claiming works
- [ ] Announce "The expedition departs at first light"
- [ ] Begin community monitoring

### Ongoing

- [ ] Monitor KPIs weekly
- [ ] Record TVL milestones when crossed
- [ ] Welcome new monthly cohorts
- [ ] Communicate holder progress updates
- [ ] Celebrate referral milestones

---

## Navigation

[Personal Brand Example](./README.md) | [The Ascent Design](../../The_Ascent_Design.md) | [Achievements Specification](../../Achievements_Specification.md)
