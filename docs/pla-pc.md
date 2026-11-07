# Estic Hoquei Herba per a PC (Windows 11): pla de projecte

**Versió 1.0 · 5 de novembre de 2026 · Projecte HC27**

Aquest pla explica com portar el joc web *Estic Hoquei Herba* (Iluro HC contra Club Polo, categoria Papis +35, al Camp Municipal d'Hoquei de Mataró) a una aplicació nativa per a Windows 11. El desenvolupament es fa amb **Claude Code dins de Visual Studio Code**, i la versió web serveix de referència funcional.

---

## 0. Resum

- **Motor:** Godot 4.7.2 (versió estable) amb GDScript i el renderitzador Forward+. Quan surti l'estable de la 4.8 (ara és a la beta 2), s'avaluarà el canvi.
- **Eines de desenvolupament:**
  - VS Code amb l'extensió de Claude Code i l'extensió godot-tools.
  - Git amb Git LFS i GitHub.
  - gdUnit4 per a les proves.
  - Blender 5.2 LTS per als models.
- **Mètode:**
  - La simulació (regles i IA) es porta primer i es valida sense gràfics. La comparem amb estadístiques extretes de la versió web.
  - Després s'hi afegeixen, per capes: l'estadi, els jugadors riggejats, les càmeres i el HUD, l'àudio, l'optimització i l'exportació.
- **Durada orientativa:** de 10 a 13 setmanes, amb una sola persona a temps parcial.
- **Lliurament:** un `.exe` per a Windows 11 x64 dins d'un zip. Opcionalment, signat i amb instal·lador.

---

## 1. Objectius i abast

### Objectius

| Àmbit | Objectiu mesurable |
|---|---|
| Rendiment | 60 fps estables a 1080p amb una gràfica integrada moderna (preset *Baixa*). 144 fps a 1440p amb una GPU dedicada de gamma mitjana (preset *Alta*). |
| Simulació | Pas fix a 60 Hz. Els partits s'han de poder simular en mode *headless*: 50 partits en menys de 3 minuts, repartits entre els nuclis del PC de desenvolupament (`bash tools/sim.sh 50`). Criteri revisat a la fase 1: abans era «un partit en menys de 3 s» (vegeu `docs/decisions/0003`). |
| Fidelitat | Les mateixes regles i la mateixa IA que la versió web. Les mitjanes de gols, xuts i penals córner per partit han de quedar dins d'un ±20 % de les de la web. |
| Gràfics | Jugadors amb esquelet i animacions, i un estadi 3D amb il·luminació de tarda i de nit. També ombres reals, repeticions i transicions. |
| Controls | Teclat i comandament (Xbox o PlayStation), amb vibració i tecles reassignables. |
| Distribució | Un executable que funciona en un Windows 11 net, sense haver d'instal·lar res més. |

### Fora d'abast de la v1

- El multijugador en línia.
- Altres equips o lligues, i un editor d'equips.
- La publicació a Steam.
- Les versions per a macOS, Linux i mòbil. Godot les permetria més endavant reutilitzant el mateix codi.

### Requisits del jugador (són objectius, i es validen a la fase 7)

| | Mínim | Recomanat |
|---|---|---|
| Sistema | Windows 10/11 x64 | Windows 11 x64 |
| GPU | Compatible amb Direct3D 12 o Vulkan (p. ex. Intel Iris Xe o Radeon Vega 8) | GTX 1650 / RX 6500 o superior |
| RAM | 4 GB | 8 GB |
| Disc | ~400 MB | ~400 MB |

Per a gràfiques antigues sense Vulkan ni D3D12, hi haurà un accés directe alternatiu amb `--rendering-method gl_compatibility` (OpenGL 3.3).

---

## 2. Decisions tècniques

| Decisió | Elecció | Per què | Alternatives descartades |
|---|---|---|---|
| Motor | **Godot 4.7.2-stable** (edició estàndard), amb la versió fixada | Té les característiques següents: <ul><li>És lliure (MIT) i no cobra royalties.</li><li>Les escenes i els scripts són text (`.tscn`, `.gd`) que Claude Code pot llegir i editar directament.</li><li>Té una CLI *headless* per a proves i exportacions.</li><li>És lleuger.</li></ul> | <ul><li>Unity: llicència, i escenes molt verboses.</li><li>Unreal: molt pesat, i amb C++/Blueprints és més difícil per a l'agent.</li><li>C++ propi: massa feina.</li><li>Empaquetar la web amb Electron/Tauri: no millora prou el rendiment.</li></ul> |
| Llenguatge | **GDScript amb tipus estàtics** | No necessita el SDK de .NET i s'itera de pressa. La simulació és petita (22 jugadors + pilota). | <ul><li>C# (requereix l'edició .NET de Godot).</li><li>GDExtension C++, que només s'usaria si el perfilador ho demanés.</li></ul> |
| Renderitzador | **Forward+** sobre D3D12 o Vulkan (es tria després de fer proves), amb *Compatibility* com a reserva | Forward+ dona la millor qualitat i ofereix escalat FSR 2.2. *Compatibility* serveix per a maquinari antic. | Mobile |
| Física | **Simulació pròpia** a `_physics_process`, a 60 Hz i determinista (amb `RandomNumberGenerator` i llavor) | La versió web ja té una cinemàtica pròpia de pilota i jugadors. Es pot provar sense gràfics i permet repeticions exactes. | Les físiques de Godot o Jolt per a la pilota (menys control i no deterministes) |
| Arquitectura | Separació estricta entre la **simulació** (`src/sim`, classes `RefCounted` sense nodes) i la **presentació** (`src/game`, nodes 3D que llegeixen l'estat) | Permet proves *headless*, repeticions i equilibrat amb milers de partits simulats. | Lògica repartida pels nodes |
| Proves | **gdUnit4** i un simulador d'estadístiques *headless* | Té un *runner* per línia d'ordres i informes JUnit/HTML, i funciona a CI. | GUT |
| Assets 3D | **Blender 5.2 LTS** i exportació a glTF (`.glb`) | És el format natiu més ben suportat per Godot. | FBX |
| Versions | **Git amb Git LFS** i un repositori privat a GitHub | Els binaris (`.blend`, `.glb`, àudio i textures) van per LFS. | — |

**Sistema de coordenades.** La simulació treballa en metres i segons:

- x és la llargada del camp (91,4 m).
- y és l'amplada (55 m).
- z és l'altura de la pilota.

La vista ho converteix a Godot com a `Vector3(x, z, y)`, perquè a Godot l'eix Y és l'altura.

---

## 3. Paquets que cal instal·lar (entorn de desenvolupament)

### 3.1 Llista

| # | Paquet | Versió | Per a què | Instal·lació | |
|---|---|---|---|---|---|
| 1 | Windows 11 actualitzat i controladors de la GPU | Darrers | Base del sistema; Vulkan i D3D12 | Windows Update i el web del fabricant (NVIDIA, AMD o Intel) | Obligatori |
| 2 | winget (App Installer) | Ve amb Windows 11 | Instal·lar la resta de paquets | — | Obligatori |
| 3 | **Git for Windows** (inclou Git Bash i Git LFS) | Darrera | Control de versions. Claude Code fa servir Git Bash com a intèrpret d'ordres. | `winget install --id Git.Git -e` | Obligatori |
| 4 | **Visual Studio Code** | ≥ 1.94 | Editor i entorn de Claude Code | `winget install --id Microsoft.VisualStudioCode -e` | Obligatori |
| 5 | **Claude Code** (CLI) | Darrera | Ordre `claude` al terminal (`claude doctor`, `/init`, `/permissions`) | `winget install Anthropic.ClaudeCode` o, a PowerShell, `irm https://claude.ai/install.ps1 \| iex` | Obligatori |
| 6 | Compte de Claude | Pro, Max, Team, Enterprise o Console | Iniciar sessió a Claude Code | — | Obligatori |
| 7 | **Extensió Claude Code per a VS Code** | Darrera | Panell de Claude dins de VS Code: plans, diffs, punts de control | `code --install-extension anthropic.claude-code` | Obligatori |
| 8 | **Extensió godot-tools** | Darrera | GDScript a VS Code: LSP, depurador i ressaltat | `code --install-extension geequlim.godot-tools` | Obligatori |
| 9 | **Godot Engine 4.7.2-stable** (estàndard, *no* .NET), win64 | 4.7.2 | Motor i editor. El zip inclou `…_win64.exe` i `…_win64_console.exe`. | Zip de godotengine.org/download/archive/4.7.2-stable (recomanat, perquè fixa la versió). Alternativa: `winget install --id GodotEngine.GodotEngine -e` | Obligatori |
| 10 | **Plantilles d'exportació 4.7.2** | 4.7.2 | Generar l'`.exe` | Des de l'editor de Godot: *Editor › Gestiona les plantilles d'exportació › Descarrega i instal·la*. També es pot fer amb el fitxer `.tpz`. | Obligatori |
| 11 | **gdUnit4** (addon dins del projecte) | v6.2.3 (compatible amb Godot 4.7; instal·lada a la fase 0) | Proves unitàries i d'integració | AssetLib de Godot o el *release* de GitHub, dins `addons/gdUnit4` | Obligatori |
| 12 | Python | 3.12 o 3.13 | gdtoolkit i scripts auxiliars | `winget install --id Python.Python.3.13 -e` | Recomanat |
| 13 | gdtoolkit 4 (`gdformat`, `gdlint`) | 4.x | Format i *lint* de GDScript | `pip install "gdtoolkit==4.*"` (o amb `pipx`) | Recomanat |
| 14 | **Blender** | 5.2 LTS | Models (jugadors, pals, estadi), rig i animacions específiques d'hoquei | `winget install --id BlenderFoundation.Blender -e` o blender.org | Recomanat |
| 15 | GitHub CLI (`gh`) | Darrera | Crear el repositori, *issues* i PR des de Claude Code | `winget install --id GitHub.cli -e` | Opcional |
| 16 | Audacity | Darrera | Retallar i normalitzar els sons | audacityteam.org | Opcional |
| 17 | Windows SDK (SignTool) i un certificat de signatura de codi | — | Signar l'`.exe` (evita l'avís de SmartScreen) | Instal·lador del Windows SDK o Visual Studio Installer | Opcional (fase 8) |
| 18 | Comandament Xbox o PlayStation | — | Provar el control i la vibració | — | Recomanat |

