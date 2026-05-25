export type TaskStatus =
  | 'pending'
  | 'in_progress'
  | 'done'
  | 'overdue'
  | 'cancelled';

export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';
export type PatternType = 'positive' | 'negative';
export type PatternMode = 'habit' | 'scenario' | 'markers';
export type PatternStepKind = 'check' | 'single_choice' | 'note';
export type PatternStepRole = 'context' | 'trigger' | 'choice' | 'action' | 'outcome';
export type PatternSessionStatus = 'in_progress' | 'completed' | 'abandoned';
export type PatternLogStatus = 'pending' | 'answered' | 'missed';

export interface PatternLog {
  id: number;
  pattern_id: number;
  response_option_id: number | null;
  scheduled_at: string;
  answered_at: string | null;
  status: PatternLogStatus;
}
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
  start_at: string | null;
  planned_minutes: number | null;
  parent_task_id: number | null;
  completed_at: string | null;
  is_archived: boolean;
  recurring_rule_id: number | null;
  created_at: string;
  updated_at: string;
  tag_ids: number[];
  subtask_total?: number | null;
  subtask_done?: number | null;
  subtask_progress?: number | null;
}

export interface RecurringRule {
  id: number;
  frequency: 'daily' | 'weekly' | 'monthly' | 'custom';
  params: Record<string, unknown>;
  is_active: boolean;
  next_run_at: string | null;
  created_at: string;
}

