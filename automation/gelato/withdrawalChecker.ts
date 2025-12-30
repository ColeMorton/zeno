/**
 * Gelato Web3 Function - Withdrawal Automation Checker
 *
 * Checks if a vault delegate can withdraw and builds the UserOperation
 * for automated withdrawal execution via ERC-4337 smart accounts.
 *
 * Cron Schedule: Monthly (0 12 1 * *)
 * Target Chains: Base, Arbitrum
 */

import {
  Web3Function,
  Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { Contract, Interface } from "ethers";

// VaultNFT ABI subset for withdrawal delegation
const VAULT_NFT_ABI = [
  "function canDelegateWithdraw(uint256 tokenId, address delegate) external view returns (bool canWithdraw, uint256 amount)",
  "function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount)",
];

// Minimum ETH balance required for gas (in wei)
const MIN_GAS_BALANCE = BigInt("10000000000000000"); // 0.01 ETH

interface UserArgs {
  tokenId: string;
  delegateAddress: string;
  vaultNFTAddress: string;
  smartAccountAddress: string;
}

Web3Function.onRun(async (context: Web3FunctionContext) => {
  const { userArgs, multiChainProvider } = context;

  const { tokenId, delegateAddress, vaultNFTAddress, smartAccountAddress } =
    userArgs as UserArgs;

  // Validate required arguments
  if (!tokenId || !delegateAddress || !vaultNFTAddress || !smartAccountAddress) {
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

  // Query withdrawal eligibility
  const vaultNFT = new Contract(vaultNFTAddress, VAULT_NFT_ABI, provider);

  const [canWithdraw, amount] = await vaultNFT.canDelegateWithdraw(
    tokenId,
    delegateAddress
  );

  if (!canWithdraw || amount === BigInt(0)) {
    return {
      canExec: false,
      message: `Withdrawal conditions not met for vault #${tokenId}`,
    };
  }

  // Build calldata for withdrawAsDelegate(tokenId)
  const iface = new Interface(VAULT_NFT_ABI);
  const callData = iface.encodeFunctionData("withdrawAsDelegate", [tokenId]);

  return {
    canExec: true,
    callData: [
      {
        to: vaultNFTAddress,
        data: callData,
      },
    ],
  };
});
