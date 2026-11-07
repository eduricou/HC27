# 0011 · Millores visuals després de la fase 7

**Data:** 7 de novembre de 2026 · **Estat:** acceptada

## Context

Amb la fase 7 acabada, l'usuari va jugar i va demanar una sèrie de millores gràfiques, una per una:

1. el casc i les guardes del porter;
2. la pilota (mida i moviment), el pal i com l'agafen les mans;
3. les sabatilles, que no fossin totes iguals;
4. els cossos, massa musculats, i que hi hagués complexions diferents;
5. dues postures: ajupit i amb el pal a terra amb la pilota, i més dret sense;
6. la gespa, les banquetes (amb una foto de les reals) i els arbres.

Després va demanar revisar-ho tot i aplicar les millores que sortissin de la revisió.

Les decisions de cada part s'han anotat com a revisions dins de les decisions anteriors. Aquesta decisió les recull i hi afegeix les de la revisió final:

- jugadors: [0007](0007-jugadors-fase-4.md);
- camp: [0006](0006-camp-real-iluro.md).

## Principis comuns

- **Res de models nous:** Blender no està instal·lat, i el paquet gratuït de Quaternius només té el cos de superheroi. Tot el que és nou es fa amb codi:
  - equip del porter (`GkGear`);
  - pal (`StickMesh`);
  - sabatilles (`ShoeMesh`);
  - banquetes (`Dugout`);
  - arbres i bardissa (`TreeMesh`);
  - públic (`SpectatorMesh`);
  - cotxes (`CarMesh`).

  Totes fan servir `MeshPart` (`src/game/mesh_part.gd`), que omple una malla amb graelles, tubs, quads i caixes, amb colors per vèrtex i, si cal, ossos i pesos.
- **Cada malla es fa una sola vegada** i es reaprofita:
  - per equip: el pal i l'equip del porter;
  - per a tots: les sabatilles, el públic i els cotxes.

  Els colors que canvien es posen per instància (*instance uniforms* o dades de MultiMesh). Les repeticions (arbres, públic, cotxes) van amb MultiMesh.
- **La simulació no es toca.** Tot és presentació. La física de la pilota continua sent la de la web (decisió 0002); l'usuari va dir que ja li està bé com frena.
- **Cada canvi es comprova** amb captures (`tools/shot_views.sh` i escenes de prova), amb proves automàtiques i amb `tools/perf.sh`. Les mesures són a l'Intel Arc 130V integrada.

## Decisions de la revisió final

### 1. Les mans no deixen el pal corrent

**Problema:** corrent amb la pilota, la mà dreta quedava a 13–19 cm de la canya.

**Causes:**
- l'abast del braç era massa gran;
- les espatlles eren les del fotograma anterior, i corrent es mouen fins a 25 cm a cada passa;
- corrent, el jugador s'adreçava massa.

**Solució:**
- El pal es col·loca dins de l'actualització de l'esquelet (`StickPlacer`, un `SkeletonModifier3D` entre la postura i la IK dels braços).
- Si els braços no hi arriben, la canya s'inclina cap a les espatlles (cerca binària).
- L'abast del braç és el real (52 cm) i s'escala amb l'alçada de cada jugador.
- A la jugada, el jugador continua ajupit també corrent.

**Resultat:**
- les mans queden a menys d'1,3 cm del pal, i 2,5 cm com a molt esprintant;
- ho comprova `test_mans_al_pal_corrent_amb_la_pilota`.

### 2. Ajupits al penal córner

Al córner, tots els que el juguen esperen ajupits i amb el pal a terra fins que s'acaba la jugada: els atacants a la vora de l'àrea i els defensors a la porteria, és a dir, els que són a menys de 18 m de la porteria (`MatchView.engagement()`, amb `pc_live`).

### 3. L'horitzó de la càmera ampla

La càmera ampla és la que fa servir l'usuari per defecte. El terç de dalt era boira grisa i es veia on s'acabava el terra. Ara:

- **Terra:** fa 8 km, i el pla de tall de la càmera és a 6 km.
- **Boira:** és suau i té el color del peu de les muntanyes del cel.
- **Conreus:** lluny del camp hi ha camps de conreu amb marges, en el mateix shader de la gespa.
- **Arbres de lluny:** hi ha grups de pins i d'arbres, amb menys polígons i sense ombra.
- **Vista de TV:** res d'això no es veu des de la càmera de TV.

### 4. Públic i cotxes en 3D

- **Públic:**
  - les persones planes de cartró (un atles d'imatges) s'han canviat per persones en 3D amb sis siluetes d'alçades, gruixos i postures diferents;
  - els colors de roba, pell i cabell són de cada persona (`spectator.gdshader`);
  - es belluguen i salten amb els gols, com abans.
- **Cotxes:** en lloc de dues caixes, són turismes amb vidres, rodes, fars i pilots, cada un d'un color (`car.gdshader`).

### 5. Cops i estirada del porter

Les animacions de Quaternius no tenen cops d'hoquei ni estirades. Es fan amb codi:

- **Cops:** el tronc gira cap al pal i l'espatlla dreta baixa segons la força del cop (la velocitat de la pilota). Amb un xut fort, el pal fa un arc un 40 % més alt.
- **Porter:** cau de costat cap a on és la pilota, fent pivot al peu, i s'aixeca (0,95 s).

### 6. Arbres de nit

De nit, la llum dels focus que rebota al camp arriba als arbres de prop, sobretot a la cara que hi mira (`tree.gdshader`). Abans eren siluetes negres.

### 7. Endreça

- **Pal i mans:** han passat de `PlayerRig` a `StickPlacer`. `player_rig.gd` ha baixat de 549 a 464 línies.
- **Banquetes:** les mides només són a `StadiumLayout`, i `Dugout` les llegeix d'allà.
- **`MeshPart`:** ha passat a `src/game/`, perquè la fan servir els jugadors i l'estadi.
- **Proves de la postura:** ara són a `tests/game/test_stance.gd`.

## Rendiment

Partit sencer (`tools/perf.sh`):

| Qualitat | Abans de les millores | Ara | Pitjor fotograma |
|---|---|---|---|
| Alta, de tarda | — | 140 fps | 17 ms |
| Alta, de nit | 120 fps | 119 fps | 21 ms |
| Baixa, de tarda | 185 fps | 195 fps* | 14 ms |

\* Mesura feta abans del públic i els cotxes en 3D.

- No hi ha cap estrebada de més de 50 ms durant el partit. Dues mesures, entre totes les d'aquests dies, van tenir una aturada puntual de 56 i 76 ms que no es va repetir.
- La memòria no passa d'1,3 GB amb *Alta*.
- Els *shaders* nous es compilen durant l'escalfament, sota la cortina «Carregant»: durant el partit no se'n compila cap.

## Què queda pendent

- **El cos de base continua sent el de superheroi.** Les complexions en treuen el relleu i n'aprimen les espatlles, però les proporcions són les seves. La solució és el cos normal del paquet de pagament de Quaternius (uns 20 $, també CC0). Ho ha de decidir l'usuari.
- **No hi ha animacions de revés ni d'arrossegament.** La simulació no distingeix aquests cops, i caldrien animacions fetes a mà o un model per a cada gest.
- **El públic no té cara.** Des de les càmeres del partit no es nota.
