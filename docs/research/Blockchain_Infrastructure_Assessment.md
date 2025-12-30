# Blockchain Infrastructure Assessment: Ethereum, Arbitrum, and Base for BTCNFT Protocol

## Executive Summary

This assessment evaluates three blockchain platforms—Ethereum Mainnet, Arbitrum One, and Base—for deploying the BTCNFT Protocol, an immutable permissionless smart contract system providing perpetual withdrawals through percentage-based collateral access. The protocol's unique characteristics—1129-day vesting periods, monthly withdrawal cycles, ERC-998 composable NFTs, and multi-decade operational lifespan—create specific infrastructure requirements that demand careful blockchain selection.

**Primary Recommendation**: Deploy on **Base** as the primary network with **Arbitrum One** as a secondary deployment for regulatory and operational diversification.

**Key Finding**: Ethereum Mainnet, while offering the highest security guarantees, fails economic viability tests for the protocol's target market due to gas costs that exceed withdrawal values for positions under 0.5 BTC.

---

## 1. Protocol Technical Requirements

Before evaluating blockchains, understanding the BTCNFT Protocol's specific requirements is essential. The protocol's architecture imposes non-negotiable constraints on any deployment target.

### 1.1 Smart Contract Complexity

The VaultNFT contract implements ERC-998 (composable NFT) functionality with substantial state management:

- **9 per-token mappings**: treasure contract, treasure ID, collateral amount, mint timestamp, last withdrawal, last activity, BTC token amount, original minted amount, poke timestamp
- **Nested delegation mappings**: per-delegate permissions, total delegated basis points, period withdrawals
- **Gas consumption per operation**:
  - Mint Vault NFT: ~250,000 gas
  - Withdraw BTC: ~80,000 gas
  - Grant Delegation: ~60,000 gas
  - Mint vestedBTC: ~120,000 gas
  - Claim Match: ~90,000 gas
  - Claim Dormant Collateral: ~150,000 gas

These gas profiles make L1 deployment economically problematic for the core use case (monthly withdrawals).

### 1.2 Time-Based Mechanism Requirements

The protocol relies heavily on accurate block timestamps:

- **1129-day vesting period**: Exact to the day, not approximate
- **30-day withdrawal cycles**: Must track `lastWithdrawal` timestamp
- **Dormancy threshold**: 1129 days without activity triggers dormancy mechanics
- **30-day grace period**: Post-poke response window

Any blockchain must provide:
- Reliable `block.timestamp` semantics
- Timestamp drift within acceptable bounds (seconds, not minutes)
- No timestamp manipulation vulnerabilities
- Historical timestamp queryability for 3+ year periods

### 1.3 Token Standard Requirements

| Standard | Purpose | Requirement |
|----------|---------|-------------|
| **ERC-998** | Composable NFT vault | Full EVM bytecode compatibility required |
| **ERC-721** | Treasure NFTs | Standard interface |
| **ERC-20** | vestedBTC, collateral tokens | Standard interface |
| **ERC-5192** | Soulbound achievement NFTs | `locked()` method implementation |

All standards build on EVM semantics. Non-EVM chains (Bitcoin, Solana native) are architecturally incompatible without significant redesign.

### 1.4 Wrapped Bitcoin Availability

The protocol accepts three wrapped Bitcoin variants as collateral:

| Collateral | Ethereum | Base | Arbitrum |
|------------|----------|------|----------|
| **wBTC** | Native | Bridged | Bridged |
| **cbBTC** | Native | **Native** | Bridged |
| **tBTC** | Native | Available | Available |

Base holds a unique advantage: cbBTC is **native** on Base (minted directly by Coinbase), eliminating one bridge layer for Coinbase-originated collateral.

### 1.5 Immutability Requirements

The protocol deploys as **fully immutable smart contracts** with no admin functions:

```solidity
immutable uint256 VESTING_PERIOD = 1129 days;
immutable uint256 WITHDRAWAL_PERIOD = 30 days;
immutable uint256 WITHDRAWAL_RATE = 1000; // 1.0%
immutable IBtcToken public btcToken;
immutable address public collateralToken;
```

