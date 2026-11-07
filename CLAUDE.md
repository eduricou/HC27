# Estic Hoquei Herba — PC (Godot 4.7.2)

Joc d'hoquei herba per a Windows 11: Iluro HC contra Club Polo, categoria Papis (+35),
al Camp Municipal d'Hoquei de Mataró. És un port de la versió web: reference/web/index.html
(NO modificar; és la font de veritat del comportament). Pla complet: docs/pla-pc.md.
Regles, constants i toleràncies: docs/regles.md. Decisions: docs/decisions/.

## Estat
- Fases 0 (preparació), 1 (simulació headless), 2 (primer jugable amb caixes grises),
  3 (estadi i gespa), 4 (jugadors amb esquelet i animacions), 5 (càmeres, repeticions,
  HUD i menús), 6 (àudio i sensacions) i 7 (optimització i qualitat, 6/11/2026) fetes.
  Després, millores visuals demanades per l'usuari (porter, pilota, pal, mans, sabatilles,
  cossos, postures, gespa, banquetes, arbres, públic, cotxes, cops; 7/11/2026,
  docs/decisions/0011). Següent: fase 8 (exportació i distribució), pla §9 i §10.
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
  Escenaris (src/game/main.gd): menu, options, intro, match, human, pc, goal (gol i
  repetició), pause, break, full. Els escenaris no llegeixen ni desen user://opcions.cfg.
- Comparar amb la web des dels angles fixos de tools/views.json:
  `node tools/shot_web.mjs [angles] [hores]` → build/shots/web/ ·
  `bash tools/shot_views.sh [angles] [hores] [qualitat]` → build/shots/godot/ (<angle>_<tarda|nit>.png)
- Textures de l'estadi i dígits dels dorsals (assets/textures/): `bash tools/bake_textures.sh`
  (obre una finestra; és el port de les funcions make*() de la web).
- Animacions dels jugadors (assets/models/animations/players.res, a partir de les UAL de
  Quaternius): `"$GODOT" --headless --path . -s res://tools/build_player_anims.gd`.
- Recorregut complet sense pantalla (partit → descansos → final → menú; falla si hi ha errors
  o avisos a la consola): `bash tools/smoke.sh`. Passa-ho després de tocar src/game o src/ui.
- Sons (assets/audio/, CC0): `"$GODOT" --headless --path . -s res://tools/prepare_audio.gd --
  <carpeta>` els prepara a partir dels paquets baixats (vegeu el fitxer). Saturació:
  `bash tools/audio_check.sh [segons] [llavor]` (grava el so d'un partit; obre finestra).
- Fps a 1920×1080 sense VSync: `bash tools/bench.sh [segons] [qualitat] [hora] [res3d] [qset]`
  (obre una finestra). res3d=2560x1440 per estimar 1440p; qset=msaa=0,ssao=false per provar.
- Rendiment d'un partit sencer, fotograma a fotograma (estrebades, CPU i GPU, pipelines
  compilats, memòria; falla si al partit hi ha un fotograma de més de 50 ms):
  `bash tools/perf.sh [qualitat] [hora] [qlen] [--fresh] [--vsync] [--gpu-profile]
  [--no-warmup] [--d3d12] [--compat]` → build/perf/<qualitat>_<hora>.csv. Passa-ho després
  de tocar el render, l'estadi, els jugadors o el flux de pantalles.
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
  MatchRunner fa els passos (pausa, descansos, final), MatchView interpola entre passos,
  CameraRig és la càmera i HumanController omple SimInput. Accions d'entrada:
  InputActions, registrades en temps d'execució i reassignables (hi afegeix A i B del
  comandament a ui_accept i ui_cancel, que Godot no porta).
- Càmeres (CameraRig, fase 5): TV/àmplia, presentació, gol, repetició amb tres angles i
  córner curt darrere de la porteria. Amb aquesta, l'entrada gira amb la càmera
  (MatchRunner.camera_angle → HumanController.angle, que només canvia amb la palanca deixada
  anar); amb la TV el gir és 0. Durant la presentació i la repetició, MatchRunner llegeix
  l'entrada també en CPU contra CPU (per saltar-les; acció skip = clic o Retorn → tap_e).
