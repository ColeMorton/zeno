# BTCNFT Protocol Actions Reference

> **Version:** 1.0.0
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [CLI Reference](./CLI.md)
> - [Technical Specification](./Technical_Specification.md)
> - [Hybrid Vault Specification](./Hybrid_Vault_Specification.md)
> - [Withdrawal Delegation](./Withdrawal_Delegation.md)
> - [Collateral Matching](./Collateral_Matching.md)

---

## Overview

Every action a user, entity, agent, or smart contract can perform within the BTCNFT Protocol. Actions are organized by lifecycle phase and actor role. Each action includes the contract function, CLI command (if available), preconditions, and effects.

**Actor types:**
- **Vault Owner** — holds the Vault NFT
- **Delegate** — granted withdrawal permissions by a vault owner
- **vBTC Holder** — holds vestedBTC ERC-20 tokens
- **Anyone** — permissionless (any address)
- **Issuer** — organization deploying on top of the protocol

---

## 1. Vault Creation

### 1.1 Mint Single-Collateral Vault

| | |
|---|---|
| **Contract** | `VaultNFT.mint(address treasureContract, uint256 treasureTokenId, address collateralToken, uint256 collateralAmount)` |
| **CLI** | `./btcnft mint <treasure_token_id> <btc_amount_satoshis>` |
| **Actor** | Anyone |
| **Preconditions** | Sufficient collateral balance; ERC-20 approval for collateral; ERC-721 approval for Treasure NFT |
| **Effects** | Mints ERC-998 Vault NFT; transfers Treasure NFT into vault; locks collateral; records mint timestamp |
| **Returns** | `uint256 tokenId` |

### 1.2 Mint Hybrid Vault (Dual-Collateral)

| | |
|---|---|
| **Contract** | `VaultNFT.mint(...)` then `VaultNFT.setRedeemHook(uint256 tokenId, address escrow)` then `VestingEscrow.deposit(uint256 tokenId, uint256 amount)` |
| **CLI** | `./btcnft hybrid-mint <treasure_token_id> <primary_satoshis> <secondary_amount>` |
| **Actor** | Anyone |
| **Preconditions** | Sufficient primary + secondary token balances; ERC-20 approvals (primary to vault, secondary to escrow); ERC-721 approval for Treasure NFT |
| **Effects** | Mints standard Vault NFT (primary leg); binds VestingEscrow as redeem hook (owner-only, one-time); escrows secondary leg keyed to the vault token ID |
| **Returns** | `uint256 tokenId` |

---

## 2. Withdrawals

### 2.1 Withdraw (Single-Collateral)

| | |
|---|---|
| **Contract** | `VaultNFT.withdraw(uint256 tokenId)` |
| **CLI** | `./btcnft withdraw <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vested (1129 days elapsed); 30+ days since last withdrawal |
| **Effects** | Transfers 1.0% of remaining collateral to owner; updates `lastWithdrawal` and `lastActivity` timestamps |
| **Returns** | `uint256 amount` |

### 2.2 Withdraw Primary (Hybrid)

| | |
|---|---|
| **Contract** | `VaultNFT.withdraw(uint256 tokenId)` (standard vault withdrawal on the primary leg) |
| **CLI** | `./btcnft hybrid-withdraw-primary <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vested; 30+ days since last primary withdrawal |
| **Effects** | Transfers 1.0% of remaining primary collateral to owner |
| **Returns** | `uint256 amount` |

### 2.3 Withdraw Secondary (Hybrid)

| | |
|---|---|
| **Contract** | `VestingEscrow.claim(uint256 tokenId)` |
| **CLI** | `./btcnft hybrid-withdraw-secondary <vault_token_id>` |
| **Actor** | Vault Owner (claim rights follow vault ownership) |
| **Preconditions** | Vested; escrow position not already claimed |
| **Effects** | Transfers 100% of escrowed secondary leg (plus accrued match share) to owner; clears position |
| **Returns** | `uint256 amount` |

### 2.4 Withdraw as Delegate (Single-Collateral)