This design requires:
- No proxy patterns or upgrade mechanisms
- Bytecode verification capability
- Deterministic execution across all nodes
- Long-term bytecode accessibility (20+ year horizon)

---

## 2. Ethereum Mainnet Analysis

### 2.1 Technical Specifications

| Metric | Value |
|--------|-------|
| Block Time | ~12 seconds |
| Finality | ~15 minutes (2 epochs) |
| TPS | ~15-30 (base layer) |
| Average Transaction Fee (2025) | $0.44 - $3.78 |
| Consensus | Proof of Stake |
| Data Availability | Full on-chain |

### 2.2 Security Model

Ethereum Mainnet provides the highest security guarantees in the EVM ecosystem:

- **Validator Set**: 1,000,000+ active validators as of 2025
- **Economic Security**: $40B+ staked ETH
- **Attack Cost**: Prohibitively expensive 51% attack
- **Track Record**: 10+ years of operation without consensus failure
- **Battle-tested**: Most audited and attacked smart contract platform

For a protocol designed to hold BTC collateral for 20+ years, Ethereum's security track record is compelling. No other blockchain has demonstrated equivalent long-term resilience.

### 2.3 Gas Economics Analysis

The Dencun upgrade (March 2024) introduced EIP-4844 (Proto-Danksharding), reducing L2 data posting costs by 50-90%. However, L1 transaction costs remain significant:

**Monthly Withdrawal Economics on Ethereum L1:**

| Position Size | 1% Withdrawal | Gas Cost (30 gwei) | Cost as % of Withdrawal |
|---------------|---------------|--------------------|-----------------------|
| 0.01 BTC ($940) | $9.40 | ~$2.40 | **25.5%** |
| 0.1 BTC ($9,400) | $94 | ~$2.40 | 2.55% |
| 0.5 BTC ($47,000) | $470 | ~$2.40 | 0.51% |
| 1.0 BTC ($94,000) | $940 | ~$2.40 | 0.26% |

*Assumes BTC at $94,000 and Ethereum gas at 30 gwei*

**Finding**: For positions under ~0.25 BTC, L1 gas costs consume a significant percentage of monthly withdrawals. The protocol's economics fundamentally break for the mass-market use case on L1.

### 2.4 Roadmap & Future State

Ethereum's roadmap includes several relevant upgrades:

- **Pectra (May 2025)**: Increased blob capacity (3→6 target, 6→9 max), raising L2 throughput
- **Danksharding (Q2 2026 target)**: Full blob scaling, 64 blobs per block
- **Verkle Trees (Q3 2026)**: Lighter node requirements, improved state management
- **The Verge/Purge**: Long-term state cleanup and node democratization

These upgrades benefit L2s more than direct L1 deployment, reinforcing the case for L2 deployment.

### 2.5 Wrapped BTC Ecosystem

Ethereum hosts the most mature wrapped BTC ecosystem:

- **wBTC**: ~$13B market cap (May 2025), highest liquidity
- **cbBTC**: Native Coinbase backing, growing adoption
- **tBTC v2**: Decentralized threshold custody, Aave v3 integration
- **Total tokenized BTC**: ~230,000 BTC across all wrappers

All major wrapped BTC variants originate on Ethereum, making it the canonical source of truth for bridge operations.

### 2.6 Ethereum Mainnet Assessment Summary

**Strengths:**
- Unmatched security and decentralization
- Full wrapped BTC availability
- Longest operational track record
- Maximum composability with DeFi ecosystem
- No bridge risk for collateral tokens

**Weaknesses:**
- Gas economics prohibit mass-market adoption
- Monthly withdrawal costs exceed value for small positions
- Slower transaction finality than L2s
- No cost improvement path (L1 will remain expensive)

**Verdict**: Ethereum L1 is architecturally suitable but economically unviable for the protocol's target use case. It may serve as a "premium" deployment option for high-net-worth users (positions >1 BTC), but cannot support mass adoption.

---

## 3. Arbitrum One Analysis

### 3.1 Technical Specifications

| Metric | Value |
|--------|-------|
| Block Time | 250 milliseconds |
| Soft Finality | Instant (sequencer confirmation) |
| Hard Finality | ~7 days (challenge period) |
| TPS | 4,000-8,000 real-world (40,000 theoretical) |
| Average Transaction Fee | $0.01 - $0.30 |
| Technology | Optimistic Rollup (Nitro) |
| L2BEAT Stage | Stage 1 |