export interface RecurringRuleSummary extends RecurringRule {
  task_count: number;
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

export interface PatternStepChoice {
  id: string;
  label: string;
  is_success?: boolean;
}

export interface PatternStep {
  id: number;
  pattern_id: number;
  sort_order: number;
  title: string;
  hint: string | null;
  step_kind: PatternStepKind;
  step_role: PatternStepRole;
  is_required: boolean;
  marks_success: boolean;
  choices: PatternStepChoice[];
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
  pattern_mode: PatternMode;
  guide_intro: string | null;
  is_boolean: boolean;
  auto_create_task: boolean;
  topic_id: number | null;
  created_at: string;
  updated_at: string;
  options: PatternOption[];
  schedules: PatternSchedule[];
  steps: PatternStep[];
}

export interface PatternStreak {
  pattern_id: number;
  title: string;
  pattern_type: PatternType;
  pattern_mode: PatternMode;
  current_streak: number;
  max_streak: number;
  anti_streak: number;
  scheduled_days_30d: number;
  success_days_30d: number;
  clean_rate_30d: number;
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
  avg_mood: number | null;
  avg_energy: number | null;
  patterns_scheduled: number;
  patterns_success: number;
  marker_events: number;
  marker_bad_events: number;
}

export interface StatsOverview {
  days: number;
  date_from: string;
  date_to: string;
  tasks_total: number;
  tasks_done: number;
  tasks_overdue: number;
  task_completion_rate: number;
  minutes_logged: number;
  pomodoro_minutes: number;
  diary_entries: number;
  avg_mood: number | null;
  avg_energy: number | null;
  patterns_scheduled: number;
  patterns_success: number;
  pattern_clean_rate: number;
  marker_events: number;
  marker_bad_events: number;
  activity_score: number;
  active_days: number;
}

export interface HolisticCorrelationWeek {
  week_start: string;
  avg_mood: number | null;
  avg_energy: number | null;
  avg_task_rate: number | null;
  avg_pattern_clean_rate: number | null;
  avg_minutes: number | null;
  corr_mood_tasks: number | null;
  corr_mood_patterns: number | null;
  corr_energy_tasks: number | null;
  days_count: number;
}

export interface PriorityBreakdown {
  priority: string;
  total: number;
  done: number;
  overdue: number;
  completion_rate: number;
}

export interface PatternStatsRow {
  pattern_id: number;
  title: string;
  pattern_type: string;
  pattern_mode: string;
  current_streak: number;
  max_streak: number;
  scheduled_days_30d: number;
  success_days_30d: number;
  clean_rate_30d: number;
}

export interface OlapMetaItem {
  id: string;
  label: string;
  hint?: string | null;
  max_period_days?: number | null;
  unit?: string | null;
}

export interface OlapMeta {
  dimensions: OlapMetaItem[];
  measures: OlapMetaItem[];
  help?: string;
}

export interface OlapRow {
  dimensions: Record<string, string | number | null>;
  measures: Record<string, number | null>;
}

export interface OlapResult {
  date_from: string;
  date_to: string;
  dimensions: string[];
  measures: string[];
  rows: OlapRow[];
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

export interface MoodBucketStat {
  bucket: string;
  label: string;
  days: number;
  avg_task_rate: number | null;
  avg_pattern_rate: number | null;
}

export interface DiaryScatterDay {
  day: string;
  mood: number;
  energy: number | null;
  task_rate: number | null;
  pattern_rate: number | null;
}

export interface DiaryInsights {
  date_from: string;
  date_to: string;
  diary_days: number;
  corr_mood_tasks: number | null;
  corr_mood_patterns: number | null;
  corr_energy_tasks: number | null;
  corr_mood_energy: number | null;
  corr_mood_tasks_same_day: number | null;
  same_day_diary_task_days: number;
  mood_buckets: MoodBucketStat[];
  insights: string[];
  scatter_days: DiaryScatterDay[];
  weeks: HolisticCorrelationWeek[];
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
  done_units: number;
  target_value: number;
  remaining_units: number;
  links: GoalLinkDetail[];
}

export interface GoalLinkDetail {
  target_type: GoalLinkTarget;
  target_id: number;
  title: string;
  contributed: boolean;
  detail: string | null;
}

export interface PatternToday {
  pattern_id: number;
  day: string;
  is_scheduled_today: boolean;
  status: string;
  can_respond: boolean;
  response_option_id: number | null;
  response_label: string | null;
  is_success_today: boolean | null;
  log_status: string | null;
  markers_today_count?: number;
  last_marker_label?: string | null;
  last_marker_at?: string | null;
  day_declared_clean?: boolean;
}

export interface PatternSession {
  id: number;
  pattern_id: number;
  session_date: string;
  status: PatternSessionStatus;
  outcome_success: boolean | null;
  started_at: string;
  completed_at: string | null;
  answers: Array<{
    step_id: number;
    choice_id: string | null;
    checked: boolean | null;
    note_text: string | null;
    answered_at: string;
  }>;
  answered_count: number;
  required_count: number;
}

export type PatternDayStatus =
  | 'success'
  | 'failure'
  | 'missed'
  | 'pending'
  | 'not_scheduled'
  | 'in_progress';

export interface PatternDayCell {
  day: string;
  status: PatternDayStatus;
}

export interface PatternChoiceStat {
  step_id: number;
  step_title: string;
  choice_id: string;
  label: string;
  count: number;
  pct: number;
  is_success: boolean | null;
}

export interface PatternPathStat {
  path: string;
  count: number;
  pct: number;
  is_success: boolean;
}

export interface PatternInsights {
  pattern_id: number;
  days: number;
  time_filter: string;
  scheduled_days: number;
  success_days: number;
  clean_rate: number;
  calendar: PatternDayCell[];
  choice_breakdown: PatternChoiceStat[];
  top_paths: PatternPathStat[];
  hourly_counts: PatternHourStat[];
  time_of_day_stats: PatternTimeBucketStat[];
  diary_correlation: PatternDiaryCorrelation | null;
  insights: string[];
}

export interface PatternHourStat {
  hour: number;
  count: number;
  bad_count: number;
}

export interface PatternTimeBucketStat {
  bucket: string;
  label: string;
  total_events: number;
  failure_count: number;
  failure_pct: number;
}

export interface PatternDiaryMoodBucket {
  mood_range: string;
  label: string;
  days: number;
  clean_days: number;
  clean_rate: number;
  avg_energy: number | null;
}

export interface PatternDiaryCorrelation {
  mood_buckets: PatternDiaryMoodBucket[];
  corr_mood_clean: number | null;
  insight: string | null;
}

export interface PatternMarker {
  id: number;
  pattern_id: number;
  marker_option_id: number;
  label: string;
  is_success: boolean;
  occurred_at: string;
  note: string | null;
}

export type TaskView = 'active' | 'completed' | 'all';

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
