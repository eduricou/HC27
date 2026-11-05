// Oracle de la simulació web: executa el codi original de reference/web/index.html
// (constants → repetició, línies 289–1051) amb Node, sense DOM, i en desa valors de
// referència perquè les proves de Godot comparin el port pas a pas.
//
// L'atzar (Math.random) es substitueix per mulberry32 amb llavor, el mateix generador
// que src/sim/sim_rng.gd. Math.hypot es substitueix per sqrt(x² + y²), la fórmula que
// fa servir el port; la diferència només és d'arrodoniment a l'últim bit.
//
// Ús: node tools/oracle_web.mjs   → tests/fixtures/web_oracle.json
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const lines = readFileSync(join(root, 'reference/web/index.html'), 'utf8').split('\n');
const start = lines.findIndex((l) => l.includes('/* =================== constants'));
const end = lines.findIndex((l) => l.includes('/* =================== audio'));
if (start < 0 || end < 0) throw new Error('No trobo els límits de la simulació a la referència');
const simSrc = lines.slice(start, end).join('\n');

export function mulberry32(seed) {
  let a = seed | 0;
  return function () {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Substituts de tot el que és presentació (so, rètols, càmera, HUD, partícules).
const STUBS = `
const SFX={hit(){},whistle(){},crowd(){},tick(){},init(){}};
const input={mv:{x:0,y:0},sprint:false,shootHeld:false,passE:false,shootE:false,shootUpE:false,tapE:false};
const CAM={mode:'tv'};
function banner(){} function spray(){} function wipe(){} function updateHUD(){} function showBreak(){}
function showHint(){} function hideHint(){} function hideOverlay(){} function camSnap(){}
function updateCamera(){} function updateParticles(){} function updateTrail(){}
function endIntro(){CAM.mode='tv';}
function clearEdges(){input.passE=input.shootE=input.shootUpE=input.tapE=false;}
`;
const API = `
return {newGame,update,nextQuarter,setupPC,clearEdges,input,TEAM_DEFS,ovrOf,teamOvr,inCircle,
  pushToDotted,angDiff,STEP,get G(){return G;},get ball(){return ball;},get players(){return players;},
  get teams(){return teams;}};`;

export function loadWeb(seed) {
  const M = Object.create(Math);
  M.random = mulberry32(seed);
  M.hypot = (x, y) => Math.sqrt(x * x + y * y);
  const el = { classList: { add() {}, remove() {} }, offsetWidth: 0 };
  const document = { querySelector: () => el };
  return new Function('Math', 'document', STUBS + simSrc + API)(M, document);
}

const r9 = (v) => Math.round(v * 1e9) / 1e9;
function snap(w, step) {
  const { G, ball, players } = w;
  return {
    step, state: G.state, q: G.quarter, clock: r9(G.clock), score: [...G.score],
    ball: [ball.x, ball.y, ball.z, ball.vx, ball.vy, ball.vz].map(r9),
    owner: ball.owner ? players.indexOf(ball.owner) : -1,
    p: players.flatMap((p) => [p.x, p.y, p.vx, p.vy, p.face, p.stamina].map(r9)),
    stats: JSON.parse(JSON.stringify(G.stats)),
  };
}

// Simula com window.__estic.simulate(): descans → següent quart, i un update per pas.
function run(seed, { qlen = 150, steps, every, pc = -1 }) {
  const w = loadWeb(seed);
  w.newGame('match', { side: -1, diff: 'normal', qlen });
  if (pc >= 0) { w.G.introT = 0; w.setupPC(w.teams[pc], 1, 'prova'); }
  const frames = [snap(w, 0)];
  let n = 0;
  for (let i = 1; i <= steps; i++) {
    if (w.G.state === 'break') w.nextQuarter();
    if (w.G.state === 'full') break;
    w.update(w.STEP); w.clearEdges(); n = i;
    if (i % every === 0) frames.push(snap(w, i));
  }
  if (frames.at(-1).step !== n) frames.push(snap(w, n)); // fotograma final (p. ex. el xiulet)
  return { seed, qlen, pc, every, frames };
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const w = loadWeb(1);
  const rng = mulberry32(12345);
  const circlePts = [];
  for (const [x, y, side] of [[40, 0, 1], [31, 0, 1], [31.1, 0, 1], [33, 10, 1], [36, 12, 1], [-40, 3, -1],
    [-40, 3, 1], [45.5, 1, 1], [46.1, 1, 1], [32, -5, 1], [-33.4, -8.2, -1], [30, 14, 1]]) {
    circlePts.push({ x, y, side, r14: w.inCircle(x, y, side), r19: w.inCircle(x, y, side, 19.63) });
  }
  const dotted = [[40, 0, 1], [35, 8, 1], [-38, -6, -1], [30, -3, 1]].map(([x, y, s]) => ({ x, y, side: s, out: w.pushToDotted(x, y, s) }));
  const ang = [[0, 3], [3, -3], [-3.1, 3.1], [1, 7], [10, -10]].map(([a, b]) => ({ a, b, d: w.angDiff(a, b) }));
  const out = {
    font: 'reference/web/index.html', generat: new Date().toISOString(),
    rng: { seed: 12345, values: Array.from({ length: 8 }, () => rng()) },
    teams: w.TEAM_DEFS.map((d) => ({
      id: d.id, name: d.name, ovr: w.teamOvr(d), squad: d.squad, players: d.squad.map((s) => w.ovrOf(s)),
    })),
    geometry: { circle: circlePts, dotted, angDiff: ang },
    runs: [
      run(1, { steps: 3600, every: 30 }),
      run(7, { steps: 3600, every: 30 }),
      run(3, { steps: 900, every: 10, pc: 0 }),
      // Partits sencers: quarts, descansos i canvi de camp.
      run(11, { qlen: 30, steps: 100000, every: 60 }),
      run(5, { qlen: 150, steps: 100000, every: 600 }),
    ],
  };
  const dest = join(root, 'tests/fixtures/web_oracle.json');
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, JSON.stringify(out) + '\n');
  const last = out.runs.map((r) => r.frames.at(-1));
  console.log(`Desat a ${dest}`);
  console.log('Estat final de cada execució:', last.map((f) => `${f.state} q${f.q} ${f.score.join('-')} pas ${f.step}`));
}