### 3.2 Security Model

Arbitrum One implements a multi-layered security architecture:

**Fraud Proofs (BOLD):**
- Permissionless fraud proof system deployed 2024
- 7-day dispute resolution window
- Multi-round interactive proofs
- Bisection game with exponential staking (691.43 ETH maximum cumulative stake)

**Upgrade Mechanism:**
- 17-day 8-hour delay on code upgrades (non-emergency)
- Security Council can bypass for emergencies
- Users have 10+ days to exit before non-emergency upgrades activate

**Data Availability:**
- All state data posted to Ethereum L1 as calldata/blobs
- Full state reconstructibility from L1 data
- Inherits Ethereum's data availability guarantees

**L2BEAT Stage 1 Requirements Met:**
- Users can exit even if operators become malicious
- Fraud proof system operational
- Security Council exists but cannot unilaterally control funds

### 3.3 Sequencer Centralization Risk

Arbitrum's sequencer is currently operated by Offchain Labs:

**Risks:**
- Single point of failure for transaction ordering
- 2025 incident: 1.5-hour outage due to inscription surge
- Censorship theoretically possible (though fraud proofs provide escape hatch)

**Mitigations:**
- Delayed inbox allows L1-based transaction submission
- Fraud proofs ensure state integrity regardless of sequencer behavior
- Sequencer decentralization on roadmap (though no firm date)

For a 20+ year protocol, sequencer centralization represents a meaningful concern. However, the fraud proof escape hatch and L1 delayed inbox provide reasonable assurance that user funds remain accessible.

### 3.4 Governance & Treasury

Arbitrum DAO represents one of crypto's most mature governance structures:

**Treasury:**
- $1.3-1.78B in assets under management (2025)
- $700M+ allocated in first two years
- STEP program diversifying into tokenized Treasurys
- Gaming Catalyst Program: $120M for gaming ecosystem

**Governance:**
- Constitutional AIPs for protocol changes
- Non-Constitutional AIPs for treasury/grants
- Semi-annual Security Council elections
- Top 50 delegates control 56% voting power

**Long-term Sustainability:**
- DAO-controlled treasury provides funding runway
- Active development (Stylus, multi-client support)
- Revenue from sequencer fees flows to DAO
- No dependency on single corporate entity

### 3.5 Gas Economics Analysis

**Monthly Withdrawal Economics on Arbitrum:**

| Position Size | 1% Withdrawal | Gas Cost | Cost as % of Withdrawal |
|---------------|---------------|----------|------------------------|
| 0.01 BTC ($940) | $9.40 | ~$0.05 | **0.53%** |
| 0.1 BTC ($9,400) | $94 | ~$0.05 | 0.053% |
| 0.5 BTC ($47,000) | $470 | ~$0.05 | 0.011% |
| 1.0 BTC ($94,000) | $940 | ~$0.05 | 0.005% |

**Finding**: Gas costs become negligible even for small positions. A 0.01 BTC position loses only 0.53% to gas per withdrawal—acceptable for a perpetual income stream.

### 3.6 Wrapped BTC Availability

| Token | Status | Liquidity |
|-------|--------|-----------|
| wBTC | Bridged from Ethereum | High |
| cbBTC | Bridged from Ethereum | Medium |
| tBTC | Native integration | Medium |

All three collateral options are available on Arbitrum, though all require bridging from Ethereum, adding one layer of bridge risk.

### 3.7 DeFi Ecosystem

Arbitrum hosts a mature DeFi ecosystem relevant to protocol operations:

- **DEXs**: Uniswap, SushiSwap, Camelot, GMX
- **Lending**: Aave v3, Radiant Capital
- **Stablecoin liquidity**: High USDC/USDT availability
- **Curve pools**: tBTC/wBTC pool with 4.33% CRV rewards

vestedBTC could integrate with existing DeFi infrastructure for secondary market liquidity.

### 3.8 Arbitrum One Assessment Summary

