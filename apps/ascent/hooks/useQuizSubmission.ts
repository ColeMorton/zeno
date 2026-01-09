'use client';

import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import {
  useAccount,
  useChainId,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { getContractAddresses, QUIZ_VERIFIER_ABI } from '@/lib/contracts';
import { encodeAbiParameters, keccak256, toBytes } from 'viem';

interface QuizSubmissionParams {
  quizId: `0x${string}`;
  answers: number[];
}

export function useQuizSubmission() {
  const { address } = useAccount();
  const chainId = useChainId();
  const queryClient = useQueryClient();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const submit = async (params: QuizSubmissionParams) => {
    const contracts = getContractAddresses(chainId);
    if (!contracts.quizVerifier) {
      throw new Error('QuizVerifier contract not configured');
    }

    writeContract({
      address: contracts.quizVerifier,
      abi: QUIZ_VERIFIER_ABI,
      functionName: 'submitQuiz',
      args: [params.quizId, params.answers],
    });
  };

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries({ queryKey: ['quizPassed'] });
      queryClient.invalidateQueries({ queryKey: ['chapterAchievements'] });
      queryClient.invalidateQueries({ queryKey: ['achievementStatus'] });
    }
  }, [isSuccess, queryClient]);

  return {
    submit,
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
  };
}

export function useQuizPassed(quizId: `0x${string}` | undefined) {
  const { address } = useAccount();
  const chainId = useChainId();
  const contracts = getContractAddresses(chainId);

  return useReadContract({
    address: contracts.quizVerifier,
    abi: QUIZ_VERIFIER_ABI,
    functionName: 'quizPassed',
    args: address && quizId ? [address, quizId] : undefined,
    query: {
      enabled: !!address && !!quizId && !!contracts.quizVerifier,
    },
  });
}

export function useQuizInfo(quizId: `0x${string}` | undefined) {
  const chainId = useChainId();
  const contracts = getContractAddresses(chainId);

  return useReadContract({
    address: contracts.quizVerifier,
    abi: QUIZ_VERIFIER_ABI,
    functionName: 'getQuiz',
    args: quizId ? [quizId] : undefined,
    query: {
      enabled: !!quizId && !!contracts.quizVerifier,
    },
  });
}

/**
 * Encode quiz ID for verification data in achievement claims
 * @param quizId The quiz ID
 * @returns ABI-encoded verification data
 */
export function encodeQuizVerificationData(quizId: `0x${string}`): `0x${string}` {
  return encodeAbiParameters([{ type: 'bytes32' }], [quizId]);
}

/**
 * Generate quiz ID from achievement ID
 * @param achievementId The achievement ID
 * @returns The corresponding quiz ID
 */
export function getQuizIdFromAchievementId(achievementId: `0x${string}`): `0x${string}` {
  return keccak256(toBytes(achievementId));
}
