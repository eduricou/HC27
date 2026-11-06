# 0007 · Jugadors amb esquelet i animacions (fase 4)

**Data:** 6 de novembre de 2026 · **Estat:** acceptada

## Context

La fase 4 demana substituir les càpsules per jugadors amb esquelet i animacions:

- equipacions, porters i variacions;
- el pal a les mans;
- locomoció i accions disparades pels esdeveniments de la simulació.

Criteris d'acceptació:

- 22 jugadors animats a 60 fps amb *Baixa* en una gràfica integrada;
- sense peus que llisquin;
- un contacte coherent del pal amb la pilota;
- les equipacions correctes.

Blender no està instal·lat. L'usuari va triar recursos CC0 en lloc de Mixamo.

## Decisions

### 1. Recursos de Quaternius (CC0)

Es baixen d'itch.io amb l'opció gratuïta.

| Paquet | Què se'n fa servir |
|---|---|
| *Universal Base Characters* [Standard] | El cos d'home (65 ossos, ~12.500 triangles i 8 LOD), quatre pentinats amb barba inclosa, i les textures de pell clara i fosca. |
| *Universal Animation Library* 1 i 2 [Standard] | 9 animacions: repòs, caminar, córrer, esprintar, celebrar, protestar, cop rebut, estirada i entrada. |

- Ho registra `assets/LICENSES.md`.
- Les textures s'han reduït a 1024 px: els jugadors es veuen petits.
- Dels paquets només s'ha copiat el que es fa servir: uns 25 MB, a LFS.
- No s'ha fet servir el model de dona: la categoria és Papis (+35) masculina.

### 2. Les animacions es converteixen abans, no en temps real

`tools/build_player_anims.gd` les passa a l'esquelet del jugador i les desa a `assets/models/animations/players.res`.

- **Per què cal convertir-les:** els dos esquelets tenen els mateixos ossos, però el repòs és diferent (fins a 17° al coll). Copiar les pistes deformaria el cos.
- **Com es converteixen:** per a cada fotograma, es pren la rotació global de cada os respecte al seu repòs al maniquí i s'aplica al repòs del jugador. La pelvis s'escala per l'alçada.
- **Exportació:** els `.glb` originals hi són perquè l'eina es pugui tornar a executar, però no entren a l'exportació (`export_presets.cfg`).

### 3. L'equipació es pinta amb un shader i la malla no es toca

- `KitMesh` prepara una textura de dades amb un píxel per vèrtex: la posició en repòs i la part del cos (cap, tronc, braç o cama), segons l'os que hi pesa més. El shader la llegeix amb `VERTEX_ID`.
- `shaders/player_kit.gdshader` decideix on acaba cada peça de roba a partir de la posició en repòs: samarreta, coll, màniga, pantaló, mitja i sabata.
- **Equipacions** (la llista de comprovació del pla):

  | Equip | Com és |
  |---|---|
  | Iluro | La meitat de dalt blanca i la de baix taronja, coll negre en V, pantalons negres i mitges blanques. |
  | Polo | Samarreta blanca amb la franja blava marina i vermella, i pantalons i mitges de color blau marí. |
  | Porters | Mànigues llargues i guants. |