**Strengths:**
- Mature optimistic rollup with proven fraud proof system
- Stage 1 decentralization achieved
- Strong DAO governance and treasury
- All wrapped BTC variants available
- Deep DeFi ecosystem for vestedBTC liquidity
- Gas economics enable mass-market adoption
- Multiple client implementations in progress

**Weaknesses:**
- Centralized sequencer (decentralization roadmap unclear)
- All wrapped BTC requires bridging (additional risk layer)
- 7-day challenge period for L1 withdrawals
- 2025 outage demonstrated sequencer vulnerability
- Governance concentration among top delegates

**Verdict**: Arbitrum represents a balanced choice with proven infrastructure, mature governance, and strong ecosystem. The DAO treasury provides funding sustainability independent of any single corporate entity. However, all wrapped BTC must be bridged, adding risk compared to L1 or Base's native cbBTC.

---

## 4. Base Analysis

### 4.1 Technical Specifications

| Metric | Value |
|--------|-------|
| Block Time | 2 seconds |
| Soft Finality | Instant (sequencer confirmation) |
| Hard Finality | ~7 days (challenge period) |
| TPS | ~2,000 (Flashblocks upgrade) |
| Average Transaction Fee | <$0.50 (often $0.0016) |
| Technology | Optimistic Rollup (OP Stack) |
| L2BEAT Stage | Stage 1 |

### 4.2 Security Model

Base implements the OP Stack's security model with recent enhancements:

**Fault Proofs:**
- OP Stack Fault Proof System deployed October 2024
- Permissionless withdrawals to Ethereum
- Interactive dispute games with ETH staking
- 7-day challenge window

**Security Council:**
- 12-member council (Base, Optimism, 10 independent entities)
- 75% consensus required for upgrades
- Multi-jurisdictional membership
- No single entity can unilaterally upgrade

**Data Availability:**
- All transaction data posted to Ethereum L1
- Blob transactions (EIP-4844) for cost efficiency
- Full state reconstructibility from L1 data

**L2BEAT Stage 1 Achievement (December 2024):**
- Users can exit without relying on operators
- Fault proofs operational
- Security Council properly structured
- 10th L2 to reach Stage 1

### 4.3 Coinbase Integration & Corporate Dependency

Base's relationship with Coinbase creates both advantages and risks:

**Advantages:**
- **Native cbBTC**: Coinbase can mint cbBTC directly on Base, eliminating bridge risk
- **Fiat on-ramp**: Seamless Coinbase exchange integration
- **Institutional trust**: Coinbase's regulatory standing and institutional relationships
- **Development resources**: Coinbase engineering team contributing to OP Stack
- **User acquisition**: Access to Coinbase's 100M+ user base

**Risks:**
- **Corporate dependency**: Base's success tied to Coinbase's fortunes
- **Regulatory exposure**: Coinbase faces ongoing SEC scrutiny
- **Sequencer centralization**: Coinbase operates the sequencer
- **Business model alignment**: Coinbase's interests may diverge from protocol users
- **Single company risk**: Unlike Arbitrum's DAO, no distributed treasury

### 4.4 Sequencer Centralization Risk

Base's sequencer is operated by Coinbase, creating similar centralization concerns as Arbitrum:

**2025 Incidents:**
- August 2025: "Unsafe head delay" outage
- Demonstrated single point of failure risk
- Highlighted reliance on AWS infrastructure

**Mitigations:**
- Fault proofs allow permissionless L1 withdrawal
- Ethereum-level censorship resistance via L1 forced transactions
- Security Council prevents unilateral changes

### 4.5 Native cbBTC Advantage

Base's most significant technical advantage for BTCNFT Protocol is **native cbBTC**:

**Risk Stack Comparison:**

| Collateral | On Ethereum | On Base | On Arbitrum |
|------------|-------------|---------|-------------|
| cbBTC | Custodian risk | Custodian risk only | Custodian + Bridge risk |
| wBTC | Custodian risk | Custodian + Bridge risk | Custodian + Bridge risk |

For cbBTC collateral, Base eliminates one entire risk layer compared to Arbitrum deployment. This is significant for a protocol holding collateral for 20+ years.

### 4.6 Gas Economics Analysis

