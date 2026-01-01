'use client';

import { useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

const REASONS = [
  {
    number: '01',
    title: 'Proven Commitment',
    description:
      '1129 days demonstrates irrefutable long-term conviction. In a world of quick flips, this is a statement of permanence.',
  },
  {
    number: '02',
    title: 'Perpetual Withdrawals',
    description:
      'After vesting, access 1% monthly forever. Your BTC works for you, not against you.',
  },
  {
    number: '03',
    title: 'No Second Chances',
    description:
      'Immutable contracts. No admin keys. No upgrades. The rules are set in stone—or rather, in code.',
  },
];

export function WhySection() {
  const containerRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    if (!containerRef.current) return;

    const items = containerRef.current.querySelectorAll('.reason-item');

    // For inverted scroll: scrollY decreases as user progresses
    // ScrollTrigger sees this as "scrolling back", so use onEnterBack/onLeaveBack
    items.forEach((item) => {
      gsap.from(item, {
        y: 60,  // Start below, slide UP into view
        opacity: 0,
        duration: 0.8,
        scrollTrigger: {
          trigger: item,
          start: 'top 80%',
          toggleActions: 'none none play reverse',  // onEnterBack: play, onLeaveBack: reverse
        },
      });
    });
  }, []);

  return (
    <section className="min-h-screen py-24 px-6 bg-gray-900">
      <div className="max-w-6xl mx-auto">
        <h2 className="text-4xl md:text-5xl font-bold text-white text-center mb-4">
          Why 1129 Days?
        </h2>
        <p className="text-gray-400 text-center mb-16 max-w-2xl mx-auto">
          The vesting period isn&apos;t arbitrary. It&apos;s a filter.
        </p>

        <div ref={containerRef} className="grid md:grid-cols-3 gap-8">
          {REASONS.map((reason) => (
            <div
              key={reason.number}
              className="reason-item p-8 rounded-xl bg-gray-800/50 border border-gray-700 hover:border-mountain-summit/50 transition-colors"
            >
              <span className="text-mountain-summit text-5xl font-bold opacity-50">
                {reason.number}
              </span>
              <h3 className="text-xl font-semibold text-white mt-4 mb-3">
                {reason.title}
              </h3>
              <p className="text-gray-400">{reason.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
