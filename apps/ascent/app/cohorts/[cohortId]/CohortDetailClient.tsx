'use client';

import { useParams } from 'next/navigation';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { parseCohortId } from '@/lib/cohort';

export default function CohortDetailClient() {
  const params = useParams();
  const cohortId = params.cohortId as string;

  let cohortInfo;
  try {
    cohortInfo = parseCohortId(cohortId);
  } catch {
    return (
      <>
        <Header />
        <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
          <div className="max-w-4xl mx-auto text-center py-12">
            <span className="text-6xl mb-6 block">❌</span>
            <h1 className="text-2xl font-bold text-white mb-4">
              Invalid Cohort ID
            </h1>
            <p className="text-gray-400">
              Cohort ID should be in YYYYMM format (e.g., 202510)
            </p>
          </div>
        </main>
        <Footer />
      </>
    );
  }

  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-4xl mx-auto">
          <div className="mb-8">
            <div className="text-sm text-mountain-summit mb-2">Climbing Party</div>
            <h1 className="text-3xl font-bold text-white mb-2">
              {cohortInfo.displayName}
            </h1>
            <p className="text-gray-400">
              All climbers who began their journey in{' '}
              {cohortInfo.monthYear.month}/{cohortInfo.monthYear.year}
            </p>
          </div>

          <div className="grid gap-6 md:grid-cols-3 mb-8">
            <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
              <div className="text-3xl font-bold text-white">--</div>
              <div className="text-gray-400">Total Climbers</div>
            </div>
            <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
              <div className="text-3xl font-bold text-mountain-summit">--%</div>
              <div className="text-gray-400">Survival Rate</div>
            </div>
            <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
              <div className="text-3xl font-bold text-white">-- BTC</div>
              <div className="text-gray-400">Total Collateral</div>
            </div>
          </div>

          <div className="bg-gray-800/50 rounded-xl p-8 border border-gray-700 text-center">
            <span className="text-4xl mb-4 block">🔧</span>
            <h2 className="text-xl font-semibold text-white mb-2">
              Coming Soon
            </h2>
            <p className="text-gray-400">
              Cohort data and survival charts will be available after subgraph
              deployment.
            </p>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
