import type {
  AppSetting,
  CalendarDay,
  CorrelationWeek,
  DiaryEntry,
  DiarySearchHit,
  ExportResponse,
  Goal,
  GoalProgress,
  HeatmapPoint,
  Holiday,
  HolisticCorrelationWeek,
  OlapMeta,
  OlapResult,
  Pattern,
  PatternInsights,
  PatternMarker,
  PatternSchedule,
  PatternSession,
  PatternStep,
  PatternStreak,
  PatternStreakDetail,
  PatternStatsRow,
  PatternToday,
  PriorityBreakdown,
  RecurringRule,
  RecurringRuleSummary,
  Tag,
  Task,
  TaskView,
  TimeLog,
  Topic,
  StatsOverview,
  TopicBreakdown,
  TopicTimeBreakdown,
  WeeklySummary,
} from './types';

const BASE = import.meta.env.VITE_API_URL || '/api/v1';

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  if (init?.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  const bodyText = await res.text();
  if (!res.ok) {
    let detail = res.statusText;
    if (bodyText) {
      try {
        const json = JSON.parse(bodyText) as { detail?: string };
        detail =
          typeof json.detail === 'string' ? json.detail : JSON.stringify(json.detail);
      } catch {
        detail = bodyText;
      }
    }
    throw new ApiError(detail, res.status);
  }
  if (res.status === 204 || bodyText === '') return undefined as T;
  return JSON.parse(bodyText) as T;
}

function qs(params: Record<string, string | number | boolean | undefined | null>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : '';
}

