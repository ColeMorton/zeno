'use client';

import { useReadContracts, useWriteContract, useChainId, useAccount } from 'wagmi';
import { formatUnits, parseUnits, type Address } from 'viem';
import { ERC4626_ABI, ERC20_ABI, getContracts, requireAddress } from '@/lib/contracts';

const VBTC_DECIMALS = 8;
const REFRESH_INTERVAL = 10_000;

interface YieldVaultState {
  /** Total vBTC assets in vault */
  totalAssets: bigint | undefined;
  /** Total yvBTC shares outstanding */
  totalSupply: bigint | undefined;
  /** Exchange rate (assets per share), formatted */
  exchangeRate: number | undefined;
  /** User's yvBTC share balance */
  userShares: bigint | undefined;
  /** User's shares converted to vBTC assets */
  userAssets: bigint | undefined;
  /** Formatted user assets */
  userAssetsFormatted: string | undefined;
  /** Loading state */
  isLoading: boolean;
  /** Error state */
  error: Error | null;
  /** Refetch vault data */
  refetch: () => void;
}

interface YieldVaultActions {
  /** Deposit vBTC assets into vault */
  deposit: (amount: string) => Promise<void>;
  /** Withdraw vBTC assets from vault */
  withdraw: (amount: string) => Promise<void>;
  /** Redeem yvBTC shares for vBTC */
  redeem: (shares: string) => Promise<void>;
  /** Preview deposit: assets -> shares */
  previewDeposit: (amount: string) => bigint | undefined;
  /** Preview withdraw: assets -> shares needed */
  previewWithdraw: (amount: string) => bigint | undefined;
  /** Transaction pending state */
  isPending: boolean;
}

export function useYieldVault(): YieldVaultState & YieldVaultActions {
  const chainId = useChainId();
  const { address: userAddress } = useAccount();

  let yieldVault: Address;
  let vBTC: Address;
  try {
    const contracts = getContracts(chainId);
    yieldVault = requireAddress(contracts.yieldVault, 'yieldVault');
    vBTC = requireAddress(contracts.vBTC, 'vBTC');
  } catch (err) {
    return {
      totalAssets: undefined,
      totalSupply: undefined,
      exchangeRate: undefined,
      userShares: undefined,
      userAssets: undefined,
      userAssetsFormatted: undefined,
      isLoading: false,
      error: err instanceof Error ? err : new Error('Contract not configured'),
      refetch: () => {},
      deposit: async () => {},
      withdraw: async () => {},
      redeem: async () => {},
      previewDeposit: () => undefined,
      previewWithdraw: () => undefined,
      isPending: false,
    };
  }

  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      {
        address: yieldVault,
        abi: ERC4626_ABI,
        functionName: 'totalAssets',
      },
      {
        address: yieldVault,
        abi: ERC4626_ABI,
        functionName: 'totalSupply',
      },
      {
        address: yieldVault,
        abi: ERC4626_ABI,
        functionName: 'balanceOf',
        args: [userAddress ?? '0x0000000000000000000000000000000000000000'],
      },
    ],
    query: {
      refetchInterval: REFRESH_INTERVAL,
      enabled: true,
    },
  });

  const { writeContractAsync, isPending } = useWriteContract();

  const totalAssets = data?.[0]?.result as bigint | undefined;
  const totalSupply = data?.[1]?.result as bigint | undefined;
  const userShares = data?.[2]?.result as bigint | undefined;

  // Calculate user assets from shares locally to avoid circular dependency
  let userAssets: bigint | undefined;
  if (userShares !== undefined && totalAssets !== undefined && totalSupply !== undefined && totalSupply > 0n) {
    userAssets = (userShares * totalAssets) / totalSupply;
  } else if (userShares !== undefined && totalSupply === 0n) {
    userAssets = userShares; // 1:1 when no shares exist yet
  }

  let exchangeRate: number | undefined;
  if (totalAssets !== undefined && totalSupply !== undefined && totalSupply > 0n) {
    exchangeRate = Number(formatUnits(totalAssets, VBTC_DECIMALS)) /
                   Number(formatUnits(totalSupply, VBTC_DECIMALS));
  } else if (totalSupply === 0n) {
    exchangeRate = 1.0; // Initial rate is 1:1
  }

  const userAssetsFormatted = userAssets !== undefined
    ? formatUnits(userAssets, VBTC_DECIMALS)
    : undefined;

  const deposit = async (amount: string) => {
    if (!userAddress) throw new Error('Wallet not connected');
    const assets = parseUnits(amount, VBTC_DECIMALS);

    // First approve vBTC spending
    await writeContractAsync({
      address: vBTC,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [yieldVault, assets],
    });

    // Then deposit
    await writeContractAsync({
      address: yieldVault,
      abi: ERC4626_ABI,
      functionName: 'deposit',
      args: [assets, userAddress],
    });

    refetch();
  };

  const withdraw = async (amount: string) => {
    if (!userAddress) throw new Error('Wallet not connected');
    const assets = parseUnits(amount, VBTC_DECIMALS);

    await writeContractAsync({
      address: yieldVault,
      abi: ERC4626_ABI,
      functionName: 'withdraw',
      args: [assets, userAddress, userAddress],
    });

    refetch();
  };

  const redeem = async (shares: string) => {
    if (!userAddress) throw new Error('Wallet not connected');
    const shareAmount = parseUnits(shares, VBTC_DECIMALS);

    await writeContractAsync({
      address: yieldVault,
      abi: ERC4626_ABI,
      functionName: 'redeem',
      args: [shareAmount, userAddress, userAddress],
    });

    refetch();
  };

  const previewDeposit = (amount: string): bigint | undefined => {
    if (!totalAssets || !totalSupply) return undefined;
    const assets = parseUnits(amount, VBTC_DECIMALS);
    if (totalSupply === 0n) return assets;
    return (assets * totalSupply) / totalAssets;
  };

  const previewWithdraw = (amount: string): bigint | undefined => {
    if (!totalAssets || !totalSupply || totalAssets === 0n) return undefined;
    const assets = parseUnits(amount, VBTC_DECIMALS);
    return (assets * totalSupply) / totalAssets;
  };

  return {
    totalAssets,
    totalSupply,
    exchangeRate,
    userShares,
    userAssets,
    userAssetsFormatted,
    isLoading,
    error: error ?? null,
    refetch,
    deposit,
    withdraw,
    redeem,
    previewDeposit,
    previewWithdraw,
    isPending,
  };
}
