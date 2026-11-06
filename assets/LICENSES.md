# Llicències dels recursos

Registre de l'origen i la llicència de cada recurs que entra al joc (models, textures, sons, fonts i animacions). Afegeix-hi una fila cada vegada que incorporis un recurs de tercers.

| Recurs | Ruta | Origen | Llicència | Notes |
|---|---|---|---|---|
| Cos del jugador, pentinats i barba | `models/players/` | [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) [Standard], de Quaternius | CC0 1.0 | Textures reduïdes a 1024 px. Al `.gltf` del cos, corregits els noms de dues textures (`*_png.png` → `*.png`). |
| Animacions | `models/animations/UAL1_Standard.glb`, `UAL2_Standard.glb` | [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) 1 i [2](https://quaternius.itch.io/universal-animation-library-2) [Standard], de Quaternius | CC0 1.0 | Només per a `tools/build_player_anims.gd`, que en fa `players.res` (inclòs al joc). Els `.glb` no s'exporten. |
| Dígits dels dorsals | `textures/players/digits.png` | Generats per `tools/bake_textures.gd` | Propis del projecte | Lletra Bahnschrift de Windows, desada com a imatge. |
| Lletres | `fonts/BigShouldersDisplay-Variable.ttf`, `fonts/BarlowCondensed-*.ttf`, `fonts/Barlow-*.ttf` | [Big Shoulders Display](https://fonts.google.com/specimen/Big+Shoulders+Display), [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed) i [Barlow](https://fonts.google.com/specimen/Barlow), del repositori de Google Fonts | SIL Open Font License 1.1 (`fonts/OFL-*.txt`) | Les mateixes que fa servir la web. Es poden incloure al joc; no es poden vendre soles. |
| Escuts | `crests/iluro.svg`, `crests/polo.svg` | Port de `drawCrest()` de la versió web | Propis del projecte | Dissenys originals amb els colors de cada club, no els escuts oficials. |
| Textures del camp | `textures/stadium/*.png` | Generades per `tools/bake_textures.gd` (port del dibuix amb canvas de la web) | Pròpies del projecte | El text de les pancartes i del rètol de les casetes del club està dibuixat amb la lletra Bahnschrift de Windows i desat com a imatge. El joc no inclou el fitxer de la lletra. |

## Addons i eines dins del repositori

| Component | Ruta | Versió | Llicència |
|---|---|---|---|
| gdUnit4 | `addons/gdUnit4/` | 6.2.3 | MIT (`addons/gdUnit4/LICENSE`). Només per a proves; no s'inclou a l'exportació. |

## Recordatoris (pla, secció 11)

- **Mixamo:** les animacions es poden fer servir dins del joc, però no es poden redistribuir els fitxers en brut.
- **Escuts i noms dels clubs:** cal el permís de l'Iluro HC i del Club Polo abans de distribuir el joc públicament.
- Preferència: recursos CC0.
