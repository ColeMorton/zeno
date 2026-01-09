// Contract ABIs and chain-specific addresses for minting flow

export const CHAPTER_REGISTRY_ABI = [
  {
    name: 'getChapter',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'chapterId', type: 'bytes32' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'chapterId', type: 'bytes32' },
          { name: 'chapterNumber', type: 'uint8' },
          { name: 'year', type: 'uint16' },
          { name: 'quarter', type: 'uint8' },
          { name: 'startTimestamp', type: 'uint48' },
          { name: 'endTimestamp', type: 'uint48' },
          { name: 'minDaysHeld', type: 'uint256' },
          { name: 'maxDaysHeld', type: 'uint256' },
          { name: 'baseURI', type: 'string' },
          { name: 'isActive', type: 'bool' },
        ],
      },
    ],
  },
  {
    name: 'getChapterAchievements',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'chapterId', type: 'bytes32' }],
    outputs: [
      {
        type: 'tuple[]',
        components: [
          { name: 'achievementId', type: 'bytes32' },
          { name: 'name', type: 'string' },
          { name: 'prerequisites', type: 'bytes32[]' },
          { name: 'verifier', type: 'address' },
        ],
      },
    ],
  },
] as const;

export const CHAPTER_MINTER_ABI = [
  {
    name: 'claimChapterAchievement',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'chapterId', type: 'bytes32' },
      { name: 'achievementId', type: 'bytes32' },
      { name: 'vaultId', type: 'uint256' },
      { name: 'collateralToken', type: 'address' },
      { name: 'verificationData', type: 'bytes' },
    ],
    outputs: [],
  },
  {
    name: 'canClaimChapterAchievement',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'claimer', type: 'address' },
      { name: 'chapterId', type: 'bytes32' },
      { name: 'achievementId', type: 'bytes32' },
      { name: 'vaultId', type: 'uint256' },
      { name: 'collateralToken', type: 'address' },
      { name: 'verificationData', type: 'bytes' },
    ],
    outputs: [
      { name: 'canClaim', type: 'bool' },
      { name: 'reason', type: 'string' },
    ],
  },
] as const;

export const CHAPTER_ACHIEVEMENT_NFT_ABI = [
  {
    name: 'hasAchievement',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'wallet', type: 'address' },
      { name: 'achievementId', type: 'bytes32' },
    ],
    outputs: [{ name: 'earned', type: 'bool' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export const PROFILE_REGISTRY_ABI = [
  {
    name: 'createProfile',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'hasProfile',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'wallet', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'registeredAt',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'wallet', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getDaysRegistered',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'wallet', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export const SIGNATURE_VERIFIER_ABI = [
  {
    name: 'signCommitment',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'signature', type: 'bytes' }],
    outputs: [],
  },
  {
    name: 'hasSignedCommitment',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'wallet', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'COMMITMENT_MESSAGE',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
] as const;

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

export const VAULT_MINT_CONTROLLER_ABI = [
  {
    name: 'mintVault',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'achievementType', type: 'bytes32' },
      { name: 'collateralAmount', type: 'uint256' },
    ],
    outputs: [{ name: 'vaultId', type: 'uint256' }],
  },
  {
    name: 'treasureNFT',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'vaultNFT',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'collateralToken',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const;

export const TREASURE_NFT_ABI = [
  {
    name: 'mintWithAchievement',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'achievementType', type: 'bytes32' },
    ],
    outputs: [{ name: 'tokenId', type: 'uint256' }],
  },
  {
    name: 'achievementType',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'bytes32' }],
  },
  {
    name: 'tokenURI',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'string' }],
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
] as const;

export const QUIZ_VERIFIER_ABI = [
  {
    name: 'submitQuiz',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'quizId', type: 'bytes32' },
      { name: 'answers', type: 'uint8[]' },
    ],
    outputs: [],
  },
  {
    name: 'quizPassed',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'wallet', type: 'address' },
      { name: 'quizId', type: 'bytes32' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'getQuiz',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'quizId', type: 'bytes32' }],
    outputs: [
      { name: 'questionCount', type: 'uint8' },
      { name: 'passingScore', type: 'uint8' },
      { name: 'exists', type: 'bool' },
    ],
  },
] as const;