| | |
|---|---|
| **Contract** | `VaultNFT.withdrawAsDelegate(uint256 tokenId)` |
| **CLI** | `./btcnft delegate-withdraw <vault_token_id>` |
| **Actor** | Delegate |
| **Preconditions** | Active delegation (wallet-level or vault-specific); vault is vested; 30+ days since delegate's last withdrawal from this vault |
| **Effects** | Transfers delegate's proportional share (vault withdrawable amount x delegate BPS) to delegate; updates delegate cooldown and vault activity |
| **Returns** | `uint256 withdrawnAmount` |

### 2.5 Withdraw Primary as Delegate (Hybrid)

| | |
|---|---|
| **Contract** | `VaultNFT.withdrawAsDelegate(uint256 tokenId)` (primary leg only; the escrowed secondary is not delegatable) |
| **CLI** | `./btcnft hybrid-delegate-withdraw <vault_token_id>` |
| **Actor** | Delegate |
| **Preconditions** | Active delegation; vault is vested; 30+ days since delegate's last withdrawal |
| **Effects** | Transfers delegate's proportional share of primary collateral to delegate |
| **Returns** | `uint256 withdrawnAmount` |

---

## 3. Early Redemption

### 3.1 Early Redeem (Single-Collateral)

| | |
|---|---|
| **Contract** | `VaultNFT.earlyRedeem(uint256 tokenId)` |
| **CLI** | `./btcnft early-redeem <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault exists; if vBTC minted, owner must hold full vBTC amount |
| **Effects** | Returns `(elapsed / 1129 days)` of collateral to owner; forfeits remainder to match pool; burns Vault NFT and Treasure NFT |
| **Returns** | `(uint256 returned, uint256 forfeited)` |

### 3.2 Early Redeem (Hybrid)

| | |
|---|---|
| **Contract** | `VaultNFT.earlyRedeem(uint256 tokenId)` (calls `VestingEscrow.onEarlyRedeem` via the redeem hook) |
| **CLI** | `./btcnft hybrid-early-redeem <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault exists; if vBTC minted, owner must hold full vBTC amount |
| **Effects** | Atomic: pro-rata return of both legs with the same forfeiture curve in one transaction; primary forfeit to vault match pool, secondary forfeit to escrow accumulator; burns Vault NFT |
| **Returns** | `(uint256 returned, uint256 forfeited)` from the vault; escrow settlement emits `EarlyRedeemed(tokenId, redeemer, returned, forfeited)` |

---

## 4. vestedBTC Separation & Recombination

### 4.1 Separate (Mint vBTC)

| | |
|---|---|
| **Contract** | `VaultNFT.mintBtcToken(uint256 tokenId)` |
| **CLI** | `./btcnft separate <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault is vested; vBTC not yet minted for this vault (`btcTokenAmount == 0`) |
| **Effects** | Mints ERC-20 vBTC tokens to owner (amount = current collateral); enables dormancy mechanics; disables redemption rights (until recombined) |
| **Returns** | `uint256 amount` |

### 4.2 Separate Hybrid (Mint vBTC from Primary)

| | |
|---|---|
| **Contract** | `VaultNFT.strip(uint256 tokenId, uint256 amount)` (standard vault stripping; the escrowed secondary is never strippable) |
| **CLI** | `./btcnft hybrid-strip <vault_token_id> <amount>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault is vested |
| **Effects** | Mints vBTC tokens from primary collateral only |
| **Returns** | `uint256 amount` |

### 4.3 Recombine (Return vBTC)

| | |
|---|---|
| **Contract** | `VaultNFT.returnBtcToken(uint256 tokenId)` |
| **CLI** | `./btcnft recombine <vault_token_id>` |
| **Actor** | Vault Owner (must hold full original vBTC amount) |
| **Preconditions** | vBTC must be minted for this vault; caller holds full `originalMintedAmount` of vBTC |
| **Effects** | Burns all vBTC; restores vault redemption rights; disables dormancy mechanics |

### 4.4 Recombine Hybrid