- **Dorsal:** a l'esquena, amb l'atles `assets/textures/players/digits.png`, que fa `tools/bake_textures.gd`.
- **Variacions per jugador** (`instance uniform`; tots els jugadors d'un equip comparteixen material):
  - el to de pell, que barreja les textures clara i fosca segons `Constants.SKINS`;
  - el color dels cabells, de `Constants.HAIRS`;
  - el dorsal.
- **Pentinats:** rapat, amb clenxa, llarg o calb, segons `p.hs`. Quatre de cada deu porten barba.
- **Per què així:** la malla, la pell i els LOD no canvien, i 22 jugadors només fan servir 4 materials.

### 4. Locomoció sense peus que llisquin

- Caminar, córrer i esprintar es barregen segons la velocitat (BlendSpace1D, `sync`).
- Tots tres cicles s'estiren a 1 s (`use_custom_timeline`) i comencen al mig del recolzament del peu esquerre. Així van en fase.
- El ritme, en cicles per segon, és la velocitat dividida per la passa interpolada (`PlayerRig.gait_rate()`).
- El repòs es barreja a part (Blend2) per sota de la velocitat de caminar.

| | Lliscament del peu de suport (1–9 m/s) |
|---|---|
| Abans de sincronitzar els cicles | 40–80 % entre els punts de mescla |
| Ara | ≤ 7 % |

Ho comprova `test_els_peus_no_rellisquen`, que hi posa un límit del 15 %.

### 5. Postura i pal

- **Postura** (`PostureModifier3D`): per sobre de l'animació, flexiona els genolls, doblega els malucs, inclina l'esquena i baixa l'espatlla del pal. Com més de pressa corre el jugador, menys postura s'hi afegeix, perquè les animacions de córrer ja van inclinades.
- **IK:** dos `TwoBoneIK3D`.
  - Cames: els peus es queden on els posa l'animació encara que la pelvis baixi.
  - Braços: les dues mans al pal.
- **El pal no va enganxat a la mà.** És una petita diferència amb el pla, que proposava un `BoneAttachment3D` a la mà dreta.
  - La pala és sempre al punt de control de la simulació (`stickPt`) i, durant el cop, segueix `stickWorld()` de la web: enrere, a la dreta i amunt.
  - Les mans van al mànec amb IK.
  - Així el contacte amb la pilota sempre quadra (ho comprova `test_el_pal_toca_on_toca_la_simulacio`).
  - Durant les accions de mans lliures, el pal passa a la mà dreta.

### 6. Accions

`MatchView.on_events` les dispara a partir dels esdeveniments de la simulació:

| Esdeveniment | Acció |
|---|---|
| Gol | El golejador ho celebra i el porter que encaixa protesta. |
| Aturada | Estirada del porter. |
| Entrada | El jugador s'hi llança, amb el pal a les mans. |
| Falta | Qui l'ha feta protesta. |
| Jugador tocat (`stun`) | Cop rebut. |

### 7. Porters

- Porten el mateix cos, amb l'equip enganxat als ossos: casc amb reixa, guardes, xuteres i guants.
- Fan servir la mateixa locomoció, amb més flexió de genolls.
- **Revisió (6/11/2026):** l'usuari va trobar que les guardes i el casc (caixes i una esfera) no semblaven reals. Ara l'equip es fa amb codi a `src/game/players/gk_gear.gd`, sense models nous:
  - **Guardes:** foam corbat davant la canyella, de sobre la xutera fins a sobre el genoll, amb genollera, ranures i una franja de color al costat de fora.
  - **Xuteres:** tapen la bota, amb la punta rodona i la sola fosca.
  - **Casc:**
    - la closca tapa el cap per dalt, pels costats i pel clatell, i deixa la cara a la vista;
    - té un ribet i una franja de color;
    - davant la cara hi ha una reixa de barres i, a sota, un protector de coll.
  - **Colors:** els ribets i les franges són del color de la samarreta del porter que més contrasta.
  - **Samarreta:** el porter la porta amb coll rodó, sense la V.
  - **Cost:** l'equip dels dos porters fa uns 28.000 triangles i triga uns 35 ms a fer-se. Es fa una sola vegada, en obrir el menú, i es reaprofita.

## Què queda pendent (i per què)

- **No hi ha animacions d'hoquei fetes a mà** (push, hit, slap i revés). No n'hi ha cap de CC0, i fer-les requereix Blender.
  - Ara el cop és procedural: el pal fa el gest de la web i els braços el segueixen amb IK.
  - Si s'instal·la Blender, es poden afegir com a OneShot sense tocar res més.
- **L'estirada del porter** fa servir una animació de lliscar (`Slide_Start`) que només s'hi assembla.
- **Els jugadors no tenen variacions de complexió.** La pell, els cabells, la barba i el dorsal sí que canvien.

## Mesures

`bash tools/bench.sh 10 <preset> <hora> [2560x1440]`, a l'Intel Arc 130V integrada, amb els 22 jugadors animats:

| Preset | Resolució 3D | Tarda | Nit |
|---|---|---|---|
| Baixa | 1920×1080 | 263 fps | 174 fps |
| Alta | 1920×1080 | — | 140 fps |
| Alta | 2560×1440 | — | 85 fps |

Pràcticament igual que amb les càpsules (decisió 0006). Muntar els 22 jugadors triga 150 ms la primera vegada (en obrir el menú, quan es carreguen els recursos) i 5 ms en cada partit nou.

## Com es comprova

- **Proves:** `tests/game/test_players.gd`. Comproven:
  - les regions de l'equipació;
  - la textura de dades;
  - les animacions i les seves velocitats;
  - que el pal toca on toca la simulació;
  - que les mans són al pal i els peus a terra;
  - que els peus no rellisquen;
  - el ritme de la passa;
  - les accions en un gol.
- **Captures de prop:** `bash tools/shot_views.sh jugador_davant,jugador_esquena,porter`.
  - Amb `--action=celebrate` a l'escenari `views`, tots els jugadors fan l'acció.
  - L'escenari `follow` segueix un jugador mentre juga: `"$GODOT" --path . --write-movie … -- --scenario=follow --cams=jugador_davant`.
- **Animacions:** si canvien, cal tornar a executar `"$GODOT" --headless --path . -s res://tools/build_player_anims.gd`.
