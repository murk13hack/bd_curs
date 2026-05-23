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
import { usePomodoroSettings } from '@/hooks/use-theme';

type Phase = 'work' | 'short_break' | 'long_break' | 'idle';

interface PomodoroState {
  phase: Phase;
  taskId: number | null;
  taskTitle: string;
  remainingSec: number;
  totalSec: number;
  cycles: number;
  running: boolean;
}

interface PomodoroContextValue extends PomodoroState {
  start: (taskId?: number, taskTitle?: string) => void;
  pause: () => void;
  resume: () => void;
  reset: () => void;
  skip: () => void;
}

const STORAGE_KEY = 'ptt-pomodoro';

const PomodoroContext = createContext<PomodoroContextValue | null>(null);

function loadState(): PomodoroState | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as PomodoroState) : null;
  } catch {
    return null;
  }
}

export function PomodoroProvider({ children }: { children: ReactNode }) {
  const { workMinutes, shortBreak, longBreak } = usePomodoroSettings();
  const [state, setState] = useState<PomodoroState>(() => {
    const saved = loadState();
    return (
      saved ?? {
        phase: 'idle',
        taskId: null,
        taskTitle: '',
        remainingSec: workMinutes * 60,
        totalSec: workMinutes * 60,
        cycles: 0,
        running: false,
      }
    );
  });
  const tickRef = useRef<number | null>(null);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [state]);

  const phaseDuration = useCallback(
    (phase: Phase) => {
      if (phase === 'work') return workMinutes * 60;
      if (phase === 'long_break') return longBreak * 60;
      if (phase === 'short_break') return shortBreak * 60;
      return workMinutes * 60;
    },
    [workMinutes, shortBreak, longBreak],
  );

  const nextPhase = useCallback(
    (current: PomodoroState): PomodoroState => {
      if (current.phase === 'work') {
        const cycles = current.cycles + 1;
        const isLong = cycles % 4 === 0;
        const phase: Phase = isLong ? 'long_break' : 'short_break';
        const totalSec = phaseDuration(phase);
        return { ...current, phase, cycles, totalSec, remainingSec: totalSec, running: true };
      }
      const totalSec = phaseDuration('work');
      return {
        ...current,
        phase: 'work',
        totalSec,
        remainingSec: totalSec,
        running: true,
      };
    },
    [phaseDuration],
  );

  useEffect(() => {
    if (!state.running || state.phase === 'idle') {
      if (tickRef.current) window.clearInterval(tickRef.current);
      return undefined;
    }

    tickRef.current = window.setInterval(() => {
      setState((prev) => {
        if (prev.remainingSec <= 1) {
          try {
            new Audio(
              'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQQAAAA=',
            ).play();
          } catch {
            /* ignore */
          }
          return nextPhase(prev);
        }
        return { ...prev, remainingSec: prev.remainingSec - 1 };
      });
    }, 1000);

    return () => {
      if (tickRef.current) window.clearInterval(tickRef.current);
    };
  }, [state.running, state.phase, nextPhase]);

  const start = useCallback(
    (taskId?: number, taskTitle = '') => {
      const totalSec = phaseDuration('work');
      setState({
        phase: 'work',
        taskId: taskId ?? null,
        taskTitle,
        remainingSec: totalSec,
        totalSec,
        cycles: 0,
        running: true,
      });
    },
    [phaseDuration],
  );

  const pause = useCallback(() => setState((s) => ({ ...s, running: false })), []);
  const resume = useCallback(() => setState((s) => ({ ...s, running: true })), []);
  const reset = useCallback(() => {
    const totalSec = phaseDuration('work');
    setState({
      phase: 'idle',
      taskId: null,
      taskTitle: '',
      remainingSec: totalSec,
      totalSec,
      cycles: 0,
      running: false,
    });
  }, [phaseDuration]);
  const skip = useCallback(() => setState((s) => nextPhase(s)), [nextPhase]);

  const value = useMemo(
    () => ({ ...state, start, pause, resume, reset, skip }),
    [state, start, pause, resume, reset, skip],
  );

  return <PomodoroContext.Provider value={value}>{children}</PomodoroContext.Provider>;
}

export function usePomodoro() {
  const ctx = useContext(PomodoroContext);
  if (!ctx) throw new Error('usePomodoro outside provider');
  return ctx;
}
