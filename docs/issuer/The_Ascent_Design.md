# The Ascent: Personal Journey Design

> **Version:** 3.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Achievements Specification](./Achievements_Specification.md) - Technical implementation details
> - [Campaign Design Example](./examples/personal-brand/Campaign_Design.md) - Implementation playbook

---

## Table of Contents

1. [Overview](#1-overview)
2. [Core Concept: The Eternal Mountain](#2-core-concept-the-eternal-mountain)
3. [Four-Layer Architecture](#3-four-layer-architecture)
4. [Layer 1: Personal Journey](#4-layer-1-personal-journey)
5. [Layer 2: Cohort Identity](#5-layer-2-cohort-identity)
6. [Layer 3: Launch Exclusives](#6-layer-3-launch-exclusives)
7. [Layer 4: Community Milestones](#7-layer-4-community-milestones)
8. [Visual Identity](#8-visual-identity)
9. [Holder Stories](#9-holder-stories)

---

## 1. Overview

This document defines **The Ascent**—a perpetual personal journey framework for issuer achievement systems on the BTCNFT Protocol.

### The Mountain Is Not a Calendar

Unlike seasonal campaigns tied to calendar dates, **The Ascent is a personal journey**. Your altitude on the mountain is determined by how long you've held your vault—not by what month it is.

> *"The mountain has always been here. It will always be here. The only question is: when do you begin your climb?"*

### Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Personal journey** | Each holder's Ascent begins at their mint timestamp |
| **Altitude = days held** | Position on mountain determined by holding duration |
| **Monthly cohorts** | Wallets minting in same month form visual identity groups |
| **Four-layer separation** | Personal journey, cohort identity, launch exclusives, and community milestones are distinct |
| **Issuer-layer achievements** | All achievements deployed by issuer, not protocol |

---

## 2. Core Concept: The Eternal Mountain

The Ascent is always available—new climbers start their personal 1129-day journey whenever they mint, joining a monthly cohort of fellow climbers.

```
THE ETERNAL MOUNTAIN
                              ^
                             /|\  SUMMIT (1129d held)
                            / | \     | Summited climbers
                           /  |  \
                          /   |   \   HIGH CAMP (365d)
                         /    |    \     | Year-one veterans
                        /     |     \
                       /      |      \  RIDGE LINE (182d)
                      /       |       \    | Half-year holders
                     /        |        \
                    /         |         \ BASE CAMP (91d)
                   /          |          \   | Quarter-stack holders
                  /           |           \
                 /            |            \ TRAIL HEAD (30d)
                /             |             \  | First-month holders
               ----------------+----------------
                              |
              NEW CLIMBERS ---+--- Arriving today, starting their ascent
```

### Thematic Elements

| Element | Protocol Concept | Narrative Translation |
|---------|------------------|----------------------|
| Vault | Position | Your foothold on the mountain |
| Mint timestamp | Journey start | The day you arrived at the trailhead |
| Days held | Altitude | How high you've climbed |
| Vesting (1129d) | Summit | The peak—perpetual access unlocked |
| Monthly cohort | Climbing party | Fellow climbers who started with you |
| Collateral | BTC deposit | Supplies for the journey |
| Withdrawal | Post-vesting access | Harvesting from the peak |
| Early redemption | Forfeit + exit | Turning back; supplies go to those who continue |
| Match pool | Forfeited collateral | Abandoned camps, claimed by continuing climbers |

---

## 3. Four-Layer Architecture

The achievement system separates concerns into four distinct layers:

```
+-------------------------------------------------------------------+
|  LAYER 1: THE ASCENT (Personal Journey)                           |
|  +- Starts at YOUR mint timestamp                                 |
|  +- Altitude = days held                                          |
|  +- CLIMBER -> TRAIL_HEAD -> BASE_CAMP -> ... -> SUMMIT           |
+-------------------------------------------------------------------+
|  LAYER 2: COHORT IDENTITY (Monthly Climbing Parties)              |
|  +- Everyone who mints in same month = same party                 |
|  +- Visual badge: "October 2025 Climbing Party"                   |
|  +- NO ACHIEVEMENTS - visual identity only                        |
+-------------------------------------------------------------------+
|  LAYER 3: LAUNCH EXCLUSIVES (Issuer Launch Window Only)           |
|  +- FIRST_ASCENT (first 100 minters for this issuer)              |
|  +- DAWN_CLIMBER (first 7 days of issuer launch)                  |
|  +- Only available during issuer's launch window                  |
+-------------------------------------------------------------------+
|  LAYER 4: COMMUNITY MILESTONES (Issuer-Tracked Metrics)           |
|  +- TVL milestones (FIRST_CAIRN, GROWING_PARTY, etc.)             |
|  +- Referrals (SHERPA, EXPEDITION_LEADER, LEGENDARY_GUIDE)        |
|  +- Tracks protocol metrics but issued by issuer contracts        |
+-------------------------------------------------------------------+
```

### Key Distinction: Personal Journey vs Calendar

| Old Model (Calendar-Based) | New Model (Personal Journey) |
|---------------------------|------------------------------|
| Everyone starts/ends together | Each holder starts at mint |
| Achievements tied to calendar dates | Achievements tied to days held |
| "Season 1, Season 2" | Perpetual journey |
| Campaign fatigue | Always welcoming new climbers |

---

## 4. Layer 1: Personal Journey

Every holder's Ascent begins at their mint timestamp. Achievements unlock based on **days held**, not calendar dates.

### Altitude Progression

```
YOUR ASCENT (starts at YOUR mint timestamp)
-------------------------------------------------------------------

Day 0 ---------- CLIMBER ----------- "Began the ascent"
     |           You arrive at the trailhead
     |
Day 30 --------- TRAIL_HEAD -------- "First steps taken"
     |           First camp established
     |
Day 91 --------- BASE_CAMP --------- "Established your position"
     |           The mountain proper begins
     |
Day 182 -------- RIDGE_WALKER ------ "Above the tree line"
     |           Exposure, commitment
     |
Day 365 -------- HIGH_CAMP --------- "Thin air, strong lungs"
     |           One year. Many turn back here.
     |
Day 730 -------- SUMMIT_PUSH ------- "The final ascent begins"
     |           Two years. The death zone awaits.
     |
Day 1129 ------- SUMMIT ------------ "The peak is yours"
     |           Vesting complete. Perpetual access unlocked.
     |
     +--------- SUMMITER ----------- "Reached the peak"
                 (After claiming match)
                        |
                        +--- MOUNTAINEER -- "Returns for another summit"
                             (Composite: mint new vault)
```

### Dependency Graph

```
                              [MINT VAULT]
                                   |
                                   v
                               CLIMBER
                           "Began the ascent"
                                   |
                                   v
                          [THE CLIMB - DURATION]
                                   |
                                   v
                              TRAIL_HEAD (30d)
                             "First steps taken"
                                   |
                                   v
                              BASE_CAMP (91d)
                          "Established your position"
                                   |
                                   v
                            RIDGE_WALKER (182d)
                           "Above the tree line"
                                   |
                                   v
                             HIGH_CAMP (365d)
                         "Thin air, strong lungs"
                                   |
                                   v
                           SUMMIT_PUSH (730d)
                        "The final ascent begins"
                                   |
                                   v
                              SUMMIT (1129d)
                           "The peak is yours"
                                   |
                                   v
                              SUMMITER
                           "Reached the peak"
                          (vested + match)
                                   |
                                   v
                            MOUNTAINEER
                      "Returns for another summit"
```

> **Technical Details:** See [Achievements Specification](./Achievements_Specification.md) for complete achievement definitions, contract interfaces, and verification requirements.

---

## 5. Layer 2: Cohort Identity

### How Cohorts Form

Each calendar month, a new **climbing party** forms at the trailhead. Everyone who mints during that month shares cohort identity.

| Mint Month | Cohort Name | Badge |
|------------|-------------|-------|
| October 2025 | October 2025 Climbing Party | OCT-25 |
| November 2025 | November 2025 Climbing Party | NOV-25 |
| December 2025 | December 2025 Climbing Party | DEC-25 |

### Cohort Properties

| Property | Description |
|----------|-------------|
| **Formation** | All wallets minting in the same calendar month |
| **Identity** | Shared badge/visual identifier |
| **Progress tracking** | See your party's current altitude distribution |
| **Survival rate** | What % of your party is still climbing |

### Visual: The Mountain with Parties

```
                         ^ SUMMIT
                        /|\
     OCT-25 Party -->  / | \  <-- Some have summited
                      /  |  \
     NOV-25 Party -> /   |   \  HIGH CAMP
                    /    |    \
     DEC-25 Party -/     |     \  RIDGE LINE
                  /      |      \
     JAN-26 ---->/       |       \  BASE CAMP
                /        |        \
     FEB-26 -->/         |         \ TRAIL HEAD
              -----------+------------
                         |
     MAR-26 -------------+  (Just arrived)
```

### Cohort as Visual Only

**Cohorts do NOT provide achievements.** Cohort identity is purely visual:

- Monthly cohort badge (e.g., "OCT-25")
- Cohort survival rate visibility
- Fellow climber progress tracking

All holders earn The Ascent achievements based on their personal journey duration.

---

## 6. Layer 3: Launch Exclusives

These achievements are **only available during the issuer's launch window**—they cannot be earned by later minters.

### Genesis Recognition

| Class | Vault IDs | Name | Tagline |
|-------|-----------|------|---------|
| Founder | 0-9 | **ROUTE_SETTER** | *"Marked the path where none existed"* |
| Early | 10-49 | **LEAD_CLIMBER** | *"Set the pace for those behind"* |
| Genesis | 50-99 | **FIRST_ASCENT** | *"Joined the pioneer party"* |

### Launch Window Timing

| Achievement | Window | Tagline |
|-------------|--------|---------|
| **DAWN_CLIMBER** | Days 1-7 | *"Started at first light"* |
| **SECOND_PARTY** | Days 8-14 | *"Joined the second wave"* |
| **SPRING_EXPEDITION** | Days 1-30 | *"Departed in the first window"* |
| **ACCLIMATIZED** | Held through 90 days | *"Adapted to the altitude"* |

> **Implementation Details:** See [Campaign Design Example](./examples/personal-brand/Campaign_Design.md) for launch window playbook.

---

## 7. Layer 4: Community Milestones

These achievements commemorate community growth and contribution. They are deployed by the issuer but track protocol-wide metrics.

### TVL Milestones

| Achievement | Trigger | Tagline |
|-------------|---------|---------|
| **FIRST_CAIRN** | TVL crossed 10 BTC | *"Witnessed the first waypoint"* |
| **GROWING_PARTY** | TVL crossed 50 BTC | *"Witnessed the expedition swell"* |
| **GRAND_EXPEDITION** | TVL crossed 100 BTC | *"Witnessed a movement become legend"* |

### Referral Achievements

| Achievement | Referrals | Tagline |
|-------------|-----------|---------|
| **SHERPA** | 1 | *"Guided another to the mountain"* |
| **EXPEDITION_LEADER** | 5 | *"Led a party upward"* |
| **LEGENDARY_GUIDE** | 10 | *"Many summits owe their success to you"* |

> **Technical Details:** See [Achievements Specification](./Achievements_Specification.md) for TVL recording and referral tracking contracts.

---

## 8. Visual Identity

### Visual Identity by Altitude

| Altitude | Days Held | Zone Name | Color | Imagery |
|----------|-----------|-----------|-------|---------|
| 0m | 0 | Trailhead | Forest green | Pine trees, trail markers |
| 1000m | 30 | First Camp | Sage green | First campfire, settling in |
| 2000m | 91 | Base Camp | Stone gray | Tents, flags, established |
| 3000m | 182 | Ridge Line | Ice blue | Above tree line, exposure |
| 4000m | 365 | High Camp | Steel gray | Thin air, commitment |
| 5000m | 730 | Death Zone | White | Snow, wind, stars |
| 5895m | 1129 | Summit | Radiant gold | Peak, endless view |

### Profile Display

```
+-----------------------------------------------------+
|  OCT-25  |  Vault #42  |  Day 400                   |
+-----------------------------------------------------+
|                                                     |
|  ALTITUDE: 4000m (HIGH CAMP)                        |
|  ||||||||||||||||||||--------  35% to summit        |
|                                                     |
|  NEXT MILESTONE: SUMMIT_PUSH (Day 730)              |
|  ===========================================        |
|                                                     |
|  ACHIEVEMENTS:                                      |
|  [CLIMBER] [TRAIL_HEAD] [BASE_CAMP]                 |
|  [RIDGE_WALKER] [HIGH_CAMP]                         |
|                                                     |
|  LAUNCH: [FIRST_ASCENT] [DAWN_CLIMBER]              |
|                                                     |
+-----------------------------------------------------+
```

### Mountain View (Cohort Visibility)

```
THE MOUNTAIN - October 2025 Climbing Party (your cohort)
---------------------------------------------------------

                    ^ SUMMIT (5895m)
                   / \
                  /   \  o 2 summited
                 /     \
                /-------\  HIGH CAMP (4000m)
               /    *    \  <-- YOU ARE HERE
              /   o o o   \  + 4 others
             /-------------\  RIDGE LINE (3000m)
            /       o       \  1 at this altitude
           /-----------------\  BASE CAMP (2000m)
          /                   \  (empty - all progressed)
         /---------------------\  TRAIL HEAD (1000m)
        -------------------------  (empty)

        x 3 turned back (early redemption)
        * = You   o = Fellow party members
```

---

## 9. Holder Stories

### Launch Minter (Vault #42, October 2025)

```
COHORT: October 2025 Climbing Party (Badge: OCT-25)

LAUNCH EXCLUSIVES (earned once, forever):
+- FIRST_ASCENT (LEAD_CLIMBER) -- "Set the pace for those behind"
+- DAWN_CLIMBER ----------------- "Started at first light"
+- SPRING_EXPEDITION ------------ "Departed in the first window"
+- ACCLIMATIZED ----------------- "Adapted to the altitude"

THE ASCENT (personal journey, day 400):
+- CLIMBER ---------------------- "Began the ascent"
+- TRAIL_HEAD (30d) ------------- "First steps taken"
+- BASE_CAMP (91d) -------------- "Established your position"
+- RIDGE_WALKER (182d) ---------- "Above the tree line"
+- HIGH_CAMP (365d) ------------- "Thin air, strong lungs"
    +- [Currently at 4000m altitude]

COMMUNITY MILESTONES (issuer-tracked):
+- FIRST_CAIRN ------------------ "Witnessed the first waypoint"
+- SHERPA ----------------------- "Guided another to the mountain"
```

### Later Minter (March 2027)

```
COHORT: March 2027 Climbing Party (Badge: MAR-27)

LAUNCH EXCLUSIVES: None (joined after launch window)

THE ASCENT (personal journey, day 180):
+- CLIMBER ---------------------- "Began the ascent"
+- TRAIL_HEAD (30d) ------------- "First steps taken"
+- BASE_CAMP (91d) -------------- "Established your position"
+- [Currently at 2800m altitude, approaching RIDGE_WALKER]

COMMUNITY MILESTONES (issuer-tracked):
+- GROWING_PARTY ---------------- "Witnessed the expedition swell"
```

---

## Navigation

[Issuer Layer](./README.md) | [Achievements Specification](./Achievements_Specification.md) | [Campaign Design Example](./examples/personal-brand/Campaign_Design.md)
