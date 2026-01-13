'use client';

import { useReadContracts, useChainId } from 'wagmi';
import { formatUnits } from 'viem';
import { CURVE_POOL_ABI, getContracts, requireAddress } from '@/lib/contracts';

const PRICE_DECIMALS = 18;
const REFRESH_INTERVAL = 10_000; // 10 seconds

interface VBTCPriceData {
  /** EMA oracle price (vBTC per cbBTC, 18 decimals) */
  priceOracle: bigint | undefined;
  /** Last trade price (vBTC per cbBTC, 18 decimals) */
  lastPrice: bigint | undefined;
  /** Formatted oracle price as number */
  priceFormatted: number | undefined;
  /** Discount from peg (1 - price), as percentage */
  discountPercent: number | undefined;
  /** Whether data is loading */
  isLoading: boolean;
  /** Error if any */
  error: Error | null;
  /** Refetch function */
  refetch: () => void;
}

/**
 * Fetches vBTC/cbBTC price from Curve CryptoSwap V2 pool.
 *
 * The pool's price_oracle() returns the EMA price, which smooths
 * short-term volatility. A price < 1e18 means vBTC trades at a
 * discount to cbBTC.
 */
export function useVBTCPrice(): VBTCPriceData {
  const chainId = useChainId();

  let curvePool;
  try {
    const contracts = getContracts(chainId);
    curvePool = requireAddress(contracts.curvePool, 'curvePool');
  } catch {
    return {
      priceOracle: undefined,
      lastPrice: undefined,
      priceFormatted: undefined,
      discountPercent: undefined,
      isLoading: false,
      error: new Error('Curve pool not configured'),
      refetch: () => {},
    };
  }

  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      {
        address: curvePool,
        abi: CURVE_POOL_ABI,
        functionName: 'price_oracle',
      },
      {
        address: curvePool,
        abi: CURVE_POOL_ABI,
        functionName: 'last_prices',
      },
    ],
    query: {
      refetchInterval: REFRESH_INTERVAL,
    },
  });

  const priceOracle = data?.[0]?.result as bigint | undefined;
  const lastPrice = data?.[1]?.result as bigint | undefined;

  let priceFormatted: number | undefined;
  let discountPercent: number | undefined;

  if (priceOracle !== undefined) {
    priceFormatted = Number(formatUnits(priceOracle, PRICE_DECIMALS));
    // Discount = (1 - price) * 100, where price < 1 means discount
    discountPercent = (1 - priceFormatted) * 100;
  }

  return {
    priceOracle,
    lastPrice,
    priceFormatted,
    discountPercent,
    isLoading,
    error: error ?? null,
    refetch,
  };
}