export const api = {
  ping: () => request<{ pong: boolean }>('/ping'),
  dbPing: () => request<{ db: string; version: string }>('/db-ping'),

  topics: {
    list: () => request<Topic[]>('/topics'),
    create: (body: { name: string; color?: string }) =>
      request<Topic>('/topics', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Partial<{ name: string; color: string }>) =>
      request<Topic>(`/topics/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/topics/${id}`, { method: 'DELETE' }),
  },

  tags: {
    list: () => request<Tag[]>('/tags'),
    create: (body: { name: string }) =>
      request<Tag>('/tags', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: { name: string }) =>
      request<Tag>(`/tags/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/tags/${id}`, { method: 'DELETE' }),
  },

  holidays: {
    list: (year?: number) => request<Holiday[]>(`/holidays${qs({ year })}`),
    create: (body: { holiday_date: string; name: string; is_official?: boolean }) =>
      request<Holiday>('/holidays', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Partial<{ name: string; is_official: boolean }>) =>
      request<Holiday>(`/holidays/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/holidays/${id}`, { method: 'DELETE' }),
  },

  settings: {
    list: () => request<AppSetting[]>('/settings'),
    get: (key: string) => request<AppSetting>(`/settings/${key}`),
    upsert: (key: string, value: unknown) =>
      request<AppSetting>(`/settings/${key}`, {
        method: 'PUT',
        body: JSON.stringify({ key, value }),
      }),
    remove: (key: string) => request<void>(`/settings/${key}`, { method: 'DELETE' }),
  },

  tasks: {
    list: (params: { view?: TaskView; [key: string]: string | number | boolean | undefined } = {}) =>
      request<Task[]>(`/tasks${qs(params)}`),
    get: (id: number) => request<Task>(`/tasks/${id}`),
    create: (body: Record<string, unknown>) =>
      request<Task>('/tasks', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Record<string, unknown>) =>
      request<Task>(`/tasks/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/tasks/${id}`, { method: 'DELETE' }),
    complete: (id: number) =>
      request<Task>(`/tasks/${id}/complete`, { method: 'POST' }),
    reopen: (id: number) =>
      request<Task>(`/tasks/${id}/reopen`, { method: 'POST' }),
    start: (id: number) => request<Task>(`/tasks/${id}/start`, { method: 'POST' }),
    cancel: (id: number) => request<Task>(`/tasks/${id}/cancel`, { method: 'POST' }),
    subtasks: (id: number) => request<Task[]>(`/tasks/${id}/subtasks`),
    getRecurring: (id: number) => request<RecurringRule>(`/tasks/${id}/recurring`),
    attachRecurring: (id: number, body: Record<string, unknown>) =>
      request<RecurringRule>(`/tasks/${id}/recurring`, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    updateRecurring: (id: number, body: Record<string, unknown>) =>
      request<RecurringRule>(`/tasks/${id}/recurring`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      }),
    detachRecurring: (id: number) =>
      request<void>(`/tasks/${id}/recurring`, { method: 'DELETE' }),
    timeLogs: (id: number) => request<TimeLog[]>(`/tasks/${id}/time-logs`),
    addTimeLog: (id: number, body: Record<string, unknown>) =>
      request<TimeLog>(`/tasks/${id}/time-logs`, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    removeTimeLog: (taskId: number, logId: number) =>
      request<void>(`/tasks/${taskId}/time-logs/${logId}`, { method: 'DELETE' }),
  },

  diary: {
    list: (params: { from?: string; to?: string } = {}) =>
      request<DiaryEntry[]>(`/diary${qs(params)}`),
    byDate: (day: string) => request<DiaryEntry>(`/diary/by-date/${day}`),
    create: (body: Record<string, unknown>) =>
      request<DiaryEntry>('/diary', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Record<string, unknown>) =>
      request<DiaryEntry>(`/diary/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/diary/${id}`, { method: 'DELETE' }),
    search: (q: string) => request<DiarySearchHit[]>(`/diary/search${qs({ q })}`),
  },

  patterns: {
    list: () => request<Pattern[]>('/patterns'),
    get: (id: number) => request<Pattern>(`/patterns/${id}`),
    create: (body: Record<string, unknown>) =>
      request<Pattern>('/patterns', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Record<string, unknown>) =>
      request<Pattern>(`/patterns/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/patterns/${id}`, { method: 'DELETE' }),
    addOption: (id: number, body: Record<string, unknown>) =>
      request<import('./types').PatternOption>(`/patterns/${id}/options`, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    addSchedule: (id: number, body: Record<string, unknown>) =>
      request<PatternSchedule>(`/patterns/${id}/schedules`, { method: 'POST', body: JSON.stringify(body) }),
    updateSchedule: (id: number, sid: number, body: Record<string, unknown>) =>
      request<PatternSchedule>(`/patterns/${id}/schedules/${sid}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      }),
    removeSchedule: (id: number, sid: number) =>
      request<void>(`/patterns/${id}/schedules/${sid}`, { method: 'DELETE' }),
    replaceSteps: (id: number, steps: unknown[]) =>
      request<PatternStep[]>(`/patterns/${id}/steps`, {
        method: 'PUT',
        body: JSON.stringify({ steps }),
      }),
    sessionToday: (id: number) => request<PatternSession>(`/patterns/${id}/sessions/today`),
    startSessionToday: (id: number) =>
      request<PatternSession>(`/patterns/${id}/sessions/today`, { method: 'POST' }),
    answerStep: (id: number, sessionId: number, stepId: number, body: Record<string, unknown>) =>
      request<PatternSession>(`/patterns/${id}/sessions/${sessionId}/steps/${stepId}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      }),
    completeSession: (id: number, sessionId: number) =>
      request<PatternSession>(`/patterns/${id}/sessions/${sessionId}/complete`, { method: 'POST' }),
    logs: (id: number, params: { limit?: number } = {}) =>
      request<import('./types').PatternLog[]>(`/patterns/${id}/logs${qs(params)}`),
    respond: (id: number, body: { response_option_id: number; scheduled_at?: string }) =>
      request<void>(`/patterns/${id}/responses`, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    streak: (id: number) => request<PatternStreakDetail>(`/patterns/${id}/streak`),
    today: (id: number) => request<PatternToday>(`/patterns/${id}/today`),
    insights: (id: number, days = 30, timeFilter = 'all') =>
      request<PatternInsights>(`/patterns/${id}/insights${qs({ days, time_filter: timeFilter })}`),
    markers: (id: number, limit = 50) =>
      request<PatternMarker[]>(`/patterns/${id}/markers${qs({ limit })}`),
    addMarker: (id: number, body: { marker_option_id: number; note?: string }) =>
      request<PatternMarker>(`/patterns/${id}/markers`, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    removeMarker: (id: number, markerId: number) =>
      request<void>(`/patterns/${id}/markers/${markerId}`, { method: 'DELETE' }),
    declareCleanDay: (id: number) =>
      request<void>(`/patterns/${id}/markers/declare-clean-day`, { method: 'POST' }),
    undeclareCleanDay: (id: number) =>
      request<void>(`/patterns/${id}/markers/declare-clean-day`, { method: 'DELETE' }),
    streaksAll: () => request<PatternStreak[]>('/patterns/streaks/all'),
  },

  calendar: {
    month: (year: number, month: number) =>
      request<CalendarDay[]>(`/calendar/${year}/${month}`),
    heatmap: (from: string, to: string) =>
      request<HeatmapPoint[]>(`/calendar/heatmap${qs({ from, to })}`),
  },

  stats: {
    meta: () => request<OlapMeta>('/stats/meta'),
    overview: (days = 30) => request<StatsOverview>(`/stats/overview${qs({ days })}`),
    olap: (body: Record<string, unknown>) =>
      request<OlapResult>('/stats/olap', { method: 'POST', body: JSON.stringify(body) }),
    topics: (params: { days?: number; from?: string; to?: string } = {}) =>
      request<TopicBreakdown[]>(`/stats/topics${qs(params)}`),
    priorities: (params: { days?: number; from?: string; to?: string } = {}) =>
      request<PriorityBreakdown[]>(`/stats/priorities${qs(params)}`),
    patterns: () => request<PatternStatsRow[]>('/stats/patterns'),
    timeDistribution: (params: { days?: number; from?: string; to?: string } = {}) =>
      request<TopicTimeBreakdown[]>(`/stats/time-distribution${qs(params)}`),
    correlation: (params: { days?: number; from?: string; to?: string } = {}) =>
      request<CorrelationWeek[]>(`/stats/correlation${qs(params)}`),
    holistic: (params: { days?: number; from?: string; to?: string } = {}) =>
      request<HolisticCorrelationWeek[]>(`/stats/holistic${qs(params)}`),
    weekly: (params: { days?: number; from?: string; to?: string; limit?: number } = {}) =>
      request<WeeklySummary[]>(`/stats/weekly${qs(params)}`),
    completionRate: (from: string, to: string, topic_id?: number) =>
      request<{ rate: number }>(`/stats/completion-rate${qs({ from, to, topic_id })}`),
  },

  goals: {
    list: () => request<Goal[]>('/goals'),
    get: (id: number) => request<Goal>(`/goals/${id}`),
    create: (body: Record<string, unknown>) =>
      request<Goal>('/goals', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Record<string, unknown>) =>
      request<Goal>(`/goals/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/goals/${id}`, { method: 'DELETE' }),
    addLink: (id: number, body: { target_type: string; target_id: number }) =>
      request(`/goals/${id}/links`, { method: 'POST', body: JSON.stringify(body) }),
    removeLink: (id: number, target_type: string, target_id: number) =>
      request<void>(
        `/goals/${id}/links${qs({ target_type, target_id })}`,
        { method: 'DELETE' },
      ),
    progress: (id: number) => request<GoalProgress>(`/goals/${id}/progress`),
  },

  recurringRules: {
    list: () => request<RecurringRuleSummary[]>('/recurring-rules'),
    get: (id: number) => request<RecurringRule>(`/recurring-rules/${id}`),
    update: (id: number, body: Record<string, unknown>) =>
      request<RecurringRule>(`/recurring-rules/${id}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      }),
    remove: (id: number) => request<void>(`/recurring-rules/${id}`, { method: 'DELETE' }),
  },

  importExport: {
    exportJson: () => request<ExportResponse>('/export/json'),
    importJson: (data: unknown, mode: 'merge' | 'restore' = 'merge') =>
      request<{ status: string; mode: string }>('/import/json', {
        method: 'POST',
        body: JSON.stringify({ data, mode }),
      }),
    exportTasksCsv: async () => {
      const res = await fetch(`${BASE}/export/csv/tasks`);
      if (!res.ok) throw new ApiError(res.statusText, res.status);
      return res.text();
    },
  },
};
