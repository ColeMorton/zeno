import ChapterDetailClient from './ChapterDetailClient';

// Generate static params for all chapter IDs
export function generateStaticParams() {
  const currentYear = new Date().getFullYear();
  const params: { chapterId: string }[] = [];

  // Generate chapter IDs for current and next year
  for (const year of [currentYear, currentYear + 1]) {
    for (let quarter = 1; quarter <= 4; quarter++) {
      for (let chapter = 1; chapter <= 12; chapter++) {
        params.push({ chapterId: `CH${chapter}_${year}Q${quarter}` });
      }
    }
  }

  return params;
}

export default function ChapterDetailPage() {
  return <ChapterDetailClient />;
}
