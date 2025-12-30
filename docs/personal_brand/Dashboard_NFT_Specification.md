# DashboardNFT Specification

Revenue-generating NFTs that unlock UI/UX features on the protocol dashboard.

## Overview

DashboardNFT is a paid NFT collection separate from The Ascent campaign. While The Ascent provides free, merit-based achievements, DashboardNFT offers premium features for purchase.

| Aspect | The Ascent | DashboardNFT |
|--------|------------|--------------|
| Cost | Free | Paid (ETH) |
| Basis | Merit/duration | Purchase |
| Transferable | No (soulbound) | Yes (ERC-721) |
| Purpose | Recognition | Feature unlocks |
| Revenue | None | Mint fees + royalties |

## Revenue Model

**Primary Revenue**: One-time mint fees paid in ETH

**Secondary Revenue**: 5% royalty (ERC-2981) on marketplace trades

## Token Standards

- **ERC-721**: Standard NFT, fully transferable
- **ERC-2981**: Royalty info for marketplace integration

## Contract Architecture

**Location**: `contracts/issuer/src/DashboardNFT.sol`

```solidity
contract DashboardNFT is ERC721Royalty, Ownable {
    mapping(uint256 => bytes32) public featureType;
    mapping(bytes32 => uint256) public mintPrice;
    mapping(bytes32 => bool) public featureActive;
    mapping(address => mapping(bytes32 => uint256)) private _featureOwnershipCount;
}
```

### Key Functions

| Function | Access | Description |
|----------|--------|-------------|
| `mint(bytes32)` | Public | Mint feature NFT with payment |
| `hasFeature(address, bytes32)` | View | Check if wallet has feature |
| `setMintPrice(bytes32, uint256)` | Owner | Configure feature price |
| `setFeatureActive(bytes32, bool)` | Owner | Enable/disable minting |
| `withdraw()` | Owner | Withdraw accumulated funds |

## Feature Categories

### Cosmetic Features (0.001-0.003 ETH)

| Feature ID | Description |
|------------|-------------|
| `THEME_DARK` | Enhanced dark theme with custom accents |
| `THEME_NEON` | Cyberpunk neon color scheme |
| `FRAME_ANIMATED` | Animated borders on Vault cards |
| `AVATAR_CUSTOM` | Upload personal profile image |

### Functional Features (0.005-0.015 ETH)

| Feature ID | Description |
|------------|-------------|
| `ANALYTICS_PRO` | Advanced charts, historical data |
| `EXPORT_CSV` | Export portfolio to CSV/JSON |
| `ALERTS_ADVANCED` | Custom notifications |
| `PORTFOLIO_MULTI` | Track multiple wallets |

### Bundle

| Feature ID | Price | Description |
|------------|-------|-------------|
| `FOUNDERS_BUNDLE` | 0.03 ETH | All features at discount |

## Frontend Integration

### Ownership Check

```typescript
const hasAccess = await dashboardNFT.hasFeature(wallet, ANALYTICS_PRO);
```

### UI Gate Pattern

```typescript
function AnalyticsDashboard() {
  const hasProAnalytics = useDashboardNFT().hasFeature(wallet, 'ANALYTICS_PRO');

  if (!hasProAnalytics) {
    return <UpgradePrompt feature="ANALYTICS_PRO" />;
  }

  return <ProAnalyticsView />;
}
```

### Mint Flow

```typescript
const price = await dashboardNFT.mintPrice(ANALYTICS_PRO);
const tx = await dashboardNFT.mint(ANALYTICS_PRO, { value: price });
```

## Feature Ownership Tracking

Ownership is tracked via count mapping updated on transfer:

```solidity
function _update(address to, uint256 tokenId, address auth) internal override {
    address from = super._update(to, tokenId, auth);
    bytes32 ft = featureType[tokenId];

    if (from != address(0)) _featureOwnershipCount[from][ft]--;
    if (to != address(0)) _featureOwnershipCount[to][ft]++;

    return from;
}
```

`hasFeature(wallet, featureType)` returns `true` if ownership count > 0.

## Deployment

### Environment Variables

```bash
PRIVATE_KEY=0x...
REVENUE_RECEIVER=0x...
ROYALTY_BPS=500  # Optional, default 5%
DASHBOARD_NAME="Dashboard NFT"  # Optional
DASHBOARD_SYMBOL="DASH"  # Optional
DASHBOARD_BASE_URI="https://api.example.com/dashboard/"  # Optional
```

### Deploy Command

```bash
cd contracts/issuer
forge script script/DeployDashboardNFT.s.sol --rpc-url $RPC_URL --broadcast
```

## Files

| Path | Purpose |
|------|---------|
| `contracts/issuer/src/DashboardNFT.sol` | Main contract |
| `contracts/issuer/src/interfaces/IDashboardNFT.sol` | Interface |
| `contracts/issuer/test/unit/DashboardNFT.t.sol` | Unit tests |
| `contracts/issuer/script/DeployDashboardNFT.s.sol` | Deployment |
