import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AppLayout } from '@/components/layout/app-layout';
import { PomodoroProvider } from '@/context/pomodoro-context';
import { CalendarPage } from '@/pages/calendar-page';
import { DashboardPage } from '@/pages/dashboard-page';
import { DiaryPage } from '@/pages/diary-page';
import { GoalsPage } from '@/pages/goals-page';
import { PatternsPage } from '@/pages/patterns-page';
import { PomodoroPage } from '@/pages/pomodoro-page';
import { SettingsPage } from '@/pages/settings-page';
import { StatsPage } from '@/pages/stats-page';
import { TasksPage } from '@/pages/tasks-page';

export default function App() {
  return (
    <BrowserRouter>
      <PomodoroProvider>
        <Routes>
          <Route element={<AppLayout />}>
            <Route index element={<DashboardPage />} />
            <Route path="tasks" element={<TasksPage />} />
            <Route path="diary" element={<DiaryPage />} />
            <Route path="patterns" element={<PatternsPage />} />
            <Route path="calendar" element={<CalendarPage />} />
            <Route path="stats" element={<StatsPage />} />
            <Route path="goals" element={<GoalsPage />} />
            <Route path="pomodoro" element={<PomodoroPage />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </PomodoroProvider>
    </BrowserRouter>
  );
}
