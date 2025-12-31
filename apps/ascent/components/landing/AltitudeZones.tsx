'use client';

import { useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';
import { ALTITUDE_ZONES } from '@/lib/altitude';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

const ZONE_DATA = [
  {
    key: 'SUMMIT',
    color: 'bg-mountain-summit',
    icon: '🏔️',
    tagline: 'Peak, endless view',
  },
  {
    key: 'DEATH_ZONE',
    color: 'bg-white',
    icon: '❄️',
    tagline: 'Snow, wind, stars',
  },
  {
    key: 'HIGH_CAMP',
    color: 'bg-gray-500',
    icon: '🏕️',
    tagline: 'Thin air, commitment',
  },
  {
    key: 'RIDGE_LINE',
    color: 'bg-mountain-ridgeline',
    icon: '🌨️',
    tagline: 'Above tree line, exposure',
  },
  {
    key: 'BASE_CAMP',
    color: 'bg-mountain-basecamp',
    icon: '⛺',
    tagline: 'Tents, flags, established',
  },
  {
    key: 'FIRST_CAMP',
    color: 'bg-mountain-firstcamp',
    icon: '🔥',
    tagline: 'Campfire, settling in',
  },
  {
    key: 'TRAILHEAD',
    color: 'bg-mountain-trailhead',
    icon: '🌲',
    tagline: 'Pine trees, trail markers',
  },
];

export function AltitudeZones() {
  const containerRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    if (!containerRef.current) return;

    const zones = containerRef.current.querySelectorAll('.zone-item');

    // For inverted scroll: elements enter viewport from TOP
    zones.forEach((zone, i) => {
      gsap.from(zone, {
        x: i % 2 === 0 ? -100 : 100,
        opacity: 0,
        duration: 0.8,
        scrollTrigger: {
          trigger: zone,
          start: 'bottom 20%',  // Element's bottom at 20% from viewport top
          toggleActions: 'play none none reverse',
        },
      });
    });
  }, []);

  return (
    <section
      id="journey"
      className="min-h-screen py-24 px-6 bg-gradient-to-b from-black to-gray-900"
    >
      <div className="max-w-4xl mx-auto">
        <h2 className="text-4xl md:text-5xl font-bold text-white text-center mb-4">
          The Journey
        </h2>
        <p className="text-gray-400 text-center mb-16 max-w-2xl mx-auto">
          1129 days to the summit. Each zone marks a milestone in your commitment.
        </p>

        <div ref={containerRef} className="relative">
          {/* Vertical line */}
          <div className="absolute left-1/2 top-0 bottom-0 w-px bg-gradient-to-b from-mountain-summit via-gray-500 to-mountain-trailhead" />

          {ZONE_DATA.map((zone, index) => {
            const zoneInfo = ALTITUDE_ZONES[zone.key as keyof typeof ALTITUDE_ZONES];
            const isLeft = index % 2 === 0;

            return (
              <div
                key={zone.key}
                className={`zone-item relative flex items-center gap-8 mb-12 ${
                  isLeft ? 'flex-row' : 'flex-row-reverse'
                }`}
              >
                {/* Content */}
                <div
                  className={`flex-1 ${isLeft ? 'text-right' : 'text-left'}`}
                >
                  <div
                    className={`inline-block px-6 py-4 rounded-lg bg-gray-800/50 border border-gray-700 ${
                      isLeft ? 'mr-8' : 'ml-8'
                    }`}
                  >
                    <div className="flex items-center gap-3 mb-2">
                      <span className="text-2xl">{zone.icon}</span>
                      <h3 className="text-xl font-semibold text-white">
                        {zoneInfo.name}
                      </h3>
                    </div>
                    <p className="text-gray-400 text-sm mb-1">{zone.tagline}</p>
                    <div className="flex items-center gap-4 text-sm">
                      <span className="text-gray-500">
                        Day {zoneInfo.days}
                      </span>
                      <span className={`px-2 py-0.5 rounded ${zone.color} text-black font-medium`}>
                        {zoneInfo.altitude}m
                      </span>
                    </div>
                  </div>
                </div>

                {/* Center dot */}
                <div className={`w-4 h-4 rounded-full ${zone.color} ring-4 ring-gray-900 z-10`} />

                {/* Spacer */}
                <div className="flex-1" />
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
