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

export const PATTERN_MODE_LABEL: Record<import('@/api/types').PatternMode, string> = {
  habit: 'Привычка',
  scenario: 'Сценарий',
  markers: 'Точки',
};

export const PATTERN_MODE_HINT: Record<import('@/api/types').PatternMode, string> = {
  habit: 'Один итог за день',
  scenario: 'Цепочка шагов',
  markers: 'Журнал эпизодов',
};

export const PATTERN_STEP_ROLE_LABEL: Record<
  import('@/api/types').PatternStepRole,
  string
> = {
  context: 'Контекст',
  trigger: 'Триггер',
  choice: 'Развилка',
  action: 'Действие',
  outcome: 'Итог',
};

export const PATTERN_STEP_KIND_LABEL: Record<
  import('@/api/types').PatternStepKind,
  string
> = {
  single_choice: 'Выбор варианта',
  check: 'Да / нет',
  note: 'Текст',
};

export const PATTERN_TYPE_LABEL: Record<PatternType, string> = {
  positive: 'Полезное поведение',
  negative: 'Отказ / абстиненция',
};

/** Подписи фильтров OLAP и дневника в статистике */
export const MOOD_BUCKET_LABEL: Record<string, string> = {
  '': 'Любое',
  none: 'Без записи в дневнике',
  low: 'Низкое (1–2)',
  mid: 'Среднее (3)',
  high: 'Высокое (4–5)',
};

export const ENERGY_BUCKET_LABEL: Record<string, string> = {
  '': 'Любая',
  none: 'Без записи в дневнике',
  low: 'Низкая (1–2)',
  mid: 'Средняя (3)',
  high: 'Высокая (4–5)',
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

/** Индексы 1–5; [0] пустой для удобства массива */
export const MOOD_EMOJI = ['', '😞', '😐', '🙂', '😊', '🤩'];
export const ENERGY_EMOJI = ['', '🪫', '😴', '🔋', '⚡', '🚀'];

export const MOOD_LABEL = ['', 'Тяжело', 'Так себе', 'Нормально', 'Хорошо', 'Отлично'];
export const ENERGY_LABEL = ['', 'Нет сил', 'Устал', 'Бодрость', 'Энергично', 'На пике'];

export const MOOD_LEVEL_COLOR = ['', '#ef4444', '#f97316', '#eab308', '#84cc16', '#22c55e'];
export const ENERGY_LEVEL_COLOR = ['', '#94a3b8', '#64748b', '#38bdf8', '#6366f1', '#a855f7'];

export function moodEmoji(level: number | null | undefined): string {
  if (level == null || level < 1 || level > 5) return '';
  return MOOD_EMOJI[level];
}

export function energyEmoji(level: number | null | undefined): string {
  if (level == null || level < 1 || level > 5) return '';
  return ENERGY_EMOJI[level];
}

export const NAV_ITEMS = [
  { to: '/', label: 'Обзор', icon: 'LayoutDashboard' },
  { to: '/tasks', label: 'Задачи', icon: 'CheckSquare' },
  { to: '/diary', label: 'Дневник', icon: 'BookOpen' },
  { to: '/patterns', label: 'Паттерны', icon: 'Repeat' },
  { to: '/calendar', label: 'Календарь', icon: 'Calendar' },
  { to: '/stats', label: 'Статистика', icon: 'BarChart3' },
  { to: '/goals', label: 'Цели', icon: 'Target' },
  { to: '/pomodoro', label: 'Pomodoro', icon: 'Timer' },
  { to: '/settings', label: 'Настройки', icon: 'Settings' },
] as const;