interface ContractAddresses {
  vaultNFT: `0x${string}`;
  treasureNFT: `0x${string}`;
  cbBTC: `0x${string}`;
  vaultMintController: `0x${string}`;
  chapterRegistry?: `0x${string}`;
  chapterMinter?: `0x${string}`;
  chapterAchievementNFT?: `0x${string}`;
  profileRegistry?: `0x${string}`;
  signatureVerifier?: `0x${string}`;
  quizVerifier?: `0x${string}`;
}

export function getContractAddresses(chainId: number): ContractAddresses {
  // Anvil local development
  if (chainId === 31337) {
    const vaultNFT = process.env.NEXT_PUBLIC_VAULT_NFT_ANVIL;
    const treasureNFT = process.env.NEXT_PUBLIC_TREASURE_NFT_ANVIL;
    const cbBTC = process.env.NEXT_PUBLIC_CBBTC_ANVIL;
    const vaultMintController = process.env.NEXT_PUBLIC_VAULT_MINT_CONTROLLER_ANVIL;

    if (!vaultNFT || !treasureNFT || !cbBTC || !vaultMintController) {
      throw new Error(
        'Anvil contract addresses not configured. Set NEXT_PUBLIC_VAULT_NFT_ANVIL, NEXT_PUBLIC_TREASURE_NFT_ANVIL, NEXT_PUBLIC_CBBTC_ANVIL, and NEXT_PUBLIC_VAULT_MINT_CONTROLLER_ANVIL'
      );
    }

    return {
      vaultNFT: vaultNFT as `0x${string}`,
      treasureNFT: treasureNFT as `0x${string}`,
      cbBTC: cbBTC as `0x${string}`,
      vaultMintController: vaultMintController as `0x${string}`,
      chapterRegistry: process.env.NEXT_PUBLIC_CHAPTER_REGISTRY_ANVIL as `0x${string}` | undefined,
      chapterMinter: process.env.NEXT_PUBLIC_CHAPTER_MINTER_ANVIL as `0x${string}` | undefined,
      chapterAchievementNFT: process.env.NEXT_PUBLIC_CHAPTER_ACHIEVEMENT_NFT_ANVIL as `0x${string}` | undefined,
      profileRegistry: process.env.NEXT_PUBLIC_PROFILE_REGISTRY_ANVIL as `0x${string}` | undefined,
      signatureVerifier: process.env.NEXT_PUBLIC_SIGNATURE_VERIFIER_ANVIL as `0x${string}` | undefined,
      quizVerifier: process.env.NEXT_PUBLIC_QUIZ_VERIFIER_ANVIL as `0x${string}` | undefined,
    };
  }

  // Base mainnet
  if (chainId === 8453) {
    const vaultNFT = process.env.NEXT_PUBLIC_VAULT_NFT_BASE;
    const treasureNFT = process.env.NEXT_PUBLIC_TREASURE_NFT_BASE;
    const cbBTC =
      process.env.NEXT_PUBLIC_CBBTC_BASE ??
      '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf';
    const vaultMintController = process.env.NEXT_PUBLIC_VAULT_MINT_CONTROLLER_BASE;

    if (!vaultNFT || !treasureNFT || !vaultMintController) {
      throw new Error(
        'Base contract addresses not configured. Set NEXT_PUBLIC_VAULT_NFT_BASE, NEXT_PUBLIC_TREASURE_NFT_BASE, and NEXT_PUBLIC_VAULT_MINT_CONTROLLER_BASE'
      );
    }

    return {
      vaultNFT: vaultNFT as `0x${string}`,
      treasureNFT: treasureNFT as `0x${string}`,
      cbBTC: cbBTC as `0x${string}`,
      vaultMintController: vaultMintController as `0x${string}`,
      chapterRegistry: process.env.NEXT_PUBLIC_CHAPTER_REGISTRY_BASE as `0x${string}` | undefined,
      chapterMinter: process.env.NEXT_PUBLIC_CHAPTER_MINTER_BASE as `0x${string}` | undefined,
      chapterAchievementNFT: process.env.NEXT_PUBLIC_CHAPTER_ACHIEVEMENT_NFT_BASE as `0x${string}` | undefined,
      profileRegistry: process.env.NEXT_PUBLIC_PROFILE_REGISTRY_BASE as `0x${string}` | undefined,
      signatureVerifier: process.env.NEXT_PUBLIC_SIGNATURE_VERIFIER_BASE as `0x${string}` | undefined,
      quizVerifier: process.env.NEXT_PUBLIC_QUIZ_VERIFIER_BASE as `0x${string}` | undefined,
    };
  }

  throw new Error(`Unsupported chain: ${chainId}`);
}
