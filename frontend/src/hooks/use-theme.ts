import { useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/api/client';

export type ThemeMode = 'light' | 'dark' | 'system';

function resolveTheme(mode: ThemeMode): 'light' | 'dark' {
  if (mode === 'system') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  return mode;
}

export function useTheme() {
  const { data: settings = [] } = useQuery({
    queryKey: ['settings'],
    queryFn: api.settings.list,
  });

  const raw = settings.find((s) => s.key === 'theme')?.value;
  const mode: ThemeMode =
    raw === 'light' || raw === 'dark' || raw === 'system' ? raw : 'system';

  useEffect(() => {
    const apply = () => {
      document.documentElement.dataset.theme = resolveTheme(mode);
    };
    apply();
    if (mode === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      mq.addEventListener('change', apply);
      return () => mq.removeEventListener('change', apply);
    }
    return undefined;
  }, [mode]);

  return { mode };
}

export function usePomodoroSettings() {
  const { data: settings = [] } = useQuery({
    queryKey: ['settings'],
    queryFn: api.settings.list,
  });

  const num = (key: string, fallback: number) => {
    const v = settings.find((s) => s.key === key)?.value;
    const n = typeof v === 'number' ? v : Number(v);
    return Number.isFinite(n) ? n : fallback;
  };

  return {
    workMinutes: num('pomodoro_minutes', 25),
    shortBreak: num('pomodoro_short_break', 5),
    longBreak: num('pomodoro_long_break', 15),
  };
}
