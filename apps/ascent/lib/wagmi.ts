import { createConfig, http } from 'wagmi';
import { connectorsForWallets } from '@rainbow-me/rainbowkit';
import {
  injectedWallet,
  rainbowWallet,
  walletConnectWallet,
  coinbaseWallet,
} from '@rainbow-me/rainbowkit/wallets';
import { base } from 'wagmi/chains';
import { defineChain } from 'viem';

// Local Anvil chain for development
export const anvil = defineChain({
  id: 31337,
  name: 'Anvil',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_ANVIL_RPC ?? 'http://127.0.0.1:8545'],
    },
  },
  testnet: true,
});

const isDev = process.env.NODE_ENV === 'development';

// Development: Anvil only (no chain switching needed)
// Production: Base only (hide chain selector)
const chains = isDev ? ([anvil] as const) : ([base] as const);

const projectId = process.env.NEXT_PUBLIC_WALLET_CONNECT_ID ?? 'demo';

const connectors = connectorsForWallets(
  [
    {
      groupName: 'Popular',
      wallets: [injectedWallet, rainbowWallet, walletConnectWallet, coinbaseWallet],
    },
  ],
  { appName: 'The Ascent', projectId }
);

export const config = createConfig({
  chains,
  connectors,
  pollingInterval: 10_000,
  transports: {
    [anvil.id]: http(),
    [base.id]: http(),
  },
  ssr: true,
});

export const SUPPORTED_CHAINS = chains;
export const ANVIL_CHAIN_ID = 31337;
