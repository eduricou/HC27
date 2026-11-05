# 0006 · El camp és el real de l'Iluro, no l'estadi de la web

**Data:** 5 de novembre de 2026 · **Estat:** acceptada · **Substitueix** la disposició de l'estadi de la decisió 0005.

## Context

La web dibuixa un estadi inventat: una gran grada coberta plena de públic, tanques LED, quatre torres de llum a les cantonades i una casa del club gran.

L'usuari ha passat una foto aèria del camp real de l'Iluro HC, al carrer Galícia de Mataró, i ha demanat adaptar-hi el joc. El camp real és força bàsic:

- No hi ha grada.
- Als laterals només hi ha tanques.
- Darrere les banquetes hi ha el passeig i el carrer.

## Decisions

### 1. El camp segueix la foto aèria

Les mides del joc no canvien. Orientació:

| Costat | Simulació | Què hi ha |
|---|---|---|
| Fons de la vista TV (oest) | −y | El passeig de formigó, amb les banquetes vermelles a la línia del mig i la taula de l'àrbitre auxiliar entre totes dues. Hi ha unes 34 persones dretes mirant el partit. Darrere, el muret amb la reixa de 2 m i les pancartes, la franja d'arbres, el carrer Galícia amb cotxes aparcats i fanals, i les cases de 2 o 3 plantes amb teulada de teula. |
| Costat de la càmera TV (est) | +y | La reixa baixa i la bardissa de 3 m. Darrere, el talús, amb la carretera a dalt i una bionda. La càmera TV queda a sobre de la carretera. |
| Dreta de la vista TV (nord) | +x | Les casetes del club. La gran té el rètol ILURO HC. Hi ha una xarxa de 5 m darrere la porteria i una rotonda al nord-oest. |
| Esquerra de la vista TV (sud) | −x | La xarxa alta (7 m), dues porteries de recanvi i un camp de matolls amb pins. |

- La gespa és més oliva, i la franja de fora del terreny de joc és de color llima, com a la foto.
- La ciutat del fons (hospital i blocs de pisos) es manté, amb el mateix generador que la web.
- La llum del sol continua sent la de la web. Ve del sud-oest, de darrere el passeig: és una llum de tarda.

### 2. Torres de llum

- N'hi ha quatre al passeig (x = ±12 i ±38), entre les banquetes i les pancartes, i dues a les cantonades de l'est (x = ±44).
- Al costat de la càmera no hi pot haver torres entre x = ±41: quedarien entre la càmera i el camp i taparien el joc. Ho comprova una prova.
- De nit hi ha un focus per torre, que apunta a la meitat del camp de l'altra banda.

### 3. Què desapareix respecte a la decisió 0005

| Element | Què passa |
|---|---|
| Grada i seients | Ja no hi són. |
| Tanques LED que es desplacen | Ara són pancartes fixes a la reixa del passeig. Com que no hi ha cap desplaçament, la variable global `led_scroll` s'ha tret. |
| Torres de 25 m a les cantonades | Ja no hi són (vegeu el punt 2). |
| Casa del club gran | Ja no hi és: al seu lloc hi ha les casetes del nord. |
| Textures | S'han tret `crowd.png`, `fascia.png` i `wall.png`. N'hi ha de noves: `people.png` (persones dretes) i `tree.png` (arbres del carrer). |

### 4. Res no pot tapar la vista TV

`test_res_no_tapa_la_camera_tv` comprova que, entre la càmera i el camp, tot queda per sota de la visual:

- la bardissa;
- els arbustos del talús;
- les torres.

Per això al talús de davant de la càmera només hi ha arbustos baixos, i els pins comencen a partir de la carretera.

## Mesures

Fetes amb `bash tools/bench.sh 10 <preset> <hora> [2560x1440]` a l'Intel Arc 130V integrada.

| Preset | Resolució 3D | Tarda | Nit |
|---|---|---|---|
| Baixa | 1920×1080 | 236 fps | 175 fps |
| Alta | 2560×1440 | 100 fps | 76 fps |

Són pràcticament les mateixes que amb l'estadi de la web (decisió 0005).

## Com es comprova

- `bash tools/shot_views.sh` fa les captures de tots els angles. L'angle que abans es deia `grada` ara es diu `banquetes`.
- Ja no té sentit comparar amb la web, perquè l'entorn és un altre. Sí que s'ha de comparar amb la foto aèria.
- **Si cal girar el camp** (per exemple, posar la càmera al costat del passeig): tota la disposició és a `src/game/stadium/stadium_layout.gd`. Les zones del terra les passa `stadium.gd` al shader `turf.gdshader` a partir d'aquestes mateixes constants.
