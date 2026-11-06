# 0010 · Optimització i qualitat (fase 7)

**Data:** 6 de novembre de 2026 · **Estat:** acceptada

## Context

La fase 7 demana:

- perfilar el joc;
- definir els presets *Baixa*, *Mitjana*, *Alta* i *Ultra* (FSR, SSAO, mida de les ombres i LOD);
- precompilar els *shaders* amb una escena d'escalfament al menú;
- provar el joc en 2 o 3 PC diferents.

Criteris d'acceptació:

- es compleixen els objectius de la secció 1 del pla (60 fps a 1080p amb *Baixa* en una gràfica integrada; 144 fps a 1440p amb *Alta* en una GPU dedicada de gamma mitjana);
- no hi ha estrebades de més de 50 ms durant el partit;
- la memòria es manté per sota d'1,5 GB.

## Decisions

### 1. Com es mesura: `tools/perf.sh`

Fins ara, `tools/bench.sh` donava els fps mitjans de 10 s de joc. Això no serveix per trobar estrebades. L'editor de Godot té un perfilador visual, però aquest projecte no fa servir l'editor i, a més, el perfilador no es pot automatitzar.

`bash tools/perf.sh [qualitat] [hora] [qlen]` fa un recorregut real i mesura cada fotograma (`PerfProbe`):

- **Recorregut:** 4 s de menú, un partit CPU contra CPU amb la llavor 1 (presentació, gols amb repetició, córners curts, descansos i final) i la tornada al menú. Per defecte, els quarts són de 40 s; un partit real en té 150.
- **Per fotograma:** el temps total i com es reparteix (simulació, scripts, preparació del render a la CPU i GPU), les crides de dibuix i les compilacions de *pipelines* de Godot.
- **Estrebades:** els fotogrames de més de 25 ms, amb el moment del partit (estat, càmera i esdeveniments).
- **Memòria:** la de Godot, la de vídeo i el pic del procés.
- **Sortida:** un resum per parts (menú, inici del partit, partit, menú final) i tots els fotogrames a `build/perf/<qualitat>_<hora>.csv`. Falla si durant el partit hi ha cap fotograma de més de 50 ms.
- **Opcions:**
  - `--fresh` esborra les memòries cau de *shaders*, com en un PC on el joc no s'ha obert mai;
  - `--vsync`, `--gpu-profile` (temps de GPU per passades, de Godot), `--no-warmup`;
  - `--d3d12` i `--compat` canvien el controlador o el renderitzador.

`Performance.TIME_PROCESS` no serveix per mesurar cada fotograma: és el màxim de cada segon. La sonda mesura cada fase amb els senyals `process_frame` i `physics_frame` de l'arbre.

### 2. El que s'ha trobat i com s'ha arreglat

| Problema | Causa | Solució | Abans → ara |
|---|---|---|---|
| El primer fotograma del partit s'encalla | Godot compilava 6 *pipelines* en dibuixar el que el menú no ensenya (la presentació des de l'aire i el HUD), i es muntaven de nou els 22 jugadors | Escalfament de *shaders* (punt 3) i reaprofitar els jugadors | *Ultra*: 147 → 15–24 ms · *Alta*: 39–44 → 14–23 ms |
| Tornar al menú s'encalla | Es muntaven 22 jugadors nous i s'alliberaven els vells | Si els jugadors són els mateixos, es reaprofiten (`MatchView._bind`) | 64–65 → 15 ms |
| Els sons s'encallen la primera vegada | Cada so es carregava el primer cop que sonava: els aplaudiments de la presentació allargaven aquell pas fins a 10 ms | `SfxBank.preload_all()` els carrega tots en obrir el joc | 10 → menys de 5 ms (el pas més llarg ara és el del gol) |
| Massa memòria amb *Ultra* | Amb l'escalfament quedaven reservats alhora els dos mapes d'ombres de 8192 (el del sol i el dels focus) | Només té la mida del preset el de la llum que es fa servir; l'altre queda a 256 | Pic del procés: 1,45 → 1,29 GB |

**La simulació no pesa.** Fa de mitjana 0,15–0,4 ms per fotograma, amb el so i les animacions dels esdeveniments inclosos. Per tant, no cal revisar la decisió 0003 (portar-la a C++).

**Godot 4.7 ja compila els *shaders* en segon pla.** Fins i tot amb les memòries cau esborrades, durant el partit no s'ha compilat cap *pipeline* en dibuixar. Les compilacions es concentraven en obrir el joc (sota la cortina, vegeu el punt 3) i en començar el partit.

### 3. Escalfament de *shaders* (`ShaderWarmup`)

En obrir el joc, una cortina amb el text «Carregant» tapa la pantalla uns quants fotogrames. Mentrestant:

