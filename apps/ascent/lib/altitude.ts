// Altitude zone configuration based on The Ascent design
// Maps holding duration (days) to altitude (meters) on the mountain

export const ALTITUDE_ZONES = {
  TRAILHEAD: { days: 0, altitude: 0, name: 'Trailhead', achievement: 'CLIMBER' },
  FIRST_CAMP: { days: 30, altitude: 1000, name: 'First Camp', achievement: 'TRAIL_HEAD' },
  BASE_CAMP: { days: 91, altitude: 2000, name: 'Base Camp', achievement: 'BASE_CAMP' },
  RIDGE_LINE: { days: 182, altitude: 3000, name: 'Ridge Line', achievement: 'RIDGE_WALKER' },
  HIGH_CAMP: { days: 365, altitude: 4000, name: 'High Camp', achievement: 'HIGH_CAMP' },
  DEATH_ZONE: { days: 730, altitude: 5000, name: 'Death Zone', achievement: 'SUMMIT_PUSH' },
  SUMMIT: { days: 1129, altitude: 5895, name: 'Summit', achievement: 'SUMMIT' },
} as const;

export type ZoneName = keyof typeof ALTITUDE_ZONES;

export interface AltitudeInfo {
  currentZone: ZoneName;
  altitude: number;
  daysHeld: number;
  nextZone: ZoneName | null;
  daysToNextZone: number;
  progressToNextZone: number; // 0-1
  achievement: string;
}

const ZONES_ORDERED: ZoneName[] = [
  'TRAILHEAD',
  'FIRST_CAMP',
  'BASE_CAMP',
  'RIDGE_LINE',
  'HIGH_CAMP',
  'DEATH_ZONE',
  'SUMMIT',
];

export function calculateAltitude(
  mintTimestamp: bigint | number,
  currentTime?: number
): AltitudeInfo {
  const now = currentTime ?? Math.floor(Date.now() / 1000);
  const mintTime = typeof mintTimestamp === 'bigint' ? Number(mintTimestamp) : mintTimestamp;
  const daysHeld = Math.floor((now - mintTime) / 86400);

  // Find current zone
  let currentZoneIndex = 0;
  for (let i = ZONES_ORDERED.length - 1; i >= 0; i--) {
    const zone = ALTITUDE_ZONES[ZONES_ORDERED[i]];
    if (daysHeld >= zone.days) {
      currentZoneIndex = i;
      break;
    }
  }

  const currentZoneName = ZONES_ORDERED[currentZoneIndex];
  const currentZone = ALTITUDE_ZONES[currentZoneName];
  const nextZoneName = currentZoneIndex < ZONES_ORDERED.length - 1
    ? ZONES_ORDERED[currentZoneIndex + 1]
    : null;
  const nextZone = nextZoneName ? ALTITUDE_ZONES[nextZoneName] : null;

  // Calculate interpolated altitude
  let altitude = currentZone.altitude;
  let progressToNextZone = 0;
  let daysToNextZone = 0;

  if (nextZone) {
    const daysInZone = daysHeld - currentZone.days;
    const zoneDuration = nextZone.days - currentZone.days;
    progressToNextZone = Math.min(1, daysInZone / zoneDuration);
    daysToNextZone = nextZone.days - daysHeld;
    altitude = currentZone.altitude + (nextZone.altitude - currentZone.altitude) * progressToNextZone;
  }

  return {
    currentZone: currentZoneName,
    altitude: Math.round(altitude),
    daysHeld,
    nextZone: nextZoneName,
    daysToNextZone,
    progressToNextZone,
    achievement: currentZone.achievement,
  };
}

export function formatAltitude(meters: number): string {
  if (meters >= 1000) {
    return `${(meters / 1000).toFixed(1)}km`;
  }
  return `${meters}m`;
}
