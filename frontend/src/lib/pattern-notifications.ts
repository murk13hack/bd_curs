import type { Pattern, PatternMode, PatternSchedule } from '@/api/types';

const STORAGE_PREFIX = 'ptt-notif-fired:';
export const NOTIF_SETTINGS_KEY = 'ptt_notifications_enabled';
/** Демо: напоминание каждые 90 с (для проверки без ожидания времени из расписания). */
export const NOTIF_DEMO_KEY = 'ptt_notifications_demo';

export type PatternNotificationPayload = {
  id: string;
  patternId: number;
  scheduleId: number;
  patternTitle: string;
  patternMode: PatternMode;
  scheduleTime: string;
};

/** Пн=0 … Вс=6 — как в backend (weekday()) и редакторе расписания. */
export function weekdayIndexMondayZero(date: Date): number {
  const d = date.getDay();
  return d === 0 ? 6 : d - 1;
}

export function scheduleMatchesNow(
  sch: PatternSchedule,
  now = new Date(),
  windowMinutes = 1,
): boolean {
  const bit = 1 << weekdayIndexMondayZero(now);
  if ((sch.dow_mask & bit) === 0) return false;
  if (sch.day_of_month != null && sch.day_of_month !== now.getDate()) return false;

  const [hStr, mStr] = sch.time_of_day.slice(0, 5).split(':');
  const targetMin = Number(hStr) * 60 + Number(mStr);
  const currentMin = now.getHours() * 60 + now.getMinutes();
  return Math.abs(currentMin - targetMin) <= windowMinutes;
}

export function notificationBody(mode: PatternMode): string {
  switch (mode) {
    case 'habit':
      return 'Отметьте итог дня в карточке паттерна.';
    case 'markers':
      return 'Зафиксируйте эпизод или закройте день без эпизодов.';
    case 'scenario':
      return 'Пройдите сценарий дня по шагам.';
    default:
      return 'Откройте раздел «Паттерны».';
  }
}

export function firedStorageKey(patternId: number, scheduleId: number, day: string): string {
  return `${STORAGE_PREFIX}${patternId}:${scheduleId}:${day}`;
}

export function wasFiredToday(patternId: number, scheduleId: number, day: string): boolean {
  try {
    return localStorage.getItem(firedStorageKey(patternId, scheduleId, day)) === '1';
  } catch {
    return false;
  }
}

export function markFiredToday(patternId: number, scheduleId: number, day: string): void {
  try {
    localStorage.setItem(firedStorageKey(patternId, scheduleId, day), '1');
  } catch {
    /* ignore quota */
  }
}

export function collectDueNotifications(
  patterns: Pattern[],
  now = new Date(),
): PatternNotificationPayload[] {
  const day = now.toISOString().slice(0, 10);
  const out: PatternNotificationPayload[] = [];

  for (const p of patterns) {
    for (const sch of p.schedules) {
      if (!scheduleMatchesNow(sch, now)) continue;
      if (wasFiredToday(p.id, sch.id, day)) continue;
      out.push({
        id: `${p.id}-${sch.id}-${day}-${sch.time_of_day.slice(0, 5)}`,
        patternId: p.id,
        scheduleId: sch.id,
        patternTitle: p.title,
        patternMode: p.pattern_mode,
        scheduleTime: sch.time_of_day.slice(0, 5),
      });
    }
  }
  return out;
}

export function isNotificationsEnabled(): boolean {
  try {
    const v = localStorage.getItem(NOTIF_SETTINGS_KEY);
    return v !== '0';
  } catch {
    return true;
  }
}

export function setNotificationsEnabled(on: boolean): void {
  localStorage.setItem(NOTIF_SETTINGS_KEY, on ? '1' : '0');
}
