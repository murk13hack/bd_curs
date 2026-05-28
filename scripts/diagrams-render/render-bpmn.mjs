/**
 * BPMN → PNG: bpmn-auto-layout (добавляет BPMNDI) + bpmn-to-image (Puppeteer).
 * Исходники без координат в .bpmn не рисуются в Camunda/draw.io — это нормально.
 */
import { readFile, writeFile, mkdir, unlink } from 'fs/promises';
import { existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';
import { layoutProcess } from 'bpmn-auto-layout';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..', '..');
const diagramsDir = join(root, 'docs', 'diagrams');
const outDir = join(diagramsDir, 'png');
const laidDir = join(diagramsDir, '_laid');

const jobs = [
  ['03-bpmn-complete-task.bpmn', '03-bpmn-complete-task.png'],
  ['04-bpmn-pattern-habit.bpmn', '04-bpmn-pattern-habit.png'],
];

function run(bin, args, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(bin, args, {
      stdio: 'inherit',
      env: { ...process.env, ...env },
      shell: false,
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${bin} exited with code ${code}`));
    });
  });
}

function resolveChromium() {
  if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    return process.env.PUPPETEER_EXECUTABLE_PATH;
  }
  for (const name of ['chromium-browser', 'chromium', 'google-chrome', 'google-chrome-stable']) {
    for (const dir of ['/usr/bin', '/usr/local/bin']) {
      const p = join(dir, name);
      if (existsSync(p)) return p;
    }
  }
  return null;
}

const bpmnToImageBin = join(__dirname, 'node_modules', '.bin', 'bpmn-to-image');
if (!existsSync(bpmnToImageBin)) {
  console.error('Не найден bpmn-to-image. Выполните: npm install (в каталоге scripts/diagrams-render)');
  process.exit(1);
}

const chromium = resolveChromium();
const puppeteerEnv = {
  PUPPETEER_SKIP_CHROMIUM_DOWNLOAD: process.env.PUPPETEER_SKIP_CHROMIUM_DOWNLOAD ?? 'true',
};
if (chromium) {
  puppeteerEnv.PUPPETEER_EXECUTABLE_PATH = chromium;
  console.log(`Chromium: ${chromium}`);
} else {
  console.warn(
    'Системный Chromium не найден — Puppeteer скачает свой (нужен интернет). ' +
      'На Fedora: sudo dnf install -y chromium && export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser',
  );
}

await mkdir(outDir, { recursive: true });
await mkdir(laidDir, { recursive: true });

for (const [bpmnName, pngName] of jobs) {
  const bpmnPath = join(diagramsDir, bpmnName);
  const xml = await readFile(bpmnPath, 'utf8');

  console.log(`\n=== ${bpmnName} ===`);
  console.log('  layout (bpmn-auto-layout)…');
  const laidOut = await layoutProcess(xml);
  const laidPath = join(laidDir, bpmnName);
  await writeFile(laidPath, laidOut, 'utf8');

  const pngPath = join(outDir, pngName);
  console.log(`  render → ${pngPath}`);
  await run(
    bpmnToImageBin,
    ['--no-footer', '--no-title', '--scale', '1.25', '--min-dimensions=900x400', `${laidPath}:${pngPath}`],
    puppeteerEnv,
  );
  console.log(`  OK (${pngName})`);
}

console.log('\nBPMN PNG готовы в docs/diagrams/png/');
