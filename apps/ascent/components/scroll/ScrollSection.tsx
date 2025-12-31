'use client';

import { ReactNode, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';
import { cn } from '@/lib/utils';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

type AltitudeZone =
  | 'trailhead'
  | 'firstcamp'
  | 'basecamp'
  | 'ridgeline'
  | 'highcamp'
  | 'deathzone'
  | 'summit';

interface ScrollSectionProps {
  children: ReactNode;
  zone?: AltitudeZone;
  className?: string;
  parallaxSpeed?: number;
  fadeIn?: boolean;
}

export function ScrollSection({
  children,
  zone,
  className,
  parallaxSpeed = 0,
  fadeIn = true,
}: ScrollSectionProps) {
  const sectionRef = useRef<HTMLElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    if (!sectionRef.current || !contentRef.current) return;

    // Parallax effect
    if (parallaxSpeed !== 0) {
      gsap.to(contentRef.current, {
        yPercent: parallaxSpeed * 100,
        ease: 'none',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top bottom',
          end: 'bottom top',
          scrub: true,
        },
      });
    }

    // Fade in animation
    if (fadeIn) {
      gsap.from(contentRef.current.children, {
        y: 50,
        opacity: 0,
        duration: 1,
        stagger: 0.2,
        ease: 'power2.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
          toggleActions: 'play none none reverse',
        },
      });
    }
  }, [parallaxSpeed, fadeIn]);

  const zoneClass = zone ? `zone-${zone}` : '';

  return (
    <section
      ref={sectionRef}
      className={cn('scroll-section', zoneClass, className)}
    >
      <div ref={contentRef} className="relative z-10 w-full max-w-7xl mx-auto px-6">
        {children}
      </div>
    </section>
  );
}
