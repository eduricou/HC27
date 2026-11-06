# 0008 · Càmeres, repeticions, HUD i menús (fase 5)

**Data:** 6 de novembre de 2026 · **Estat:** acceptada

## Context

La fase 5 demana:

- les càmeres de presentació, de gol i de repetició multiangle a càmera lenta, i una càmera nova darrere de la porteria per als córners curts;
- el HUD complet (marcador amb escuts, minimapa, indicador del jugador, rètols, descans i final);
- el menú del partit;
- unes opcions desades a `user://`.

Criteris d'acceptació:

- tots els menús es poden fer servir només amb el teclat, només amb el ratolí o només amb el comandament;
- les opcions es conserven en reiniciar el joc;
- la repetició es pot saltar.

## Decisions

### 1. La interfície continua construïda des del codi

La decisió 0004 deia que la fase 5 refaria el HUD i el menú amb escenes (`scenes/ui/*.tscn`). Finalment no s'ha fet: cada pantalla és una classe de `src/ui/` que es construeix sola.

**Per què:**

- Moltes parts depenen de les dades: les files d'estadístiques, els golejadors, les caselles de tecles i les resolucions que caben a la pantalla.
- Les proves poden crear qualsevol pantalla amb `.new()` i navegar-hi sense pantalla (`tests/game/test_ui.gd`).
- Escriure molts `.tscn` a mà, sense l'editor, és fràgil.

**Com està organitzat:** els colors, les lletres, els escuts i el tema són a `UiKit`. Les pantalles són aquestes:

| Pantalla | Classe |
|---|---|
| HUD del partit | `Hud` |
| Pausa | `PauseScreen` |
| Descans i final | `BreakScreen` |
| Menú principal | `MainMenu` |
| Opcions | `OptionsScreen` |

Amb peces auxiliars: `Minimap`, `PlayerMarker`, `Wipe`, `MenuPlate` i `KitPreview`.

### 2. Lletres i escuts com a la web

- **Lletres** (OFL, a `assets/fonts/`): Big Shoulders Display (títols, gruix 900), Barlow Condensed (interfície) i Barlow (text). Són les mateixes que la web carrega de Google Fonts. L'espaiat de les etiquetes en majúscules es fa amb `FontVariation.spacing_glyph`.
- **Escuts** (`assets/crests/iluro.svg` i `polo.svg`): port de `drawCrest()`. Són dissenys originals de la web amb els colors de cada club.
- **Equipacions del menú:** a diferència de la web, que les dibuixa en 2D, són els jugadors 3D en repòs dins d'un `SubViewport`, el porter i un jugador de camp de cada equip.
  - Aquestes dues vistes només es dibuixen amb el menú obert, perquè cadascuna costa temps de GPU.

### 3. Càmeres (`CameraRig`)

| Mode | Quan | Com |
|---|---|---|
| TV | Per defecte | Com la web (`tvTarget()`). Amb l'opció «Àmplia», més alta i més lluny. |
| Presentació | Mentre dura `intro_t` (4,2 s) | Vol des de l'aire fins a la posició de la TV, amb sortida i arribada suaus (`camTarget()`). |
| Gol | 0,7 s després del gol | Primer pla del golejador. |
| Repetició | Mentre dura la repetició | Tres angles amb talls entre ells (vegeu més avall). |
| Córner curt | Des de la preparació fins que s'acaba la jugada (`pc_live`) | Darrere de la porteria que es defensa, a 8 m d'alçada. Es pot desactivar a les opcions. |

**Repetició:**

- La simulació ja la passa a mitja velocitat, com la web: 300 fotogrames gravats triguen 10 s.
- Els angles depenen dels fotogrames que falten per al gol:

  | Angle | Quan |
  |---|---|
  | Alta, per darrere de la jugada | Fins a 200 fotogrames abans del gol |
  | Arran de gespa, des de la banda | Fins a 100 fotogrames abans del gol |
  | Darrere de la porteria (la de la web) | El xut i el gol |

- No s'ha canviat la durada de la repetició ni s'ha repetit la jugada dues vegades, perquè això toca la simulació i l'oracle deixaria de coincidir (decisió 0002).

**Controls amb la càmera del córner curt:** la direcció es gira amb la càmera, de manera que amunt a la pantalla és cap on mira la càmera.

- El gir només s'actualitza quan es deixa anar la palanca o les fletxes (`HumanController.angle`): en un canvi de càmera, el jugador no canvia de rumb de cop.
- Amb la TV el gir és 0 i tot queda exactament com a la web.

### 4. Saltar la presentació i la repetició

- La simulació ja les salta amb PASSA, XUTA o `tap_e`.
- Ara `MatchRunner` també llegeix l'entrada durant la presentació i la repetició quan no hi ha cap jugador humà (CPU contra CPU), com fa la web.
- L'acció `skip` (clic del ratolí i Retorn) omple `tap_e`.

### 5. HUD

Port de les línies 50–80 del CSS i 1870–1938 de la web:

- **Marcador:** escuts, ILU i POL, resultat (que s'il·lumina de taronja en marcar), quart, rellotge i l'etiqueta PAPIS. A sota, qui porta la pilota.
- **Minimapa:** el camp es dibuixa una sola vegada i els jugadors són una textura petita pintada amb el color de cada un.
  - La primera versió costava 0,45 ms per fotograma.
  - Ara el HUD sencer en costa menys de 0,1.
- **Indicador del jugador controlat:** dorsal i nom damunt del cap, resistència i potència als peus, i la línia de xut mentre es carrega.
- **Rètols:** n'hi ha dos tipus.
  - El normal, amb la vora del color de l'equip.
  - El de gol, gran sobre el color de l'equip.
- **Etiqueta REPETICIÓ i franges de cinema:** durant la presentació i la repetició.
- **Cortineta:** l'escut de l'equip sobre una franja taronja i blau marí, de 0,8 s, que tapa el tall entre el gol i la repetició.
- **Vinyeta**.
- **Botó de pausa:** per jugar només amb el ratolí.
- **El minimapa s'amaga** a la presentació, a la repetició i amb la càmera del córner curt, perquè tapa la porteria.

### 6. Opcions (`GameSettings`, `OptionsScreen`)

- Es desen a `user://opcions.cfg` amb `ConfigFile`. A Windows, el fitxer és a `%APPDATA%\Godot\app_userdata\Estic Hoquei Herba\`.
- Contingut:

  | Grup | Què es desa |
  |---|---|
  | Pantalla | Mode de finestra (finestra, pantalla completa o completa exclusiva), resolució de la finestra, VSync, límit de fps, qualitat, escala FSR 2.2 i càmera dels córners curts. |
  | So | Volums de quatre busos: General, Ambient, Efectes i Interfície (`AudioBuses`). La fase 6 hi posarà els sons. |
  | Tecles | Fins a tres tecles i dos botons del comandament per acció. Amb el comandament, moure's sempre és amb la palanca esquerra i la creu. Una tecla només pot fer una acció. |
  | Partit | Les darreres eleccions del menú. |

- Cada canvi s'aplica i es desa a l'acte.
- `--quality` de la línia d'ordres mana sobre l'opció desada.
- Els escenaris de proves i captures no llegeixen ni desen el fitxer.
- **FSR 2.2:** amb una escala per sota de 1, el 3D es dibuixa a menys resolució. En aquest cas no s'aplica l'MSAA ni l'FXAA del preset, perquè FSR ja suavitza.

### 7. Navegació amb teclat, ratolí i comandament

- Tots els menús fan servir els botons i lliscadors de Godot amb el focus automàtic.
- El focus es veu amb una vora taronja, o blanca sobre els botons taronja.
- **Godot 4.7 no posa cap botó del comandament a `ui_accept` ni a `ui_cancel`.** `InputActions.ensure()` hi afegeix A i B. Sense això, amb el comandament no es podia acceptar res als menús.
- Esc o B: tornen enrere a les opcions i tanquen la pausa.

## Mesures

`bash tools/bench.sh 10 <preset> <hora> [2560x1440]`, a l'Intel Arc 130V integrada:

| Preset | Resolució 3D | Tarda | Nit |
|---|---|---|---|
| Baixa | 1920×1080 | 253 fps | 177 fps |
| Alta | 1920×1080 | — | 138 fps |
| Alta | 2560×1440 | — | 88 fps |

Són les mateixes xifres que a la fase 4 (decisió 0007). Aquest portàtil varia molt d'un moment a l'altre (en una mateixa sessió, la fase 4 va donar entre 121 i 179 fps de nit), així que les comparacions s'han fet alternant execucions amb el HUD i sense.

## Com es comprova

- **Proves:** `tests/game/test_ui.gd`, 16 proves.
  - Les opcions es desen i es tornen a llegir, i els valors dolents no trenquen res.
  - Tecles i comandament.
  - Busos d'àudio.
  - Modes de càmera i angles de la repetició.
  - Controls relatius a la càmera del córner curt.
  - La presentació i la repetició es poden saltar, també en CPU contra CPU.
  - Navegació:
    - al menú principal, a les opcions (les tres pestanyes), a la pausa i al descans s'arriba a tots els botons amb les fletxes, i s'hi pot fer clic;
    - al menú principal, a més, s'hi fan servir fletxes, creu del comandament, A, Retorn i un clic de ratolí reals;
    - es pot reassignar una tecla i un botó del comandament.
- **Captures:** `bash tools/shot.sh <escenari>`. Escenaris nous:
  - `goal`: fins al primer gol, amb la càmera del gol, la cortineta i la repetició (`--after=<segons>` avança més);
  - `options` (`--tab=0|1|2`);
  - `menu --controls=1`.

## Què queda pendent

- Els volums no es poden sentir fins a la fase 6, quan hi hagi sons.
- Cal provar a mà, amb un comandament físic i un monitor real, la navegació i els canvis de mode de finestra i de resolució. Les proves simulen els esdeveniments i, sense pantalla, el canvi de finestra no fa res.
- La repetició té talls d'angle, però no repeteix la jugada des de més d'un angle (vegeu el punt 3).