| | |
|---|---|
| **Contract** | `VaultNFT.recombine(uint256 tokenId, uint256 amount)` (standard vault recombination) |
| **CLI** | `./btcnft hybrid-recombine <vault_token_id>` |
| **Actor** | Vault Owner (must hold full original vBTC amount) |
| **Preconditions** | Same as 4.3 |
| **Effects** | Same as 4.3 |

---

## 5. Match Pool Claims

### 5.1 Claim Match (Single-Collateral)

| | |
|---|---|
| **Contract** | `VaultNFT.claimMatch(uint256 tokenId)` |
| **CLI** | `./btcnft claim-match <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault is vested; match pool has balance; vault has not already claimed |
| **Effects** | Transfers pro-rata share of match pool (`matchPool x holderCollateral / totalActiveCollateral`) to vault's collateral |
| **Returns** | `uint256 amount` |

### 5.2 Claim Primary Match (Hybrid)

| | |
|---|---|
| **Contract** | `VaultNFT.claimMatch(uint256 tokenId)` (shared vault match pool) |
| **CLI** | `./btcnft hybrid-claim-primary-match <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vested; vault match pool has balance |
| **Effects** | Credits pro-rata share of the vault match pool to the primary leg |
| **Returns** | `uint256 amount` |

### 5.3 Claim Secondary Match (Hybrid)

| | |
|---|---|
| **Contract** | `VestingEscrow.claimMatch(uint256 tokenId)` |
| **CLI** | `./btcnft hybrid-claim-secondary-match <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Escrow position exists; pending match share > 0 |
| **Effects** | Settles accrued forfeit share (accumulator-based) into the position's escrowed amount |
| **Returns** | `uint256 amount` |

---

## 6. Delegation Management

### 6.1 Grant Wallet-Level Delegation (Single-Collateral)

| | |
|---|---|
| **Contract** | `VaultNFT.grantWithdrawalDelegate(address delegate, uint256 percentageBPS)` |
| **CLI** | `./btcnft delegate-grant <vault_token_id> <delegate_address> <percentage_bps>` |
| **Actor** | Vault Owner |
| **Preconditions** | Delegate is not self; total wallet delegation + new grant <= 10000 BPS |
| **Effects** | Grants persistent wallet-level withdrawal rights to delegate across all vaults owned by caller |

### 6.2 Grant Wallet-Level Delegation (Hybrid)

| | |
|---|---|
| **Contract** | `VaultNFT.grantWithdrawalDelegate(address delegate, uint256 percentageBPS)` (same contract; delegation covers the primary leg only) |
| **CLI** | (same as single-collateral when targeting hybrid) |
| **Actor** | Vault Owner |
| **Preconditions** | Same as 6.1 |
| **Effects** | Same as 6.1, applies to all hybrid vaults owned by caller |

### 6.3 Revoke Wallet-Level Delegation

| | |
|---|---|
| **Contract** | `VaultNFT.revokeWithdrawalDelegate(address delegate)` or `revokeAllWithdrawalDelegates()` |
| **CLI** | `./btcnft delegate-revoke <vault_token_id> <delegate_address>` or `--all` |
| **Actor** | Vault Owner |
| **Preconditions** | Delegate must be active |
| **Effects** | Removes wallet-level delegation (single or all delegates) |

### 6.4 Grant Vault-Specific Delegation

| | |
|---|---|
| **Contract** | `VaultNFT.grantVaultDelegate(uint256 tokenId, address delegate, uint256 percentageBPS, uint256 durationSeconds)` |
| **CLI** | `./btcnft vault-delegate-grant <vault_token_id> <delegate_address> <percentage_bps> <duration_seconds>` |
| **Actor** | Vault Owner |
| **Preconditions** | Caller owns vault; delegate is not self; total vault delegation + new grant <= 10000 BPS |
| **Effects** | Grants time-limited vault-specific delegation; vault-level takes precedence over wallet-level |

### 6.5 Revoke Vault-Specific Delegation

| | |
|---|---|
| **Contract** | `VaultNFT.revokeVaultDelegate(uint256 tokenId, address delegate)` |
| **CLI** | `./btcnft vault-delegate-revoke <vault_token_id> <delegate_address>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault-specific delegation is active |
| **Effects** | Removes vault-specific delegation for the given delegate |