**Monthly Withdrawal Economics on Base:**

| Position Size | 1% Withdrawal | Gas Cost | Cost as % of Withdrawal |
|---------------|---------------|----------|------------------------|
| 0.01 BTC ($940) | $9.40 | ~$0.002 | **0.02%** |
| 0.1 BTC ($9,400) | $94 | ~$0.002 | 0.002% |
| 0.5 BTC ($47,000) | $470 | ~$0.002 | 0.0004% |
| 1.0 BTC ($94,000) | $940 | ~$0.002 | 0.0002% |

**Finding**: Base offers the lowest gas costs among evaluated chains. Even micro-positions lose negligible value to gas.

### 4.7 DeFi Ecosystem

Base has developed a robust DeFi ecosystem:

- **TVL**: $4.32B (late 2025), surpassing Arbitrum
- **DEXs**: Aerodrome (dominant), Uniswap, BaseSwap
- **Daily transactions**: 50M+ monthly, 1M+ daily active addresses
- **Curve integration**: tBTC/cbBTC pool with 7.78% AERO rewards

The Aerodrome DEX provides deep liquidity for wrapped BTC pairs, supporting vestedBTC secondary markets.

### 4.8 Long-term Sustainability Concerns

Unlike Arbitrum's DAO treasury, Base's sustainability depends on Coinbase:

**Coinbase Financial Position (2025):**
- $7.4B projected revenue
- 41% from subscriptions/services (reducing trading dependency)
- Profitable, but revenue tied to crypto market cycles
- NASDAQ-listed with institutional oversight

**Scenario Analysis:**

| Scenario | Impact on Base |
|----------|----------------|
| Coinbase thrives | Continued development, resources |
| Coinbase struggles | Potential reduced investment |
| Coinbase bankruptcy | Uncertain—OP Stack open source provides some continuity |
| Regulatory action | Could force Coinbase to divest Base |

The open-source OP Stack provides some insurance—another entity could theoretically operate Base's sequencer. However, native cbBTC would lose its advantage if Coinbase exits.

### 4.9 Base Assessment Summary

**Strengths:**
- Native cbBTC eliminates bridge risk for Coinbase-backed collateral
- Lowest gas costs among evaluated options
- Highest user adoption metrics (1M+ daily active addresses)
- Stage 1 decentralization with proper Security Council
- Coinbase fiat integration accelerates user onboarding
- Strong OP Stack foundation with Optimism collaboration

**Weaknesses:**
- Corporate dependency on Coinbase
- No independent treasury (unlike Arbitrum DAO)
- Sequencer centralization with demonstrated outages
- Regulatory risk from Coinbase's SEC exposure
- wBTC requires bridging (only cbBTC is native)
- Shorter track record than Arbitrum

**Verdict**: Base offers the strongest technical advantages for BTCNFT Protocol—native cbBTC and lowest gas costs—but introduces corporate dependency risk. For a 20+ year protocol, Coinbase's long-term viability becomes a material consideration.

---

## 5. Comparative Analysis

### 5.1 Technical Comparison Matrix

| Dimension | Ethereum L1 | Arbitrum | Base | Protocol Need |
|-----------|-------------|----------|------|---------------|
| EVM Compatibility | Full | Full | Full | Required |
| ERC-998 Support | Native | Full | Full | Required |
| Block Timestamp Reliability | Excellent | Excellent | Excellent | Required |
| Gas Cost (Withdrawal) | ~$2.40 | ~$0.05 | ~$0.002 | Low preferred |
| Finality | 15 min | 7 days* | 7 days* | Acceptable |
| L2BEAT Stage | N/A | Stage 1 | Stage 1 | Stage 1+ |
| Sequencer | N/A | Centralized | Centralized | Risk factor |

*Soft finality is instant; 7-day hard finality for L1 withdrawals

### 5.2 Wrapped BTC Risk Stack

| Collateral | Ethereum L1 | Base | Arbitrum |
|------------|-------------|------|----------|
| cbBTC | Custodian | **Custodian** | Custodian + Bridge |
| wBTC | Custodian | Custodian + Bridge | Custodian + Bridge |
| tBTC | DAO | DAO + Bridge | DAO + Bridge |

