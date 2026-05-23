import { useQuery } from '@tanstack/react-query';

const API_URL: string = import.meta.env.VITE_API_URL || '/api/v1';

interface PingResponse {
  pong: boolean;
}

async function fetchPing(): Promise<PingResponse> {
  const r = await fetch(`${API_URL}/ping`);
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return (await r.json()) as PingResponse;
}

export default function App() {
  const { data, error, isLoading } = useQuery({
    queryKey: ['ping'],
    queryFn: fetchPing,
  });

  return (
    <main className="app">
      <header>
        <h1>ПТТ — Персональный таск-трекер</h1>
        <p className="subtitle">Курсовая работа по дисциплине «Базы данных»</p>
      </header>

      <section className="card">
        <h2>Статус подключения к API</h2>
        <p>
          <code>API_URL</code> = <code>{API_URL}</code>
        </p>
        {isLoading && <p>Проверяю соединение…</p>}
        {error && (
          <p className="error">
            Ошибка: {(error as Error).message}. Убедитесь, что бэкенд запущен.
          </p>
        )}
        {data && (
          <p className="ok">
            Бэкенд отвечает: <code>{JSON.stringify(data)}</code>
          </p>
        )}
      </section>

      <footer>
        <a href="/docs" target="_blank" rel="noreferrer">
          Документация API (Swagger)
        </a>
        <span> · </span>
        <a href="/redoc" target="_blank" rel="noreferrer">
          ReDoc
        </a>
      </footer>
    </main>
  );
}
