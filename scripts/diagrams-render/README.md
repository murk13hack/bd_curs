# Экспорт диаграмм в PNG (Fedora)

Исходные `.bpmn` в репозитории **без координат BPMNDI** — Camunda Modeler и draw.io показывают пустой холст. Скрипт сначала строит разметку (`bpmn-auto-layout`), затем рендерит PNG (`bpmn-to-image` + Chromium).

## Быстрый старт

```bash
cd /path/to/bd_curs
chmod +x scripts/render-diagrams-fedora.sh
# один раз: пакеты ОС (nodejs, chromium, plantuml…) + рендер
./scripts/render-diagrams-fedora.sh --install-deps
```

Без `--install-deps` скрипт **не** вызывает `dnf` — только проверяет, что `node`/`npm` уже есть, и ставит npm-зависимости в `scripts/diagrams-render/`.

Результат:

| Файл PNG | Исходник | Рисунок в записке |
|----------|----------|-------------------|
| `03-bpmn-complete-task.png` | `03-bpmn-complete-task.bpmn` | 3 |
| `04-bpmn-pattern-habit.png` | `04-bpmn-pattern-habit.bpmn` | 4 |
| `01-er-full.png` | `01-er-full.mmd` | 1 |
| `02-architecture.png` | `02-architecture.mmd` | 2 |
| `08-sequence-calendar.png` | `08-sequence-calendar.mmd` | 8 |
| `05-state-task.png` | `05-state-task.puml` | 5 |
| `06-state-pattern-log.png` | `06-state-pattern-log.puml` | 6 |
| `07-activity-daily.png` | `07-activity-daily.puml` | 7 |

Каталог вывода: `docs/diagrams/png/`.  
BPMN с разметкой (для Camunda): `docs/diagrams/_laid/`.

## Зависимости Fedora

```bash
sudo dnf install -y nodejs npm chromium plantuml graphviz
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

При ошибках Puppeteer («shared library») дополнительно:

```bash
sudo dnf install -y \
  alsa-lib atk at-spi2-atk cups-libs libdrm libXcomposite libXdamage \
  libXrandr mesa-libgbm nss pango libxkbcommon
```

## Опции

```bash
./scripts/render-diagrams-fedora.sh --bpmn-only
./scripts/render-diagrams-fedora.sh --mermaid-only
./scripts/render-diagrams-fedora.sh --plantuml-only
./scripts/render-diagrams-fedora.sh --skip-npm   # после первого npm install
```

## Только Node (без обёртки)

```bash
cd scripts/diagrams-render
export NPM_CONFIG_REGISTRY=https://registry.npmjs.org/
npm install
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
npm run all
```

## Корпоративный npm (Windows / зеркало)

Если `npm install` падает с E401, явно укажите публичный registry:

```bash
export NPM_CONFIG_REGISTRY=https://registry.npmjs.org/
npm install
```

## Вставка в Word

Скопируйте PNG из `docs/diagrams/png/` в `KURSOVAYA_BD.docx` по [KURSOVAYA_INSERT_CHECKLIST.md](../../docs/KURSOVAYA_INSERT_CHECKLIST.md).
