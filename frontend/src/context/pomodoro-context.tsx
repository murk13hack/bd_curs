import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '@/api/client';
import { usePomodoroSettings } from '@/hooks/use-theme';
import {
  advancePhase,
  idleState,
  loadPomodoroState,
  pauseState,
  POMODORO_MIN_LOG_SEC,
  resumeState,
  savePomodoroState,
  startWorkState,
  syncFromClock,
  type PomodoroPhase,
  type PomodoroState,
} from '@/lib/pomodoro-timer';

export type { PomodoroPhase };

interface PomodoroContextValue extends PomodoroState {
  notice: string | null;
  clearNotice: () => void;
  /** Старт work-фазы; задача необязательна (время пишется в задачу только если она выбрана). */
  start: (taskId?: number, taskTitle?: string) => void;
  /** Привязка / смена задачи; null — отвязать (накопленное по старой задаче сохранится). */
  selectTask: (taskId: number | null, taskTitle?: string) => void;
  pause: () => void;
  resume: () => void;
  reset: () => void;
  skip: () => void;
}

const PomodoroContext = createContext<PomodoroContextValue | null>(null);

function playPhaseEndSound() {
  try {
    new Audio(
      'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQQAAAA=',
    ).play();
  } catch {
    /* ignore */
  }
}

async function writeWorkLog(taskId: number, focusedSec: number): Promise<string | null> {
  if (focusedSec < POMODORO_MIN_LOG_SEC) return null;
  const ended = new Date();
  const started = new Date(ended.getTime() - focusedSec * 1000);
  try {
    await api.tasks.addTimeLog(taskId, {
      started_at: started.toISOString(),
      ended_at: ended.toISOString(),
      is_pomodoro: true,
    });
    return null;
  } catch (e) {
    if (e instanceof ApiError && e.status === 409) {
      return 'Время не сохранено: интервал пересекается с другой записью.';
    }
    if (e instanceof Error) return e.message;
    return 'Не удалось сохранить время в задачу.';
  }
}

function taskFromArgs(taskId?: number, taskTitle?: string): { id: number; title: string } | null {
  if (taskId == null) return null;
  return { id: taskId, title: taskTitle ?? '' };
}

