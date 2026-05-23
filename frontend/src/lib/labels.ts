import type { PatternType, TaskPriority, TaskStatus } from '@/api/types';

export const TASK_STATUS_LABEL: Record<TaskStatus, string> = {
  pending: 'Ожидает',
  in_progress: 'В работе',
  done: 'Выполнена',
  overdue: 'Просрочена',
  cancelled: 'Отменена',
};

export const TASK_PRIORITY_LABEL: Record<TaskPriority, string> = {
  low: 'Низкий',
  medium: 'Средний',
  high: 'Высокий',
  urgent: 'Срочный',
};

export const PATTERN_TYPE_LABEL: Record<PatternType, string> = {
  positive: 'Полезная',
  negative: 'Вредная',
};

export const STATUS_COLOR: Record<TaskStatus, string> = {
  pending: 'bg-slate-500/15 text-slate-600 dark:text-slate-300',
  in_progress: 'bg-blue-500/15 text-blue-700 dark:text-blue-300',
  done: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300',
  overdue: 'bg-red-500/15 text-red-700 dark:text-red-300',
  cancelled: 'bg-zinc-500/15 text-zinc-600 dark:text-zinc-300',
};

export const PRIORITY_COLOR: Record<TaskPriority, string> = {
  low: 'text-slate-500',
  medium: 'text-blue-600',
  high: 'text-orange-600',
  urgent: 'text-red-600',
};

export const MOOD_EMOJI = ['', '😞', '😐', '🙂', '😊', '🤩'];
export const ENERGY_EMOJI = ['', '🔋', '🔋', '⚡', '⚡', '🚀'];

export const NAV_ITEMS = [
  { to: '/', label: 'Обзор', icon: 'LayoutDashboard' },
  { to: '/tasks', label: 'Задачи', icon: 'CheckSquare' },
  { to: '/diary', label: 'Дневник', icon: 'BookOpen' },
  { to: '/patterns', label: 'Привычки', icon: 'Repeat' },
  { to: '/calendar', label: 'Календарь', icon: 'Calendar' },
  { to: '/stats', label: 'Статистика', icon: 'BarChart3' },
  { to: '/goals', label: 'Цели', icon: 'Target' },
  { to: '/pomodoro', label: 'Pomodoro', icon: 'Timer' },
  { to: '/settings', label: 'Настройки', icon: 'Settings' },
] as const;