**No cal instal·lar:**

- **Node.js.** L'instal·lador natiu de Claude Code no el necessita. Només cal si s'instal·la Claude Code per npm, i en aquest cas ha de ser Node 22 o superior.
- **El SDK de .NET.** No es fa servir C#.
- **WSL2.** Només caldria si es volgués el *sandbox* de Claude Code, que no està disponible a Windows natiu.

> Els identificadors de winget de Git, VS Code, Python, Blender i GitHub CLI són els habituals, però no els he pogut verificar un per un. Si algun no es troba, fes `winget search <nom>`.

### 3.2 Script d'instal·lació (PowerShell)

```powershell
# 1) Eines (tanca i torna a obrir el terminal en acabar perquè s'actualitzi el PATH)
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudioCode -e
winget install Anthropic.ClaudeCode
winget install --id Python.Python.3.13 -e
winget install --id BlenderFoundation.Blender -e
winget install --id GitHub.cli -e            # opcional

# 2) Extensions de VS Code i gdtoolkit
code --install-extension anthropic.claude-code
code --install-extension geequlim.godot-tools
pip install "gdtoolkit==4.*"

# 3) Godot 4.7.2 a una ruta fixa (primer descarrega Godot_v4.7.2-stable_win64.exe.zip)
New-Item -ItemType Directory C:\Tools\Godot -Force | Out-Null
Expand-Archive "$HOME\Downloads\Godot_v4.7.2-stable_win64.exe.zip" C:\Tools\Godot -Force
[Environment]::SetEnvironmentVariable("GODOT", "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe", "User")
```

La variable `GODOT` apunta a l'executable de **consola**. Així, les ordres *headless* que llança Claude Code mostren la sortida al terminal.

### 3.3 Verificació

```powershell
git --version; git lfs version
code --version                  # 1.94 o superior
claude --version
claude doctor                   # diagnòstic de la instal·lació
& $env:GODOT --version          # 4.7.2.stable.official...
python --version; gdformat --version
```

A continuació:

1. Executa `claude` un cop i inicia la sessió amb el teu compte.
2. Obre el panell de Claude Code a VS Code i comprova que també hi tens la sessió iniciada.

Si `claude doctor` no troba Git Bash, afegeix això a `%USERPROFILE%\.claude\settings.json`:

```json
{ "env": { "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe" } }
```

---

## 4. Configuració de l'entorn

### 4.1 Editor de Godot (*Editor › Configuració de l'editor*)

- **Text Editor › External:**
  - Activa *Use External Editor*.
  - *Exec Path:* la ruta de `code.cmd`. Des de Godot 4.5 es detecta automàticament.
  - *Exec Flags:* `{project} --goto {file}:{line}:{col}`.
- **Text Editor › Behavior › Files:** activa *Auto Reload Scripts on External Change*. És imprescindible, perquè Claude edita els fitxers des de fora de l'editor.
- **Network:** deixa el *Language Server* al port 6005 i el *Debug Adapter* al 6006, que són els valors per defecte.
- **FileSystem › Import › Blender:** posa-hi la ruta de Blender si vols importar `.blend` directament. El pla, però, fa servir `.glb` exportats.
- **Export › Windows › Sign Tool:** la ruta de `signtool.exe`. És opcional (fase 8).

### 4.2 `.vscode/settings.json`

```json
{
  "godotTools.editorPath.godot4": "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64.exe",
  "godotTools.lsp.headless": true,
  "files.eol": "\n",
  "[gdscript]": { "editor.insertSpaces": false, "editor.tabSize": 4 },
  "files.exclude": { ".godot/": true }
}
```

### 4.3 `.vscode/launch.json` (executar i depurar des de VS Code)

```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "Godot: executar el joc", "type": "godot", "request": "launch", "project": "${workspaceFolder}" }
  ]
}
```

L'extensió godot-tools també pot generar aquesta configuració des de *Run › Add Configuration*.

### 4.4 `.gitignore` i `.gitattributes`

```gitignore
.godot/
/build/
/reports/
*.tmp
```

```gitattributes
* text=auto eol=lf
*.blend filter=lfs diff=lfs merge=lfs -text
*.glb   filter=lfs diff=lfs merge=lfs -text
*.png   filter=lfs diff=lfs merge=lfs -text
*.jpg   filter=lfs diff=lfs merge=lfs -text
*.exr   filter=lfs diff=lfs merge=lfs -text
*.wav   filter=lfs diff=lfs merge=lfs -text
*.ogg   filter=lfs diff=lfs merge=lfs -text
```

### 4.5 Permisos de Claude Code per al projecte (`.claude/settings.json`, es desa al repositori)

```json
{
  "permissions": {
    "allow": [
      "Bash(bash tools/test.sh *)",
      "Bash(bash tools/sim.sh *)",
      "Bash(bash tools/lint.sh *)",
      "Bash(bash tools/shot.sh *)",
      "Bash(gdformat *)",
      "Bash(gdlint *)",
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git add *)",
      "Bash(git commit *)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(bash tools/export.sh *)"
    ],
    "deny": [
      "Bash(git push --force *)",
      "Bash(rm -rf *)"
    ]
  }
}
```

**Modes de permís:**

- Comença en el mode **Manual**.
- Usa **Plan** per començar cada fase. En aquest mode, Claude explora i proposa sense editar.
- Quan confiïs en la dinàmica, passa a **Accept edits**. Si el teu pla ofereix el mode **auto**, també és una opció.
- **No facis servir `bypassPermissions`.** A Windows natiu no hi ha *sandbox*. La xarxa de seguretat són els commits petits i els punts de control de l'extensió.

Si fas servir PowerShell en lloc de Git Bash, les regles tenen la mateixa forma: `PowerShell(git commit *)`.

**Opcional:** pots demanar a Claude que creï un *hook* `PostToolUse` que passi `gdformat` sobre cada fitxer `.gd` que editi.

---

## 5. Estructura del repositori

```
estic-pc/
├─ CLAUDE.md                     ← context permanent per a Claude Code (secció 6)
├─ README.md
├─ project.godot
├─ export_presets.cfg            ← sense credencials
├─ .claude/settings.json
├─ .vscode/ settings.json · launch.json · extensions.json
├─ docs/
│  ├─ pla-pc.md                  ← aquest document
│  ├─ regles.md                  ← regles, constants i toleràncies d'equilibri
│  └─ decisions/                 ← decisions curtes (ADR)
├─ reference/
│  ├─ web/index.html             ← versió web v4 (només lectura)
│  └─ golden/stats_web.json      ← estadístiques de referència (fase 0)
├─ addons/gdUnit4/
├─ src/
│  ├─ sim/                       ← simulació pura, sense nodes
│  │  ├─ constants.gd  team_data.gd  player.gd  team.gd  ball.gd
│  │  ├─ ball_actions.gd  rules.gd  ai.gd  ai_gk.gd  movement.gd
│  │  ├─ match_state.gd  match_sim.gd  replay_buffer.gd
│  ├─ game/                      ← pont entre la simulació i l'escena
│  │  ├─ match_runner.gd  human_controller.gd  camera_rig.gd
│  │  ├─ player_view.gd  ball_view.gd  fx.gd
│  ├─ ui/                        ← menú, HUD, pausa, descans, opcions
│  └─ audio/sfx_bank.gd
├─ scenes/ main.tscn · stadium.tscn · player.tscn · ball.tscn · goal.tscn · ui/*.tscn
├─ data/teams/ iluro.tres · polo.tres
├─ shaders/ turf.gdshader · net.gdshader · crowd.gdshader
├─ assets/ models/ · textures/ · audio/ · fonts/ · crests/ (SVG)
├─ art_src/ *.blend              ← fitxers font de Blender (LFS)
├─ tests/ sim/ · game/
└─ tools/ test.sh · sim.sh · lint.sh · shot.sh · export.sh · sim_stats.gd · golden_web.js
```

---

## 6. CLAUDE.md inicial

Copia-ho a l'arrel del repositori. Claude Code el llegeix a cada sessió. Es pot refinar més endavant amb `/init` o editant-lo a mà.

