'use client';

import { useReadContracts, useChainId } from 'wagmi';
import { formatUnits, type Address } from 'viem';
import { PERPETUAL_VAULT_ABI, getContracts, requireAddress } from '@/lib/contracts';
import { type Position, Side, formatLeverage } from '@/lib/perpetual';

const VBTC_DECIMALS = 8;
const REFRESH_INTERVAL = 10_000;

interface PositionData {
  /** Position details */
  position: Position | undefined;
  /** Position owner address */
  owner: Address | undefined;
  /** Preview P&L */
  pnl: bigint | undefined;
  /** Preview payout */
  payout: bigint | undefined;
  /** Formatted collateral */
  collateralFormatted: string | undefined;
  /** Formatted notional */
  notionalFormatted: string | undefined;
  /** Formatted entry price */
  entryPriceFormatted: number | undefined;
  /** Formatted leverage */
  leverageFormatted: string | undefined;
  /** Formatted P&L */
  pnlFormatted: string | undefined;
  /** Formatted payout */
  payoutFormatted: string | undefined;
  /** P&L percentage */
  pnlPercent: number | undefined;
  /** Is position profitable */
  isProfitable: boolean;
  /** Loading state */
  isLoading: boolean;
  /** Error state */
  error: Error | null;
  /** Refetch function */
  refetch: () => void;
}

export function usePosition(positionId: bigint | undefined): PositionData {
  const chainId = useChainId();

  let perpetualVault: Address;
  try {
    const contracts = getContracts(chainId);
    perpetualVault = requireAddress(contracts.perpetualVault, 'perpetualVault');
  } catch (err) {
    return {
      position: undefined,
      owner: undefined,
      pnl: undefined,
      payout: undefined,
      collateralFormatted: undefined,
      notionalFormatted: undefined,
      entryPriceFormatted: undefined,
      leverageFormatted: undefined,
      pnlFormatted: undefined,
      payoutFormatted: undefined,
      pnlPercent: undefined,
      isProfitable: false,
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
        functionName: 'getPosition',
        args: positionId !== undefined ? [positionId] : undefined,
      },
      {
        address: perpetualVault,
        abi: PERPETUAL_VAULT_ABI,
        functionName: 'getPositionOwner',
        args: positionId !== undefined ? [positionId] : undefined,
      },
      {
        address: perpetualVault,
        abi: PERPETUAL_VAULT_ABI,
        functionName: 'previewClose',
        args: positionId !== undefined ? [positionId] : undefined,
      },
    ],
    query: {
      refetchInterval: REFRESH_INTERVAL,
      enabled: positionId !== undefined,
    },
  });

  const rawPosition = data?.[0]?.result as
    | readonly [bigint, bigint, bigint, bigint, bigint, bigint, number]
    | undefined;
  const owner = data?.[1]?.result as Address | undefined;
  const previewResult = data?.[2]?.result as readonly [bigint, bigint] | undefined;

  let position: Position | undefined;
  if (rawPosition) {
    position = {
      collateral: rawPosition[0],
      notional: rawPosition[1],
      leverageX100: rawPosition[2],
      entryPrice: rawPosition[3],
      entryFundingAccumulator: rawPosition[4],
      openTimestamp: rawPosition[5],
      side: rawPosition[6] as Side,
    };
  }

  const pnl = previewResult?.[0];
  const payout = previewResult?.[1];

  const collateralFormatted = position
    ? Number(formatUnits(position.collateral, VBTC_DECIMALS)).toFixed(4)
    : undefined;

  const notionalFormatted = position
    ? Number(formatUnits(position.notional, VBTC_DECIMALS)).toFixed(4)
    : undefined;

  const entryPriceFormatted = position
    ? Number(formatUnits(position.entryPrice, 18))
    : undefined;

  const leverageFormatted = position
    ? formatLeverage(position.leverageX100)
    : undefined;

  const pnlFormatted = pnl !== undefined
    ? Number(formatUnits(pnl, VBTC_DECIMALS)).toFixed(4)
    : undefined;

  const payoutFormatted = payout !== undefined
    ? Number(formatUnits(payout, VBTC_DECIMALS)).toFixed(4)
    : undefined;

  let pnlPercent: number | undefined;
  if (pnl !== undefined && position && position.collateral > 0n) {
    pnlPercent = (Number(pnl) / Number(position.collateral)) * 100;
  }

  const isProfitable = pnl !== undefined && pnl > 0n;

  return {
    position,
    owner,
    pnl,
    payout,
    collateralFormatted,
    notionalFormatted,
    entryPriceFormatted,
    leverageFormatted,
    pnlFormatted,
    payoutFormatted,
    pnlPercent,
    isProfitable,
    isLoading,
    error: error ?? null,
    refetch,
  };
}
