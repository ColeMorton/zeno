'use client';

import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { ScrollProvider } from '@/components/scroll/ScrollProvider';
import { MountainHero } from '@/components/landing/MountainHero';
import { AltitudeZones } from '@/components/landing/AltitudeZones';
import { WhySection } from '@/components/landing/WhySection';

export default function HomePage() {
  return (
    <>
      <Header transparent />
      <ScrollProvider reversed>
        <main className="flex flex-col-reverse">
          {/* Sections are reversed - bottom is first, top is last */}
          <MountainHero />
          <AltitudeZones />
          <WhySection />

          {/* CTA Section - End of journey */}
          <section className="min-h-screen flex items-center justify-center bg-black px-6">
            <div className="text-center">
              <h2 className="text-4xl md:text-6xl font-bold text-white mb-6">
                Begin Your Climb
              </h2>
              <p className="text-xl text-gray-400 mb-8 max-w-xl mx-auto">
                Connect your wallet to view your altitude and track your journey
                to the summit.
              </p>
              <a
                href="/dashboard"
                className="inline-block px-12 py-5 bg-mountain-summit text-black font-bold text-lg rounded-lg hover:bg-yellow-400 transition-colors"
              >
                Enter The Ascent
              </a>
            </div>
          </section>
        </main>
      </ScrollProvider>
      <Footer />
    </>
  );
}