```markdown
# Estic Hoquei Herba — PC (Godot 4.7.2)

Joc d'hoquei herba per a Windows 11: Iluro HC contra Club Polo, categoria Papis (+35),
al Camp Municipal d'Hoquei de Mataró. És un port de la versió web: reference/web/index.html
(NO modificar; és la font de veritat del comportament). Pla complet: docs/pla-pc.md.
Regles, constants i toleràncies: docs/regles.md.

## Stack
- Godot 4.7.2-stable estàndard (sense .NET), GDScript amb tipus estàtics, renderitzador Forward+.
- Proves: gdUnit4 (addons/gdUnit4). Format i lint: gdtoolkit 4 (gdformat, gdlint).
- Executable de Godot (consola): variable d'entorn $GODOT. L'intèrpret d'ordres és Git Bash.

## Ordres
- Proves: `bash tools/test.sh` (tota la suite) · `bash tools/test.sh tests/sim/test_rules.gd`
- Estadístiques: `bash tools/sim.sh 50` → JSON amb mitjanes per partit (CPU contra CPU)
- Format i lint: `bash tools/lint.sh`
- Comprovar un script: `"$GODOT" --headless --path . --check-only -s <script.gd>`
- Reimportar recursos: `"$GODOT" --headless --path . --import`
- Captures per revisar visualment: `bash tools/shot.sh <escenari>` → PNG a build/shots/
- Exportació: `bash tools/export.sh` (sempre demana confirmació)

## Arquitectura (obligatori)
- src/sim/ és simulació pura: classes RefCounted, sense nodes, sense Input, sense render i
  sense temps real. Tot l'atzar passa per un RandomNumberGenerator amb llavor injectada.
- Pas fix de 60 Hz a _physics_process. La vista interpola amb
  Engine.get_physics_interpolation_fraction().
- src/game/ llegeix l'estat de la simulació i l'aplica als nodes; no canvia regles.
- Unitats en metres i segons. Simulació: x = llargada (91,4), y = amplada (55), z = altura.
  Vista: Vector3(x, z, y).
- Constants del camp i del joc: src/sim/constants.gd, copiades de la referència.

## Convencions
- Fitxers en snake_case. Classes en PascalCase amb class_name. Tipus estàtics a tot arreu.
- Comentaris en català. Els textos de la interfície passen per tr() i el fitxer de traduccions.
- Cada funció portada de la web conserva el nom en snake_case i porta un comentari
  `# ref: nomFuncio()`.
- No afegeixis addons ni dependències sense preguntar.
- Pots editar .tscn i .tres com a text, però no toquis els uid:// ni els .import a mà.
- No editis res dins .godot/ ni dels addons de tercers.

## Flux de treball
- Per canviar el comportament de la simulació: primer la prova, després el codi.
- Després de cada canvi: `bash tools/lint.sh` i `bash tools/test.sh`. Si fallen, la tasca no està feta.
- Si toques la IA o les regles: `bash tools/sim.sh 50` i compara amb
  reference/golden/stats_web.json (toleràncies a docs/regles.md).