- la càmera passa per 10 angles (l'inici de la presentació, la TV, el córner curt de cada porteria, els tres angles de la repetició, el primer pla del gol, i cap a la bardissa i cap al passeig), primer amb l'altra llum (tarda o nit) i després amb la que toca;
- es dibuixa tot el HUD alhora: la vinyeta, els rètols, les pantalles de pausa i descans, les franges i la cortineta.

Després, la cortina s'esvaeix i es veu el menú. Godot ja té creats els *pipelines* del partit, i canviar de tarda a nit al menú tampoc no s'encalla.

**Detalls:**

- Es torna a fer en tancar les opcions si s'ha canviat la qualitat. Si s'ha canviat durant un partit (pausa › opcions), es fa en tornar al menú.
- L'escalfament no canvia la mida dels mapes d'ombres: els *pipelines* no en depenen, i així mai no hi ha els dos mapes grans alhora.
- Mentre dura, la interfície no accepta entrada.
- No es fa als escenaris de captures, perquè la cortina hi sortiria.
- Encara queden lents els primers fotogrames en obrir el joc (uns 140 ms), però queden sota la cortina.
- A la fase 8, el *shader baker* de l'exportació (Godot 4.5 o posterior) pot escurçar també aquesta primera càrrega.

### 4. Presets (`Quality`)

| | *Baixa* | *Mitjana* | *Alta* | *Ultra* |
|---|---|---|---|---|
| Suavitzat | FXAA | MSAA 2x | MSAA 2x | MSAA 4x |
| Ombra del sol | 2048, 2 trams, 110 m | 4096, 3 trams, 120 m | 4096, 4 trams, 130 m | 8192, 4 trams, 150 m |
| Focus de nit que fan ombra | 2 | 4 | 6 | 6 |
| Mapa d'ombres dels focus | 2048 | 4096 | 4096 | 8192 |
| Filtre de les ombres | molt baix | baix | mitjà | alt |
| SSAO · SSIL | no · no | no · no | sí · no | sí · sí |
| LOD (`mesh_lod_threshold`) | 4 px | 2 px | 1 px | 0,5 px |

**Canvis d'aquesta fase:**

- **LOD:** és el llindar a partir del qual Godot passa a una versió més simple d'una malla (els jugadors en porten, generades en importar). Amb 4 px a *Baixa*, els triangles de nit baixen de 450–590 mil a uns 220 mil, i els fps pugen un 5–15 %. Des de la càmera de partit no es nota.
- **Focus que fan ombra:** cada focus amb ombra torna a dibuixar els 22 jugadors cada fotograma. Amb 2 focus en lloc de 6 (els dos del mig del passeig, `Stadium.SPOT_SHADOW_ORDER`), *Baixa* dibuixa la meitat de triangles. Amb *Mitjana*, 4 focus guanyen un 5 %.
- **Mapes d'ombres:** només el de la llum que es fa servir té la mida del preset (punt 2).
- **FSR 2.2 no forma part de cap preset:** en aquesta integrada, a 1080p, fa anar el joc més lent (*Baixa*: 139 fps amb FSR al 67 % contra 157–177 sense; *Alta*: 126 contra 142). Costa més del que estalvia. Continua a les opcions com una opció a part, pensada per a 1440p o 4K amb una gràfica dedicada.
- **El primer cop que s'obre el joc**, la qualitat es tria segons la gràfica (`Quality.for_adapter_type()`): *Alta* amb una de dedicada; *Baixa* amb una d'integrada o desconeguda. Les opcions ja desades no canvien.
- **Amb el renderitzador Compatibility** (`Quality.adapt_to_renderer()`) no hi ha FXAA, FSR, SSAO ni SSIL: hi posa MSAA 2x en lloc de l'FXAA i treu la resta, perquè Godot no avisi.

### 5. Controlador de gràfics: Vulkan

El pla deixava per a aquesta fase triar entre Direct3D 12 i Vulkan. Mesurats l'un darrere l'altre, amb el mateix partit (*Alta*, de nit):

| Controlador | Fps de mitjana | GPU | Pitjor fotograma |
|---|---|---|---|
| Vulkan | 136 | 7,0 ms | 18 ms |
| Direct3D 12 | 81 | 11,8 ms | 135 ms (dues vegades) |

Les dues estrebades de Direct3D 12 són del controlador: la simulació, els scripts i la CPU del render no passen de 3 ms, i la GPU dona una lectura impossible.

- Ens quedem amb Vulkan, que ja era el valor per defecte. Ara queda escrit a `project.godot` (`rendering_device/driver.windows`), perquè no canviï si canvia el valor per defecte de Godot.
- Si un PC no té Vulkan, Godot passa sol a Direct3D 12 (`fallback_to_d3d12`, actiu per defecte).
- **Compatibility (OpenGL 3.3)**, per a les gràfiques antigues: el joc s'hi pot jugar sencer, amb 95 fps de mitjana a *Baixa* i sense estrebades. Però de tarda la gespa surt més fosca que amb Forward+.

### 6. Provar en 2 o 3 PC

Només hi ha disponible el portàtil de desenvolupament (Intel Arc 130V integrada). En el seu lloc s'han provat els tres camins de render (Vulkan, Direct3D 12 i OpenGL) i el pitjor cas, amb les memòries cau de *shaders* buides. La prova en altres PC queda pendent.

## Mesures

`bash tools/perf.sh <preset> <hora> 20`: partit sencer amb quarts de 20 s i la llavor 1 (presentació, tres gols amb repetició, córners curts, descansos i final), a 1920×1080 sense VSync, amb Vulkan a l'Intel Arc 130V integrada.

| Preset | Hora | Fps de mitjana | 1 % més lents | Pitjor fotograma | GPU | Pic de memòria del procés |
|---|---|---|---|---|---|---|
| *Baixa* | nit | 185 | 6,5 ms (154 fps) | 13,9 ms | 5,0 ms | 0,97 GB |
| *Baixa* | tarda | 183 | 6,5 ms (155 fps) | 14,7 ms | 5,0 ms | 0,93 GB |
| *Mitjana* | nit | 152 | 7,9 ms (126 fps) | 17,8 ms | 6,1 ms | 1,24 GB |
| *Alta* | nit | 120 | 10,4 ms (97 fps) | 21,5 ms | 8,0 ms | 1,20 GB |
| *Alta* | tarda | 138 | 8,7 ms (115 fps) | 18,8 ms | 6,8 ms | 1,20 GB |
| *Ultra* | nit | 69 | 17,0 ms (59 fps) | 20,1 ms | 14,4 ms | 1,34 GB |
| *Ultra* | tarda | 73 | 15,8 ms (63 fps) | 25,0 ms | 13,4 ms | 1,34 GB |

- En cap cas no hi ha cap fotograma de més de 33 ms durant el partit, ni s'hi compila cap *pipeline* en dibuixar.
- **Primer cop, amb les memòries cau buides** (`--fresh`, *Alta*, nit): les compilacions (36 *pipelines*) queden totes al menú, sota la cortina. El primer fotograma del partit fa 19,9 ms i el pitjor del partit, 20,8 ms.
  - Sense l'escalfament (`--no-warmup`), en començar el partit se'n compilen 6 i aquell fotograma fa 22,8 ms amb *Alta*. Amb *Ultra* (MSAA 4x) en feia 147.
- **1440p** (`bash tools/bench.sh 8 alta <hora> 2560x1440`): *Alta* fa 76–86 fps de nit i 101–104 de tarda. Una GPU dedicada de gamma mitjana (RTX 3060 o RX 6600) és unes 2,5–3 vegades més ràpida que aquesta integrada, i n'hauria de fer de 190 a 310.
- **Compatibility** (*Baixa*, nit): 95 fps de mitjana, pitjor fotograma 27 ms i 1,0 GB.

Aquest portàtil varia molt: la GPU s'escalfa i baixa de velocitat (en un mateix partit, de 7 a 12 ms per fotograma i tornar). Les comparacions s'han fet una darrere l'altra i, si calia, alternant.

**Acceptació:**

- **60 fps a 1080p amb *Baixa* en una integrada:** complert. Aquí fa 185 fps, i el 1 % més lent no baixa de 154. Una Iris Xe o una Radeon Vega 8, que són unes 2–2,5 vegades més lentes que l'Arc 130V, haurien de fer 75–90 fps; cal confirmar-ho (vegeu «Què queda pendent»).
- **144 fps a 1440p amb *Alta* en una GPU mitjana:** no es pot mesurar aquí. L'estimació és de 190–310 fps.
- **Cap estrebada de més de 50 ms durant el partit:** complert amb tots els presets, de tarda i de nit, també amb les memòries cau buides. El pitjor fotograma és de 25 ms.
- **Memòria per sota d'1,5 GB:** complert. El pic és d'1,34 GB, amb *Ultra*, i d'1 GB amb *Baixa*. En aquesta integrada, la memòria de vídeo també compta com a memòria del procés; amb una gràfica dedicada, el procés en faria servir menys.

## Com es comprova

- **Proves:** `tests/game/test_perf.gd`, 9 proves.
  - Els presets van de més barat a més car (LOD, focus amb ombra, mides dels mapes).
  - La qualitat del primer cop segons la gràfica.
  - El preset per al renderitzador Compatibility.
  - Només el mapa d'ombres de la llum que es fa servir té la mida del preset, i l'escalfament no el toca.
  - *Baixa* fa ombra amb els dos focus del mig.
  - Els jugadors es reaprofiten entre partits i deixen l'acció que feien.
  - Tots els sons es carreguen d'entrada.
  - L'escalfament passa per tots els angles, de tarda i de nit, i ho deixa tot com estava.
  - La sonda compta només les estrebades del partit.
- **Rendiment:** `bash tools/perf.sh [qualitat] [hora] [qlen] [opcions]` i `bash tools/bench.sh`.

## Què queda pendent

- **Provar en altres PC:**
  - en una GPU dedicada de gamma mitjana, per confirmar els 144 fps a 1440p amb *Alta*;
  - en una integrada més antiga (Iris Xe o Radeon Vega 8), per confirmar els 60 fps a 1080p amb *Baixa*.
- **Compatibility:** de tarda, la gespa surt més fosca que amb Forward+.
- **Estrebades fora del partit:** els primers fotogrames en obrir el joc (sota la cortina), i els canvis de qualitat a les opcions.