export function PomodoroProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient();
  const settings = usePomodoroSettings();
  const settingsRef = useRef(settings);
  settingsRef.current = settings;

  const [state, setState] = useState<PomodoroState>(() => loadPomodoroState(settings));
  const [notice, setNotice] = useState<string | null>(null);
  const stateRef = useRef(state);
  stateRef.current = state;

  const clearNotice = useCallback(() => setNotice(null), []);

  const invalidateTimeQueries = useCallback(() => {
    void qc.invalidateQueries({ queryKey: ['stats'] });
    void qc.invalidateQueries({ queryKey: ['stats-time'] });
    void qc.invalidateQueries({ queryKey: ['task-time-logs'] });
  }, [qc]);

  const flushWork = useCallback(
    async (taskId: number | null, focusedSec: number) => {
      if (!taskId || focusedSec < POMODORO_MIN_LOG_SEC) return;
      const err = await writeWorkLog(taskId, focusedSec);
      if (err) setNotice(err);
      else invalidateTimeQueries();
    },
    [invalidateTimeQueries],
  );

  const commit = useCallback((next: PomodoroState) => {
    stateRef.current = next;
    setState(next);
    savePomodoroState(next);
  }, []);

  const completePhase = useCallback(
    (current: PomodoroState) => {
      if (current.phase === 'work' && current.taskId) {
        void flushWork(current.taskId, current.workFocusedSec);
      }
      playPhaseEndSound();
      const next = advancePhase(current, settingsRef.current);
      commit(next);
    },
    [commit, flushWork],
  );

  const tick = useCallback(() => {
    const prev = stateRef.current;
    if (!prev.running || prev.phase === 'idle') return;

    const synced = syncFromClock(prev);
    if (synced.remainingSec <= 0 && prev.remainingSec > 0) {
      completePhase(synced);
      return;
    }
    if (synced.remainingSec !== prev.remainingSec || synced.workFocusedSec !== prev.workFocusedSec) {
      commit(synced);
    }
  }, [commit, completePhase]);

  useEffect(() => {
    savePomodoroState(state);
  }, [state]);

  useEffect(() => {
    const prev = stateRef.current;
    if (!prev.running || prev.phase === 'idle') return;
    const synced = syncFromClock(prev);
    if (synced.remainingSec <= 0 && prev.remainingSec > 0) {
      completePhase(synced);
    } else if (
      synced.remainingSec !== prev.remainingSec ||
      synced.workFocusedSec !== prev.workFocusedSec
    ) {
      commit(synced);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- once after reload
  }, []);

  useEffect(() => {
    const onVis = () => {
      if (document.visibilityState === 'visible') tick();
    };
    document.addEventListener('visibilitychange', onVis);
    return () => document.removeEventListener('visibilitychange', onVis);
  }, [tick]);

  useEffect(() => {
    if (!state.running || state.phase === 'idle') return undefined;
    const id = window.setInterval(tick, 1000);
    return () => window.clearInterval(id);
  }, [state.running, state.phase, tick]);

  useEffect(() => {
    const totalSec = settings.workMinutes * 60;
    setState((prev) => {
      if (prev.phase !== 'idle') return prev;
      if (prev.totalSec === totalSec && prev.remainingSec === totalSec) return prev;
      const next = { ...prev, totalSec, remainingSec: totalSec };
      savePomodoroState(next);
      return next;
    });
  }, [settings.workMinutes]);

  const start = useCallback(
    (taskId?: number, taskTitle?: string) => {
      clearNotice();
      commit(startWorkState(settingsRef.current, taskFromArgs(taskId, taskTitle), 0));
    },
    [commit, clearNotice],
  );

  const selectTask = useCallback(
    async (taskId: number | null, taskTitle = '') => {
      clearNotice();
      let prev = syncFromClock(stateRef.current);

      if (taskId === null) {
        if (prev.phase === 'work' && prev.taskId != null && prev.workFocusedSec >= POMODORO_MIN_LOG_SEC) {
          await flushWork(prev.taskId, prev.workFocusedSec);
          prev = { ...prev, workFocusedSec: 0, savedAt: Date.now() };
        }
        commit({ ...prev, taskId: null, taskTitle: '' });
        return;
      }

      if (prev.phase === 'work' && prev.taskId != null && prev.taskId !== taskId) {
        await flushWork(prev.taskId, prev.workFocusedSec);
        prev = { ...prev, workFocusedSec: 0, savedAt: Date.now() };
      }

      commit({ ...prev, taskId, taskTitle });
    },
    [clearNotice, commit, flushWork],
  );

  const pause = useCallback(() => {
    commit(pauseState(stateRef.current));
  }, [commit]);

  const resume = useCallback(() => {
    commit(resumeState(stateRef.current));
  }, [commit]);

  const reset = useCallback(() => {
    const prev = syncFromClock(stateRef.current);
    if (prev.phase === 'work' && prev.taskId) {
      void flushWork(prev.taskId, prev.workFocusedSec);
    }
    clearNotice();
    commit(idleState(settingsRef.current));
  }, [commit, flushWork, clearNotice]);

  const skip = useCallback(() => {
    const prev = syncFromClock(stateRef.current);
    if (prev.phase === 'work' && prev.taskId) {
      void flushWork(prev.taskId, prev.workFocusedSec);
    }
    if (prev.remainingSec <= 0) return;
    playPhaseEndSound();
    commit(advancePhase({ ...prev, remainingSec: 0 }, settingsRef.current));
  }, [commit, flushWork]);

  const value = useMemo(
    () => ({
      ...state,
      notice,
      clearNotice,
      start,
      selectTask,
      pause,
      resume,
      reset,
      skip,
    }),
    [state, notice, clearNotice, start, selectTask, pause, resume, reset, skip],
  );

  return <PomodoroContext.Provider value={value}>{children}</PomodoroContext.Provider>;
}

export function usePomodoro() {
  const ctx = useContext(PomodoroContext);
  if (!ctx) throw new Error('usePomodoro outside provider');
  return ctx;
}
