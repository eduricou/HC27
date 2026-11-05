// Captures de la versió web des dels angles fixos de tools/views.json, per comparar-les
// amb les de Godot (bash tools/shot.sh view <angle> <tarda|nit>). Fa servir Edge o Chrome
// en mode headless, sense dependències.
//
// Ús: node tools/shot_web.mjs [angles=tots, separats per comes] [hores=tarda,nit]
// Resultat: build/shots/web/<angle>_<hora>.png (1920x1080, sense HUD)
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const allViews = JSON.parse(readFileSync(join(root, 'tools/views.json'), 'utf8'));
delete allViews._doc;
const names = (process.argv[2] && process.argv[2] !== 'tots') ? process.argv[2].split(',') : Object.keys(allViews);
const times = (process.argv[3] ?? 'tarda,nit').split(',');
for (const n of names) if (!allViews[n]) throw new Error(`Angle desconegut: ${n}`);
const port = 9334;
const outDir = join(root, 'build/shots/web');
mkdirSync(outDir, { recursive: true });

const browsers = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
];
const exe = browsers.find((p) => existsSync(p));
if (!exe) throw new Error('No trobo Edge ni Chrome');

const page = pathToFileURL(join(root, 'reference/web/index.html')).href;
const profile = mkdtempSync(join(tmpdir(), 'estic-shot-'));
const browser = spawn(exe, [
  '--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  '--window-size=1920,1080', '--mute-audio', '--no-first-run', '--enable-unsafe-swiftshader',
  '--disable-background-timer-throttling', '--disable-renderer-backgrounding', page,
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

  await send('Emulation.setDeviceMetricsOverride', { width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false });
  for (let i = 0; !(await evaluate('!!window.__estic')); i++) {
    if (i > 60) throw new Error('La pàgina no exposa window.__estic');
    await sleep(500);
  }
  const frames = 'new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(r))))';
  for (const time of times) {
    // Partit CPU contra CPU, 25 s de joc, i en pausa: el bucle continua dibuixant però ja no
    // mou la càmera (updateCamera() només corre dins d'update()).
    await evaluate(`(() => {
      const E = window.__estic;
      Object.assign(E.OPTS, { side: -1, diff: 'normal', qlen: 150, time: ${JSON.stringify(time)} });
      E.startMatch();
      E.simulate(25);
      E.G.paused = true;
      document.querySelectorAll('.hud, #banner, #intro, #lbox, #wipe, #menu, #pause, #brk, #touch')
        .forEach((e) => { e.style.visibility = 'hidden'; });
      return true;
    })()`);
    for (const name of names) {
      await evaluate(`Object.assign(window.__estic.CAM, ${JSON.stringify(allViews[name])}); ${frames}`);
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      const file = join(outDir, `${name}_${time}.png`);
      writeFileSync(file, Buffer.from(shot.result.data, 'base64'));
      console.log(`Captura: ${file}`);
    }
  }
} finally {
  ws?.close();
  browser.kill();
}
