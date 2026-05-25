import type {
  PatternStep,
  PatternStepKind,
  PatternStepRole,
  PatternType,
} from '@/api/types';

export type StepChoiceDraft = {
  id: string;
  label: string;
  is_success: boolean;
};

export type StepDraft = {
  clientId: string;
  title: string;
  hint: string;
  step_kind: PatternStepKind;
  step_role: PatternStepRole;
  is_required: boolean;
  marks_success: boolean;
  choices: StepChoiceDraft[];
};

export type ScenarioTemplate = {
  id: string;
  label: string;
  description: string;
  pattern_type: PatternType;
  guide_intro: string;
  steps: StepDraftInput[];
};

export const SCENARIO_TEMPLATES: ScenarioTemplate[] = [
  {
    id: 'blank',
    label: 'С нуля',
    description: 'Один пустой шаг — настройте цепочку сами',
    pattern_type: 'negative',
    guide_intro: '',
    steps: [blankStep({ step_role: 'outcome', marks_success: true, step_kind: 'single_choice' })],
  },
  {
    id: 'quit_smoking',
    label: 'Бросаю курить',
    description: 'Триггеры, развилки, итог дня',
    pattern_type: 'negative',
    guide_intro:
      'Пройдите типичный день честно — шаг за шагом. Это поможет увидеть триггеры, а не только «сорвался / нет».',
    steps: [
      {
        title: 'Конец рабочего дня / начало вечера',
        hint: 'Где вы были, что происходило?',
        step_kind: 'check',
        step_role: 'context',
        is_required: true,
        marks_success: false,
        choices: [],
      },
      {
        title: 'Уровень стресса или усталости',
        hint: 'Оцените честно — частый триггер',
        step_kind: 'single_choice',
        step_role: 'trigger',
        is_required: true,
        marks_success: false,
        choices: [
          { id: 'low', label: 'Низкий', is_success: false },
          { id: 'mid', label: 'Средний', is_success: false },
          { id: 'high', label: 'Высокий', is_success: false },
        ],
      },
      {
        title: 'Перекур с коллегами / в компании?',
        step_kind: 'single_choice',
        step_role: 'choice',
        is_required: true,
        marks_success: false,
        choices: [
          { id: 'no', label: 'Нет', is_success: false },
          { id: 'avoided', label: 'Было, но избежал', is_success: false },
          { id: 'joined', label: 'Да, присоединился', is_success: false },
        ],
      },
      {
        title: 'Появилось желание закурить?',
        step_kind: 'single_choice',
        step_role: 'trigger',
        is_required: true,
        marks_success: false,
        choices: [
          { id: 'no', label: 'Нет', is_success: false },
          { id: 'resisted', label: 'Было, удержался', is_success: false },
          { id: 'smoked', label: 'Было, закурил', is_success: false },
        ],
      },
      {
        title: 'Что сделали вместо курения?',
        step_kind: 'single_choice',
        step_role: 'action',
        is_required: false,
        marks_success: false,
        choices: [
          { id: 'walk', label: 'Прогулка / воздух', is_success: false },
          { id: 'snack', label: 'Вода / перекус', is_success: false },
          { id: 'nothing', label: 'Ничего', is_success: false },
          { id: 'na', label: 'Не было желания', is_success: false },
        ],
      },
      {
        title: 'Итог дня по курению',
        hint: 'Определяет серию «дней без срыва»',
        step_kind: 'single_choice',
        step_role: 'outcome',
        is_required: true,
        marks_success: true,
        choices: [
          { id: 'zero', label: '0 раз — чистый день', is_success: true },
          { id: 'one', label: '1 раз', is_success: false },
          { id: 'two_plus', label: '2+ раз', is_success: false },
        ],
      },
    ],
  },
  {
    id: 'morning_routine',
    label: 'Утро без телефона',
    description: 'Positive-сценарий с итогом',
    pattern_type: 'positive',
    guide_intro: 'Отметьте ключевые точки утра — найдите, где срываетесь на экран.',
    steps: [
      {
        title: 'Проснулись без телефона в первые 15 мин?',
        step_kind: 'check',
        step_role: 'context',
        is_required: true,
        marks_success: false,
        choices: [],
      },
      {
        title: 'Завтрак / вода',
        step_kind: 'check',
        step_role: 'action',
        is_required: false,
        marks_success: false,
        choices: [],
      },
      {
        title: 'Итог утра',
        step_kind: 'single_choice',
        step_role: 'outcome',
        is_required: true,
        marks_success: true,
        choices: [
          { id: 'good', label: 'Утро прошло как задумано', is_success: true },
          { id: 'partial', label: 'Частично', is_success: false },
          { id: 'bad', label: 'Снова залип в телефон', is_success: false },
        ],
      },
    ],
  },
];

let _uid = 0;
export function newClientId(): string {
  _uid += 1;
  return `step_${Date.now()}_${_uid}`;
}

export function slugId(label: string): string {
  const base = label
    .toLowerCase()
    .replace(/[^a-zа-яё0-9]+/gi, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 24);
  return base ? `${base}_${Math.random().toString(36).slice(2, 6)}` : newClientId();
}

