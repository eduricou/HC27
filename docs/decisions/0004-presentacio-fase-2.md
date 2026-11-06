# 0004 · Presentació de la fase 2 (caixes grises)

**Data:** 5 de novembre de 2026 · **Estat:** acceptada

## Decisions

1. **Les accions d'entrada es registren en temps d'execució** (`src/game/input_actions.gd`) i no a `project.godot`. La fase 5 les ha de poder reassignar i desar a `user://`, i així les assignacions per defecte són en un sol lloc del codi. A l'editor de Godot no surten a *Projecte › Configuració › Mapa d'entrada*.
2. **El HUD i el menú es construeixen des del codi** (`src/ui/hud.gd`, `menu.gd` i `ui_kit.gd`). La fase 5 els refarà amb escenes (`scenes/ui/*.tscn`), escuts i fonts pròpies. *(Fase 5: es van refer amb escuts i lletres pròpies, però continuen construïts des del codi; vegeu la decisió 0008.)*
3. **La interpolació de la vista és manual.**
   - `MatchView` desa l'estat després de cada pas de simulació (en `_physics_process`, amb prioritat posterior a la del `MatchRunner`).
   - A cada fotograma interpola amb `Engine.get_physics_interpolation_fraction()`.
   - Els salts grans (represes, repetició) no s'interpolen.
   - `physics_jitter_fix` val 0.
4. **Les malles generades no descarten cares** (`cull_mode = CULL_DISABLED`). `Coords.to_view()` és una reflexió (la simulació i Godot tenen orientacions diferents) i inverteix els triangles. Sense aquesta opció, les línies del camp no es veien.
5. **Rendiment de l'escena gris.**
   - Ombra direccional amb 2 divisions.
   - Fons i llum ambiental de color pla, sense cel procedural.

   Així s'aconsegueixen uns 355 fps a 1080p amb l'Intel Arc 130V. Amb 4 divisions i cel procedural en feia 318, molt a prop del límit de 300. La fase 3 (estadi, il·luminació de tarda i de nit) ho tornarà a revisar amb els presets de qualitat.

## Com es comprova

- `bash tools/smoke.sh`: recorregut complet sense pantalla, de partit al menú, amb CPU contra CPU i amb un humà automàtic (`Autopilot`). Falla si la consola mostra errors o avisos.
- `bash tools/bench.sh`: fps a 1920×1080 sense VSync.
- `bash tools/shot.sh <escenari>`: captures. Escenaris disponibles: `menu`, `intro`, `match`, `human`, `pc`, `pause`, `break` i `full`.
