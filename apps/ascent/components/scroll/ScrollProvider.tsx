'use client';

import { ReactNode, useEffect, useRef, useState, useCallback } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

interface ScrollProviderProps {
  children: ReactNode;
  reversed?: boolean;
}

export function ScrollProvider({ children, reversed = false }: ScrollProviderProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const [scrollY, setScrollY] = useState(0);
  const [contentHeight, setContentHeight] = useState(0);
  const targetYRef = useRef(0);
  const currentYRef = useRef(0);
  const touchStartYRef = useRef(0);
  const lastTouchYRef = useRef(0);

  const getMaxScroll = useCallback(() => {
    return Math.max(0, contentHeight - window.innerHeight);
  }, [contentHeight]);

  // Initialize content height and scroll position
  useEffect(() => {
    if (!containerRef.current || !contentRef.current) return;

    const content = contentRef.current;
    const height = content.scrollHeight;
    setContentHeight(height);

    if (reversed) {
      // Start at bottom of page (Hero/summit) - user scrolls UP to reveal content above
      const maxScroll = height - window.innerHeight;
      window.scrollTo(0, maxScroll);
      setScrollY(maxScroll);
      targetYRef.current = maxScroll;
      currentYRef.current = maxScroll;
    }

    document.body.style.height = `${height}px`;

    return () => {
      document.body.style.height = '';
    };
  }, [reversed]);

  // Resize observer to handle content height changes
  useEffect(() => {
    if (!contentRef.current) return;

    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const height = entry.target.scrollHeight;
        setContentHeight(height);
        document.body.style.height = `${height}px`;
      }
    });

    observer.observe(contentRef.current);
    return () => observer.disconnect();
  }, []);

  // GSAP ScrollTrigger scroller proxy
  useEffect(() => {
    if (!reversed) return;

    ScrollTrigger.scrollerProxy(document.body, {
      scrollTop(value) {
        if (arguments.length && typeof value === 'number') {
          targetYRef.current = value;
          setScrollY(value);
        }
        return scrollY;
      },
      getBoundingClientRect() {
        return {
          top: 0,
          left: 0,
          width: window.innerWidth,
          height: window.innerHeight,
        };
      },
    });

    return () => {
      ScrollTrigger.clearScrollMemory();
    };
  }, [reversed, scrollY]);

  // Update ScrollTrigger when scrollY changes
  useEffect(() => {
    if (reversed) {
      ScrollTrigger.update();
    }
  }, [reversed, scrollY]);

  // Main scroll handling for reversed mode
  useEffect(() => {
    if (!reversed) return;

    let rafId: number;

    const handleWheel = (e: WheelEvent) => {
      e.preventDefault();
      const maxScroll = getMaxScroll();
      // Scroll UP (negative deltaY) -> content moves UP -> reveals content below
      targetYRef.current = Math.max(0, Math.min(maxScroll, targetYRef.current + e.deltaY));
      window.scrollTo(0, targetYRef.current);
    };

    const handleTouchStart = (e: TouchEvent) => {
      touchStartYRef.current = e.touches[0].clientY;
      lastTouchYRef.current = touchStartYRef.current;
    };

    const handleTouchMove = (e: TouchEvent) => {
      e.preventDefault();
      const touchY = e.touches[0].clientY;
      const deltaY = lastTouchYRef.current - touchY; // Positive when swiping up
      lastTouchYRef.current = touchY;

      const maxScroll = getMaxScroll();
      // Swipe UP (positive delta) -> content moves UP -> reveals content below
      targetYRef.current = Math.max(0, Math.min(maxScroll, targetYRef.current - deltaY));
      window.scrollTo(0, targetYRef.current);
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      const scrollAmount = 100;
      const pageAmount = window.innerHeight * 0.9;
      const maxScroll = getMaxScroll();

      let delta = 0;

      switch (e.key) {
        case 'ArrowUp':
          delta = -scrollAmount;
          break;
        case 'ArrowDown':
          delta = scrollAmount;
          break;
        case 'PageUp':
        case ' ':
          delta = -pageAmount;
          e.preventDefault();
          break;
        case 'PageDown':
          delta = pageAmount;
          e.preventDefault();
          break;
        case 'Home':
          targetYRef.current = 0;
          window.scrollTo(0, 0);
          return;
        case 'End':
          targetYRef.current = maxScroll;
          window.scrollTo(0, maxScroll);
          return;
        default:
          return;
      }

      e.preventDefault();
      targetYRef.current = Math.max(0, Math.min(maxScroll, targetYRef.current + delta));
      window.scrollTo(0, targetYRef.current);
    };

    const smoothScroll = () => {
      currentYRef.current += (targetYRef.current - currentYRef.current) * 0.1;
      setScrollY(currentYRef.current);
      rafId = requestAnimationFrame(smoothScroll);
    };

    window.addEventListener('wheel', handleWheel, { passive: false });
    window.addEventListener('touchstart', handleTouchStart, { passive: true });
    window.addEventListener('touchmove', handleTouchMove, { passive: false });
    window.addEventListener('keydown', handleKeyDown);
    rafId = requestAnimationFrame(smoothScroll);

    return () => {
      window.removeEventListener('wheel', handleWheel);
      window.removeEventListener('touchstart', handleTouchStart);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('keydown', handleKeyDown);
      if (rafId) cancelAnimationFrame(rafId);
    };
  }, [reversed, getMaxScroll]);

  // Standard scroll for non-reversed mode
  useEffect(() => {
    if (reversed) return;

    const handleScroll = () => {
      setScrollY(window.scrollY);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [reversed]);

  return (
    <div ref={containerRef} className="scroll-container">
      <div
        ref={contentRef}
        style={{
          transform: `translateY(${-scrollY}px)`,
          willChange: 'transform',
        }}
      >
        {children}
      </div>
    </div>
  );
}
