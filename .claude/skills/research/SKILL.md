---
name: research
description: "Protocol Research Knowledge Base for BTCNFT Protocol. Centralized management of all research documents covering protocol economics, deployment feasibility, financial engineering, competitive analysis, and architecture decisions. Use this skill whenever the user mentions: research, references, vesting analysis, withdrawal rate, 1129-day, competitive positioning, deployment feasibility, L2 viability, RGB protocol, Bitcoin deployment, collateral architecture, return regime, quantitative validation, protocol lifespan, delegation marketplace, vBTC pricing, time-preference, volatility farming, Peapods, Sablier streaming, long-duration strategies, market analysis, or any work involving .claude/skills/research/references/. Also trigger when the user wants to create new research, update existing research, archive or delete research documents, understand protocol parameter rationale, explore deployment options, or review financial engineering models. Trigger proactively when research context would inform the user's question about protocol design decisions."
---

# Protocol Research Knowledge Base

You are the custodian of the BTCNFT Protocol's research corpus — 25 documents spanning protocol economics, deployment strategy, financial engineering, and competitive positioning. Your role is to help users navigate, query, create, maintain, and evolve this knowledge base.

For research **methodology** (how to conduct new research, statistical rigor, validation frameworks), read `.claude/commands/researcher.md` which defines the Protocol Research Specialist role with domain expertise, output standards, and analysis templates.

## Initialization

Read documents based on what the user needs:

| User Need | Read First |
|-----------|------------|
| Protocol parameters (why 1129 days, why 12%) | `Vesting_Period.md`, `Withdrawal_Rate_Stability.md`, `Optimal_Vesting_Window.md` |
| Economic sustainability / failure modes | `Return_Regime_Analysis.md`, `Optimal_Withdrawal_Rate.md`, `Quantitative_Validation.md` |
| Where to deploy | `L2_Deployment_Viability.md`, `Blockchain_Infrastructure_Assessment.md`, `Protocol_Lifespan_Assessment.md` |
| Native Bitcoin deployment | `Bitcoin_Deployment_Feasibility.md`, `RGB_Viability_Assessment.md` |
| Competitive landscape | `Competitive_Positioning.md`, `Bitcoin_Holder_Conversation_Script.md` |
| Financial models / pricing | `vBTC_Pricing_Model.md`, `Time_Preference_Primer.md`, `Long_Duration_Capital_Strategies.md` |
| DeFi integrations | `Sablier_Streaming_Integration.md`, `Delegation_Marketplace_Assessment.md`, `Peapods_Finance_Analysis.md`, `Native_Volatility_Farming_Architecture.md` |
| Collateral design | `Collateral_Architecture.md` |
| Protocol philosophy | `Vision_and_Mission.md` |
| Full knowledge base overview | `references/README.md` |

For a navigable index with links, see `references/README.md`.

## Research Taxonomy

### Foundational (Protocol Identity)

| Document | Purpose | Status |
|----------|---------|--------|
| `Vision_and_Mission.md` | 1129-day SMA insight, Zeno's paradox withdrawal, protocol philosophy | Final |
| `Vesting_Period.md` | 1129-day derivation, historical validation, early redemption mechanics | Final |
| `Withdrawal_Rate_Stability.md` | 12% rate duality (BTC decay vs USD stability), calibration insight | Final |

### Parameter Optimization

| Document | Purpose | Status |
|----------|---------|--------|
| `Quantitative_Validation.md` | Historical BTC data (2017-2025), 1,837 rolling windows, tail-risk analysis | Final |
| `Optimal_Vesting_Window.md` | Sensitivity analysis (30-2000 days), 4 optimization objectives, why 1129 not 1093 | Research |
| `Optimal_Withdrawal_Rate.md` | Rate-to-CAGR mapping, 12% derivation from 25th-percentile expected CAGR | Research |
| `Return_Regime_Analysis.md` | Gold precedent, diminishing returns, 15-25% failure probability over 10yr | Research |
| `Withdrawal_Tier.md` | Archived: why single 12% rate over 3-tier system | Archived |

### Deployment Feasibility

