# Regles, constants i toleràncies d'equilibri

Font de veritat: `reference/web/index.html`. Si aquest document i la referència no coincideixen, mana la referència: corregeix el document.

## Constants (referència, línies 290–291)

| Constant | Valor | Significat |
|---|---|---|
| `FL` | 91,4 m | Llargada del camp (eix x) |
| `FW` | 55 m | Amplada del camp (eix y) |
| `HL`, `HW` | `FL/2`, `FW/2` | Mitja llargada i mitja amplada |
| `GHW` | 1,83 m | Mitja amplada de la porteria |
| `GH` | 2,14 m | Altura de la porteria |
| `GD` | 1,2 m | Fondària de la porteria |
| `CR` | 14,63 m | Radi del cercle (àrea de tir) |
| `DR` | 19,63 m | Radi de la línia discontínua (5 m fora del cercle) |
| `L23` | `HL − 22,9` | Posició de la línia de 23 m, mesurada des del centre |
| `PSPOT` | 6,475 m | Punt de penal |
| `STEP` | 1/60 s | Pas fix de la simulació |
| `QGAME` | 900 s | Durada d'un quart al rellotge del partit (15 min) |
| `TILT` | 0,78 | Inclinació de la càmera (només per al render, no va a `src/sim`) |

**Rellotge.** El rellotge del partit baixa a `QGAME / qlen` segons de joc per segon real (`tickClock`, línia 1026), on `qlen` és la durada real de cada quart. La web ofereix 90, 150 (per defecte) i 240 s. El rellotge no corre durant el servei del centre, la preparació d'un penal córner (fins a la injecció), les celebracions de gol ni les repeticions.

**Dificultat** (`DIFFS`, línia 322). En CPU contra CPU (`side = −1`), tots dos equips fan servir `normal`.

## Regles

Portades a `src/sim/rules.gd`, `ball_actions.gd` i `match_sim.gd`, i provades a `tests/sim/test_rules.gd`.

- **Gol** (`check_bounds`, `touch`).
  - Un toc dins del cercle d'atac fa que el gol sigui vàlid per a aquell equip (`ball.valid_for`).
  - Un toc fora del cercle, o que la pilota en surti, ho anul·la.
  - Si la pilota entra a la porteria (|y| < 1,83 m i z < 2,14 m) sense ser vàlida i l'últim toc és de l'atacant, és «gol anul·lat» i el defensor fa una sortida.
- **Sortida de fons.**
  - Si l'últim toc és de l'atacant, el defensor fa una sortida a 14,63 m de la línia de fons.
  - Si és del defensor, l'atacant treu un córner llarg a la línia de 23 m.
- **Banda.** Treu l'equip contrari al de l'últim toc, a 5 cm de la línia. Els rivals han de quedar a 5 m.
- **Faltes.**
  - Les entrades fallides poden fer falta. La probabilitat és més alta si l'entrada és per darrere o si el defensor és dins del seu cercle.
  - Una falta del defensor dins del seu cercle és penal córner.
  - Fora del cercle és cop franc al lloc de la falta. Si és un cop franc d'atac a menys de 5 m del cercle, es porta a la línia discontínua.
- **Peu.** Si un jugador de camp rep al seu cercle una pilota de més de 6 m/s que ve del rival, la referència xiula peu (penal córner) en un 30 % dels casos.
- **Penal córner** (`setup_pc`, `update_pc`).
  - Xuta el jugador amb més xut i injecta el que té més passada (el primer de la plantilla si n'hi ha dos d'iguals).
  - Quatre defensors, ordenats per defensa, es col·loquen a la línia de fons i la resta al mig del camp.
  - La CPU injecta al cap d'1,8 s.
  - Mentre la pilota no surt del cercle (`pc_pending`), cap toc fa vàlid el gol i només el que xuta la pot controlar.
  - El penal córner s'acaba al cap de 8 s o quan la pilota surt de la zona (radi `DR` + 2 m).
- **Quarts.**
  - El quart s'acaba quan el rellotge arriba a 0, però no mentre hi ha un penal córner en joc.
  - Serveix l'Iluro al 1r i al 3r quart, i el Polo al 2n i al 4t. Al 3r quart els equips canvien de camp.
  - Després d'un gol hi ha la repetició (10 s; es pot saltar) i serveix l'equip que l'ha rebut.

## Estadístiques de referència i toleràncies

Fitxer: `reference/golden/stats_web.json`, generat amb `node tools/golden_headless.mjs` (o enganxant `tools/golden_web.js` a la consola de DevTools).

Condicions: 50 partits CPU contra CPU, dificultat normal i `qlen = 150` s (el valor per defecte de la web). Les mitjanes són per partit i sumen els dos equips.

| Mètrica | Mitjana web | Desviació típica | Tolerància Godot |
|---|---|---|---|
| Gols (`goals`) | 6,74 | 2,64 | ±20 % → 5,39–8,09 |
| Xuts (`shots`) | 17,06 | 5,21 | ±20 % → 13,65–20,47 |
| Penals córner (`pcs`) | 5,58 | 2,73 | ±20 % → 4,46–6,70 |
| Xuts a porteria (`on`) | 15,46 | 4,83 | informativa |
| Faltes (`fouls`) | 25,78 | 5,20 | informativa |
| Possessió de l'Iluro (`poss_iluro`) | 0,50 | 0,03 | informativa |

`bash tools/sim.sh 50` compara automàticament les tres primeres mètriques i surt amb codi 1 si alguna queda fora del ±20 %. També informa del rendiment: l'objectiu és que els 50 partits acabin en menys de 3 minuts (`docs/decisions/0003`). Si no s'hi arriba, ho avisa però no falla.

**Compte amb `qlen`.** El nombre d'esdeveniments creix amb la durada real del quart, perquè la IA juga en temps real i el rellotge només n'escala la visualització. Amb `qlen = 90` s, la web dona 3,78 gols, 10,16 xuts i 3,92 penals córner per partit, que són els valors indicatius del pla original. Compara sempre amb el mateix `qlen` que el fitxer de referència (`meta.qlen`).

**Resultat de Godot (fase 1, 5/11/2026)**, amb `bash tools/sim.sh 50` (llavors 1–50):

| Mètrica | Godot | Web | Desviació |
|---|---|---|---|
| Gols | 7,26 | 6,74 | +7,7 % |
| Xuts | 17,06 | 17,06 | +0,0 % |
| Penals córner | 6,50 | 5,58 | +16,5 % |

Les desviacions són soroll de mostreig. El codi de la web executat amb les mateixes llavors 1–50 (`tools/oracle_web.mjs`) dona 7,26 gols, 17,06 xuts i 6,48 penals córner, i 49 dels 50 partits són idèntics als de Godot (vegeu `docs/decisions/0002`).

**Soroll estadístic.** Amb 50 partits, l'error típic de la mitjana de gols és d'un 6 % (2,64 / √50 / 6,74). El marge del ±20 % ho absorbeix, però si una mètrica queda a la vora, repeteix-ho amb `bash tools/sim.sh 200` abans de tocar la IA.