**Optimal Risk Profile**: cbBTC on Base (single custodian layer, no bridge)

### 5.3 Long-term Sustainability Factors

| Factor | Ethereum | Arbitrum | Base |
|--------|----------|----------|------|
| Operational Years | 10+ | 4+ | 2+ |
| Governance | EIP process | DAO | Coinbase |
| Treasury | Protocol revenue | $1.3B+ DAO | Corporate |
| Development Funding | Ethereum Foundation | DAO grants | Coinbase budget |
| Independence | Maximum | High | Low |
| Bankruptcy Risk | Minimal | DAO dissolution | Coinbase bankruptcy |

### 5.4 User Economics Comparison

For a representative 0.1 BTC position ($9,400):

| Chain | Monthly Withdrawal | Gas Cost | Net to User | Annual Gas % |
|-------|-------------------|----------|-------------|--------------|
| Ethereum L1 | $94 | $2.40 | $91.60 | 2.55% |
| Arbitrum | $94 | $0.05 | $93.95 | 0.053% |
| Base | $94 | $0.002 | $93.998 | 0.002% |

Over 20 years (240 withdrawals):

| Chain | Total Gas Paid | % of Total Withdrawals |
|-------|---------------|----------------------|
| Ethereum L1 | ~$576 | 2.55% |
| Arbitrum | ~$12 | 0.053% |
| Base | ~$0.48 | 0.002% |

---

## 6. Risk Assessment

### 6.1 Bridge Risk Analysis

For a protocol holding collateral for 20+ years, bridge risk compounds significantly:

**Historical Bridge Exploits:**
- Ronin Bridge: $625M (2022)
- Wormhole: $320M (2022)
- Nomad: $190M (2022)

**Risk Mitigation:**
- Base's native cbBTC eliminates one bridge layer
- Multi-collateral deployment spreads bridge exposure
- L2 fraud proofs provide escape hatch independent of bridge

### 6.2 Sequencer Failure Scenarios

| Scenario | Arbitrum | Base | Mitigation |
|----------|----------|------|------------|
| Sequencer offline | L1 delayed inbox | L1 delayed inbox | Ethereum fallback |
| Sequencer censorship | Fraud proofs + L1 | Fault proofs + L1 | 7-day exit |
| Sequencer compromise | State verifiable on L1 | State verifiable on L1 | Reorg protection |

Both L2s provide reasonable sequencer failure protection through Ethereum fallback mechanisms.

### 6.3 Regulatory Risk Matrix

| Risk | Ethereum | Arbitrum | Base |
|------|----------|----------|------|
| Security classification | Low | Low | Medium (Coinbase exposure) |
| KYC requirements | None | None | Potential Coinbase requirements |
| Geographic restrictions | None | None | Coinbase regional limits |
| OFAC compliance | Protocol level | Protocol level | Coinbase-imposed |

Base inherits Coinbase's regulatory posture, which could impose restrictions not present on other chains.

### 6.4 20-Year Horizon Considerations

For a protocol designed to operate for 20+ years:

**Ethereum L1:**
- Highest probability of continued operation
- Protocol-level governance (EIP process) is slow but stable
- No corporate dependency

**Arbitrum:**
- DAO treasury provides multi-year runway
- Open source with multiple client implementations in development
- Could theoretically operate without Offchain Labs

**Base:**
- Dependent on Coinbase's continued operation
- OP Stack is open source (mitigation)
- cbBTC advantage disappears if Coinbase exits

---

## 7. Deployment Strategy Recommendations

### 7.1 Primary Recommendation: Multi-L2 Deployment

Deploy on **Base (primary)** and **Arbitrum (secondary)** with the following rationale:

**Base Primary:**
- Native cbBTC eliminates bridge risk for Coinbase users
- Lowest gas costs maximize small-position viability
- Coinbase fiat integration simplifies onboarding
- Highest user activity metrics

**Arbitrum Secondary:**
- DAO governance provides long-term independence
- Regulatory diversification (different jurisdictions)
- Mature DeFi ecosystem for vestedBTC liquidity
- Hedge against Coinbase corporate risk

### 7.2 Collateral Strategy Per Chain

