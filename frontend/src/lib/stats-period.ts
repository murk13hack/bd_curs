import { toIsoDate } from '@/lib/format';

export function statsPeriodRange(days: number): { from: string; to: string; days: number } {
  const to = new Date();
  const from = new Date();
  from.setDate(from.getDate() - (days - 1));
  return { from: toIsoDate(from), to: toIsoDate(to), days };
}

/** Меры OLAP, возвращаемые в процентах 0–100 */
export const OLAP_PERCENT_MEASURES = new Set([
  'completion_rate',
  'pattern_clean_rate',
]);

export function formatOlapMeasure(measureId: string, value: number): string {
  if (OLAP_PERCENT_MEASURES.has(measureId)) return `${Math.round(value)}%`;
  if (measureId === 'avg_mood' || measureId === 'avg_energy') return value.toFixed(1);
  return String(value);
}
