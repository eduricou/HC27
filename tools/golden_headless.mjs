// Executa tools/golden_web.js dins d'Edge (o Chrome) en mode headless i desa
// el resultat a reference/golden/stats_web.json. Opcional: només fa falta Node
// (sense dependències) i un navegador Chromium instal·lat.
//
// Ús: node tools/golden_headless.mjs [N=50] [qlen=150] [sortida=reference/golden/stats_web.json]
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const n = Number(process.argv[2] ?? 50);
const qlen = Number(process.argv[3] ?? 150);
const port = 9333;

const browsers = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
];
const exe = browsers.find((p) => existsSync(p));
if (!exe) throw new Error('No trobo Edge ni Chrome');

const page = pathToFileURL(join(root, 'reference/web/index.html')).href;
const profile = mkdtempSync(join(tmpdir(), 'estic-golden-'));
const browser = spawn(exe, [
  '--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  '--mute-audio', '--no-first-run', '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding', page,
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function pageTarget() {
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const t = list.find((x) => x.type === 'page' && x.url.startsWith('file:'));
      if (t) return t;
    } catch { /* encara arrencant */ }
    await sleep(500);
  }
  throw new Error('El navegador no ha obert la pàgina');
}

let ws;
try {
  const target = await pageTarget();
  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

  let id = 0;
  const pending = new Map();
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.method === 'Runtime.consoleAPICalled') {
      const text = msg.params.args.map((a) => a.value ?? a.description ?? '').join(' ');
      if (text.startsWith('partit ')) process.stdout.write(`\r${text}        `);
    }
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  };
  const send = (method, params = {}) => new Promise((res) => {
    const mid = ++id; pending.set(mid, res); ws.send(JSON.stringify({ id: mid, method, params }));
  });
  const evaluate = async (expression) => {
    const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    if (r.result?.exceptionDetails) {
      throw new Error(r.result.exceptionDetails.exception?.description ?? r.result.exceptionDetails.text);
    }
    return r.result?.result?.value;
  };

  await send('Runtime.enable');
  for (let i = 0; !(await evaluate('!!window.__estic')); i++) {
    if (i > 60) throw new Error('La pàgina no exposa window.__estic');
    await sleep(500);
  }

  await evaluate(`window.__esticGoldenOpts = ${JSON.stringify({ n, qlen, download: false })}; true`);
  const out = await evaluate(readFileSync(join(root, 'tools/golden_web.js'), 'utf8'));
  process.stdout.write('\n');

  const dest = resolve(root, process.argv[4] ?? 'reference/golden/stats_web.json');
  writeFileSync(dest, JSON.stringify(out, null, 2) + '\n');
  console.log(`Desat a ${dest}`);
  console.log('Mitjanes per partit:', out.mean);
} finally {
  ws?.close();
  browser.kill();
}
