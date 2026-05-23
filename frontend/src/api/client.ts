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
  Pattern,
  PatternStreak,
  PatternStreakDetail,
  Tag,
  Task,
  TimeLog,
  Topic,
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
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const json = (await res.json()) as { detail?: string };
      detail = typeof json.detail === 'string' ? json.detail : JSON.stringify(json.detail);
    } catch {
      detail = (await res.text()) || detail;
    }
    throw new ApiError(detail, res.status);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
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
    list: (params: Record<string, string | number | boolean | undefined> = {}) =>
      request<Task[]>(`/tasks${qs(params)}`),
    get: (id: number) => request<Task>(`/tasks/${id}`),
    create: (body: Record<string, unknown>) =>
      request<Task>('/tasks', { method: 'POST', body: JSON.stringify(body) }),
    update: (id: number, body: Record<string, unknown>) =>
      request<Task>(`/tasks/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (id: number) => request<void>(`/tasks/${id}`, { method: 'DELETE' }),
    complete: (id: number) =>
      request<Task>(`/tasks/${id}/complete`, { method: 'POST' }),
    subtasks: (id: number) => request<Task[]>(`/tasks/${id}/subtasks`),
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
      request(`/patterns/${id}/options`, { method: 'POST', body: JSON.stringify(body) }),
    addSchedule: (id: number, body: Record<string, unknown>) =>
      request(`/patterns/${id}/schedules`, { method: 'POST', body: JSON.stringify(body) }),
    respond: (id: number, body: { response_option_id: number; scheduled_at?: string }) =>
      request<void>(`/patterns/${id}/responses`, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    streak: (id: number) => request<PatternStreakDetail>(`/patterns/${id}/streak`),
    streaksAll: () => request<PatternStreak[]>('/patterns/streaks/all'),
  },

  calendar: {
    month: (year: number, month: number) =>
      request<CalendarDay[]>(`/calendar/${year}/${month}`),
    heatmap: (from: string, to: string) =>
      request<HeatmapPoint[]>(`/calendar/heatmap${qs({ from, to })}`),
  },

  stats: {
    topics: () => request<TopicBreakdown[]>('/stats/topics'),
    timeDistribution: () => request<TopicTimeBreakdown[]>('/stats/time-distribution'),
    correlation: (params: { from?: string; to?: string } = {}) =>
      request<CorrelationWeek[]>(`/stats/correlation${qs(params)}`),
    weekly: (params: { from?: string; to?: string; limit?: number } = {}) =>
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

  importExport: {
    exportJson: () => request<ExportResponse>('/export/json'),
    importJson: (data: unknown) =>
      request('/import/json', { method: 'POST', body: JSON.stringify({ data }) }),
    exportTasksCsv: () => fetch(`${BASE}/export/csv/tasks`).then((r) => r.text()),
  },
};
