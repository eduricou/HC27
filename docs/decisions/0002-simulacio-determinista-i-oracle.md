# 0002 · Simulació determinista, oracle web i rendiment

**Data:** 5 de novembre de 2026 · **Estat:** acceptada

## Context

La fase 1 porta la simulació de la web (línies 289–1051 de `reference/web/index.html`) a `src/sim/`. El pla demana que sigui determinista, que es pugui provar sense gràfics i que les mitjanes de 50 partits quedin dins d'un ±20 % de la web. Una comparació només estadística no detecta bé els errors de traducció: un error pot moure les mitjanes menys d'un 20 %.

## Decisions

1. **Generador d'atzar propi (`SimRng`, mulberry32).** No es fa servir `RandomNumberGenerator`. L'oracle (punt 2) fa servir el mateix generador a JavaScript, de manera que amb la mateixa llavor totes dues simulacions reben els mateixos números. El mètode es diu `rand()` i no `randf()`, perquè dins de la classe `randf()` cridava la funció global de Godot.
2. **Oracle web (`tools/oracle_web.mjs`).**
   - Executa el codi original de la web amb Node, amb aquests canvis:
     - la presentació (so, rètols, càmera) se substitueix per funcions buides;
     - `Math.random` passa a ser mulberry32;
     - `Math.hypot(x, y)` passa a ser `sqrt(x² + y²)`, que és la mateixa fórmula que fa servir el port.
   - Desa els fotogrames a `tests/fixtures/web_oracle.json`.
   - `tests/sim/test_oracle.gd` els reprodueix amb `MatchSim` i exigeix que coincideixin (tolerància 1e-6) en cinc recorreguts: dos minuts des del servei, un penal córner i dos partits sencers.
3. **Càlculs en `float` (64 bits), no en `Vector2`.** `Vector2` desa els valors en 32 bits, i aquest error d'arrodoniment feia divergir de seguida una simulació caòtica com aquesta. Les funcions que retornen un punt el deixen en camps de l'estat (`s.st_x/st_y`, `s.out_x/out_y`, `s.icpt_x/icpt_y`).
4. **El control humà és dins de la simulació (`src/sim/human.gd`).** Aquí el port se separa del mapa del pla. La capa de joc només omple `SimInput` a cada pas; la lògica de passar, xutar i fer entrades és a la simulació. Així, la llavor i l'entrada reprodueixen un partit exactament (repeticions, proves).
5. **La repetició modifica l'estat, com a la web (`apply_replay`).** Es grava sempre. El servei posterior ho torna a col·locar tot excepte el cicle d'animació (`anim`), que fa oscil·lar la pilota quan es condueix. Per això el resultat no ha de dependre de si es grava o no.
6. **La presentació rep esdeveniments.** A cada pas, `MatchState.events` recull els xuts, xiulets, gols, aturades, represes, etc., i la capa de joc (fases 2–6) hi reaccionarà.
7. **Optimitzacions exactes.** Totes s'han validat amb l'oracle:
   - rols com a enters i referència directa al rival (`team.opp`);
   - `mods()` i `accel_to()` incrustades dins de `move_toward()`;
   - poda de candidats a `assign_roles()` amb una cota inferior del temps d'intercepció;
   - col·lisions sobre arrays locals;
   - trajectòria de la pilota calculada només quan cal.

## Resultats

- **Fidelitat.**
  - Els 5 recorreguts de l'oracle coincideixen pas a pas.
  - Amb les llavors 1–50, 49 partits són idèntics als de la web (marcador i estadístiques). El que no ho és (llavor 4) divergeix després de 8,6 minuts de joc idèntic. Hi havia un empat exacte (dos jugadors a 5,000 m de la pilota) que es decideix a l'últim bit, i les funcions `sin`/`cos`/`atan2` de V8 i de Windows no arrodoneixen igual aquest bit.
- **Mitjanes (50 partits, `qlen` 150) contra `stats_web.json`:**
  - gols: +7,7 %;
  - xuts: +0,0 %;
  - penals córner: +16,5 %.

  La diferència de penals córner és soroll de mostreig: la web, amb les mateixes llavors 1–50, en dona 6,48 per partit i Godot 6,50.
- **Rendiment.**
  - Un partit triga uns 9–10 s en un sol procés, i el pla en demana menys de 3. GDScript va unes 10–20 vegades més lent que V8 en aquest codi: una crida costa uns 85 ns i llegir una propietat d'un altre objecte uns 15 ns.
  - `tools/sim.sh` reparteix els partits entre processos (per defecte, un per nucli): 50 partits triguen 2–3 minuts, és a dir, uns 2,5–3 s per partit de rendiment efectiu. Amb fils dins d'un sol procés no escala.
  - Per jugar en temps real no és cap problema: un pas costa uns 0,2 ms d'un fotograma de 16,7 ms.

## Conseqüències

- Rendiment: ens quedem amb GDScript i el criteri passa a ser de rendiment efectiu (vegeu `0003`).
- Qualsevol canvi a la simulació s'ha de validar amb `bash tools/test.sh`, que inclou l'oracle. Si es canvia la referència web, cal regenerar l'oracle amb `node tools/oracle_web.mjs`.
- Les proves de l'oracle depenen que l'ordre de les crides a l'atzar sigui idèntic al de la web. Un canvi que n'afegeixi o en tregui una desincronitza tota la resta. És intencionat: ho detecta.
