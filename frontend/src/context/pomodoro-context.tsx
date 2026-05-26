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
  advanceSessionPhase,
  loadPomodoroStore,
  pauseSession,
  POMODORO_MAX_SESSIONS,
  POMODORO_MIN_LOG_SEC,
  resumeSession,
  savePomodoroStore,
  sessionFocusChanged,
  startWorkSession,
  syncFromClock,
  type PomodoroPhase,
  type PomodoroSession,
  type PomodoroStore,
} from '@/lib/pomodoro-timer';

export type { PomodoroPhase, PomodoroSession };

interface PomodoroContextValue {
  sessions: PomodoroSession[];
  maxSessions: number;
  canAddSession: boolean;
  notice: string | null;
  clearNotice: () => void;
  createSession: (taskId?: number, taskTitle?: string) => string | null;
  removeSession: (sessionId: string) => void;
  selectTask: (sessionId: string, taskId: number | null, taskTitle?: string) => void;
  pause: (sessionId: string) => void;
  resume: (sessionId: string) => void;
  reset: (sessionId: string) => void;
  skip: (sessionId: string) => void;
  getSession: (sessionId: string) => PomodoroSession | undefined;
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
    if (e instanceof ApiError) return e.message;
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

  const [store, setStore] = useState<PomodoroStore>(() => loadPomodoroStore(settings));
  const [notice, setNotice] = useState<string | null>(null);
  const storeRef = useRef(store);
  storeRef.current = store;

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

  const commitStore = useCallback((next: PomodoroStore) => {
    storeRef.current = next;
    setStore(next);
    savePomodoroStore(next);
  }, []);

  const updateSession = useCallback(
    (sessionId: string, updater: (s: PomodoroSession) => PomodoroSession) => {
      const prev = storeRef.current;
      const idx = prev.sessions.findIndex((s) => s.id === sessionId);
      if (idx < 0) return;
      const sessions = [...prev.sessions];
      sessions[idx] = updater(sessions[idx]);
      commitStore({ version: 2, sessions });
    },
    [commitStore],
  );

  const tickAll = useCallback(() => {
    const prev = storeRef.current;
    let changed = false;
    let phaseEnded = false;

    const sessions = prev.sessions.map((s) => {
      if (!s.running || s.phase === 'idle') return s;

      const before = s;
      const synced = syncFromClock(s);

      if (synced.remainingSec <= 0 && before.remainingSec > 0) {
        changed = true;
        phaseEnded = true;
        if (synced.phase === 'work' && synced.taskId) {
          void flushWork(synced.taskId, synced.taskFocusedSec);
        }
        return advanceSessionPhase({ ...synced, remainingSec: 0 }, settingsRef.current);
      }

      if (sessionFocusChanged(before, synced)) {
        changed = true;
        return synced;
      }
      return s;
    });

    if (phaseEnded) playPhaseEndSound();
    if (changed) {
      commitStore({ version: 2, sessions });
    }
  }, [commitStore, flushWork]);

  useEffect(() => {
    savePomodoroStore(store);
  }, [store]);

  useEffect(() => {
    tickAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const onVis = () => {
      if (document.visibilityState === 'visible') tickAll();
    };
    document.addEventListener('visibilitychange', onVis);
    return () => document.removeEventListener('visibilitychange', onVis);
  }, [tickAll]);

  useEffect(() => {
    const anyRunning = store.sessions.some((s) => s.running && s.phase !== 'idle');
    if (!anyRunning) return undefined;
    const id = window.setInterval(tickAll, 1000);
    return () => window.clearInterval(id);
  }, [store.sessions, tickAll]);

  const createSession = useCallback(
    (taskId?: number, taskTitle?: string) => {
      clearNotice();
      const prev = storeRef.current;
      if (prev.sessions.length >= POMODORO_MAX_SESSIONS) {
        setNotice(`Не больше ${POMODORO_MAX_SESSIONS} таймеров одновременно.`);
        return null;
      }
      const session = startWorkSession(
        settingsRef.current,
        taskFromArgs(taskId, taskTitle),
        0,
      );
      commitStore({ version: 2, sessions: [...prev.sessions, session] });
      return session.id;
    },
    [clearNotice, commitStore],
  );

