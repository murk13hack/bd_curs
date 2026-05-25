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

/** Подпись оси Y для выбранной меры OLAP */
export function olapYAxisLabel(measureId: string): string {
  if (OLAP_PERCENT_MEASURES.has(measureId)) return 'Значение, %';
  if (measureId === 'avg_mood' || measureId === 'avg_energy') return 'Средний балл (1–5)';
  if (measureId === 'minutes_logged' || measureId === 'pomodoro_minutes') return 'Минуты';
  if (measureId === 'active_days') return 'Дней';
  return 'Количество';
}
