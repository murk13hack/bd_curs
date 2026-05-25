import { useState } from 'react';
import { Bell } from 'lucide-react';
import {
  isNotificationsEnabled,
  NOTIF_DEMO_KEY,
  notificationBody,
  setNotificationsEnabled,
} from '@/lib/pattern-notifications';

export function NotificationsSettings() {
  const [enabled, setEnabled] = useState(isNotificationsEnabled);
  const [demo, setDemo] = useState(() => {
    try {
      return localStorage.getItem(NOTIF_DEMO_KEY) === '1';
    } catch {
      return false;
    }
  });
  const [perm, setPerm] = useState(
    typeof window !== 'undefined' && 'Notification' in window
      ? Notification.permission
      : 'unsupported',
  );
  const [hint, setHint] = useState('');

  const toggleEnabled = (on: boolean) => {
    setNotificationsEnabled(on);
    setEnabled(on);
  };

  const toggleDemo = (on: boolean) => {
    localStorage.setItem(NOTIF_DEMO_KEY, on ? '1' : '0');
    setDemo(on);
    setHint(on ? 'Демо: напоминание каждые 90 с (перезагрузите страницу при первом включении)' : '');
  };

  const requestPermission = async () => {
    if (!('Notification' in window)) {
      setHint('Браузер не поддерживает уведомления');
      return;
    }
    const p = await Notification.requestPermission();
    setPerm(p);
    setHint(p === 'granted' ? 'Разрешение получено' : 'Уведомления заблокированы в браузере');
  };

  const sendTest = () => {
    if (!('Notification' in window)) {
      setHint('Браузер не поддерживает уведомления');
      return;
    }
    if (Notification.permission !== 'granted') {
      setHint('Сначала разрешите уведомления');
      void requestPermission();
      return;
    }
    new Notification('ПТТ · Тест', {
      body: notificationBody('habit'),
      tag: 'ptt-test',
    });
    setHint('Тестовое уведомление отправлено');
  };

  return (
    <section className="card">
      <div className="card-body space-y-4">
        <h2 className="flex items-center gap-2 font-semibold">
          <Bell size={18} /> Напоминания по паттернам
        </h2>
        <p className="text-xs text-ink-muted">
          Мок доставки: по расписанию из карточки паттерна (время и дни недели). Пока без
          серверного push — проверка в браузере и всплывающие карточки в приложении.
        </p>

        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => toggleEnabled(e.target.checked)}
          />
          Включить напоминания
        </label>

        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={demo} onChange={(e) => toggleDemo(e.target.checked)} />
          Демо-режим (каждые 90 с, для проверки)
        </label>

        <div className="flex flex-wrap gap-2">
          <button type="button" className="btn-secondary text-sm" onClick={() => void requestPermission()}>
            Разрешить в браузере
          </button>
          <button type="button" className="btn-primary text-sm" onClick={sendTest}>
            Тестовое уведомление
          </button>
        </div>

        <p className="text-xs text-ink-muted">
          Статус:{' '}
          {perm === 'unsupported'
            ? 'не поддерживается'
            : perm === 'granted'
              ? 'разрешено'
              : perm === 'denied'
                ? 'заблокировано'
                : 'не запрошено'}
        </p>
        {hint && <p className="text-xs text-accent">{hint}</p>}
      </div>
    </section>
  );
}
