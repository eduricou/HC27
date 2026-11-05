# 0005 · Estadi, il·luminació i presets de qualitat (fase 3)

**Data:** 5 de novembre de 2026 · **Estat:** acceptada

## Context

La fase 3 del pla demana:

- la gespa amb *shader*;
- les porteries amb xarxa animada;
- banquetes, tanques, la casa del club, les torres de llum i els pins;
- la ciutat, el cel i la grada amb públic;
- llum de tarda i de nit;
- LightmapGI, ReflectionProbe, *glow* i *tonemapping*.

Criteris d'acceptació:

- captures equivalents o millors que les de la web des dels mateixos angles;
- 60 fps a 1080p amb el preset *Baixa* en una gràfica integrada;
- 144 fps a 1440p amb el preset *Alta* en una GPU mitjana.

## Decisions

1. **L'estadi es construeix per codi** (`src/game/stadium/`), amb les mesures de `glInit()` de la web, i `scenes/stadium.tscn` només en porta el script.
   - La ciutat i els pins fan servir el mateix generador que la web (Park–Miller amb llavor 11). Per això surten els mateixos 26 blocs i els mateixos 69 pins, i una prova ho comprova amb valors calculats amb el codi de la web.
   - `MeshBuilder` orienta cada triangle a partir de la normal que es demana. Així les malles fan servir el descart de cares normal, tot i que `Coords.to_view()` és una reflexió (vegeu la decisió 0004).
2. **Les textures es generen una vegada i es desen en PNG.**
   - `tools/bake_textures.gd` és el port de les funcions `make*()` de la web, que dibuixen amb canvas. Desa els PNG a `assets/textures/stadium/`, que van per LFS.
   - S'executa amb `bash tools/bake_textures.sh`, que obre una finestra un moment: dibuixar text necessita la GPU.
   - Els mipmaps vénen d'`importer_defaults` a `project.godot` (el mateix que fa el botó *Defineix per defecte* de l'editor). Els `.import` no es toquen a mà.
   - El text es dibuixa amb la lletra Bahnschrift de Windows, en negreta estreta (s'assembla a la Barlow Condensed de la web). Si no hi és, es fa servir Arial Narrow.
3. **El públic és un MultiMesh de quads** amb un atles de 64 persones: 48 de locals i 16 del Polo, que van a un sector propi. Els seients són un altre MultiMesh.
   - N'hi ha unes 700, amb una ocupació del 74 %, com a la web.
   - Es belluguen sempre una mica, i salten amb els xuts i els gols (`crowd_jump`, com `G.crowdJump` a la web).
4. **Hi ha tres variables globals de shader** a `project.godot`:
   - `night`;
   - `crowd_jump`;
   - `led_scroll`, el desplaçament de les tanques LED cada 5 s.

   Un sol canvi arriba a tots els materials.
5. **Llum.**
   - **Tarda.** Un `DirectionalLight3D` amb ombres PSSM, en la direcció de `SUN` de la web: el sol és darrere la grada, a l'esquerra.
   - **Nit.** Quatre `SpotLight3D` als capçals de les torres, que apunten al centre del camp.
     - El con fa 55° i s'esmorteeix cap a la vora, perquè la zona de sota de cada torre no quedi cremada.
     - Els focus no fan ombra de l'estadi fix. L'estadi va a la capa 2, i els focus tenen `shadow_caster_mask` sense aquesta capa. Amb un con tan ample, l'ombra de la coberta i dels pilars sortia a trossos sobre la grada. Ara només fan ombra els jugadors i les porteries, cosa que també és més barata.
   - Els capçals tenen *glow* i un halo additiu, que fa el paper de `drawGlows()` de la web.
6. **No hi ha LightmapGI ni ReflectionProbe.** És una desviació del pla.
   - LightmapGI s'ha de coure a mà a l'editor: Godot no té cap API ni ordre per fer-ho. A més, no encaixa amb geometria que es genera per codi.
   - L'escena és a l'aire lliure. La llum directa ve del sol o dels focus, i el cel posa l'ambient i els reflexos (`reflected_light_source = sky`) als vidres de les façanes i a les tanques LED.
   - En lloc de llum precalculada, hi ha SSAO a *Alta* i SSIL a *Ultra*.
   - Es pot tornar a mirar a la fase 7 si les captures ho demanen.
7. **Coses noves respecte a la web:**
   - banquetes al costat de la càmera (al costat de la grada tapaven el públic);
   - una tanca baixa de reixa al voltant del voral;
   - la copa dels pins vista des de dalt;
   - la xarxa de la porteria es deforma a la GPU. Les vores lligades als pals no es mouen, perquè si no la malla s'obriria.
8. **Presets de qualitat** (`src/game/quality.gd`): *baixa*, *mitjana*, *alta* i *ultra*.
   - Per defecte, *alta*.
   - Es trien amb `--quality=<nom>`. Per a proves de rendiment, `--qset=clau=valor,...` en canvia valors concrets.
   - *Alta* fa servir MSAA 2x. Amb 4x, a 1440p de nit, feia 64–75 fps a l'Arc 130V; amb 2x en fa 72–87. El 4x queda per a *Ultra*.
   - La fase 5 els posarà al menú d'opcions, i la fase 7 els ajustarà.

## Mesures

Fetes amb `bash tools/bench.sh 10 <preset> <hora> [2560x1440]`: partit CPU contra CPU, sense VSync, a l'Intel Arc 130V integrada (Core Ultra 5 228V).

Per mesurar 1440p, la finestra és de 1080p i l'escena 3D es renderitza a 2560×1440 (`scaling_3d_scale`).

| Preset | Resolució 3D | Tarda | Nit |
|---|---|---|---|
| Baixa | 1920×1080 | 230 fps | 183 fps |
| Alta | 1920×1080 | 145 fps | 141 fps |
| Alta | 2560×1440 | 97 fps | 72 fps |

- **Baixa, 1080p, gràfica integrada (≥ 60 fps):** complert, amb un marge de 3 vegades.
- **Alta, 1440p, GPU mitjana (≥ 144 fps):** aquí no es pot mesurar.
  - Una GPU de gamma mitjana (RTX 3060 o RX 6600) és unes 2,5–3 vegades més ràpida que l'Arc 130V, i hauria de fer entre 180 i 290 fps.
  - S'ha de confirmar a la fase 7, en la prova amb 2 o 3 PC.

## Com es comprova

- **Captures de la web** des dels angles fixos de `tools/views.json`: `node tools/shot_web.mjs [angles] [hores]`. Es desen a `build/shots/web/`.
- **Captures de Godot** des dels mateixos angles: `bash tools/shot_views.sh [angles] [hores] [qualitat]`. Es desen a `build/shots/godot/`.
  - Amb `--net=<segons>` a l'escenari `views`, la xarxa de la dreta surt deformada.
  - L'angle `porteria_lateral` serveix per veure-ho.
- **Rendiment:** `bash tools/bench.sh [segons] [qualitat] [hora] [res3d] [qset]`.
- **Proves:** `tests/game/test_stadium.gd`. Comproven:
  - la disposició, igual que a la web;
  - la xarxa i el públic quan hi ha un gol;
  - les tanques LED;
  - els presets;
  - l'orientació de les cares;
  - que l'estadi es construeix sencer.
