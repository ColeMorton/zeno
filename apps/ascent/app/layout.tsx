import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Web3Provider } from '@/components/providers/Web3Provider';
import { DevToolbar } from '@/components/dev/DevToolbar';
import './globals.css';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
});

export const metadata: Metadata = {
  title: 'The Ascent | BTCNFT Protocol',
  description: 'Fortify your NFTs with Bitcoin. Built to last generations.',
  openGraph: {
    title: 'The Ascent | BTCNFT Protocol',
    description: 'Fortify your NFTs with Bitcoin. Built to last generations.',
    type: 'website',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} font-sans antialiased`}>
        <Web3Provider>
          {children}
          <DevToolbar />
        </Web3Provider>
      </body>
    </html>
  );
}
