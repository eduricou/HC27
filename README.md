# Estic Hoquei Herba (PC)

Port per a Windows 11 del joc web *Estic Hoquei Herba*: Iluro HC contra Club Polo, categoria Papis (+35), al Camp Municipal d'Hoquei de Mataró. Fet amb Godot 4.7.2 i GDScript.

- Pla del projecte: [docs/pla-pc.md](docs/pla-pc.md)
- Regles, constants i toleràncies: [docs/regles.md](docs/regles.md)
- Context per a Claude Code: [CLAUDE.md](CLAUDE.md)
- Versió web de referència (només lectura): [reference/web/index.html](reference/web/index.html)

## Posada en marxa

1. Instal·la les eines de la secció 3 del pla. Com a mínim: Git amb LFS, VS Code, Python amb gdtoolkit, i Godot 4.7.2 a `C:\Tools\Godot` amb les plantilles d'exportació.
2. Obre aquesta carpeta (`estic-pc`) a VS Code i accepta les extensions recomanades (Claude Code i godot-tools).
3. Obre el projecte a l'editor de Godot (`project.godot`) i activa la recàrrega automàtica de scripts (pla, secció 4.1).

## Ordres habituals (Git Bash)

| Què | Ordre |
|---|---|
| Proves | `bash tools/test.sh` |
| Format i lint | `bash tools/lint.sh` |
| Estadístiques de la simulació | `bash tools/sim.sh 50` |
| Captura de pantalla | `bash tools/shot.sh menu` |
| Captures des dels angles fixos (Godot / web) | `bash tools/shot_views.sh` · `node tools/shot_web.mjs` |
| Regenerar les textures de l'estadi | `bash tools/bake_textures.sh` |
| Recorregut automàtic (menú → partit → final) | `bash tools/smoke.sh` |
| Fps (preset, tarda o nit, 1440p) | `bash tools/bench.sh 10 baixa nit` · `bash tools/bench.sh 10 alta nit 2560x1440` |
| Exportar l'`.exe` i el zip | `bash tools/export.sh` |
| Regenerar la referència web | `node tools/golden_headless.mjs` |

## Estat

- **Fase 0 (preparació):** feta. Hi ha l'esquelet del projecte, les proves i el lint funcionen, les estadístiques de referència de la web estan generades i l'exportació d'un `.exe` buit funciona.
- **Fase 1 (simulació headless):** feta. `src/sim/` reprodueix la web pas a pas amb la mateixa llavor. Hi ha 43 proves, i les mitjanes de 50 partits queden dins del ±20 %. Un partit triga unes 10 s en un procés; 50 partits en paral·lel, 2–3 minuts, que és el criteri acordat (vegeu `docs/decisions/0003`).
- **Fase 2 (primer jugable amb caixes grises):** feta. Hi ha camp pla amb línies, jugadors com a càpsules, càmera TV, teclat i comandament, HUD mínim, pausa, descansos i menú amb un partit de fons. Va a uns 355 fps a 1080p.
- **Fase 3 (estadi i gespa):** feta. El camp és el real de l'Iluro al carrer Galícia: gespa amb shader, passeig amb banquetes i públic, tanques amb pancartes, bardissa i talús, torres de llum, casetes del club, el carrer amb cases i la ciutat al fons. També hi ha porteries amb xarxa que es mou, llum de tarda i de nit, i presets de qualitat. Fa 175–236 fps amb *Baixa* a 1080p i 76–100 fps amb *Alta* a 1440p en una gràfica integrada (`docs/decisions/0005` i `0006`).
- **Fase 4 (jugadors riggejats i animacions):** feta. Els jugadors són models amb esquelet (Quaternius, CC0) amb les equipacions de l'Iluro i del Polo, dorsals, pell, cabells i barbes variats, i porters amb casc i proteccions. Corren sense que els peus rellisquin, porten el pal amb les dues mans i la pala toca la pilota on toca la simulació; celebren els gols i protesten les faltes. Fa 174–263 fps amb *Baixa* a 1080p (`docs/decisions/0007`).
- **Fase 5 (càmeres, repeticions, HUD i menús):** és la següent.
