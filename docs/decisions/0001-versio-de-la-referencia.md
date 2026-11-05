# 0001 · Versió de la referència web

**Data:** 5 de novembre de 2026 · **Estat:** acceptada (provisional)

## Context

El pla (`docs/pla-pc.md`, secció 8) descriu la referència com una «versió 4» de 2.311 línies, amb jugadors 3D instanciats. El fitxer que hi havia a la carpeta del projecte (`Estic Hoquei Herba.html`) té 2.029 línies i és una versió anterior. Els jugadors es dibuixen en 2D (`drawPlayer`, en un canvas per sobre) sobre l'estadi WebGL.

La part que es porta a la fase 1 (constants, equips, regles, IA, moviment, bucle i repetició, línies 289–1031) coincideix amb el mapa del pla original, amb només una línia de desfasament.

## Decisió

- Es copia aquest fitxer a `reference/web/index.html` com a font de veritat.
- Es corregeix el mapa de línies de la secció 8 de `docs/pla-pc.md` perquè apunti a aquesta còpia.
- Les estadístiques de referència (`reference/golden/stats_web.json`) es generen a partir d'aquesta còpia.

## Conseqüències

- La fase 1 no queda afectada.
- Per a les fases 3–5, la referència visual dels jugadors és el dibuix 2D, no un model 3D.
- **Si apareix la versió 4:** cal substituir `reference/web/index.html`, tornar a fer el mapa de línies i regenerar `stats_web.json` amb `node tools/golden_headless.mjs`. Si la simulació ja s'ha portat, cal comparar el codi de les línies 289–1031 de les dues versions per detectar canvis de regles o d'IA.