| Chain | Primary Collateral | Rationale |
|-------|-------------------|-----------|
| Base | cbBTC | Native issuance, no bridge risk |
| Arbitrum | tBTC | Decentralized custody, DAO-aligned |

This strategy minimizes total risk exposure by pairing each chain with its lowest-risk collateral option.

### 7.3 Ethereum L1 Consideration

Ethereum L1 deployment is **not recommended** for general availability due to gas economics. However, a "premium" L1 deployment could serve:

- Institutional users with large positions (>1 BTC)
- Users prioritizing maximum security over gas efficiency
- Protocol treasury holdings

### 7.4 Migration Path Considerations

The protocol's immutability means no upgrade path exists. Each deployment is permanent. This reinforces the importance of:

1. Thorough testing before mainnet deployment
2. Multi-chain deployment for redundancy
3. Clear user communication about chain-specific risks

---

## 8. Conclusion

The BTCNFT Protocol's unique characteristics—perpetual operation, monthly withdrawals, long vesting periods, and immutable deployment—create specific blockchain requirements that favor L2 deployment over Ethereum mainnet.

**Final Rankings:**

1. **Base** (Primary): Best gas economics, native cbBTC, highest adoption—offset by Coinbase corporate dependency
2. **Arbitrum** (Secondary): Mature governance, DAO sustainability, regulatory diversification—offset by bridge requirements
3. **Ethereum L1** (Not Recommended): Maximum security but economically unviable for target market

The recommended deployment strategy—Base primary with Arbitrum secondary—balances technical optimization against long-term sustainability concerns. Native cbBTC on Base provides the cleanest risk profile for collateral, while Arbitrum's DAO governance offers insurance against corporate dependency.

For a protocol designed to hold Bitcoin collateral for 20+ years, this dual-deployment approach provides reasonable assurance that users will retain access to their funds regardless of individual platform outcomes.

---

## Sources

### Layer 2 Comparisons
- [Base vs Arbitrum: Which Ethereum L2 Is Better?](https://archlending.com/blog/base-vs-arbitrum)
- [Arbitrum vs Base Comparison | Chainspect](https://chainspect.app/compare/arbitrum-vs-base)
- [Layer 2 Showdown | Mitosis](https://university.mitosis.org/layer-2-showdown-which-scaling-solution-will-win-the-battle-for-ethereums-future/)

### Arbitrum Technical
- [Arbitrum One - L2BEAT](https://l2beat.com/scaling/projects/arbitrum)
- [Arbitrum vs Ethereum Overview | Arbitrum Docs](https://docs.arbitrum.io/build-decentralized-apps/arbitrum-vs-ethereum/comparison-overview)
- [Arbitrum DAO Governance | Dune](https://dune.com/blog/arbitrum-dao-the-evolution-of-decentralized-governance)

### Base Technical
- [Base Chain - L2BEAT](https://l2beat.com/scaling/projects/base)
- [Base becomes 10th L2 to reach Stage 1](https://cryptoslate.com/base-becomes-10th-l2-network-to-reach-at-least-stage-1-decentralization/)
- [Demystifying Base 2025 | Fystack](https://fystack.io/blog/demystifying-base-2025-how-coinbases-layer-2-won-the-ethereum-l2-race-part-1)

### Ethereum Roadmap
- [Ethereum Roadmap | ethereum.org](https://ethereum.org/roadmap/)
- [Danksharding | ethereum.org](https://ethereum.org/roadmap/danksharding/)
- [Ethereum Pectra Upgrade | Consensys](https://consensys.io/ethereum-pectra-upgrade)

### Wrapped BTC
- [What is cbBTC? | CoinLedger](https://coinledger.io/learn/what-is-cbbtc)
- [June 2025 Recap: tBTC | Threshold Network](https://www.threshold.network/blog/june-2025-recap-tbtc-threshold/)

### Security & Risks
- [L2 Centralization Risks | BeInCrypto](https://beincrypto.com/ethereum-l2-rollup-centralization-concern-solutions/)
- [Layer 2 Resilience and Investment Risk | Bitget](https://www.bitget.com/news/detail/12560604946869)

---

*Assessment completed December 2025. Data reflects current market conditions and may change.*