export function blankStep(
  overrides: Partial<Omit<StepDraft, 'clientId'>> = {},
): Omit<StepDraft, 'clientId'> {
  return {
    title: 'Новый шаг',
    hint: '',
    step_kind: 'single_choice',
    step_role: 'context',
    is_required: true,
    marks_success: false,
    choices: [
      { id: slugId('a'), label: 'Вариант 1', is_success: false },
      { id: slugId('b'), label: 'Вариант 2', is_success: false },
    ],
    ...overrides,
  };
}

export type StepDraftInput = Omit<StepDraft, 'clientId' | 'hint'> & { hint?: string };

export function toStepDrafts(steps: StepDraftInput[]): StepDraft[] {
  return steps.map((s) => ({ ...s, hint: s.hint ?? '', clientId: newClientId() }));
}

export function fromPatternSteps(steps: PatternStep[]): StepDraft[] {
  return [...steps]
    .sort((a, b) => a.sort_order - b.sort_order)
    .map((s) => ({
      clientId: `db_${s.id}`,
      title: s.title,
      hint: s.hint ?? '',
      step_kind: s.step_kind,
      step_role: s.step_role,
      is_required: s.is_required,
      marks_success: s.marks_success,
      choices: (s.choices ?? []).map((c) => ({
        id: c.id,
        label: c.label,
        is_success: c.is_success ?? false,
      })),
    }));
}

export function toApiSteps(steps: StepDraft[]) {
  return steps.map((s, i) => ({
    title: s.title.trim(),
    hint: s.hint.trim() || null,
    step_kind: s.step_kind,
    step_role: s.step_role,
    is_required: s.is_required,
    marks_success: s.marks_success,
    sort_order: i,
    choices:
      s.step_kind === 'single_choice'
        ? s.choices.map((c) => ({
            id: c.id || slugId(c.label),
            label: c.label.trim(),
            is_success: c.is_success,
          }))
        : [],
  }));
}

export function validateScenarioSteps(steps: StepDraft[]): string | null {
  if (steps.length === 0) return 'Добавьте хотя бы один шаг';
  for (const [i, s] of steps.entries()) {
    if (!s.title.trim()) return `Шаг ${i + 1}: укажите название`;
    if (s.step_kind === 'single_choice') {
      if (s.choices.length === 0) return `Шаг «${s.title}»: добавьте варианты ответа`;
      if (s.choices.some((c) => !c.label.trim())) return `Шаг «${s.title}»: пустой вариант`;
    }
  }
  const outcome = steps.filter((s) => s.marks_success || s.step_role === 'outcome');
  if (outcome.length === 0) {
    return 'Отметьте один шаг как «Итог дня» (роль outcome или флаг «считает успех»)';
  }
  if (outcome.some((s) => s.step_kind === 'note')) {
    return 'Итог дня не может быть заметкой — используйте «да/нет» или варианты ответа';
  }
  return null;
}

export function setMarksSuccess(steps: StepDraft[], clientId: string, value: boolean): StepDraft[] {
  return steps.map((s) => {
    if (s.clientId === clientId) {
      return {
        ...s,
        marks_success: value,
        step_role: value ? 'outcome' : s.step_role === 'outcome' ? 'context' : s.step_role,
      };
    }
    if (value) return { ...s, marks_success: false };
    return s;
  });
}

export function moveStep(steps: StepDraft[], clientId: string, dir: -1 | 1): StepDraft[] {
  const idx = steps.findIndex((s) => s.clientId === clientId);
  if (idx < 0) return steps;
  const next = idx + dir;
  if (next < 0 || next >= steps.length) return steps;
  const copy = [...steps];
  [copy[idx], copy[next]] = [copy[next], copy[idx]];
  return copy;
}

export const DOW_LABELS = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'] as const;

export function dowMaskFromArray(days: boolean[]): number {
  return days.reduce((mask, on, i) => (on ? mask | (1 << i) : mask), 0);
}

export function dowArrayFromMask(mask: number): boolean[] {
  return DOW_LABELS.map((_, i) => (mask & (1 << i)) > 0);
}

export function todayDateOnly(): string {
  const d = new Date();
  d.setHours(12, 0, 0, 0);
  return d.toISOString();
}

export function formatScheduleTimes(schedules: { time_of_day: string }[]): string {
  return schedules.map((s) => s.time_of_day.slice(0, 5)).join(', ') || 'без напоминаний';
}

export function streakLabel(type: 'positive' | 'negative', mode: string): string {
  if (mode === 'markers') return 'Дней без негативных отметок';
  if (mode === 'scenario' && type === 'negative') return 'Дней без срыва';
  if (type === 'negative') return 'Без срыва';
  return 'Серия';
}

export function rateLabel(scheduled: number, success: number): string {
  if (scheduled === 0) return '—';
  if (scheduled < 3) return `${success}/${scheduled} дн.`;
  const pct = Math.round((success / scheduled) * 100);
  return `${success}/${scheduled} (${pct}%)`;
}

export function todayTone(
  isSuccess: boolean | null | undefined,
  status?: string,
): 'good' | 'bad' | 'pending' {
  if (status === 'missed') return 'bad';
  if (isSuccess === true) return 'good';
  if (isSuccess === false) return 'bad';
  return 'pending';
}
