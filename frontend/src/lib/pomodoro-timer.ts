/** Чистая логика Pomodoro: дедлайн фазы + учёт только «тикающих» секунд (без пауз). */

export type PomodoroPhase = 'work' | 'short_break' | 'long_break' | 'idle';

export interface PomodoroSettings {
  workMinutes: number;
  shortBreak: number;
  longBreak: number;
}

export interface PomodoroState {
  phase: PomodoroPhase;
  taskId: number | null;
  taskTitle: string;
  remainingSec: number;
  totalSec: number;
  cycles: number;
  running: boolean;
  /** Когда running — момент окончания текущей фазы (epoch ms). */
  deadlineAt: number | null;
  /** Секунды work-фазы всего (для отображения сессии). */
  workFocusedSec: number;
  /** Секунды фокуса по текущей taskId с момента её привязки. */
  taskFocusedSec: number;
  savedAt: number;
}

export const POMODORO_STORAGE_KEY = 'ptt-pomodoro';
export const POMODORO_MIN_LOG_SEC = 30;

export const POMODORO_PHASE_LABEL: Record<PomodoroPhase, string> = {
  idle: 'Готов к работе',
  work: 'Фокус',
  short_break: 'Короткий перерыв',
  long_break: 'Длинный перерыв',
};

export function phaseDuration(phase: PomodoroPhase, s: PomodoroSettings): number {
  if (phase === 'work') return s.workMinutes * 60;
  if (phase === 'long_break') return s.longBreak * 60;
  if (phase === 'short_break') return s.shortBreak * 60;
  return s.workMinutes * 60;
}

export function idleState(s: PomodoroSettings): PomodoroState {
  const totalSec = phaseDuration('work', s);
  return {
    phase: 'idle',
    taskId: null,
    taskTitle: '',
    remainingSec: totalSec,
    totalSec,
    cycles: 0,
    running: false,
    deadlineAt: null,
    workFocusedSec: 0,
    taskFocusedSec: 0,
    savedAt: Date.now(),
  };
}

/** Синхронизация remaining / workFocusedSec с часами (в т.ч. после reload). */
export function syncFromClock(state: PomodoroState, now = Date.now()): PomodoroState {
  if (!state.running || state.deadlineAt == null) {
    return { ...state, savedAt: now };
  }

  const remainingSec = Math.max(0, Math.ceil((state.deadlineAt - now) / 1000));
  let workFocusedSec = state.workFocusedSec;
  let taskFocusedSec = state.taskFocusedSec;
  if (state.phase === 'work' && state.savedAt < now) {
    const delta = Math.floor((now - state.savedAt) / 1000);
    workFocusedSec += delta;
    if (state.taskId != null) {
      taskFocusedSec += delta;
    }
  }

  return {
    ...state,
    remainingSec,
    workFocusedSec,
    taskFocusedSec,
    savedAt: now,
  };
}

export function pauseState(state: PomodoroState, now = Date.now()): PomodoroState {
  const synced = syncFromClock(state, now);
  return {
    ...synced,
    running: false,
    deadlineAt: null,
    savedAt: now,
  };
}

export function resumeState(state: PomodoroState, now = Date.now()): PomodoroState {
  if (state.running || state.phase === 'idle' || state.remainingSec <= 0) {
    return state;
  }
  return {
    ...state,
    running: true,
    deadlineAt: now + state.remainingSec * 1000,
    savedAt: now,
  };
}

export function startWorkState(
  settings: PomodoroSettings,
  task: { id: number; title: string } | null = null,
  cycles = 0,
  now = Date.now(),
): PomodoroState {
  const totalSec = phaseDuration('work', settings);
  return {
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

export function advancePhase(state: PomodoroState, settings: PomodoroSettings, now = Date.now()): PomodoroState {
  if (state.phase === 'work') {
    const cycles = state.cycles + 1;
    const phase: PomodoroPhase = cycles % 4 === 0 ? 'long_break' : 'short_break';
    const totalSec = phaseDuration(phase, settings);
    const running = state.running;
    return {
      ...state,
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
  const running = state.running;
  return {
    ...state,
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

export function loadPomodoroState(settings: PomodoroSettings): PomodoroState {
  try {
    const raw = localStorage.getItem(POMODORO_STORAGE_KEY);
    if (!raw) return idleState(settings);
    const parsed = JSON.parse(raw) as Partial<PomodoroState>;
    const base: PomodoroState = {
      phase: parsed.phase ?? 'idle',
      taskId: parsed.taskId ?? null,
      taskTitle: parsed.taskTitle ?? '',
      remainingSec: Number(parsed.remainingSec) || phaseDuration('work', settings),
      totalSec: Number(parsed.totalSec) || phaseDuration('work', settings),
      cycles: Number(parsed.cycles) || 0,
      running: Boolean(parsed.running),
      deadlineAt: parsed.deadlineAt ?? null,
      workFocusedSec: Number(parsed.workFocusedSec) || 0,
      taskFocusedSec: Number(parsed.taskFocusedSec) || 0,
      savedAt: Number(parsed.savedAt) || Date.now(),
    };
    if (base.running && base.deadlineAt == null && base.remainingSec > 0) {
      base.deadlineAt = Date.now() + base.remainingSec * 1000;
    }
    return syncFromClock(base);
  } catch {
    return idleState(settings);
  }
}

export function savePomodoroState(state: PomodoroState): void {
  localStorage.setItem(POMODORO_STORAGE_KEY, JSON.stringify(state));
}
