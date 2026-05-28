/**
 * Mermaid .mmd → PNG через @mermaid-js/mermaid-cli (mmdc).
 */
import { existsSync } from 'fs';
import { mkdir } from 'fs/promises';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..', '..');
const diagramsDir = join(root, 'docs', 'diagrams');
const outDir = join(diagramsDir, 'png');

const jobs = [
  ['01-er-full.mmd', '01-er-full.png'],
  ['02-architecture.mmd', '02-architecture.png'],
  ['08-sequence-calendar.mmd', '08-sequence-calendar.png'],
];

function run(bin, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(bin, args, { stdio: 'inherit', env: process.env });
    child.on('error', reject);
    child.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`exit ${code}`))));
  });
}

const mmdc = join(__dirname, 'node_modules', '.bin', 'mmdc');
if (!existsSync(mmdc)) {
  console.error('Не найден mmdc. Выполните: npm install');
  process.exit(1);
}

await mkdir(outDir, { recursive: true });

for (const [mmd, png] of jobs) {
  const input = join(diagramsDir, mmd);
  const output = join(outDir, png);
  if (!existsSync(input)) {
    console.warn(`Пропуск (нет файла): ${mmd}`);
    continue;
  }
  console.log(`\n=== ${mmd} → ${png} ===`);
  await run(mmdc, [
    '-i',
    input,
    '-o',
    output,
    '-b',
    'white',
    '-w',
    '2200',
    '-H',
    '1400',
    '--scale',
    '2',
  ]);
}

console.log('\nMermaid PNG готовы в docs/diagrams/png/');