| Document | Purpose | Status |
|----------|---------|--------|
| `Protocol_Lifespan_Assessment.md` | 20-year Ethereum viability, compound probability model, risk factors | Research |
| `L2_Deployment_Viability.md` | Base (primary) + Arbitrum (secondary), Stage 1 status, cbBTC availability | Research |
| `Blockchain_Infrastructure_Assessment.md` | Ethereum L1 vs Arbitrum vs Base gas economics, timestamp reliability | Research |
| `Bitcoin_Deployment_Feasibility.md` | Native BTC deployment via Ordinals, Runes, RGB, BitVM, covenants | Research |
| `RGB_Viability_Assessment.md` | RGB protocol evaluation, AluVM, client-side validation, 4-phase strategy | Research |

### Architecture

| Document | Purpose | Status |
|----------|---------|--------|
| `Collateral_Architecture.md` | 1:1 deployment per collateral vs whitelist multi-collateral, risk isolation | Research |

### Market & Positioning

| Document | Purpose | Status |
|----------|---------|--------|
| `Competitive_Positioning.md` | vs Strategy (MSTR), Strive (SATA), raw BTC, DeFi yield farming | Final |
| `Bitcoin_Holder_Conversation_Script.md` | Sales narrative for Bitcoin-native audience, vBTC discount arbitrage | Final |
| `Time_Preference_Primer.md` | First-principles explainer: time-preference, present value, discount rates | Final |

### Financial Engineering

| Document | Purpose | Status |
|----------|---------|--------|
| `vBTC_Pricing_Model.md` | Option-theoretic pricing, optimal stopping problem, break-even periods | Research |
| `Minting_Economics.md` | 0.005 WBTC reference unit, vault sizing, gas thresholds, multi-vault optionality | Research |
| `Bootstrap_Minting_Behavior.md` | Three-phase minting model during 1129-day bootstrap, xBTC gradient, DeFi precedents | Research |
| `Long_Duration_Capital_Strategies.md` | 30-50 year perpetual roll strategy, 6.55x net BTC multiplication | Research |
| `Peapods_Finance_Analysis.md` | Comparative: Peapods volatility farming vs BTCNFT yield mechanics | Research |
| `Native_Volatility_Farming_Architecture.md` | ERC-4626 yield vault (yvBTC) design for vestedBTC Curve LP | Research |
| `Delegation_Marketplace_Assessment.md` | On-chain orderbook for withdrawal delegation rights trading | Research |
| `Sablier_Streaming_Integration.md` | Convert discrete monthly withdrawals to continuous Sablier streams | Research |
| `vBTC_Ratio_Upper_Bound.md` | Why vbtcRatio is structurally bounded below 1.0 — arbitrage ceiling, decay, simulation gap | Research |

### Visual & Technical

| Document | Purpose | Status |
|----------|---------|--------|
| `SVG_Layer_Isolation_Plan.md` | Diamond Hands medallion SVG decomposition into 4 semantic layers | Technical |

## Document Lifecycle

### Creating a New Document

1. **Determine category** from the taxonomy above
2. **Name the file** using `Title_Case_With_Underscores.md` (match existing convention)
3. **Apply the document template** (below)
4. **Write the document** in `references/`
5. **Update `references/README.md`** — add a link in the correct category
6. **Add cross-references** — link to related documents in the new document's header and add back-references in related documents where appropriate

### Document Template

```markdown
# [Document Title]

> **Version:** 1.0
> **Status:** Research | Final | Technical | Archived
> **Last Updated:** YYYY-MM-DD
> **Related Documents:**
> - [Related Doc 1](./Related_Doc_1.md)
> - [Related Doc 2](./Related_Doc_2.md)

---

## Executive Summary

[1-3 paragraph summary of key findings and recommendations]

---

## Table of Contents

1. [Section 1](#1-section-1)
2. [Section 2](#2-section-2)
...

---

## 1. Section 1

[Content with tables, formulas, and data where applicable]

---

## References

### Internal
- `path/to/related/file.md` - Description

### External
- [Source Name](URL) - Description
```

### Updating a Document

- **Content revision**: Update the `Last Updated` date and increment version
- **Status transition**: Move from `Research` to `Final` when the research conclusion has been implemented in the protocol. Add implementation status note at top if applicable (see `Optimal_Vesting_Window.md` for example)
- **Update cross-references**: If the update changes conclusions that other documents depend on, update those documents' references too

### Archiving a Document

Archive when a document's conclusions have been **superseded** by a newer document or design decision:

1. Change status to `Archived` in the document header
2. Add an archive note at the top explaining what superseded it (see `Withdrawal_Tier.md` for example)
3. Move the entry to the "Archived" section in `references/README.md`
4. Do **not** delete — archived documents preserve decision history

