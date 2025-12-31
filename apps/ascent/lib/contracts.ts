// Contract ABIs and chain-specific addresses for minting flow

export const ERC20_ABI = [
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
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export const ERC721_ABI = [
  {
    name: 'setApprovalForAll',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'operator', type: 'address' },
      { name: 'approved', type: 'bool' },
    ],
    outputs: [],
  },
  {
    name: 'isApprovedForAll',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'operator', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'tokenOfOwnerByIndex',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'index', type: 'uint256' },
    ],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export const VAULT_NFT_ABI = [
  {
    name: 'mint',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'treasureContract', type: 'address' },
      { name: 'treasureTokenId', type: 'uint256' },
      { name: 'collateralToken', type: 'address' },
      { name: 'collateralAmount', type: 'uint256' },
    ],
    outputs: [{ name: 'tokenId', type: 'uint256' }],
  },
] as const;

interface ContractAddresses {
  vaultNFT: `0x${string}`;
  achievementNFT: `0x${string}`;
  cbBTC: `0x${string}`;
}

export function getContractAddresses(chainId: number): ContractAddresses {
  // Anvil local development
  if (chainId === 31337) {
    const vaultNFT = process.env.NEXT_PUBLIC_VAULT_NFT_ANVIL;
    const achievementNFT = process.env.NEXT_PUBLIC_ACHIEVEMENT_NFT_ANVIL;
    const cbBTC = process.env.NEXT_PUBLIC_CBBTC_ANVIL;

    if (!vaultNFT || !achievementNFT || !cbBTC) {
      throw new Error(
        'Anvil contract addresses not configured. Set NEXT_PUBLIC_VAULT_NFT_ANVIL, NEXT_PUBLIC_ACHIEVEMENT_NFT_ANVIL, and NEXT_PUBLIC_CBBTC_ANVIL'
      );
    }

    return {
      vaultNFT: vaultNFT as `0x${string}`,
      achievementNFT: achievementNFT as `0x${string}`,
      cbBTC: cbBTC as `0x${string}`,
    };
  }

  // Base mainnet
  if (chainId === 8453) {
    const vaultNFT = process.env.NEXT_PUBLIC_VAULT_NFT_BASE;
    const achievementNFT = process.env.NEXT_PUBLIC_ACHIEVEMENT_NFT_BASE;
    const cbBTC =
      process.env.NEXT_PUBLIC_CBBTC_BASE ??
      '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf';

    if (!vaultNFT || !achievementNFT) {
      throw new Error(
        'Base contract addresses not configured. Set NEXT_PUBLIC_VAULT_NFT_BASE and NEXT_PUBLIC_ACHIEVEMENT_NFT_BASE'
      );
    }

    return {
      vaultNFT: vaultNFT as `0x${string}`,
      achievementNFT: achievementNFT as `0x${string}`,
      cbBTC: cbBTC as `0x${string}`,
    };
  }

  throw new Error(`Unsupported chain: ${chainId}`);
}
