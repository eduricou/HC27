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
| Exportar l'`.exe` i el zip | `bash tools/export.sh` |
| Regenerar la referència web | `node tools/golden_headless.mjs` |

## Estat

- **Fase 0 (preparació):** feta. Hi ha l'esquelet del projecte, les proves i el lint funcionen, les estadístiques de referència de la web estan generades i l'exportació d'un `.exe` buit funciona.
- **Fase 1 (simulació headless):** feta. `src/sim/` reprodueix la web pas a pas amb la mateixa llavor. Hi ha 43 proves, i les mitjanes de 50 partits queden dins del ±20 %. Un partit triga unes 10 s en un procés; 50 partits en paral·lel, 2–3 minuts, que és el criteri acordat (vegeu `docs/decisions/0003`).
- **Fase 2 (primer jugable amb caixes grises):** és la següent.
