import { useCallback, useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { api } from '@/api/client';
import {
  collectDueNotifications,
  isNotificationsEnabled,
  markFiredToday,
  notificationBody,
  NOTIF_DEMO_KEY,
  type PatternNotificationPayload,
} from '@/lib/pattern-notifications';

const POLL_MS = 15_000;

async function showBrowserNotification(payload: PatternNotificationPayload): Promise<void> {
  if (!('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;
  const n = new Notification(`ПТТ · ${payload.patternTitle}`, {
    body: notificationBody(payload.patternMode),
    tag: payload.id,
    icon: '/favicon.ico',
  });
  n.onclick = () => {
    window.focus();
    n.close();
  };
}

export function usePatternNotifications() {
  const navigate = useNavigate();
  const [toasts, setToasts] = useState<PatternNotificationPayload[]>([]);
  const patterns = useQuery({
    queryKey: ['patterns'],
    queryFn: api.patterns.list,
    refetchInterval: 60_000,
  });

  const dispatch = useCallback(
    (items: PatternNotificationPayload[]) => {
      const day = new Date().toISOString().slice(0, 10);
      for (const item of items) {
        markFiredToday(item.patternId, item.scheduleId, day);
        void showBrowserNotification(item);
      }
      if (items.length) {
        setToasts((prev) => {
          const ids = new Set(prev.map((t) => t.id));
          return [...prev, ...items.filter((i) => !ids.has(i.id))].slice(-5);
        });
      }
    },
    [],
  );

  const tick = useCallback(() => {
    if (!isNotificationsEnabled()) return;
    const list = patterns.data ?? [];
    if (!list.length) return;
    dispatch(collectDueNotifications(list));
  }, [patterns.data, dispatch]);

  useEffect(() => {
    tick();
    const id = window.setInterval(tick, POLL_MS);
    return () => window.clearInterval(id);
  }, [tick]);

  useEffect(() => {
    try {
      if (localStorage.getItem(NOTIF_DEMO_KEY) !== '1') return;
    } catch {
      return;
    }
    const run = () => {
      const p = patterns.data?.find((x) => x.schedules.length > 0);
      if (!p) return;
      const sch = p.schedules[0];
      const day = new Date().toISOString().slice(0, 10);
      dispatch([
        {
          id: `demo-${Date.now()}`,
          patternId: p.id,
          scheduleId: sch.id,
          patternTitle: p.title,
          patternMode: p.pattern_mode,
          scheduleTime: sch.time_of_day.slice(0, 5),
        },
      ]);
    };
    run();
    const id = window.setInterval(run, 90_000);
    return () => window.clearInterval(id);
  }, [patterns.data, dispatch]);

  const dismissToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const openPattern = (payload: PatternNotificationPayload) => {
    dismissToast(payload.id);
    navigate('/patterns');
  };

  const requestPermission = async (): Promise<NotificationPermission | 'unsupported'> => {
    if (!('Notification' in window)) return 'unsupported';
    if (Notification.permission === 'granted') return 'granted';
    return Notification.requestPermission();
  };

  const sendTestNotification = (title = 'Тестовое напоминание') => {
    const payload: PatternNotificationPayload = {
      id: `test-${Date.now()}`,
      patternId: 0,
      scheduleId: 0,
      patternTitle: title,
      patternMode: 'habit',
      scheduleTime: new Date().toTimeString().slice(0, 5),
    };
    void showBrowserNotification(payload);
    setToasts((prev) => [...prev, payload].slice(-5));
  };

  return {
    toasts,
    dismissToast,
    openPattern,
    requestPermission,
    sendTestNotification,
    permission:
      typeof window !== 'undefined' && 'Notification' in window
        ? Notification.permission
        : ('unsupported' as const),
    enabled: isNotificationsEnabled(),
  };
}
