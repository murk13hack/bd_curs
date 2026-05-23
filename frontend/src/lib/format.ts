import { format, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  return format(parseISO(iso.slice(0, 10)), 'dd.MM.yyyy', { locale: ru });
}

export function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  return format(parseISO(iso), 'dd.MM.yyyy HH:mm', { locale: ru });
}

export function fmtTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  return format(parseISO(iso), 'HH:mm', { locale: ru });
}

export function toIsoDate(d: Date): string {
  return format(d, 'yyyy-MM-dd');
}

export function toIsoDateTimeLocal(d: Date): string {
  return format(d, "yyyy-MM-dd'T'HH:mm");
}

export function minutesLabel(m: number): string {
  if (m < 60) return `${m} мин`;
  const h = Math.floor(m / 60);
  const rest = m % 60;
  return rest ? `${h} ч ${rest} мин` : `${h} ч`;
}

export function pct(n: number): string {
  return `${Math.round(n)}%`;
}

export function downloadText(filename: string, content: string, mime = 'text/plain') {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function downloadJson(filename: string, data: unknown) {
  downloadText(filename, JSON.stringify(data, null, 2), 'application/json');
}
