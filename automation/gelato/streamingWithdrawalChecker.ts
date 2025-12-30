/**
 * Gelato Web3 Function - Streaming Withdrawal Automation
 *
 * Creates Sablier streams from VaultNFT withdrawals via SablierStreamWrapper.
 * Converts discrete monthly withdrawals into continuous 30-day linear streams.
 *
 * Cron Schedule: Monthly (0 12 1 * *)
 * Target Chains: Base, Arbitrum
 */

import {
  Web3Function,
  Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { Contract, Interface } from "ethers";

// SablierStreamWrapper ABI subset
const STREAM_WRAPPER_ABI = [
  "function canCreateStream(uint256 vaultTokenId) external view returns (bool canCreate, uint256 amount)",
  "function createStreamFromVault(uint256 vaultTokenId) external returns (uint256 streamId)",
];

// Minimum ETH balance required for gas (in wei)
const MIN_GAS_BALANCE = BigInt("10000000000000000"); // 0.01 ETH

interface UserArgs {
  tokenId: string;
  streamWrapperAddress: string;
  smartAccountAddress: string;
}

Web3Function.onRun(async (context: Web3FunctionContext) => {
  const { userArgs, multiChainProvider } = context;

  const { tokenId, streamWrapperAddress, smartAccountAddress } =
    userArgs as UserArgs;

  // Validate required arguments
  if (!tokenId || !streamWrapperAddress || !smartAccountAddress) {
    return {
      canExec: false,
      message: "Missing required user arguments",
    };
  }

  const provider = multiChainProvider.default();

  // Check smart account gas balance
  const balance = await provider.getBalance(smartAccountAddress);
  if (balance < MIN_GAS_BALANCE) {
    return {
      canExec: false,
      message: `Insufficient gas balance: ${balance.toString()} wei (need ${MIN_GAS_BALANCE.toString()})`,
    };
  }

  // Query stream creation eligibility via wrapper
  const wrapper = new Contract(streamWrapperAddress, STREAM_WRAPPER_ABI, provider);

  const [canCreate, amount] = await wrapper.canCreateStream(tokenId);

  if (!canCreate || amount === BigInt(0)) {
    return {
      canExec: false,
      message: `Stream creation conditions not met for vault #${tokenId}`,
    };
  }

  // Build calldata for createStreamFromVault(tokenId)
  const iface = new Interface(STREAM_WRAPPER_ABI);
  const callData = iface.encodeFunctionData("createStreamFromVault", [tokenId]);

  return {
    canExec: true,
    callData: [
      {
        to: streamWrapperAddress,
        data: callData,
      },
    ],
  };
});
