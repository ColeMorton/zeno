'use client';

import { useReadContracts, useChainId } from 'wagmi';
import { formatUnits, type Address } from 'viem';
import { PERPETUAL_VAULT_ABI, getContracts, requireAddress } from '@/lib/contracts';
import { type GlobalState, formatFundingRate } from '@/lib/perpetual';

const VBTC_DECIMALS = 8;
const REFRESH_INTERVAL = 10_000;

interface PerpetualVaultState {
  /** Global vault state */
  globalState: GlobalState | undefined;
  /** Current funding rate in BPS */
  fundingRateBPS: bigint | undefined;
  /** Formatted funding rate string */
  fundingRateFormatted: string | undefined;
  /** Current vBTC/cbBTC price (18 decimals) */
  currentPrice: bigint | undefined;
  /** Formatted current price */
  priceFormatted: number | undefined;
  /** Total long OI formatted */
  longOIFormatted: string | undefined;
  /** Total short OI formatted */
  shortOIFormatted: string | undefined;
  /** OI imbalance percentage (positive = more longs) */
  oiImbalancePercent: number | undefined;
  /** Loading state */
  isLoading: boolean;
  /** Error state */
  error: Error | null;
  /** Refetch function */
  refetch: () => void;
}

export function usePerpetualVault(): PerpetualVaultState {
  const chainId = useChainId();

  let perpetualVault: Address;
  try {
    const contracts = getContracts(chainId);
    perpetualVault = requireAddress(contracts.perpetualVault, 'perpetualVault');
  } catch (err) {
    return {
      globalState: undefined,
      fundingRateBPS: undefined,
      fundingRateFormatted: undefined,
      currentPrice: undefined,
      priceFormatted: undefined,
      longOIFormatted: undefined,
      shortOIFormatted: undefined,
      oiImbalancePercent: undefined,
      isLoading: false,
      error: err instanceof Error ? err : new Error('Contract not configured'),
      refetch: () => {},
    };
  }

  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      {
        address: perpetualVault,
        abi: PERPETUAL_VAULT_ABI,
        functionName: 'getGlobalState',
      },
      {
        address: perpetualVault,
        abi: PERPETUAL_VAULT_ABI,
        functionName: 'getCurrentFundingRate',
      },
      {
        address: perpetualVault,
        abi: PERPETUAL_VAULT_ABI,
        functionName: 'getCurrentPrice',
      },
    ],
    query: {
      refetchInterval: REFRESH_INTERVAL,
    },
  });

  const rawGlobalState = data?.[0]?.result as
    | readonly [bigint, bigint, bigint, bigint, bigint, bigint, bigint]
    | undefined;
  const fundingRateBPS = data?.[1]?.result as bigint | undefined;
  const currentPrice = data?.[2]?.result as bigint | undefined;

  let globalState: GlobalState | undefined;
  if (rawGlobalState) {
    globalState = {
      longOI: rawGlobalState[0],
      shortOI: rawGlobalState[1],
      longCollateral: rawGlobalState[2],
      shortCollateral: rawGlobalState[3],
      fundingAccumulatorLong: rawGlobalState[4],
      fundingAccumulatorShort: rawGlobalState[5],
      lastFundingUpdate: rawGlobalState[6],
    };
  }

  const fundingRateFormatted =
    fundingRateBPS !== undefined ? formatFundingRate(fundingRateBPS) : undefined;

  const priceFormatted =
    currentPrice !== undefined ? Number(formatUnits(currentPrice, 18)) : undefined;

  const longOIFormatted =
    globalState !== undefined
      ? Number(formatUnits(globalState.longOI, VBTC_DECIMALS)).toFixed(4)
      : undefined;

  const shortOIFormatted =
    globalState !== undefined
      ? Number(formatUnits(globalState.shortOI, VBTC_DECIMALS)).toFixed(4)
      : undefined;

  let oiImbalancePercent: number | undefined;
  if (globalState) {
    const totalOI = globalState.longOI + globalState.shortOI;
    if (totalOI > 0n) {
      const imbalance = globalState.longOI - globalState.shortOI;
      oiImbalancePercent = (Number(imbalance) / Number(totalOI)) * 100;
    } else {
      oiImbalancePercent = 0;
    }
  }

  return {
    globalState,
    fundingRateBPS,
    fundingRateFormatted,
    currentPrice,
    priceFormatted,
    longOIFormatted,
    shortOIFormatted,
    oiImbalancePercent,
    isLoading,
    error: error ?? null,
    refetch,
  };
}