- Commits petits, en català, amb el format `fase N: què canvia`. No facis mai `git push` sense que t'ho demani.
- La referència és llarga (unes 2.300 línies): llegeix-la per blocs segons el mapa de docs/pla-pc.md §8.
```

---

## 7. Com treballar amb Claude Code a VS Code

1. **Obre la carpeta del repositori a VS Code.** Obre-hi també l'editor de Godot amb el mateix projecte, per veure les escenes en directe.
2. **Una conversa per tasca.** Obre el panell de Claude Code i comença cada fase o subtasca en una conversa nova. Entre tasques llargues, fes servir `/clear` o `/compact` per mantenir net el context.
3. **Planifica primer.** Entra en mode Plan (selector de mode o `/plan`) i enganxa el *prompt* de la fase (secció 10). Revisa el pla, corregeix-lo i aprova'l.
4. **Implementa.** Canvia a *Accept edits*. Claude edita, executa les proves i el lint, i et mostra els diffs.
   - Per assenyalar fitxers o seleccions concretes, fes servir les @-mencions (Alt+K). Per exemple, `@reference/web/index.html` amb un interval de línies.
5. **Revisa i desa.** Revisa els canvis i fes un commit (Claude el pot fer). Si alguna cosa no et convenç, torna enrere amb els punts de control (*rewind*).
6. **Revisió visual.** Claude no veu la finestra del joc, però sí que pot llegir imatges.
   - `tools/shot.sh` executa el joc amb `--write-movie build/shots/frame.png --fixed-fps 60 --quit-after N` en un escenari de càmera predefinit.
   - Claude pot obrir les captures resultants i comparar-les amb les de la versió web.
7. **Feina en paral·lel.** Si vols dues sessions alhora (per exemple, art i simulació), fes-les en branques o *worktrees* diferents.

**Precaució amb les escenes obertes.** Si una escena està oberta a Godot amb canvis sense desar i Claude edita el `.tscn`, Godot el pot sobreescriure en desar. Abans de demanar canvis en una escena, desa-la o tanca-la.

---

## 8. Mapa del port (de JS a GDScript)

Les línies fan referència a `reference/web/index.html` (2.029 línies).

> **Nota (fase 0, 5/11/2026).** El pla original citava una «versió 4» de 2.311 línies amb jugadors 3D instanciats. La còpia que hi ha al repositori és una versió anterior: té 2.029 línies i els jugadors es dibuixen en 2D (`drawPlayer`) sobre l'estadi WebGL. La simulació (línies 289–1031) coincideix amb el pla original, amb una línia de desfasament. Aquesta taula ja està corregida per a la còpia del repositori. Vegeu `docs/decisions/0001-versio-de-la-referencia.md`.

| Línies | Contingut de la referència | Destinació |
|---|---|---|
| 289–295 | Constants del camp i del temps (FL, FW, CR, DR, L23, PSPOT, STEP, QGAME), utilitats (`clamp`, `lerp`, `angDiff`, `gauss`) | `src/sim/constants.gd` |
| 297–338 | `TEAM_DEFS` (plantilles Papis, equipacions), `WEIGHTS`, `SLOTS` (1-4-3-3), `DIFFS`, `makeTeam` | `data/teams/*.tres`, `team_data.gd`, `team.gd`, `player.gd` |
| 340–361 | Estat: `OPTS`, `newBall`, `newGame`, `diffOf`, `possTeam` | `match_state.gd`, `ball.gd` |
| 363–438 | Geometria (363–372: `inCircle`, `stickPt`…) i accions de pilota (374–438: `touch`, `gain`, `kick`, `passTo`, `tryTackle`) | `ball_actions.gd` |
| 439–545 | Represes, faltes, penal córner (`setupPC`, `updatePC`), gols i quarts (516–545) | `rules.gd` |
| 546–779 | IA: posicions base, marcatge, suport, trajectòries, rols, `bestPass`, regat, xut, porter (729–779) | `ai.gd`, `ai_gk.gd` |
| 780–806 | Moviment i col·lisions | `movement.gd` |
| 807–869 | Control humà (passada, apuntar, xut, entrada, canvi de jugador) | `src/sim/human.gd` (lògica, determinista). `game/human_controller.gd` només omple `SimInput` a partir del teclat o el comandament (fase 2). Vegeu `docs/decisions/0002`. |
| 870–1031 | Bucle `update`, pilota, recollida, `rules`, represes, rellotge | `match_sim.gd` |
| 1032–1051 | Repetició (buffer i interpolació) | `replay_buffer.gd` |
| 1052–1089 | So sintetitzat (WebAudio) | `audio/sfx_bank.gd`, amb mostres reals |
| 1090–1152 | Entrada (teclat i tàctil) | InputMap i `human_controller.gd` |
| 1153–1184 | Escuts dibuixats per codi | `assets/crests/*.svg` |
| 1185–1248 | Matrius i càmeres (TV, intro, gol, repetició) | `game/camera_rig.gd` |
| 1249–1579 | Estadi, gespa i cel en WebGL | `scenes/stadium.tscn`, `shaders/turf.gdshader` |
| 1580–1869 | Capa 2D per sobre: jugadors dibuixats (`drawPlayer`, 1590–1698), ombres, porteries, pilota, partícules, estela, minimapa (1854) i cortineta | `scenes/player.tscn` (només com a referència de proporcions i colors), GPUParticles3D i `ui/minimap` |
| 1870–1939 | HUD i DOM (marcador, rètols, descans, estadístiques) | `ui/*.tscn` |
| 1940–2029 | Flux (menú, intro, pausa) i arrencada, amb el ganxo de proves `window.__estic` (2023) | `game/main.gd` |

---

## 9. Fases, lliuraments i criteris d'acceptació

Les durades són orientatives i suposen una sola persona a temps parcial.

### Fase 0: preparació (1–2 dies)

**Feina:**

- Instal·lar els paquets de la secció 3.
- Crear el repositori a GitHub i el projecte de Godot, amb aquesta configuració:
  - renderitzador Forward+;
  - 60 *ticks* de física;
  - finestra de 1920×1080;
  - nom «Estic Hoquei Herba».
- Afegir gdUnit4, `CLAUDE.md`, `.claude/settings.json` i els scripts de `tools/`.
- Copiar la versió web a `reference/web/`.
- **Estadístiques de referència:**
  - Obre `reference/web/index.html` a Edge o Chrome.
  - A la consola de DevTools, executa `tools/golden_web.js`. L'escriu Claude, i fa servir el ganxo `window.__estic`: posa CPU contra CPU, crida `startMatch()` i després `simulate()` fins al final.
  - Repeteix-ho per a 50 partits i desa el resultat a `reference/golden/stats_web.json`.
  - Valors indicatius actuals (8 partits Papis): unes 3 gols, 11 xuts i 4 penals córner per partit entre els dos equips.
  - **Fet (5/11/2026).** Amb 50 partits i la durada de quart per defecte de la web (150 s reals): 6,74 gols, 17,06 xuts i 5,58 penals córner per partit. Els valors indicatius d'aquí dalt corresponen a quarts de 90 s (amb 90 s surten 3,78 gols, 10,16 xuts i 3,92 penals córner). Detalls a `docs/regles.md`.
- **Prova del pipeline d'exportació:** exporta ja un `.exe` buit que s'obri a Windows 11.

**Acceptació:**

- `claude doctor` no dona errors.
- `bash tools/test.sh` passa una prova d'exemple.
- L'`.exe` buit s'executa.

### Fase 1: simulació *headless* (1,5–2 setmanes)

**Feina:**

- Portar a `src/sim/` les constants, els equips, la pilota, els jugadors, el moviment, les regles, la IA, la màquina d'estats i el buffer de repetició. Sense cap gràfic.
- Proves unitàries de regles:
  - el gol només és vàlid si el toc és dins del cercle;
  - les sortides de fons i de banda;
  - el córner llarg a la línia de 23 m;
  - el penal córner (posicions, `pcPending`, primer xut);
  - les faltes i el peu;
  - els canvis de quart.
- Prova de determinisme: la mateixa llavor ha de donar el mateix partit.
- `tools/sim.sh N`: simula N partits CPU contra CPU i treu les mitjanes en JSON.

**Acceptació:**

- Totes les proves passen.
- Amb 50 partits, les mitjanes de gols, xuts i penals córner queden dins del ±20 % de la referència web.
- `bash tools/sim.sh 50` acaba en menys de 3 minuts al PC de desenvolupament (criteri revisat; vegeu `docs/decisions/0003`).

### Fase 2: primer jugable amb caixes grises (1 setmana)

**Feina:**

- Camp pla amb línies, càpsules per als jugadors i una esfera per a la pilota.
- Càmera TV que segueix la pilota.
- Control amb teclat i comandament.
- HUD mínim (marcador, rellotge i quart) i pausa.

**Acceptació:**

- Es pot jugar un partit complet, del menú al xiulet final, amb teclat i amb comandament.
- La consola no mostra errors.
- El joc va a més de 300 fps al PC de desenvolupament.

**Fet (5/11/2026).**
- El recorregut complet sense pantalla passa sense errors ni avisos, tant CPU contra CPU com amb un humà automàtic (`tools/smoke.sh`).
- Va a uns 355 fps a 1080p (Intel Arc 130V; `tools/bench.sh`).
- Queda per provar a mà una partida amb el teclat i una amb un comandament físic.
- Decisions: `docs/decisions/0004`.

### Fase 3: estadi i gespa (1,5 setmanes)

**Feina:**

- Gespa artificial amb *shader*: franges, soroll, línies del camp i cercles.
- Porteries amb xarxes animades.
- Banquetes, tanques, el *clubhouse*, les torres de llum i els pins.
- Façanes de la ciutat al fons, cel, i grada amb públic (MultiMesh).
- Il·luminació de **tarda** (DirectionalLight amb ombres PSSM) i de **nit** (projectors amb SpotLight3D).
- LightmapGI per a l'estadi estàtic, ReflectionProbe, *glow* i *tonemapping*.

**Acceptació:**

- Les captures des dels mateixos angles han de ser equivalents o millors que la versió web.
- A 1080p, ≥ 60 fps amb el preset *Baixa* en una gràfica integrada.
- A 1440p, ≥ 144 fps amb el preset *Alta* en una GPU mitjana.

**Fet (5/11/2026).**
- Les captures de Godot i de la web des dels mateixos angles, de tarda i de nit, es fan amb `tools/shot_views.sh` i `tools/shot_web.mjs` (`tools/views.json`).
- Primer es va fer l'estadi de la web, amb llum real, ombres i públic en 3D. Després, a petició de l'usuari i a partir d'una foto aèria, s'ha substituït pel camp real de l'Iluro: sense grada, passeig amb banquetes, tanques, bardissa i talús, i casetes del club (`docs/decisions/0006`).
- Amb *Baixa* a 1080p fa 175–236 fps a l'Intel Arc 130V integrada.
- Amb *Alta* a 1440p fa 76–100 fps a la mateixa integrada. Una GPU mitjana n'hauria de fer unes 2,5–3 vegades més; queda per confirmar a la fase 7.
- No hi ha LightmapGI ni ReflectionProbe: l'estadi es genera per codi i LightmapGI s'ha de coure a mà a l'editor. En lloc d'això, hi ha SSAO a *Alta* i SSIL a *Ultra*.
- Decisions: `docs/decisions/0005` i `0006`.

### Fase 4: jugadors riggejats i animacions (2–3 setmanes) — és la fase de més risc

**El model:**

- Un model base *low-poly* (6–10 k triangles) amb un rig humanoide compatible amb el `SkeletonProfileHumanoid` de Godot (retargeting).
- LOD automàtics en importar.

**Variacions dels jugadors:**

- Tons de pell, 5 pentinats i barbes.
- Equipacions fetes amb materials:
  - **Iluro:** samarreta amb la meitat de dalt blanca i la de baix taronja, coll negre, pantalons negres i mitges blanques.
  - **Polo:** samarreta blanca amb el blau marí i la franja vermella.
- Dorsals fets amb un atles de textures.
- Porters amb proteccions i casc.

**El pal:**

- Una malla pròpia, enganxada a la mà dreta amb un `BoneAttachment3D`.
- La mà esquerra s'ajusta a l'empunyadura amb IK (SkeletonModifier3D).

**Animacions:**

- *Repòs*, caminar, córrer, esprintar i córrer conduint la pilota.
- Push, hit (amb el gest enrere i el cop), slap i revés.
- Entrada, recepció, celebració i protesta.
- Per al porter: posició preparada, aturada a esquerra i dreta, estirada i xut.
- Origen: la locomoció pot venir de Mixamo; els gestos d'hoquei es fan a Blender.

**Control de les animacions:**

- Un AnimationTree amb un BlendSpace2D per a la locomoció i OneShot per a les accions.
- Les accions es disparen amb els esdeveniments de la simulació (xut, entrada, aturada).

**Acceptació:**

- Els 22 jugadors animats van a 60 fps amb el preset *Baixa* en una gràfica integrada.
- No hi ha peus que llisquin a velocitats normals.
- El contacte del pal amb la pilota és coherent.
- Les equipacions compleixen la llista de comprovació.

**Fet (6/11/2026).**
- Model i animacions de Quaternius (CC0), sense Blender ni Mixamo. Les animacions es converteixen a l'esquelet del jugador amb `tools/build_player_anims.gd`.
- Les equipacions es pinten amb un shader damunt del cos, i hi ha dorsals, variacions de pell, cabells i barba, i porters amb casc, guardes, xuteres i guants.
- Locomoció amb els cicles sincronitzats: el peu de suport llisca ≤ 7 % entre 1 i 9 m/s (hi ha una prova).
- Postura d'hoquei i IK de cames i braços. La pala del pal sempre és al punt de control de la simulació, i les dues mans hi van amb IK.
- 22 jugadors animats: 174–263 fps amb *Baixa* a 1080p a l'Intel Arc 130V.
- Pendent: no hi ha animacions d'hoquei fetes a mà (push, hit, slap, revés). El cop és procedural, com a la web. L'estirada del porter i les seves proteccions són provisionals.
- Decisions: `docs/decisions/0007`.

### Fase 5: càmeres, repeticions, HUD i menús (1,5 setmanes)

**Càmeres:**

- TV, intro amb vol d'apropament, gol i repetició multiangle a càmera lenta.
- Una càmera nova darrere de la porteria per als penals córner.

**HUD:**

- Marcador amb escuts, rellotge, quart i l'etiqueta PAPIS.
- Minimapa, indicador del jugador i barra de potència.
- Rètols (GOL!, penal córner, córner…), descans amb estadístiques i pantalla final.

**Menú:**

- Tria del costat (Iluro, Polo o CPU contra CPU), dificultat, durada del quart, tarda o nit, i càmera.

**Opcions:**

- Resolució, mode de finestra, VSync, límit de fps, preset de qualitat, escala FSR, volums i tecles.
- Es desen a `user://` amb ConfigFile.

**Acceptació:**

- Tots els menús es poden navegar només amb teclat, només amb ratolí i només amb comandament.
- Les opcions es conserven en reiniciar el joc.
- La repetició es pot saltar.

**Fet (6/11/2026).**
- **Càmeres:** TV (i «Àmplia»), presentació amb vol des de l'aire, primer pla del golejador i repetició a mitja velocitat amb tres angles (alta per darrere de la jugada, arran de gespa des de la banda i darrere de la porteria).
- **Córner curt:** càmera nova darrere de la porteria. Amb aquesta càmera, els controls giren amb ella.
- **HUD:** com el de la web, amb les seves lletres (OFL) i els escuts en SVG: marcador, minimapa, indicador del jugador amb resistència i potència, rètols, cortineta, franges de cinema, i descans i final amb estadístiques.
- **Menú:** placa del partit amb les equipacions en 3D, costat, dificultat, durada, hora i càmera.
- **Opcions:** pantalla, FSR 2.2, so i tecles, desades a `user://opcions.cfg`.
- **Acceptació:** ho comproven les proves (`tests/game/test_ui.gd`): navegació amb teclat, ratolí i comandament, opcions que es conserven, i saltar la repetició també en CPU contra CPU.
- **Gamepad als menús:** Godot 4.7 no posava el comandament a `ui_accept` ni a `ui_cancel`. Ara s'hi posa (A i B).
- **Rendiment:** el HUD costa menys de 0,1 ms per fotograma, i els fps són els de la fase 4.
- **Pendent:** provar a mà el comandament físic i els canvis de mode de finestra. Els volums es podran sentir a la fase 6.
- La interfície continua construïda des del codi, i no amb `.tscn`.
- Decisions: `docs/decisions/0008`.

### Fase 6: àudio i sensacions (1 setmana)

**Feina:**

- Mostres de so amb llicència CC0 o gravades per tu:
  - els cops de pal (push, hit, slap);
  - la pilota contra la gespa i el cop contra la taula de fons de la porteria;
  - el xiulet i l'ambient de grada amb reaccions.
- Busos d'àudio: Mestre, Ambient, Efectes i Interfície.
- Vibració del comandament en xuts, entrades i gols.

**Acceptació:**

- No hi ha saturació.
- Els volums són ajustables.
- El so respon a tots els esdeveniments.

**Fet (6/11/2026).**
- **Sons:** reals i CC0, de Kenney (cops, porteria, interfície), de BigSoundBank (públic) i de Wikimedia Commons (un xiulet d'àrbitre real, que substitueix un xiulet de plàstic poc realista). Els prepara `tools/prepare_audio.gd`.
  - El pal sona més fort com més de pressa va la pilota.
  - El gol baix fa el «bum» de la taula de fons i el gol alt sona a la xarxa.
  - La pilota sona en caure a la gespa.
  - El públic és petit, com el del camp de l'Iluro: murmura, s'anima a prop de la porteria i als córners curts, i crida i aplaudeix els gols.
  - Els cops sonen en 3D al lloc on passen.
- **Busos:** General, Ambient, Efectes i Interfície, amb un limitador al Master.
- **Ajustos després de la prova de l'usuari:** el públic sonava massa fort i s'ha baixat. La càmera àmplia passa a ser la de per defecte.
- **Vibració del comandament:** en xuts, entrades i gols de l'humà. Es pot desactivar.
- **Acceptació:**
  - **No satura:** gravant un partit amb gols (`tools/audio_check.sh`), el pic és de −0,5 dBFS, el sostre del limitador, i cap mostra no queda retallada.
  - **Volums ajustables:** els volums són a les opcions.
  - **Tots els esdeveniments sonen:** una prova comprova que cada tipus d'esdeveniment que emet la simulació té so o una raó per no tenir-ne.
- **Pendent:** escoltar-ho a mà, amb un comandament físic per a la vibració. Els sons s'han triat i ajustat analitzant-los, sense escoltar-los.
- Decisions: `docs/decisions/0009`.

### Fase 7: optimització i qualitat (1 setmana)

**Feina:**

- Perfilar amb el perfilador de Godot i el *visual profiler*.
- Definir els presets *Baixa*, *Mitjana*, *Alta* i *Ultra* (FSR, SSAO, mida de les ombres, LOD).
- Precompilar els *shaders* amb una escena d'escalfament al menú.
- Provar en 2 o 3 PC diferents.

**Acceptació:**

- Es compleixen els objectius de la secció 1.
- No hi ha estrebades de més de 50 ms durant el partit.
- La memòria es manté per sota d'1,5 GB.

**Fet (6/11/2026).**
- **Perfilar:** `tools/perf.sh` juga un partit sencer des del menú i mesura cada fotograma (simulació, scripts, CPU del render, GPU, *pipelines* compilats i memòria). Substitueix el perfilador de l'editor, que no es pot automatitzar.
- **Estrebades arreglades:**
  - en començar el partit, de 147 a 15–24 ms amb *Ultra*: escalfament de *shaders* i jugadors reaprofitats entre partits;
  - en tornar al menú, de 64 a 15 ms;
  - la primera vegada que sona cada so, fins a 10 ms: ara es carreguen en obrir el joc.
- **Escalfament de *shaders*:** en obrir el joc, sota una cortina «Carregant», la càmera passa pels angles del partit, de tarda i de nit, amb tot el HUD.
- **Presets:**
  - hi ha LOD (de 4 px a *Baixa* a 0,5 px a *Ultra*) i un nombre de focus de nit que fan ombra (2, 4, 6 i 6);
  - només el mapa d'ombres de la llum que es fa servir té la mida del preset;
  - el primer cop, la qualitat es tria segons la gràfica.
  - L'FSR 2.2 no és a cap preset, perquè en una integrada a 1080p fa anar el joc més lent. Continua a les opcions.
- **Controlador:** Vulkan, fixat. Amb Direct3D 12 anava un 40 % més lent i tenia estrebades del controlador. El renderitzador Compatibility (OpenGL) funciona.
- **Acceptació** (Intel Arc 130V integrada, 1080p, partit sencer):
  - **60 fps amb *Baixa*:** en fa 185, i el 1 % més lent no baixa de 154.
  - **144 fps a 1440p amb *Alta* en una GPU mitjana:** aquí no es pot mesurar. *Alta* a 1440p fa 76–104 fps en aquesta integrada, i l'estimació per a una GPU mitjana és de 190–310.
  - **Cap estrebada de més de 50 ms:** el pitjor fotograma del partit és de 25 ms, amb qualsevol preset, de tarda i de nit, també el primer cop que s'obre el joc.
  - **Memòria:** el pic és d'1,34 GB, amb *Ultra*.
- **Pendent:** provar-ho en altres PC (no n'hi havia cap més); la gespa de tarda surt més fosca amb Compatibility.
- Decisions: `docs/decisions/0010`.

### Després de la fase 7: millores visuals

**Fet (7/11/2026).** L'usuari va jugar i va demanar millores gràfiques una per una; després, una revisió de tot. Ho recull la decisió 0011: equip del porter, pilota de mida real que roda, pal amb ganxo i mans que l'agafen, sabatilles de colors, set complexions de Papis, postures ajupit o dret segons la jugada, cops amb el cos i estirada del porter, gespa i banquetes com les reals, i arbres, públic i cotxes en 3D fets amb codi. La simulació no canvia. Rendiment: 119–140 fps amb *Alta* i cap estrebada de més de 50 ms durant el partit.

### Fase 8: exportació i distribució (2–3 dies)

**Feina:**

- Preset *Windows Desktop* x86_64 amb aquesta configuració:
  - PCK incrustat;
  - icona (escut);
  - versió 1.0.0;
  - nom del producte.
- Opcional: signatura amb SignTool.
- Opcional: un workflow de GitHub Actions que executi les proves amb gdunit4-action i exporti el joc.

**Acceptació:** en un Windows 11 net (sense eines de desenvolupament), es descomprimeix el zip, s'executa el joc i es pot jugar un partit complet. Per fer la prova, serveix Windows Sandbox (Windows 11 Pro o Enterprise) o una màquina virtual. Les dades queden a `%APPDATA%`.

---

## 10. *Prompts* per arrencar cada fase

Són per enganxar a Claude Code en mode Plan.

- **Fase 0.** «Llegeix docs/pla-pc.md (seccions 4, 5 i 6) i crea l'esquelet del projecte Godot 4.7.2: project.godot, carpetes, .gitignore, .gitattributes amb LFS, els scripts de tools/ i una prova d'exemple amb gdUnit4. Escriu també tools/golden_web.js per extreure estadístiques de la versió web. No implementis encara lògica de joc. Executa les proves i ensenya'm el resultat.»
- **Fase 1.** «Portarem la simulació. Llegeix reference/web/index.html per blocs segons el mapa de la secció 8 i proposa l'ordre de feina. Comença per les constants, els equips i la pilota, amb proves. Després les regles i després la IA. Proves verdes i un commit després de cada bloc. Al final, executa sim.sh 50 i compara amb el fitxer de referència.»
- **Fase 2.** «Crea scenes/main.tscn amb un camp pla, càpsules i una esfera que llegeixin l'estat de match_sim. Afegeix una càmera TV, l'InputMap per a teclat i comandament, un HUD mínim i la pausa. Fes captures amb shot.sh i revisa-les.»
- **Fases 3–8.** Fes servir el mateix patró: objectiu de la fase, els criteris d'acceptació d'aquest pla i les captures de la versió web com a referència visual.

---

## 11. Riscos i mitigacions

| Risc | Impacte | Mitigació |
|---|---|---|
| No hi ha animacions d'hoquei fetes | Alt | Locomoció genèrica més IK al pal i poques animacions pròpies. Començar amb poses simples i polir-les després. |
| El comportament divergeix de la versió web | Mitjà | Estadístiques de referència, proves de regles i llavor determinista. |
| El fitxer de referència és massa llarg per al context de Claude | Mitjà | Lectura per blocs (secció 8), `CLAUDE.md` i una conversa per tasca. |
| Godot sobreescriu canvis fets per Claude a escenes obertes | Mitjà | Desar o tancar l'escena abans de demanar-hi canvis, i tenir activada la recàrrega automàtica. |
| Estrebades en compilar *shaders* | Mitjà | Escena d'escalfament i compilació de *pipelines*. |
| Gràfiques antigues sense D3D12 ni Vulkan | Baix | Accés directe amb el renderitzador *Compatibility*. |
| SmartScreen o l'antivirus avisen d'un `.exe` sense signar | Mitjà | Signatura de codi (fase 8) o instruccions per a l'usuari. No fer servir empaquetadors. |
| Canvis en passar de Godot 4.7 a 4.8 | Baix | Mantenir la 4.7.2 fins a la v1 i migrar en una branca a part. |
| Compatibilitat entre gdUnit4 i la versió de Godot | Baix | Fixar la versió de l'addon dins del repositori. |
| **Drets dels escuts i noms dels clubs** | Alt si es publica | Per a ús privat no hi ha problema. Abans de distribuir-lo públicament, cal el permís de l'Iluro HC i del Club Polo. |
| Llicències dels assets | Mitjà | Mixamo permet fer servir les animacions dins del joc, però no redistribuir-ne els fitxers en brut. Preferir assets CC0 i portar un registre a `assets/LICENSES.md`. |
| Límits d'ús del pla de Claude | Mitjà | Treballar per fases, mantenir el context net i fer commits freqüents. |
| No hi ha *sandbox* a Windows natiu | Mitjà | Modes Manual o Accept edits, regles `deny` i commits petits. |

---

## 12. Fonts

- [Claude Code: configuració i instal·lació](https://code.claude.com/docs/en/setup)
- [Claude Code a VS Code](https://code.claude.com/docs/en/vs-code)
- [Claude Code: permisos](https://code.claude.com/docs/en/permissions)
- [Claude Code: memòria i CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Claude Code: hooks](https://code.claude.com/docs/en/hooks-guide)
- [Godot 4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable)
- [Arxiu de versions de Godot](https://godotengine.org/download/archive)
- [Godot: exportar per a Windows](https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_windows.rst)
- [Godot: línia d'ordres](https://github.com/godotengine/godot-docs/blob/master/tutorials/editor/command_line_tutorial.rst)
- [Godot: editor extern](https://github.com/godotengine/godot-docs/blob/master/tutorials/editor/external_editor.rst)
- [godot-tools per a VS Code](https://github.com/godotengine/godot-vscode-plugin)
- [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (abans a MikeSchulze/gdUnit4)
- [gdtoolkit (gdformat, gdlint)](https://pypi.org/project/gdtoolkit)
- [Blender (descàrrega)](https://www.blender.org/download/)
- [winget: GodotEngine.GodotEngine](https://winget.ragerworks.com/package/GodotEngine.GodotEngine)
- [Mixamo: FAQ de llicències](https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/td-p/13234775)
