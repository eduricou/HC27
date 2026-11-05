# Estic Hoquei Herba — PC (Godot 4.7.2)

Joc d'hoquei herba per a Windows 11: Iluro HC contra Club Polo, categoria Papis (+35),
al Camp Municipal d'Hoquei de Mataró. És un port de la versió web: reference/web/index.html
(NO modificar; és la font de veritat del comportament). Pla complet: docs/pla-pc.md.
Regles, constants i toleràncies: docs/regles.md. Decisions: docs/decisions/.

## Estat
- Fase 0 (preparació) i fase 1 (simulació headless) fetes el 5/11/2026. Següent: fase 2
  (primer jugable amb caixes grises), pla §9 i §10.
- La referència és la versió de 2.029 línies, no la «v4» del pla original (docs/decisions/0001).
- La simulació de src/sim/ reprodueix la web pas a pas amb la mateixa llavor
  (docs/decisions/0002). Un partit triga ~10 s en un procés i ens hi quedem: el criteri és
  50 partits en < 3 min en paral·lel (docs/decisions/0003). No proposis portar-la a C++
  si no ho demanen els criteris de revisió d'aquesta decisió.

## Stack
- Godot 4.7.2-stable estàndard (sense .NET), GDScript amb tipus estàtics, renderitzador Forward+.
- Proves: gdUnit4 6.2.3 (addons/gdUnit4). Format i lint: gdtoolkit 4 (gdformat, gdlint).
- Executable de Godot (consola): variable d'entorn $GODOT
  (C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe). Els scripts de tools/ hi tenen
  aquesta ruta per defecte si la variable no hi és. L'intèrpret d'ordres és Git Bash.

## Ordres
- Proves: `bash tools/test.sh` (tota la suite) · `bash tools/test.sh tests/sim/test_rules.gd`
- Estadístiques: `bash tools/sim.sh 50` → mitjanes per partit (CPU contra CPU) comparades amb
  reference/golden/stats_web.json; JSON a reports/sim_stats.json. Reparteix els partits entre
  processos (4t argument; 1 = un procés). 50 partits ≈ 2–3 min.
- Oracle web (comparació pas a pas): `"$GODOT" --headless --path . -s res://tools/oracle_check.gd`.
  Si canvia la referència: `node tools/oracle_web.mjs` regenera tests/fixtures/web_oracle.json.
- Format i lint: `bash tools/lint.sh` (comprova) · `bash tools/lint.sh --fix` (reformata)
- Comprovar un script: `"$GODOT" --headless --path . --check-only -s <script.gd>`
- Reimportar recursos: `"$GODOT" --headless --path . --import`
- Captures per revisar visualment: `bash tools/shot.sh <escenari> [fotogrames]` → PNG a build/shots/
- Exportació: `bash tools/export.sh` (sempre demana confirmació)
- Referència web: `node tools/golden_headless.mjs [N] [qlen] [sortida]` (Edge headless)

## Arquitectura (obligatori)
- src/sim/ és simulació pura: classes RefCounted, sense nodes, sense Input, sense render i
  sense temps real. Tot l'atzar passa per `s.rng` (SimRng, mulberry32 amb llavor), en el
  mateix ordre que les crides a R() de la web: si n'afegeixes o en treus una, l'oracle falla.
- Entrada humana: la capa de joc omple `s.input` (SimInput, coordenades de la simulació) i
  crida `MatchSim.step()`. La lògica de passar, xutar, etc. és a src/sim/human.gd.
- Sortida per a la presentació: `s.events` (esdeveniments de l'últim pas) i l'estat de
  MatchState. Durant la repetició (&"replay") l'estat ja mostra els fotogrames gravats.
- A src/sim/ no facis servir Vector2/Vector3 per a càlculs: són de 32 bits i la simulació
  divergeix de la web. Les funcions que retornen un punt el deixen a s.st_*, s.out_*, s.icpt_*.
- Pas fix de 60 Hz a _physics_process. La vista interpola amb
  Engine.get_physics_interpolation_fraction().
- src/game/ llegeix l'estat de la simulació i l'aplica als nodes; no canvia regles.
- Unitats en metres i segons. Simulació: x = llargada (91,4), y = amplada (55), z = altura.
  Vista: Vector3(x, z, y).
- Constants del camp i del joc: src/sim/constants.gd, copiades de la referència.
- API: `MatchSim.new(llavor, qlen, side = -1, diff = "normal", mode = &"match")`,
  `step()`, `next_quarter()` (després del descans), `run_to_end() -> {"score", "stats", ...}`
  (format de `window.__estic.simulate()`) i `dispose()` (trenca els cicles de referències).

## Convencions
- Fitxers en snake_case. Classes en PascalCase amb class_name. Tipus estàtics a tot arreu.
- Comentaris en català. Els textos de la interfície passen per tr() i el fitxer de traduccions.
- Cada funció portada de la web conserva el nom en snake_case i porta un comentari
  `# ref: nomFuncio()`.
- No afegeixis addons ni dependències sense preguntar.
- Pots editar .tscn i .tres com a text, però no toquis els uid:// ni els .import a mà.
- No editis res dins .godot/ ni dels addons de tercers.
- Paraules reservades de GDScript que no es poden fer servir com a nom de variable: pass,
  match, signal, class, func, var, const, enum, static, await, breakpoint, etc.

## Flux de treball
- Per canviar el comportament de la simulació: primer la prova, després el codi. Si el canvi
  és intencionat i se separa de la web, l'oracle deixarà de coincidir: documenta-ho en una
  decisió i ajusta o retira el recorregut afectat.
- Després de cada canvi: `bash tools/lint.sh` i `bash tools/test.sh`. Si fallen, la tasca no està feta.
- Si toques la IA o les regles: `bash tools/sim.sh 50` i compara amb
  reference/golden/stats_web.json (toleràncies a docs/regles.md). Fes servir el mateix qlen.
- Commits petits, en català, amb el format `fase N: què canvia`. No facis mai `git push` sense que t'ho demani.
- La referència és llarga (2.029 línies): llegeix-la per blocs segons el mapa de docs/pla-pc.md §8.
