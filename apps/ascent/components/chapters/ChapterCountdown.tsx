'use client';

import { useEffect, useState } from 'react';
import { formatTimeRemaining } from '@/lib/chapters';

interface ChapterCountdownProps {
  windowEnd: number;
  className?: string;
}

export function ChapterCountdown({ windowEnd, className = '' }: ChapterCountdownProps) {
  const [timeRemaining, setTimeRemaining] = useState<number>(0);

  useEffect(() => {
    const updateRemaining = () => {
      const now = Math.floor(Date.now() / 1000);
      setTimeRemaining(Math.max(0, windowEnd - now));
    };

    updateRemaining();
    const interval = setInterval(updateRemaining, 1000);

    return () => clearInterval(interval);
  }, [windowEnd]);

  if (timeRemaining <= 0) {
    return (
      <div className={`text-red-400 font-medium ${className}`}>
        Chapter Ended
      </div>
    );
  }

  // Break down time components
  const days = Math.floor(timeRemaining / 86400);
  const hours = Math.floor((timeRemaining % 86400) / 3600);
  const minutes = Math.floor((timeRemaining % 3600) / 60);
  const seconds = timeRemaining % 60;

  return (
    <div className={`${className}`}>
      <div className="text-xs text-gray-500 mb-1">Time Remaining</div>
      <div className="flex gap-3">
        <TimeUnit value={days} label="days" />
        <TimeUnit value={hours} label="hrs" />
        <TimeUnit value={minutes} label="min" />
        <TimeUnit value={seconds} label="sec" />
      </div>
    </div>
  );
}

function TimeUnit({ value, label }: { value: number; label: string }) {
  return (
    <div className="text-center">
      <div className="text-xl font-mono font-bold text-white">
        {value.toString().padStart(2, '0')}
      </div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}

/**
 * Compact countdown for card displays
 */
export function ChapterCountdownCompact({
  windowEnd,
  className = '',
}: ChapterCountdownProps) {
  const [timeRemaining, setTimeRemaining] = useState<number>(0);

  useEffect(() => {
    const updateRemaining = () => {
      const now = Math.floor(Date.now() / 1000);
      setTimeRemaining(Math.max(0, windowEnd - now));
    };

    updateRemaining();
    const interval = setInterval(updateRemaining, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [windowEnd]);

  if (timeRemaining <= 0) {
    return <span className={`text-red-400 ${className}`}>Ended</span>;
  }

  return (
    <span className={`text-green-400 ${className}`}>
      {formatTimeRemaining(timeRemaining)} left
    </span>
  );
}