### Deleting a Document

Delete only when a document contains **incorrect information that could mislead** and has no historical value. This should be rare — archiving is preferred.

1. Remove the file from `references/`
2. Remove the entry from `references/README.md`
3. Remove cross-references from other documents that linked to it
4. Verify no other skills or commands reference the deleted file

## Cross-Reference Standards

Documents should reference related documents in two places:

1. **Header**: `Related Documents` list in the frontmatter block
2. **Body**: Inline references where specific findings are cited, using relative links: `[Document Name](./Document_Name.md)`

When a document cites a specific finding from another document, include the section reference:
```markdown
From [Return Regime Analysis](./Return_Regime_Analysis.md) Section 4:
> Combined failure probability: 15-25% over 10 years
```

### Reference Graph (Key Dependencies)

```
Vision_and_Mission ──► Vesting_Period ──► Optimal_Vesting_Window
        │                    │
        ▼                    ▼
Withdrawal_Rate_Stability ──► Optimal_Withdrawal_Rate
        │                           │
        ▼                           ▼
Quantitative_Validation ◄── Return_Regime_Analysis
        │
        ▼
Protocol_Lifespan_Assessment ──► L2_Deployment_Viability
        │                              │
        ▼                              ▼
Bitcoin_Deployment_Feasibility    Blockchain_Infrastructure_Assessment
        │
        ▼
RGB_Viability_Assessment

Competitive_Positioning ◄── Bitcoin_Holder_Conversation_Script
                                    │
                               Time_Preference_Primer
                                    │
                               vBTC_Pricing_Model ──► Long_Duration_Capital_Strategies

Peapods_Finance_Analysis ──► Native_Volatility_Farming_Architecture

Collateral_Architecture (standalone)
Delegation_Marketplace_Assessment (standalone)
Sablier_Streaming_Integration (standalone)
SVG_Layer_Isolation_Plan (standalone)
```

## Quality Standards

Research documents in this knowledge base must:

- **State the research question** explicitly in the executive summary
- **Cite data sources** with date ranges, sample sizes, and methodology
- **Acknowledge limitations** — every quantitative claim has confidence bounds
- **Distinguish observation from projection** — historical data vs forward-looking assumptions
- **Include failure modes** — what conditions would invalidate the conclusions
- **Use consistent terminology** from `docs/GLOSSARY.md`

## Common Tasks

### "What research exists on [topic]?"

1. Read `references/README.md` for the index
2. Identify documents in the relevant category from the taxonomy
3. Read the executive summary of each relevant document
4. Synthesize findings across documents, noting where they agree or conflict

### "Create research on [new topic]"

1. Check if existing documents already cover the topic (avoid duplication)
2. Read `.claude/commands/researcher.md` for methodology and output templates
3. Create the document using the template above
4. Place in the correct taxonomy category
5. Update `references/README.md`
6. Add cross-references to related existing documents

### "Update [document] with new findings"

1. Read the current document fully
2. Identify what has changed and why
3. Update content, increment version, update date
4. Check if the update affects conclusions cited by other documents
5. Update cross-references if needed

### "What are the key parameters and why?"

Read in order: `Vision_and_Mission.md` (philosophy) → `Vesting_Period.md` (1129 days) → `Withdrawal_Rate_Stability.md` (12% rate) → `Quantitative_Validation.md` (data backing). These four documents form the core parameter justification chain.

### "How viable is deployment on [platform]?"

Read the relevant deployment document:
- Ethereum L1: `Protocol_Lifespan_Assessment.md` + `Blockchain_Infrastructure_Assessment.md`
- Base/Arbitrum/Optimism: `L2_Deployment_Viability.md` + `Blockchain_Infrastructure_Assessment.md`
- Native Bitcoin: `Bitcoin_Deployment_Feasibility.md` + `RGB_Viability_Assessment.md`

### "Summarize the entire research corpus"

Read all documents in taxonomy order (Foundational → Parameter → Deployment → Architecture → Market → Financial Engineering → Visual). Produce a synthesis that identifies: core thesis, key parameters and their justification, deployment strategy, risk factors, and open questions.

## Output Standards

- Reference specific documents by filename when citing findings
- Include document status (Final/Research/Archived) when relevance depends on maturity
- When synthesizing across documents, note where conclusions conflict or have different confidence levels
- Keep the taxonomy tables in this file as the authoritative inventory. Update `references/README.md` when documents are added or removed
