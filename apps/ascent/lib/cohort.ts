// Cohort utilities for The Ascent
// Cohorts are monthly climbing parties identified by YYYYMM

export interface CohortInfo {
  id: string; // YYYYMM format
  displayName: string; // e.g., "OCT-25 Climbing Party"
  monthYear: { month: number; year: number };
}

const MONTH_NAMES = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

export function deriveCohortId(mintTimestamp: bigint | number): string {
  const timestamp = typeof mintTimestamp === 'bigint' ? Number(mintTimestamp) : mintTimestamp;
  const date = new Date(timestamp * 1000);
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  return `${year}${month}`;
}

export function parseCohortId(cohortId: string): CohortInfo {
  const year = parseInt(cohortId.slice(0, 4), 10);
  const month = parseInt(cohortId.slice(4, 6), 10);
  const shortYear = year.toString().slice(-2);
  const monthName = MONTH_NAMES[month - 1];

  return {
    id: cohortId,
    displayName: `${monthName}-${shortYear} Climbing Party`,
    monthYear: { month, year },
  };
}

export function formatCohortDisplay(cohortId: string): string {
  return parseCohortId(cohortId).displayName;
}
