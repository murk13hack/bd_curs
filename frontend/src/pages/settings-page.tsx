import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Download, Plus, Trash2, Upload } from 'lucide-react';
import { api } from '@/api/client';
import type { ThemeMode } from '@/hooks/use-theme';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { downloadJson, downloadText } from '@/lib/format';

export function SettingsPage() {
  const qc = useQueryClient();
  const [topicName, setTopicName] = useState('');
  const [tagName, setTagName] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const settings = useQuery({ queryKey: ['settings'], queryFn: api.settings.list });
  const topics = useQuery({ queryKey: ['topics'], queryFn: api.topics.list });
  const tags = useQuery({ queryKey: ['tags'], queryFn: api.tags.list });
  const holidays = useQuery({
    queryKey: ['holidays', 2026],
    queryFn: () => api.holidays.list(2026),
  });

  const theme =
    (settings.data?.find((s) => s.key === 'theme')?.value as ThemeMode | undefined) ?? 'system';
  const pomodoroMinutes = Number(settings.data?.find((s) => s.key === 'pomodoro_minutes')?.value ?? 25);

  const saveSetting = useMutation({
    mutationFn: ({ key, value }: { key: string; value: unknown }) => api.settings.upsert(key, value),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['settings'] }),
  });

  const addTopic = useMutation({
    mutationFn: () => api.topics.create({ name: topicName }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['topics'] });
      setTopicName('');
    },
    onError: (e: Error) => setError(e.message),
  });

  const addTag = useMutation({
    mutationFn: () => api.tags.create({ name: tagName }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['tags'] });
      setTagName('');
    },
    onError: (e: Error) => setError(e.message),
  });

  const deleteTopic = useMutation({
    mutationFn: (id: number) => api.topics.remove(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['topics'] }),
    onError: (e: Error) => setError(e.message),
  });

  const deleteTag = useMutation({
    mutationFn: (id: number) => api.tags.remove(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tags'] }),
  });

  const exportJson = useMutation({
    mutationFn: api.importExport.exportJson,
    onSuccess: (data) => {
      downloadJson(`ptt-export-${Date.now()}.json`, data);
      setMessage('JSON экспортирован');
    },
  });

  const exportCsv = useMutation({
    mutationFn: api.importExport.exportTasksCsv,
    onSuccess: (csv) => {
      downloadText(`ptt-tasks-${Date.now()}.csv`, csv, 'text/csv');
      setMessage('CSV экспортирован');
    },
  });

  const importJson = useMutation({
    mutationFn: (file: File) =>
      file.text().then((text) => {
        const parsed = JSON.parse(text) as { data?: unknown };
        return api.importExport.importJson(parsed.data ?? parsed);
      }),
    onSuccess: () => {
      setMessage('Импорт выполнен');
      qc.invalidateQueries();
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <div>
      <PageHeader title="Настройки" subtitle="Тема, справочники, импорт и экспорт" />

      {error && <div className="mb-4"><ErrorBanner message={error} /></div>}
      {message && (
        <div className="mb-4 rounded-lg border border-green-500/30 bg-accent-soft px-4 py-3 text-sm">
          {message}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="card">
          <div className="card-body space-y-4">
            <h2 className="font-semibold">Оформление</h2>
            <label className="block text-sm">
              <span className="mb-1 block text-ink-muted">Тема</span>
              <select
                className="select"
                value={theme}
                onChange={(e) =>
                  saveSetting.mutate({ key: 'theme', value: e.target.value })
                }
              >
                <option value="system">Системная</option>
                <option value="light">Светлая</option>
                <option value="dark">Тёмная</option>
              </select>
            </label>
            <label className="block text-sm">
              <span className="mb-1 block text-ink-muted">Pomodoro (мин)</span>
              <input
                type="number"
                className="input"
                min={5}
                max={120}
                value={pomodoroMinutes}
                onChange={(e) =>
                  saveSetting.mutate({
                    key: 'pomodoro_minutes',
                    value: Number(e.target.value),
                  })
                }
              />
            </label>
          </div>
        </section>

        <section className="card">
          <div className="card-body space-y-4">
            <h2 className="font-semibold">Импорт / экспорт</h2>
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                className="btn-secondary"
                disabled={exportJson.isPending}
                onClick={() => exportJson.mutate()}
              >
                <Download size={16} /> JSON
              </button>
              <button
                type="button"
                className="btn-secondary"
                disabled={exportCsv.isPending}
                onClick={() => exportCsv.mutate()}
              >
                <Download size={16} /> CSV задачи
              </button>
              <label className="btn-secondary cursor-pointer">
                <Upload size={16} /> Импорт JSON
                <input
                  type="file"
                  accept="application/json,.json"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) importJson.mutate(f);
                  }}
                />
              </label>
            </div>
          </div>
        </section>

        <section className="card">
          <div className="card-body space-y-3">
            <h2 className="font-semibold">Темы</h2>
            <div className="flex gap-2">
              <input
                className="input"
                placeholder="Новая тема"
                value={topicName}
                onChange={(e) => setTopicName(e.target.value)}
              />
              <button
                type="button"
                className="btn-primary shrink-0"
                disabled={!topicName.trim()}
                onClick={() => addTopic.mutate()}
              >
                <Plus size={16} />
              </button>
            </div>
            <ul className="space-y-1">
              {(topics.data ?? []).map((t) => (
                <li key={t.id} className="flex items-center justify-between rounded-lg border border-border px-3 py-2 text-sm">
                  <span className="flex items-center gap-2">
                    <span className="h-3 w-3 rounded-full" style={{ backgroundColor: t.color }} />
                    {t.name}
                  </span>
                  <button type="button" className="btn-ghost px-2" onClick={() => deleteTopic.mutate(t.id)}>
                    <Trash2 size={14} />
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className="card">
          <div className="card-body space-y-3">
            <h2 className="font-semibold">Теги</h2>
            <div className="flex gap-2">
              <input
                className="input"
                placeholder="Новый тег"
                value={tagName}
                onChange={(e) => setTagName(e.target.value)}
              />
              <button
                type="button"
                className="btn-primary shrink-0"
                disabled={!tagName.trim()}
                onClick={() => addTag.mutate()}
              >
                <Plus size={16} />
              </button>
            </div>
            <ul className="flex flex-wrap gap-2">
              {(tags.data ?? []).map((t) => (
                <li key={t.id} className="flex items-center gap-1 rounded-full border border-border px-3 py-1 text-sm">
                  {t.name}
                  <button type="button" className="btn-ghost px-1 py-0" onClick={() => deleteTag.mutate(t.id)}>
                    <Trash2 size={12} />
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className="card lg:col-span-2">
          <div className="card-body">
            <h2 className="mb-3 font-semibold">Праздники 2026</h2>
            {holidays.isLoading ? (
              <Spinner />
            ) : (
              <div className="flex flex-wrap gap-2">
                {(holidays.data ?? []).map((h) => (
                  <span key={h.id} className="badge bg-red-500/10 text-red-700 dark:text-red-300">
                    {h.holiday_date.slice(5)} — {h.name}
                  </span>
                ))}
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
