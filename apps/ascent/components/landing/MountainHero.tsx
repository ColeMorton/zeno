'use client';

import { useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

export function MountainHero() {
  const containerRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);

  useGSAP(() => {
    if (!containerRef.current || !titleRef.current || !subtitleRef.current) return;

    // Parallax effect for inverted scroll (user starts here, scrolls UP to leave)
    // As user scrolls UP, hero exits toward bottom of viewport
    gsap.to(titleRef.current, {
      yPercent: -50,  // Move UP as hero exits
      opacity: 0,
      ease: 'none',
      scrollTrigger: {
        trigger: containerRef.current,
        start: 'bottom bottom',  // When hero's bottom at viewport bottom
        end: 'top bottom',       // When hero's top at viewport bottom (fully scrolled past)
        scrub: true,
      },
    });

    gsap.to(subtitleRef.current, {
      yPercent: -100,  // Move UP faster
      opacity: 0,
      ease: 'none',
      scrollTrigger: {
        trigger: containerRef.current,
        start: 'bottom bottom',
        end: 'center bottom',  // Fade out by halfway
        scrub: true,
      },
    });
  }, []);

  return (
    <div
      ref={containerRef}
      className="relative min-h-screen flex items-center justify-center overflow-hidden"
    >
      {/* Mountain gradient background */}
      <div className="absolute inset-0 bg-gradient-to-t from-mountain-trailhead via-gray-900 to-black" />

      {/* Star field effect */}
      <div className="absolute inset-0 opacity-50">
        {Array.from({ length: 100 }).map((_, i) => (
          <div
            key={i}
            className="absolute w-1 h-1 bg-white rounded-full animate-pulse-slow"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 60}%`,
              animationDelay: `${Math.random() * 3}s`,
              opacity: Math.random() * 0.7 + 0.3,
            }}
          />
        ))}
      </div>

      {/* Mountain silhouette */}
      <svg
        className="absolute bottom-0 left-0 right-0 w-full h-1/2"
        viewBox="0 0 1440 400"
        preserveAspectRatio="none"
      >
        <path
          d="M0,400 L0,300 L200,200 L400,280 L600,150 L720,100 L840,150 L1000,200 L1200,250 L1440,200 L1440,400 Z"
          fill="#1a2f1a"
          opacity="0.8"
        />
        <path
          d="M0,400 L0,350 L300,280 L500,320 L700,220 L720,200 L740,220 L900,280 L1100,300 L1440,260 L1440,400 Z"
          fill="#228B22"
          opacity="0.6"
        />
      </svg>

      {/* Summit glow */}
      <div
        className="absolute w-32 h-32 rounded-full blur-3xl opacity-40"
        style={{
          background: 'radial-gradient(circle, #FFD700 0%, transparent 70%)',
          top: '20%',
          left: '50%',
          transform: 'translateX(-50%)',
        }}
      />

      {/* Content */}
      <div className="relative z-10 text-center px-6">
        <h1
          ref={titleRef}
          className="text-5xl md:text-7xl lg:text-8xl font-bold text-white mb-6"
        >
          The Ascent
        </h1>
        <p
          ref={subtitleRef}
          className="text-xl md:text-2xl text-gray-300 max-w-2xl mx-auto mb-8"
        >
          The mountain has always been here. It will always be here.
          <br />
          <span className="text-mountain-summit">
            The only question is: when do you begin your climb?
          </span>
        </p>

        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <a
            href="/dashboard"
            className="px-8 py-4 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors"
          >
            View Your Altitude
          </a>
          <a
            href="#journey"
            className="px-8 py-4 border border-white/30 text-white font-semibold rounded-lg hover:bg-white/10 transition-colors"
          >
            Learn More
          </a>
        </div>
      </div>

      {/* Scroll indicator - user starts here, scrolls UP to discover content */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 animate-bounce-up">
        <span className="text-white/50 text-sm">Scroll up to discover</span>
        <svg
          className="w-6 h-6 text-white/50"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M5 10l7-7m0 0l7 7m-7-7v18"
          />
        </svg>
      </div>
    </div>
  );
}