  const removeSession = useCallback(
    async (sessionId: string) => {
      const prev = storeRef.current;
      const session = prev.sessions.find((s) => s.id === sessionId);
      if (!session) return;
      const synced = syncFromClock(session);
      if (synced.phase === 'work' && synced.taskId) {
        await flushWork(synced.taskId, synced.taskFocusedSec);
      }
      commitStore({
        version: 2,
        sessions: prev.sessions.filter((s) => s.id !== sessionId),
      });
    },
    [commitStore, flushWork],
  );

  const selectTask = useCallback(
    async (sessionId: string, taskId: number | null, taskTitle = '') => {
      clearNotice();
      const prev = storeRef.current;
      const idx = prev.sessions.findIndex((s) => s.id === sessionId);
      if (idx < 0) return;

      let session = syncFromClock(prev.sessions[idx]);

      if (taskId === null) {
        if (session.phase === 'work' && session.taskId != null) {
          await flushWork(session.taskId, session.taskFocusedSec);
        }
        session = { ...session, taskId: null, taskTitle: '', taskFocusedSec: 0, savedAt: Date.now() };
      } else {
        if (session.phase === 'work' && session.taskId != null && session.taskId !== taskId) {
          await flushWork(session.taskId, session.taskFocusedSec);
        }
        session = {
          ...session,
          taskId,
          taskTitle,
          taskFocusedSec: 0,
          savedAt: Date.now(),
        };
      }

      const sessions = [...prev.sessions];
      sessions[idx] = session;
      commitStore({ version: 2, sessions });
    },
    [clearNotice, commitStore, flushWork],
  );

  const pause = useCallback(
    (sessionId: string) => {
      updateSession(sessionId, (s) => pauseSession(s));
    },
    [updateSession],
  );

  const resume = useCallback(
    (sessionId: string) => {
      updateSession(sessionId, (s) => resumeSession(s));
    },
    [updateSession],
  );

  const reset = useCallback(
    (sessionId: string) => {
      void removeSession(sessionId);
    },
    [removeSession],
  );

  const skip = useCallback(
    (sessionId: string) => {
      const prev = storeRef.current;
      const idx = prev.sessions.findIndex((s) => s.id === sessionId);
      if (idx < 0) return;

      let session = syncFromClock(prev.sessions[idx]);
      if (session.phase === 'work' && session.taskId) {
        void flushWork(session.taskId, session.taskFocusedSec);
      }
      if (session.remainingSec <= 0) return;

      playPhaseEndSound();
      session = advanceSessionPhase({ ...session, remainingSec: 0 }, settingsRef.current);

      const sessions = [...prev.sessions];
      sessions[idx] = session;
      commitStore({ version: 2, sessions });
    },
    [commitStore, flushWork],
  );

  const getSession = useCallback(
    (sessionId: string) => storeRef.current.sessions.find((s) => s.id === sessionId),
    [],
  );

  const value = useMemo(
    () => ({
      sessions: store.sessions,
      maxSessions: POMODORO_MAX_SESSIONS,
      canAddSession: store.sessions.length < POMODORO_MAX_SESSIONS,
      notice,
      clearNotice,
      createSession,
      removeSession,
      selectTask,
      pause,
      resume,
      reset,
      skip,
      getSession,
    }),
    [
      store.sessions,
      notice,
      clearNotice,
      createSession,
      removeSession,
      selectTask,
      pause,
      resume,
      reset,
      skip,
      getSession,
    ],
  );

  return <PomodoroContext.Provider value={value}>{children}</PomodoroContext.Provider>;
}

export function usePomodoro() {
  const ctx = useContext(PomodoroContext);
  if (!ctx) throw new Error('usePomodoro outside provider');
  return ctx;
}
