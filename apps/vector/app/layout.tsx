import type { Metadata } from 'next';
import { Web3Provider } from '@/components/providers/Web3Provider';
import { Header } from '@/components/layout/Header';
import './globals.css';

export const metadata: Metadata = {
  title: 'Vector | vestedBTC Derivatives',
  description: 'Perpetual leverage, yield, and volatility exposure for vestedBTC',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="bg-vector-surface text-white min-h-screen font-sans">
        <Web3Provider>
          <Header />
          <main className="container mx-auto px-4 py-8">
            {children}
          </main>
        </Web3Provider>
      </body>
    </html>
  );
}
