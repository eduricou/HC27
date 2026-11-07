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
- **Revisió (7/11/2026):** l'usuari va demanar revisar la pilota, el pal i com l'agafen les mans. Abans, la pilota feia 24 cm i no girava, el pal era de caixes i gairebé vertical, i les dues mans anaven juntes dalt de tot sense tancar els dits. Ara:
  - **Pilota** (`BallView`):
    - té la mida real (7,3 cm de diàmetre);
    - des de les càmeres de lluny es dibuixa més gran perquè no faci mai menys de 7 px d'alt a 1080p;
    - roda sense lliscar segons com es mou, i a l'aire manté el gir;
    - té la costura i una marca perquè es vegi girar, i una ombra de contacte a terra.
  - **Pal** (`StickMesh`, fet amb codi):
    - fa 93 cm i té el cap en forma de J amb la cara plana a l'esquerra;
    - la canya és ovalada i el puny és blanc, amb la franja de l'equip (colors de la web);
    - el cap reposa pla a terra si la canya s'inclina 32° (`LIE`) i no s'hi clava mai;
    - la pilota toca la cara del fons del ganxo al punt de control de la simulació, i quan el jugador la porta, on es veu la pilota.
  - **Mans** (`GripModifier3D`):
    - l'esquerra agafa dalt de tot i la dreta, més avall, tan avall com li arriba el braç (`RIGHT_REACH`), uns 15 cm més avall;
    - totes dues tenen el polze cap avall, com al golf;
    - cada mà segueix la línia de l'espatlla al pal, girada al voltant de la canya;
    - els dits es tanquen al voltant del puny: el punt on passa la canya i la flexió de cada falange s'han ajustat amb una cerca sobre l'esquelet, de manera que les articulacions queden a uns 2,5 cm de l'eix.
  - **Postura:** quiets o a poc a poc, els jugadors s'ajupen una mica més (malucs 0,6 rad i pelvis 24 cm avall) perquè la mà dreta pugui baixar per la canya.
  - **Física de la simulació:** no ha canviat. El fregament, el bot i la velocitat de la pilota són els de la web, que comprova l'oracle (decisió 0002).
- **Revisió (7/11/2026, sabatilles):** l'usuari va demanar millorar les sabatilles, que no fossin totes iguals. Abans, el peu del model era nu, amb els dits marcats, i estava pintat de negre. Ara:
  - **Malla** (`ShoeMesh`, feta amb codi):
    - sola gruixuda, amb el taló més alt i la punta una mica aixecada;
    - empenya que tapa el peu fins al turmell;
    - es mou amb els ossos com el peu del model: la punta, amb l'os dels dits, i el coll del darrere, una mica amb la cama.
  - **Dibuixos:** les tres ratlles, els cordons, el taló reforçat, la pestanya i la marca els fa el shader (`shoe.gdshader`) a partir de la posició dins la sabatilla, que va al color del vèrtex. Així una sola malla serveix per a tothom.
  - **Colors:**
    - cada jugador porta una de les 12 combinacions de la paleta (empenya, ratlles i sola);
    - es tria pel dorsal i l'equip, de manera que és sempre la mateixa i els companys no la repeteixen.
  - **Porters:** no en porten, perquè ja els tapen les xuteres.
  - **Peu de sota:** es pinta del color del mitjó, i si en surt un tros pel coll de la sabatilla, no es nota.
  - **Cost:** cap ombra pròpia (ja la fa el peu). La mesura del partit sencer (Alta, de nit) dona 139 fps, i cap fotograma passa de 16,4 ms.
- **Revisió (7/11/2026, complexions):** l'usuari va dir que els jugadors eren massa musculats i que en un equip de Papis hi ha cossos molt diferents.
  - **Per què no un model nou:** el paquet gratuït de Quaternius només té el cos de superheroi (els cossos normals són al de pagament), i sense Blender no se'n poden fer de nous. Per això el cos es deforma al shader i la malla no es toca.
  - **Músculs** (`KitMesh.shape_texture`):
    - un suavitzat de Taubin de la malla (30 passades, 46 ms en obrir el joc) dona, per a cada vèrtex, quant s'ha de moure per perdre el relleu dels músculs sense encongir el cos;
    - el shader (`player_kit.gdshader`) mou el vèrtex al llarg de la normal i, a més, aprima els trapezis, les espatlles, el pit, els dorsals, els braços i les cuixes;
    - la pell perd el relleu pintat de la textura, i la samarreta queda llisa.
  - **Complexió de cada jugador** (`PlayerRig.BUILDS`): prim i alt, normal, baix i fort, panxut, gran, atlètic, i baix i prim. Cada una té:
    - l'alçada, que va del 93 % al 106 % (el cos s'escala, i la passa es corregeix perquè els peus no rellisquin);
    - el gruix, la panxa i quant múscul perd.
  - **Repartiment:** la complexió es tria pel dorsal i l'equip, i és sempre la mateixa per a cada jugador.
  - **Què no es toca:** el cap, les mans i els peus, on van el casc, els guants i les sabatilles. Les zones es difuminen segons la posició en repòs perquè no s'obrin plecs entre les parts del cos.
  - **Rendiment** (partit sencer):

    | Qualitat | Fps de mitjana | Pitjor fotograma |
    |---|---|---|
    | Alta, de nit | 127–137 | 19–21 ms |
    | Baixa, de tarda | 203 | 13 ms |

    Una de les tres mesures a Alta va tenir una aturada puntual de 76 ms, que no es va repetir.
- **Revisió (7/11/2026, postura segons la jugada; la revisió final és a la decisió 0011):** l'usuari va demanar dues postures. Ajupit i amb el pal a terra quan el jugador porta la pilota, i més dret quan no la porta. I que els que no la porten només posin el pal a terra quan s'acosten a qui la porta per robar-la.
  - **Qui és a la jugada** (`MatchView.engagement()`, de 0 a 1):
    - el porter, sempre;
    - qui porta la pilota;
    - un rival de qui la porta, que s'hi acosta: comença a ajupir-se a 5 m i ho està del tot a 3 m (les entrades es fan a menys d'1,5 m);
    - amb la pilota lliure, qui n'espera la passada (de 9 a 5 m) i qui hi va a prop (de 4,5 a 2,5 m), perquè quan la rep ja tingui el pal a terra;
    - els companys de qui la porta, mai.
  - **Postura** (`PlayerRig.low`, suavitzat):
    - **a la jugada:** és l'ajupida d'abans;
    - **fora de la jugada:** el jugador s'inclina i doblega els malucs molt menys, gairebé no baixa la pelvis, i porta el pal aixecat, amb la pala a uns 30 cm de terra, davant i a la dreta (`CARRY_BLADE`, `TOP_HAND_UP`);
    - el canvi entre les dues és gradual (uns 0,4 s).
  - **Cops:** el gest del cop va per sobre de les dues postures.

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