- Interfície (src/ui/, docs/decisions/0008): construïda des del codi, sense .tscn. UiKit té
  la paleta, les lletres (assets/fonts, OFL), els escuts (assets/crests/*.svg) i el tema.
  Pantalles: Hud (amb PauseScreen i BreakScreen), MainMenu, OptionsScreen. Opcions i
  darreres eleccions del menú: GameSettings → user://opcions.cfg (ConfigFile). Busos
  d'àudio: AudioBuses. Tot s'ha de poder fer amb teclat, ratolí i comandament (hi ha proves).
  En crear controls a _ready() (ja dins de l'arbre), fes servir
  set_anchors_and_offsets_preset(): set_anchors_preset() hi deixa la mida 0.
- Coords.to_view() és una reflexió: les malles generades s'han de fer amb MeshBuilder
  (src/game/stadium/mesh_builder.gd, coordenades de la simulació) o MeshPart
  (src/game/mesh_part.gd, coordenades de Godot, amb colors per vèrtex i ossos), que
  orienten cada triangle segons la normal; si no, les cares no es veuen.
- El camp (scenes/stadium.tscn, src/game/stadium/) és el real de l'Iluro al carrer Galícia
  (foto aèria; docs/decisions/0006), no l'estadi de la web: sense grada, passeig amb
  banquetes i públic dret a −y, bardissa i talús a +y (on és la càmera TV), casetes del club
  a +x. Tota la disposició és a StadiumLayout. Res de l'est no pot tapar la vista TV (hi ha
  una prova). Fet amb codi (docs/decisions/0011): banquetes com les reals (Dugout), arbres
  i bardissa (TreeMesh), públic (SpectatorMesh) i cotxes (CarMesh), repetits amb MultiMesh;
  el terra arriba a l'horitzó, amb conreus i arbres de lluny. Porta també la llum (tarda:
  sol; nit: 6 focus), el cel i l'entorn. Shader globals a project.godot: night,
  crowd_jump. El camp fix va a la capa 2 i els focus de nit no en fan ombra
  (shadow_caster_mask). Efectes del partit (xarxa, públic): StadiumFx.
- Jugadors (docs/decisions/0007 i 0011): PlayerView (posició i orientació, de MatchView)
  conté un PlayerRig (src/game/players/): cos de Quaternius (CC0) amb l'equipació pintada pel
  shader player_kit (KitMesh: textura de dades per vèrtex llegida amb VERTEX_ID; el mateix
  shader fa les complexions de PlayerRig.BUILDS amb el relleu de KitMesh.shape_texture),
  AnimationTree (locomoció sincronitzada: ritme = velocitat / passa, peus sense lliscar) i
  modificadors de l'esquelet, en aquest ordre: PostureModifier3D (ajupit o dret, i el cop),
  IK de les cames, StickPlacer (el pal i on l'agafen les mans), IK dels braços i
  GripModifier3D (gira les mans i hi tanca els dits). El pal (StickMesh) toca la pilota amb
  la cara del ganxo al punt de control de la simulació (stickPt/stickWorld) o, si la porta,
  on es veu la pilota. MatchView.engagement() diu qui és a la jugada: ajupit i amb el pal a
  terra (qui porta la pilota, el rival que la va a robar, el córner, el porter) o més dret
  i amb el pal aixecat. Equip del porter: GkGear; sabatilles: ShoeMesh (es mouen amb els
  ossos del peu; colors per jugador). La pilota és BallView: mida real, però mai menys de
  7 px a la pantalla, i roda. MatchView.on_events dispara les accions (celebrar, protestar,
  entrada), la força del cop i l'estirada del porter (procedural).
- So (src/game/audio/, docs/decisions/0009): MatchSound escolta els esdeveniments de cada
  pas (com MatchView) i fa sonar SfxBank en 3D al lloc on passen; el públic (petit) és un
  murmuri en dues capes amb reaccions. Cada tipus d'esdeveniment de src/sim/ ha de ser a
  MatchSound.SOUNDS o SILENT (hi ha una prova). UiSounds: sons dels menús. Rumble: vibració
  del comandament. Limitador al Master (AudioBuses). Sense pantalla no es reprodueix cap
  so (el mesclador no els alliberaria); per tancar el joc, quit_game() (calla i espera).
- Rendiment (fase 7, docs/decisions/0010): presets a src/game/quality.gd (opcions o
  `--quality=baixa|mitjana|alta|ultra`, que hi mana; el primer cop, segons la gràfica:
  integrada → baixa, dedicada → alta). Porten LOD (mesh_lod_threshold) i quants focus de nit
  fan ombra. Només el mapa d'ombres de la llum activa té la mida del preset. L'FSR 2.2 és una
  opció a part (en una integrada a 1080p va més lent). Controlador: Vulkan (fixat a
  project.godot; si no n'hi ha, D3D12). ShaderWarmup: en obrir el joc, sota una cortina,
  dibuixa els angles del partit de tarda i de nit i tot el HUD perquè Godot no compili
  pipelines en començar el partit; si afegeixes un angle de càmera o una pantalla nova,
  afegeix-la a l'escalfament (ShaderWarmup.VIEWS, Hud.show_all). MatchView reaprofita els 22
  jugadors entre partits (PlayerView.key_of) i SfxBank.preload_all() carrega els sons
  d'entrada: muntar o carregar coses durant el joc fa estrebades.
- Arguments del joc: `--time=tarda|nit` (per defecte, el de les opcions: nit, com la web).
  Decisions de la fase 3: docs/decisions/0005 i 0006.
- Escenaris de revisió: `views` (angles de tools/views.json; també segueixen jugadors amb
  "follow"; `--action=celebrate` fa fer l'acció a tothom) i `follow` (càmera que segueix un
  jugador mentre juga).
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
- Commits en català, amb el format `fase N: què canvia`, només quan hi ha un bloc de feina
  acabat i verificat (lint i proves en verd). Res de commits per a retocs solts: s'afegeixen
  al següent commit amb contingut. Puja a GitHub (`git push`) quan valgui la pena, p. ex. en
  acabar un bloc o una fase. Mai `git push --force`.
- La referència és llarga (2.029 línies): llegeix-la per blocs segons el mapa de docs/pla-pc.md §8.
