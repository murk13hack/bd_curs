#!/usr/bin/env bash
# Экспорт диаграмм курсовой в PNG (Fedora / Linux).
#
#   chmod +x scripts/render-diagrams-fedora.sh
#   ./scripts/render-diagrams-fedora.sh
#
# Опции:
#   --install-deps   установить пакеты Fedora через dnf (nodejs, chromium, plantuml…)
#   --bpmn-only      только BPMN (рис. 3–4)
#   --mermaid-only   только Mermaid (рис. 1, 2, 8)
#   --plantuml-only  только PlantUML (рис. 5–7), нужен пакет plantuml
#   --skip-npm       не вызывать npm install (уже установлено)
#
# Результат: docs/diagrams/png/*.png
# С разметкой BPMN (для Camunda): docs/diagrams/_laid/*.bpmn

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDER_DIR="$ROOT/scripts/diagrams-render"
DIAGRAMS="$ROOT/docs/diagrams"
OUT="$DIAGRAMS/png"

RUN_BPMN=1
RUN_MERMAID=1
RUN_PLANTUML=1
SKIP_NPM=0
INSTALL_DEPS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-deps) INSTALL_DEPS=1 ;;
    --bpmn-only) RUN_MERMAID=0; RUN_PLANTUML=0 ;;
    --mermaid-only) RUN_BPMN=0; RUN_PLANTUML=0 ;;
    --plantuml-only) RUN_BPMN=0; RUN_MERMAID=0 ;;
    --skip-npm) SKIP_NPM=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
  shift
done

# Публичный registry (если в .npmrc указан корпоративный зеркал с auth)
export NPM_CONFIG_REGISTRY="${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org/}"

install_fedora_deps() {
  if ! command -v dnf >/dev/null 2>&1; then
    echo "dnf не найден — установка пакетов ОС только для Fedora/RHEL." >&2
    exit 1
  fi
  echo "=== Установка пакетов Fedora (dnf) ==="
  local pkgs=(nodejs npm chromium)
  if [[ "$RUN_PLANTUML" -eq 1 ]]; then
    pkgs+=(plantuml graphviz)
  fi
  # Библиотеки для headless Chromium (Puppeteer)
  pkgs+=(
    alsa-lib atk at-spi2-atk cups-libs libdrm libXcomposite libXdamage
    libXrandr mesa-libgbm nss pango libxkbcommon
  )
  sudo dnf install -y "${pkgs[@]}"
  echo "Пакеты ОС установлены."
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    if [[ "$INSTALL_DEPS" -eq 1 ]]; then
      install_fedora_deps
      return 0
    fi
    echo "Не найдено: $1 — $2" >&2
    echo "Или запустите: $0 --install-deps" >&2
    exit 1
  fi
}

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  install_fedora_deps
fi

need_cmd node "sudo dnf install -y nodejs   # или: $0 --install-deps"
need_cmd npm "sudo dnf install -y npm"

# Chromium для Puppeteer (bpmn-to-image, mmdc)
if [[ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]]; then
  for c in /usr/bin/chromium-browser /usr/bin/chromium /usr/bin/google-chrome; do
    if [[ -x "$c" ]]; then
      export PUPPETEER_EXECUTABLE_PATH="$c"
      break
    fi
  done
fi
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="${PUPPETEER_SKIP_CHROMIUM_DOWNLOAD:-true}"

if [[ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]]; then
  echo "Предупреждение: Chromium не найден. Установите:" >&2
  echo "  sudo dnf install -y chromium" >&2
  echo "  export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser" >&2
  echo "Либо Puppeteer скачает Chromium при npm install (дольше, ~150 МБ)." >&2
fi

mkdir -p "$OUT" "$DIAGRAMS/_laid"

cd "$RENDER_DIR"

if [[ "$SKIP_NPM" -eq 0 ]]; then
  echo "=== npm install (scripts/diagrams-render) ==="
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
fi

if [[ "$RUN_BPMN" -eq 1 ]]; then
  echo ""
  echo "=== BPMN → PNG ==="
  npm run bpmn
fi

if [[ "$RUN_MERMAID" -eq 1 ]]; then
  echo ""
  echo "=== Mermaid → PNG ==="
  npm run mermaid
fi

if [[ "$RUN_PLANTUML" -eq 1 ]]; then
  echo ""
  echo "=== PlantUML → PNG ==="
  if ! command -v plantuml >/dev/null 2>&1; then
    echo "Пропуск PlantUML: пакет не установлен." >&2
    echo "  sudo dnf install -y plantuml graphviz" >&2
  else
    (cd "$DIAGRAMS" && plantuml -tpng -o png \
      05-state-task.puml \
      06-state-pattern-log.puml \
      07-activity-daily.puml)
    echo "PlantUML PNG в $OUT/"
  fi
fi

echo ""
echo "=== OLAP + Compose PNG (рис. 9, 14) — Pillow ==="
python3 "$ROOT/scripts/render_diagrams_pil.py" 2>/dev/null || python "$ROOT/scripts/render_diagrams_pil.py"

echo ""
echo "=== EXPLAIN → PNG (рис. 11–13) ==="
if command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/scripts/render_explain_png.py"
elif command -v python >/dev/null 2>&1; then
  python "$ROOT/scripts/render_explain_png.py"
else
  echo "Пропуск: нужен python3 для render_explain_png.py" >&2
fi

echo ""
echo "Готово. Файлы:"
ls -la "$OUT"/*.png 2>/dev/null || echo "(нет PNG — проверьте ошибки выше)"