---

## 7. Dormancy Lifecycle

Dormancy applies only to vaults where vBTC has been separated (section 4). Three-step lifecycle: poke -> prove-activity OR claim-dormant.

### 7.1 Poke (Initiate Dormancy)

| | |
|---|---|
| **Contract** | `VaultNFT.pokeDormant(uint256 tokenId)` |
| **CLI** | `./btcnft poke <vault_token_id>` / `./btcnft hybrid-poke <vault_token_id>` |
| **Actor** | Anyone |
| **Preconditions** | Vault is dormant-eligible (vBTC separated + 1129 days of inactivity); not already poked |
| **Effects** | Starts 30-day grace period; transitions vault to `POKE_PENDING` state |

### 7.2 Prove Activity

| | |
|---|---|
| **Contract** | `VaultNFT.proveActivity(uint256 tokenId)` |
| **CLI** | `./btcnft prove-activity <vault_token_id>` / `./btcnft hybrid-prove-activity <vault_token_id>` |
| **Actor** | Vault Owner |
| **Preconditions** | Vault is in `POKE_PENDING` state |
| **Effects** | Resets dormancy timer; transitions vault back to `ACTIVE` state |

### 7.3 Claim Dormant Collateral

| | |
|---|---|
| **Contract** | `VaultNFT.claimDormantCollateral(uint256 tokenId, uint256 amount)` |
| **CLI** | `./btcnft claim-dormant <vault_token_id>` / `./btcnft hybrid-claim-dormant <vault_token_id>` |
| **Actor** | vBTC Holder |
| **Preconditions** | Grace period expired (vault is `CLAIMABLE`); caller holds sufficient vBTC for the claimed amount |
| **Effects** | Transfers vault collateral to caller (primary leg only for hybrid; the escrowed secondary remains claimable by the vault owner); burns vBTC |
| **Returns** | `uint256 collateral` |

---

## 8. Token Operations

### 8.1 Approve ERC-20 Token

| | |
|---|---|
| **Contract** | `IERC20.approve(address spender, uint256 amount)` |
| **CLI** | `./btcnft token-approve <token_alias> <spender_address> <amount>` |
| **Actor** | Token Holder |
| **Preconditions** | None |
| **Effects** | Sets spending allowance for spender on caller's token balance |

### 8.2 Transfer vBTC (ERC-20)

| | |
|---|---|
| **Contract** | `IERC20.transfer(address to, uint256 amount)` or `transferFrom(address from, address to, uint256 amount)` |
| **CLI** | None (use `cast send` directly) |
| **Actor** | vBTC Holder |
| **Preconditions** | Sufficient balance; for `transferFrom`: sufficient allowance |
| **Effects** | Transfers vBTC tokens; changes who can recombine or claim dormant collateral |

### 8.3 Transfer Vault NFT (ERC-721)

| | |
|---|---|
| **Contract** | `IERC721.transferFrom(address from, address to, uint256 tokenId)` or `safeTransferFrom(...)` |
| **CLI** | None (use `cast send` directly) |
| **Actor** | Vault Owner (or approved operator) |
| **Preconditions** | Caller is owner or approved |
| **Effects** | Transfers vault ownership; new owner inherits withdrawal rights, delegation management, and dormancy response obligations |

### 8.4 Approve Vault NFT (ERC-721)

| | |
|---|---|
| **Contract** | `IERC721.approve(address to, uint256 tokenId)` or `setApprovalForAll(address operator, bool approved)` |
| **CLI** | None (use `cast send` directly) |
| **Actor** | Vault Owner |
| **Preconditions** | Caller is owner or approved-for-all operator |
| **Effects** | Grants transfer permission for a specific vault or all vaults |

---

## 9. Query Actions (Read-Only)

These do not modify state but are essential for decision-making.

### 9.1 Vault Status

| | |
|---|---|
| **Contract** | `VaultNFT.getVaultInfo(uint256 tokenId)` |
| **CLI** | `./btcnft status <vault_token_id>` |
| **Returns** | Treasure contract/ID, collateral token/amount, mint timestamp, last withdrawal, last activity, vBTC amount, original minted amount |

