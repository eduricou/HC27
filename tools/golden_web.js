// Estadístiques de referència de la versió web (fase 0 del pla).
//
// Ús manual:
//   1. Obre reference/web/index.html a Edge o Chrome.
//   2. Obre DevTools (F12) › Console, enganxa aquest fitxer sencer i prem Enter.
//   3. En acabar, el JSON es copia al porta-retalls i es descarrega com a
//      stats_web.json. Desa'l a reference/golden/stats_web.json.
// Ús automàtic (Edge headless): node tools/golden_headless.mjs
//
// Simula N partits CPU contra CPU (OPTS.side = -1, dificultat normal) amb la
// durada de quart per defecte de la web (150 s reals) fent servir el ganxo
// window.__estic: startMatch() i després simulate() fins al xiulet final.
// El resum té les mateixes claus que tools/sim_stats.gd (mitjanes per partit,
// sumant els dos equips).
(async () => {
  const opts = Object.assign({ n: 50, qlen: 150, download: true }, window.__esticGoldenOpts || {});
  const E = window.__estic;
  if (!E) throw new Error('No trobo window.__estic: obre reference/web/index.html');

  // Silencia el so mentre simula (el botó #bSound alterna SFX.on).
  const sound = document.querySelector('#bSound');
  const wasOn = sound && sound.getAttribute('aria-label') === 'So activat';
  if (wasOn) sound.click();

  const savedOpts = { ...E.OPTS };
  Object.assign(E.OPTS, { side: -1, diff: 'normal', qlen: opts.qlen });

  const matches = [];
  const t0 = performance.now();
  for (let i = 0; i < opts.n; i++) {
    E.startMatch();
    let r = null;
    // simulate(60) avança 60 s reals; un partit en dura uns 12-15 minuts.
    for (let k = 0; k < 120; k++) {
      r = E.simulate(60);
      if (r.state === 'full') break;
    }
    if (!r || r.state !== 'full') throw new Error(`El partit ${i + 1} no ha arribat al final`);
    matches.push({ score: r.score, stats: r.stats });
    console.log(`partit ${i + 1}/${opts.n}: Iluro ${r.score[0]}-${r.score[1]} Polo`);
    await new Promise((res) => setTimeout(res, 0)); // deixa respirar la pàgina
  }
  const seconds = (performance.now() - t0) / 1000;

  const pair = (a) => a[0] + a[1];
  const rows = matches.map((m) => {
    const p = m.stats.poss, pt = p[0] + p[1];
    return {
      goals: pair(m.score), shots: pair(m.stats.shots), on: pair(m.stats.on),
      pcs: pair(m.stats.pcs), fouls: pair(m.stats.fouls), poss_iluro: pt > 0 ? p[0] / pt : 0.5,
    };
  });
  const mean = {}, sd = {};
  for (const k of ['goals', 'shots', 'on', 'pcs', 'fouls', 'poss_iluro']) {
    const mu = rows.reduce((a, r) => a + r[k], 0) / rows.length;
    mean[k] = mu;
    sd[k] = Math.sqrt(rows.reduce((a, r) => a + (r[k] - mu) ** 2, 0) / rows.length);
  }

  const out = {
    meta: {
      font: 'web',
      referencia: 'reference/web/index.html',
      data: new Date().toISOString(),
      n: opts.n, qlen: opts.qlen, dificultat: 'normal', costat: -1,
      segons_simulacio: Math.round(seconds * 10) / 10,
      navegador: navigator.userAgent,
    },
    n: rows.length, mean, sd, matches,
  };

  E.backToMenu();
  Object.assign(E.OPTS, savedOpts);
  if (wasOn) sound.click();

  window.__esticGolden = out;
  const json = JSON.stringify(out, null, 2);
  console.log('Mitjanes per partit:', mean);
  if (opts.download) {
    try { copy(json); console.log('JSON copiat al porta-retalls.'); } catch (e) { /* fora de DevTools */ }
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    a.download = 'stats_web.json';
    a.click();
  }
  return out;
})();
