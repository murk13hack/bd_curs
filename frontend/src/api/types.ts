export type TaskStatus =
  | 'pending'
  | 'in_progress'
  | 'done'
  | 'overdue'
  | 'cancelled';

export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';
export type PatternType = 'positive' | 'negative';
export type PatternLogStatus = 'pending' | 'answered' | 'missed';
export type GoalLinkTarget = 'task' | 'pattern';

export interface Topic {
  id: number;
  name: string;
  color: string;
}

export interface Tag {
  id: number;
  name: string;
}

export interface Holiday {
  id: number;
  holiday_date: string;
  name: string;
  is_official: boolean;
}

export interface AppSetting {
  key: string;
  value: unknown;
}

export interface Task {
  id: number;
  topic_id: number;
  title: string;
  description: string | null;
  priority: TaskPriority;
  status: TaskStatus;
  deadline: string | null;
  planned_minutes: number | null;
  parent_task_id: number | null;
  completed_at: string | null;
  is_archived: boolean;
  recurring_rule_id: number | null;
  created_at: string;
  updated_at: string;
  tag_ids: number[];
}

export interface TimeLog {
  id: number;
  task_id: number;
  started_at: string;
  ended_at: string;
  duration_seconds: number;
  is_pomodoro: boolean;
  note: string | null;
}

export interface DiaryEntry {
  id: number;
  entry_date: string;
  content: string;
  mood: number | null;
  energy: number | null;
  created_at: string;
  updated_at: string;
  tag_ids: number[];
}

export interface DiarySearchHit {
  entry_id: number;
  entry_date: string;
  rank: number;
  snippet: string;
}

export interface PatternOption {
  id: number;
  label: string;
  is_success: boolean;
  sort_order: number;
}

export interface PatternSchedule {
  id: number;
  time_of_day: string;
  dow_mask: number;
  day_of_month: number | null;
}

export interface Pattern {
  id: number;
  title: string;
  description: string | null;
  pattern_type: PatternType;
  is_boolean: boolean;
  auto_create_task: boolean;
  topic_id: number | null;
  created_at: string;
  updated_at: string;
  options: PatternOption[];
  schedules: PatternSchedule[];
}

export interface PatternStreak {
  pattern_id: number;
  title: string;
  pattern_type: PatternType;
  current_streak: number;
  max_streak: number;
  anti_streak: number;
  logs_30d: number;
  success_rate_30d: number;
}

export interface PatternStreakDetail {
  current_streak: number;
  max_streak: number;
  anti_streak: number;
}

export interface CalendarDay {
  day: string;
  total: number;
  done: number;
  ratio: number;
  color: string;
  is_holiday: boolean;
  holiday_name: string | null;
  has_diary: boolean;
}

export interface HeatmapPoint {
  day: string;
  activity: number;
}

export interface TopicBreakdown {
  topic_id: number;
  topic_name: string;
  total: number;
  done: number;
  overdue: number;
  completion_rate: number;
  avg_planned_minutes: number | null;
  avg_overdue_minutes: number | null;
}

export interface TopicTimeBreakdown {
  topic_id: number;
  topic_name: string;
  minutes: number;
  pomodoro_minutes: number;
}

export interface WeeklySummary {
  week_start: string;
  tasks_total: number;
  tasks_done: number;
  tasks_overdue: number;
  minutes_logged: number;
  diary_entries: number;
}

export interface CorrelationWeek {
  week_start: string;
  avg_mood: number | null;
  avg_energy: number | null;
  avg_completion_rate: number | null;
  corr_mood_rate: number | null;
  corr_energy_rate: number | null;
  days_count: number;
}

export interface GoalLink {
  target_type: GoalLinkTarget;
  target_id: number;
}

export interface Goal {
  id: number;
  title: string;
  description: string | null;
  deadline: string | null;
  target_value: number;
  is_completed: boolean;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
  links: GoalLink[];
}

export interface GoalProgress {
  goal_id: number;
  progress: number;
}

export interface ExportPayload {
  schema_version: number;
  exported_at: string;
  topics: Array<{ name: string; color: string }>;
  tags: Array<{ name: string }>;
  [key: string]: unknown;
}

export interface ExportResponse {
  data: ExportPayload;
}
