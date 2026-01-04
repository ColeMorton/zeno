import CohortDetailClient from './CohortDetailClient';

// Generate static params for cohort IDs (YYYYMM format)
export function generateStaticParams() {
  const currentYear = new Date().getFullYear();
  const params: { cohortId: string }[] = [];

  // Generate cohort IDs for 3 years (past, current, future)
  for (const year of [currentYear - 1, currentYear, currentYear + 1]) {
    for (let month = 1; month <= 12; month++) {
      const cohortId = `${year}${month.toString().padStart(2, '0')}`;
      params.push({ cohortId });
    }
  }

  return params;
}

export default function CohortPage() {
  return <CohortDetailClient />;
}