### 9.2 Hybrid Vault Status

| | |
|---|---|
| **Contract** | `VaultNFT.getVaultInfo(uint256 tokenId)` + `VestingEscrow.escrowAmount(uint256 tokenId)` / `claimable(uint256 tokenId)` |
| **CLI** | `./btcnft hybrid-status <vault_token_id>` |
| **Returns** | Standard vault info for the primary leg plus escrowed secondary amount and claimability |

### 9.3 Check Vesting Status

| | |
|---|---|
| **Contract** | `VaultNFT.isVested(uint256 tokenId)` |
| **CLI** | Included in `status` / `hybrid-status` output |
| **Returns** | `bool` |

### 9.4 Get Withdrawable Amount

| | |
|---|---|
| **Contract** | `VaultNFT.getWithdrawableAmount(uint256 tokenId)` (primary) / `VestingEscrow.claimable(uint256 tokenId)` (secondary) |
| **CLI** | Included in `status` / `hybrid-status` output |
| **Returns** | `uint256` |

### 9.5 Check Collateral Claim (vBTC)

| | |
|---|---|
| **Contract** | `VaultNFT.getCollateralClaim(uint256 tokenId)` |
| **CLI** | None |
| **Returns** | Current remaining collateral backing the vBTC |

### 9.6 Get Claim Value for vBTC Holder

| | |
|---|---|
| **Contract** | `VaultNFT.getClaimValue(address holder, uint256 tokenId)` |
| **CLI** | None |
| **Returns** | Proportional claim on current collateral based on holder's vBTC balance |

### 9.7 Check Dormancy Eligibility

| | |
|---|---|
| **Contract** | `VaultNFT.isDormantEligible(uint256 tokenId)` |
| **CLI** | Included in `status` / `hybrid-status` output |
| **Returns** | `(bool eligible, DormancyState state)` |

### 9.8 Query Delegation Status

| | |
|---|---|
| **Contract** | `getWalletDelegatePermission(address owner, address delegate)`, `getVaultDelegatePermission(uint256 tokenId, address delegate)`, `getEffectiveDelegation(uint256 tokenId, address delegate)`, `canDelegateWithdraw(uint256 tokenId, address delegate)` |
| **CLI** | `./btcnft delegates <vault_id> [address]` / `./btcnft hybrid-delegates <vault_id> [address]` |
| **Returns** | Permission details, effective BPS, delegation type, withdrawal availability |

### 9.9 Token Balance

| | |
|---|---|
| **Contract** | `IERC20.balanceOf(address account)` |
| **CLI** | `./btcnft token-balance <token_alias> [wallet_address] [spender]` |
| **Returns** | Token balance and optional allowance |

### 9.10 Batch Vault Status

| | |
|---|---|
| **CLI** | `./btcnft batch-status <id1> [id2] [id3] ...` |
| **Returns** | Tabular summary: ID, Collateral, Vested, vBTC, Delegated % |

### 9.11 Get Delegate Cooldown

| | |
|---|---|
| **Contract** | `VaultNFT.getDelegateCooldown(address delegate, uint256 tokenId)` |
| **CLI** | Included in `delegates` detailed query |
| **Returns** | Timestamp of delegate's last withdrawal from this vault |

---

## 10. Development Actions (Local Only)

### 10.1 Setup

| | |
|---|---|
| **CLI** | `./btcnft setup` |
| **Network** | Local (Anvil) only |
| **Effects** | Deploys all contracts, seeds 5 test vaults (1100 days old), generates `.env`, resets time to epoch baseline |

### 10.2 Time Skip

| | |
|---|---|
| **CLI** | `./btcnft time-skip <days>` |
| **Network** | Local (Anvil) only |
| **Effects** | Fast-forwards blockchain time by specified days; uses `evm_increaseTime` + `evm_mine` |

---

## 11. Multi-Step Workflows

These are common sequences of individual actions that together accomplish a higher-level goal.

### 11.1 Full Vault Lifecycle

```
approve collateral -> mint -> [wait 1129 days] -> withdraw (monthly) -> separate -> [trade vBTC] -> recombine -> withdraw
```

