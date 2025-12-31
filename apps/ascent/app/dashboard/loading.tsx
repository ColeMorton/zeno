import { Header } from '@/components/layout/Header';
import {
  AltitudeProgressSkeleton,
} from '@/components/dashboard/AltitudeProgress';
import { VaultCardSkeleton } from '@/components/dashboard/VaultCard';

export default function DashboardLoading() {
  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8">
            <div className="h-9 w-40 bg-gray-800 rounded animate-pulse mb-2" />
            <div className="h-5 w-64 bg-gray-800 rounded animate-pulse" />
          </div>
          <div className="grid gap-6 lg:grid-cols-2">
            <AltitudeProgressSkeleton />
            <VaultCardSkeleton />
          </div>
        </div>
      </main>
    </>
  );
}
