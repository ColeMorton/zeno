'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  useChainId,
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
  usePublicClient,
} from 'wagmi';
import { decodeEventLog } from 'viem';
import { getContractAddresses, VAULT_NFT_ABI, TREASURE_NFT_ABI } from '@/lib/contracts';

interface MintParams {
  achievementType: `0x${string}`;
  collateralAmount: bigint;
}

type MintStage = 'idle' | 'minting-treasure' | 'minting-vault' | 'complete';

export function useVaultMint() {
  const chainId = useChainId();
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const contracts = getContractAddresses(chainId);

  const [stage, setStage] = useState<MintStage>('idle');
  const [treasureTokenId, setTreasureTokenId] = useState<bigint | null>(null);
  const [error, setError] = useState<Error | null>(null);

  // Treasure minting
  const {
    writeContract: writeTreasure,
    data: treasureTxHash,
    isPending: isTreasurePending,
    error: treasureError,
    reset: resetTreasure,
  } = useWriteContract();

  const {
    isLoading: isTreasureConfirming,
    isSuccess: isTreasureSuccess,
    data: treasureReceipt,
  } = useWaitForTransactionReceipt({
    hash: treasureTxHash,
  });

  // Vault minting
  const {
    writeContract: writeVault,
    data: vaultTxHash,
    isPending: isVaultPending,
    error: vaultError,
    reset: resetVault,
  } = useWriteContract();

  const {
    isLoading: isVaultConfirming,
    isSuccess: isVaultSuccess,
    data: vaultReceipt,
  } = useWaitForTransactionReceipt({
    hash: vaultTxHash,
  });

  // Extract treasure token ID from mint receipt
  useEffect(() => {
    if (treasureReceipt && isTreasureSuccess && stage === 'minting-treasure') {
      // Find Transfer event to get tokenId
      for (const log of treasureReceipt.logs) {
        try {
          const event = decodeEventLog({
            abi: [
              {
                type: 'event',
                name: 'Transfer',
                inputs: [
                  { indexed: true, name: 'from', type: 'address' },
                  { indexed: true, name: 'to', type: 'address' },
                  { indexed: true, name: 'tokenId', type: 'uint256' },
                ],
              },
            ],
            data: log.data,
            topics: log.topics,
          });

          if (event.eventName === 'Transfer') {
            const tokenId = event.args.tokenId as bigint;
            setTreasureTokenId(tokenId);
            break;
          }
        } catch {
          // Not a Transfer event, continue
        }
      }
    }
  }, [treasureReceipt, isTreasureSuccess, stage]);

  // Proceed to vault mint after treasure is minted
  useEffect(() => {
    if (treasureTokenId !== null && stage === 'minting-treasure') {
      setStage('minting-vault');
    }
  }, [treasureTokenId, stage]);

  // Mint vault once we have the treasure token ID
  const mintVaultWithTreasure = useCallback(
    (tokenId: bigint, collateralAmount: bigint) => {
      writeVault({
        address: contracts.vaultNFT,
        abi: VAULT_NFT_ABI,
        functionName: 'mint',
        args: [contracts.treasureNFT, tokenId, contracts.cbBTC, collateralAmount],
        ...(chainId === 31337 && { gas: 500_000n }),
      });
    },
    [writeVault, contracts, chainId]
  );

  // Track pending mint params for vault creation
  const [pendingParams, setPendingParams] = useState<MintParams | null>(null);

  // Effect to mint vault after treasure is ready
  useEffect(() => {
    if (stage === 'minting-vault' && treasureTokenId !== null && pendingParams) {
      mintVaultWithTreasure(treasureTokenId, pendingParams.collateralAmount);
    }
  }, [stage, treasureTokenId, pendingParams, mintVaultWithTreasure]);

  // Mark complete when vault is minted
  useEffect(() => {
    if (isVaultSuccess && vaultReceipt) {
      setStage('complete');
    }
  }, [isVaultSuccess, vaultReceipt]);

  // Aggregate errors
  useEffect(() => {
    if (treasureError) {
      setError(treasureError);
    } else if (vaultError) {
      setError(vaultError);
    }
  }, [treasureError, vaultError]);

  const mint = (params: MintParams) => {
    if (!address) {
      setError(new Error('Wallet not connected'));
      return;
    }

    // Reset state
    setError(null);
    setTreasureTokenId(null);
    setPendingParams(params);
    setStage('minting-treasure');

    // Step 1: Mint TreasureNFT with achievement type
    writeTreasure({
      address: contracts.treasureNFT,
      abi: TREASURE_NFT_ABI,
      functionName: 'mintWithAchievement',
      args: [address, params.achievementType],
      ...(chainId === 31337 && { gas: 200_000n }),
    });
  };

  const reset = () => {
    setStage('idle');
    setTreasureTokenId(null);
    setPendingParams(null);
    setError(null);
    resetTreasure();
    resetVault();
  };

  const isPending =
    stage === 'minting-treasure' ||
    stage === 'minting-vault' ||
    isTreasurePending ||
    isTreasureConfirming ||
    isVaultPending ||
    isVaultConfirming;

  return {
    mint,
    isPending,
    isSuccess: stage === 'complete',
    txHash: vaultTxHash ?? treasureTxHash,
    receipt: vaultReceipt,
    error,
    reset,
    stage,
  };
}
