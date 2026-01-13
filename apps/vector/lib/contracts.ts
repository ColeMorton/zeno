import { type Address } from 'viem';

// Curve CryptoSwap V2 Pool ABI (vBTC/cbBTC)
export const CURVE_POOL_ABI = [
  {
    name: 'price_oracle',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'last_prices',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'balances',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'i', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'get_virtual_price',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'get_dy',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'i', type: 'int128' },
      { name: 'j', type: 'int128' },
      { name: 'dx', type: 'uint256' },
    ],
    outputs: [{ type: 'uint256' }],
  },
] as const;

// ERC-20 ABI (minimal for vBTC)
export const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'decimals',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    name: 'symbol',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'string' }],
  },
] as const;

// ERC-4626 Tokenized Vault ABI (yvBTC)
export const ERC4626_ABI = [
  // Read functions
  {
    name: 'asset',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'totalAssets',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'totalSupply',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'convertToShares',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'convertToAssets',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'shares', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'maxDeposit',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'receiver', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'maxWithdraw',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'previewDeposit',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'previewWithdraw',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'previewRedeem',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'shares', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  // Write functions
  {
    name: 'deposit',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'withdraw',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'redeem',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
] as const;

// PerpetualVault ABI (IPerpetualVault)
export const PERPETUAL_VAULT_ABI = [
  // Position management
  {
    name: 'openPosition',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'collateral', type: 'uint256' },
      { name: 'leverageX100', type: 'uint256' },
      { name: 'side', type: 'uint8' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'closePosition',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'positionId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'addCollateral',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'positionId', type: 'uint256' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [],
  },
  // View functions
  {
    name: 'previewClose',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'positionId', type: 'uint256' }],
    outputs: [
      { name: 'pnl', type: 'int256' },
      { name: 'payout', type: 'uint256' },
    ],
  },
  {
    name: 'getPosition',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'positionId', type: 'uint256' }],
    outputs: [
      {
        name: 'position',
        type: 'tuple',
        components: [
          { name: 'collateral', type: 'uint256' },
          { name: 'notional', type: 'uint256' },
          { name: 'leverageX100', type: 'uint256' },
          { name: 'entryPrice', type: 'uint256' },
          { name: 'entryFundingAccumulator', type: 'int256' },
          { name: 'openTimestamp', type: 'uint256' },
          { name: 'side', type: 'uint8' },
        ],
      },
    ],
  },
  {
    name: 'getPositionOwner',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'positionId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'getCurrentFundingRate',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'int256' }],
  },
  {
    name: 'getGlobalState',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      {
        name: 'state',
        type: 'tuple',
        components: [
          { name: 'longOI', type: 'uint256' },
          { name: 'shortOI', type: 'uint256' },
          { name: 'longCollateral', type: 'uint256' },
          { name: 'shortCollateral', type: 'uint256' },
          { name: 'fundingAccumulatorLong', type: 'int256' },
          { name: 'fundingAccumulatorShort', type: 'int256' },
          { name: 'lastFundingUpdate', type: 'uint256' },
        ],
      },
    ],
  },
  {
    name: 'getCurrentPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'vBTC',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const;

// Contract addresses by chain
interface VectorContracts {
  vBTC: Address;
  cbBTC: Address;
  curvePool: Address;
  perpetualVault: Address;
  yieldVault: Address;
  volatilityPool: Address;
}

const ANVIL_CONTRACTS: VectorContracts = {
  vBTC: (process.env.NEXT_PUBLIC_VBTC_ANVIL ?? '') as Address,
  cbBTC: (process.env.NEXT_PUBLIC_CBBTC_ANVIL ?? '') as Address,
  curvePool: (process.env.NEXT_PUBLIC_CURVE_POOL_ANVIL ?? '') as Address,
  perpetualVault: (process.env.NEXT_PUBLIC_PERPETUAL_VAULT_ANVIL ?? '') as Address,
  yieldVault: (process.env.NEXT_PUBLIC_YIELD_VAULT_ANVIL ?? '') as Address,
  volatilityPool: (process.env.NEXT_PUBLIC_VOLATILITY_POOL_ANVIL ?? '') as Address,
};

const BASE_CONTRACTS: VectorContracts = {
  vBTC: (process.env.NEXT_PUBLIC_VBTC_BASE ?? '') as Address,
  cbBTC: (process.env.NEXT_PUBLIC_CBBTC_BASE ?? '') as Address,
  curvePool: (process.env.NEXT_PUBLIC_CURVE_POOL_BASE ?? '') as Address,
  perpetualVault: (process.env.NEXT_PUBLIC_PERPETUAL_VAULT_BASE ?? '') as Address,
  yieldVault: (process.env.NEXT_PUBLIC_YIELD_VAULT_BASE ?? '') as Address,
  volatilityPool: (process.env.NEXT_PUBLIC_VOLATILITY_POOL_BASE ?? '') as Address,
};

export function getContracts(chainId: number): VectorContracts {
  if (chainId === 31337) {
    return ANVIL_CONTRACTS;
  }
  if (chainId === 8453) {
    return BASE_CONTRACTS;
  }
  throw new Error(`Unsupported chain: ${chainId}`);
}

// Validation helper - fail fast if address is missing
export function requireAddress(address: Address | undefined, name: string): Address {
  if (!address || address.length < 42) {
    throw new Error(`Contract address not configured: ${name}`);
  }
  return address;
}