### 11.2 Early Exit

```
approve collateral -> mint -> [any time] -> early-redeem
```

### 11.3 Delegation Setup

```
mint -> [vest] -> delegate-grant (or vault-delegate-grant) -> [delegate calls] delegate-withdraw
```

### 11.4 Dormancy Claim (by vBTC Holder)

```
[Vault owner separates vBTC] -> [vBTC holder acquires tokens] -> [1129 days inactivity] -> poke -> [30 days grace] -> claim-dormant
```

### 11.5 Hybrid Vault Full Lifecycle

```
approve primary + secondary -> hybrid-mint -> [wait 1129 days] -> hybrid-withdraw-primary (monthly) -> hybrid-withdraw-secondary (one-time) -> hybrid-separate -> [trade vBTC]
```

### 11.6 Match Pool Participation

```
mint -> [wait 1129 days] -> claim-match (share of forfeitures from early redeemers)
```

### 11.7 vBTC DeFi Composability

```
mint -> [vest] -> separate -> [provide liquidity on Curve/Uniswap] -> [earn LP fees] -> [remove liquidity] -> recombine
```

---

## Action Summary Matrix

| # | Action | Actor | State Change | CLI | Reversible |
|---|--------|-------|-------------|-----|-----------|
| 1.1 | Mint vault | Anyone | Yes | `mint` | Via early-redeem |
| 1.2 | Mint hybrid vault | Anyone | Yes | `hybrid-mint` | Via hybrid-early-redeem |
| 2.1 | Withdraw | Owner | Yes | `withdraw` | No |
| 2.2 | Withdraw primary | Owner | Yes | `hybrid-withdraw-primary` | No |
| 2.3 | Withdraw secondary | Owner | Yes | `hybrid-withdraw-secondary` | No |
| 2.4 | Delegate withdraw | Delegate | Yes | `delegate-withdraw` | No |
| 2.5 | Hybrid delegate withdraw | Delegate | Yes | `hybrid-delegate-withdraw` | No |
| 3.1 | Early redeem | Owner | Yes | `early-redeem` | No (burns vault) |
| 3.2 | Early redeem hybrid | Owner | Yes | `hybrid-early-redeem` | No (burns vault) |
| 4.1 | Separate | Owner | Yes | `separate` | Via recombine |
| 4.2 | Separate hybrid | Owner | Yes | `hybrid-separate` | Via hybrid-recombine |
| 4.3 | Recombine | Owner+vBTC | Yes | `recombine` | Via separate |
| 4.4 | Recombine hybrid | Owner+vBTC | Yes | `hybrid-recombine` | Via hybrid-separate |
| 5.1 | Claim match | Owner | Yes | `claim-match` | No |
| 5.2 | Claim primary match | Owner | Yes | `hybrid-claim-primary-match` | No |
| 5.3 | Claim secondary match | Owner | Yes | `hybrid-claim-secondary-match` | No |
| 6.1 | Grant wallet delegation | Owner | Yes | `delegate-grant` | Via delegate-revoke |
| 6.3 | Revoke wallet delegation | Owner | Yes | `delegate-revoke` | Via delegate-grant |
| 6.4 | Grant vault delegation | Owner | Yes | `vault-delegate-grant` | Via vault-delegate-revoke |
| 6.5 | Revoke vault delegation | Owner | Yes | `vault-delegate-revoke` | Via vault-delegate-grant |
| 7.1 | Poke | Anyone | Yes | `poke` / `hybrid-poke` | Owner proves activity |
| 7.2 | Prove activity | Owner | Yes | `prove-activity` / `hybrid-prove-activity` | N/A |
| 7.3 | Claim dormant | vBTC Holder | Yes | `claim-dormant` / `hybrid-claim-dormant` | No |
| 8.1 | Approve ERC-20 | Holder | Yes | `token-approve` | Set to 0 |
| 8.2 | Transfer vBTC | Holder | Yes | None | Transfer back |
| 8.3 | Transfer vault NFT | Owner | Yes | None | Transfer back |
| 8.4 | Approve vault NFT | Owner | Yes | None | Revoke |
