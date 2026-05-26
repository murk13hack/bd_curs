/** Pomodoro: дедлайн фазы + учёт тикающих секунд; до MAX параллельных сессий. */

export type PomodoroPhase = 'work' | 'short_break' | 'long_break' | 'idle';

export interface PomodoroSettings {
  workMinutes: number;
  shortBreak: number;
  longBreak: number;
}

export interface PomodoroSession {
  id: string;
  phase: PomodoroPhase;
  taskId: number | null;
  taskTitle: string;
  remainingSec: number;
  totalSec: number;
  cycles: number;
  running: boolean;
  deadlineAt: number | null;
  workFocusedSec: number;
  taskFocusedSec: number;
  savedAt: number;
}

export interface PomodoroStore {
  version: 2;
  sessions: PomodoroSession[];
}

export const POMODORO_STORAGE_KEY = 'ptt-pomodoro';
export const POMODORO_MIN_LOG_SEC = 30;
export const POMODORO_MAX_SESSIONS = 10;

export const POMODORO_PHASE_LABEL: Record<PomodoroPhase, string> = {
  idle: 'Готов к работе',
  work: 'Фокус',
  short_break: 'Короткий перерыв',
  long_break: 'Длинный перерыв',
};

export function newSessionId(): string {
  return `p-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

export function phaseDuration(phase: PomodoroPhase, s: PomodoroSettings): number {
  if (phase === 'work') return s.workMinutes * 60;
  if (phase === 'long_break') return s.longBreak * 60;
  if (phase === 'short_break') return s.shortBreak * 60;
  return s.workMinutes * 60;
}

export function syncFromClock(session: PomodoroSession, now = Date.now()): PomodoroSession {
  if (!session.running || session.deadlineAt == null) {
    return { ...session, savedAt: now };
  }

  const remainingSec = Math.max(0, Math.ceil((session.deadlineAt - now) / 1000));
  let workFocusedSec = session.workFocusedSec;
  let taskFocusedSec = session.taskFocusedSec;
  if (session.phase === 'work' && session.savedAt < now) {
    const delta = Math.floor((now - session.savedAt) / 1000);
    workFocusedSec += delta;
    if (session.taskId != null) {
      taskFocusedSec += delta;
    }
  }

  return {
    ...session,
    remainingSec,
    workFocusedSec,
    taskFocusedSec,
    savedAt: now,
  };
}

export function pauseSession(session: PomodoroSession, now = Date.now()): PomodoroSession {
  const synced = syncFromClock(session, now);
  return {
    ...synced,
    running: false,
    deadlineAt: null,
    savedAt: now,
  };
}

export function resumeSession(session: PomodoroSession, now = Date.now()): PomodoroSession {
  if (session.running || session.phase === 'idle' || session.remainingSec <= 0) {
    return session;
  }
  return {
    ...session,
    running: true,
    deadlineAt: now + session.remainingSec * 1000,
    savedAt: now,
  };
}

export function startWorkSession(
  settings: PomodoroSettings,
  task: { id: number; title: string } | null = null,
  cycles = 0,
  now = Date.now(),
): PomodoroSession {
  const totalSec = phaseDuration('work', settings);
  return {
    id: newSessionId(),
    phase: 'work',
    taskId: task?.id ?? null,
    taskTitle: task?.title ?? '',
    remainingSec: totalSec,
    totalSec,
    cycles,
    running: true,
    deadlineAt: now + totalSec * 1000,
    workFocusedSec: 0,
    taskFocusedSec: 0,
    savedAt: now,
  };
}

export function advanceSessionPhase(
  session: PomodoroSession,
  settings: PomodoroSettings,
  now = Date.now(),
): PomodoroSession {
  if (session.phase === 'work') {
    const cycles = session.cycles + 1;
    const phase: PomodoroPhase = cycles % 4 === 0 ? 'long_break' : 'short_break';
    const totalSec = phaseDuration(phase, settings);
    const running = session.running;
    return {
      ...session,
      phase,
      cycles,
      workFocusedSec: 0,
      taskFocusedSec: 0,
      totalSec,
      remainingSec: totalSec,
      running,
      deadlineAt: running ? now + totalSec * 1000 : null,
      savedAt: now,
    };
  }

  const totalSec = phaseDuration('work', settings);
  const running = session.running;
  return {
    ...session,
    phase: 'work',
    workFocusedSec: 0,
    taskFocusedSec: 0,
    totalSec,
    remainingSec: totalSec,
    running,
    deadlineAt: running ? now + totalSec * 1000 : null,
    savedAt: now,
  };
}

export function formatPomodoroClock(remainingSec: number): string {
  const m = Math.floor(remainingSec / 60)
    .toString()
    .padStart(2, '0');
  const s = (remainingSec % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

export function pomodoroProgress(totalSec: number, remainingSec: number): number {
  if (totalSec <= 0) return 0;
  return ((totalSec - remainingSec) / totalSec) * 100;
}

function normalizeSession(
  raw: Partial<PomodoroSession>,
  settings: PomodoroSettings,
): PomodoroSession {
  const base: PomodoroSession = {
    id: raw.id ?? newSessionId(),
    phase: raw.phase ?? 'work',
    taskId: raw.taskId ?? null,
    taskTitle: raw.taskTitle ?? '',
    remainingSec: Number(raw.remainingSec) || phaseDuration('work', settings),
    totalSec: Number(raw.totalSec) || phaseDuration('work', settings),
    cycles: Number(raw.cycles) || 0,
    running: Boolean(raw.running),
    deadlineAt: raw.deadlineAt ?? null,
    workFocusedSec: Number(raw.workFocusedSec) || 0,
    taskFocusedSec: Number(raw.taskFocusedSec) || 0,
    savedAt: Number(raw.savedAt) || Date.now(),
  };
  if (base.running && base.deadlineAt == null && base.remainingSec > 0) {
    base.deadlineAt = Date.now() + base.remainingSec * 1000;
  }
  return base;
}

export function loadPomodoroStore(settings: PomodoroSettings): PomodoroStore {
  try {
    const raw = localStorage.getItem(POMODORO_STORAGE_KEY);
    if (!raw) return { version: 2, sessions: [] };

    const parsed = JSON.parse(raw) as Partial<PomodoroStore> & Partial<PomodoroSession>;

    if (parsed.version === 2 && Array.isArray(parsed.sessions)) {
      const sessions = parsed.sessions
        .slice(0, POMODORO_MAX_SESSIONS)
        .map((s) => syncFromClock(normalizeSession(s, settings)));
      return { version: 2, sessions };
    }

    if (parsed.phase != null) {
      const legacy = syncFromClock(normalizeSession(parsed, settings));
      if (legacy.phase === 'idle' && legacy.taskId == null) {
        return { version: 2, sessions: [] };
      }
      return { version: 2, sessions: [legacy] };
    }

    return { version: 2, sessions: [] };
  } catch {
    return { version: 2, sessions: [] };
  }
}

export function savePomodoroStore(store: PomodoroStore): void {
  localStorage.setItem(POMODORO_STORAGE_KEY, JSON.stringify(store));
}

export function sessionForTask(
  sessions: PomodoroSession[],
  taskId: number | null,
): PomodoroSession | undefined {
  return sessions.find((s) => s.taskId === taskId);
}

export function sessionFocusChanged(prev: PomodoroSession, next: PomodoroSession): boolean {
  return (
    next.remainingSec !== prev.remainingSec ||
    next.workFocusedSec !== prev.workFocusedSec ||
    next.taskFocusedSec !== prev.taskFocusedSec ||
    next.phase !== prev.phase
  );
}
