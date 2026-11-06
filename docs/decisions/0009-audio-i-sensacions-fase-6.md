# 0009 · Àudio i sensacions (fase 6)

**Data:** 6 de novembre de 2026 · **Estat:** acceptada

## Context

La fase 6 demana:

- sons reals amb llicència CC0 per als cops de pal, la pilota a la gespa, el cop contra la taula de fons, el xiulet i el públic amb reaccions;
- quatre busos d'àudio;
- la vibració del comandament en xuts, entrades i gols.

Criteris d'acceptació:

- no hi ha saturació;
- els volums són ajustables;
- el so respon a tots els esdeveniments.

La web sintetitza tots els sons amb WebAudio (`SFX`, línies 1052–1089): soroll filtrat per als cops, un sinus per al xiulet i soroll de banda per al públic.

## Decisions

### 1. Mostres CC0 de dues fonts, preparades amb una eina

| Font | Què se'n fa servir |
|---|---|
| Kenney, *Impact Sounds* | Fusta lleugera (passades), fusta mitjana (cops i xuts), fusta forta (entrades), impacte genèric (recepcions i rebots), toc suau (pilota a la gespa), taulell (taula de fons), metall (pal de la porteria), cop encoixinat (proteccions del porter) i impacte suau fort (xarxa). |
| Kenney, *Interface Sounds* | El focus, el clic, enrere i el canvi de jugador. |
| BigSoundBank | El murmuri del públic, en dues capes: gent d'un poble petit (80 s) i 50–60 persones parlant (108 s). Aplaudiments de 25–50 persones a l'aire lliure. Crits d'alegria. |
| Wikimedia Commons | El xiulet: un xiulet d'àrbitre real (SpliceSound), gravat en un pavelló. |

- **Com s'han triat:** sense escoltar-los, analitzant-los amb Godot: durada, nivell segon a segon, segments i freqüència dominant.
  - Per al públic, s'han triat gravacions amb un nivell estable.
  - Per al xiulet, primer es va fer servir un bufet llarg d'un xiulet de plàstic de BigSoundBank, tallat a la durada de cada xiulada. Provant el joc, l'usuari va dir que no era realista.
    - L'anàlisi ho confirmava: era una nota fixa de 2,5 kHz, sense el tremolor de la bola.
    - S'ha canviat per un xiulet d'àrbitre real, amb la nota que tremola entre 2,6 i 2,9 kHz unes 60 vegades per segon.
    - Els bufets ja no es tallen: n'hi ha un de curt (l'original, 0,41 s) i un de llarg (0,98 s, repetint el tros estable del mig), tots dos amb la seva entrada natural i l'eco del pavelló.
- **El públic és petit**, com el del camp real de l'Iluro (decisió 0006): unes desenes de persones, no un estadi.
- **`tools/prepare_audio.gd`** ho fa tot a partir dels paquets baixats:
  - copia els sons amb noms del joc (`assets/audio/sfx`, `ui` i `crowd`);
  - retalla el bufet del xiulet;
  - genera el «whoosh» de la cortineta, que és soroll filtrat i propi del projecte.

  Si es canvia un so, es torna a executar. Les fonts i les llicències són a `assets/LICENSES.md`.

### 2. Com sona cada esdeveniment (`MatchSound`)

`MatchSound` escolta els esdeveniments de cada pas de la simulació, com fa `MatchView` amb les animacions.

**Sons en 3D, al lloc on passen:** cops, recepcions, entrades, aturades, pal i porteria.

- Els sent la càmera, i a la repetició de prop sonen més a prop.
- Volum: inversa de la distància, amb un sostre.
- El panoràmic és suau (0,6) perquè el so no salti d'un costat a l'altre.

| Esdeveniment | So |
|---|---|
| `kick` | Pal. Les passades sonen més fluix que els cops i els xuts, i el volum puja amb la velocitat de la pilota. |
| `control`, `deflect` | Recepció o rebot. |
| `tackle` | Pals que xoquen. |
| `save` | Proteccions del porter, aplaudiments i el públic s'anima. |
| `post` | Metall del pal. El públic s'aixeca. |
| `goal`, `net` | Per sota de 46 cm, el «bum» de la taula de fons; per sobre, la xarxa. Si marca l'Iluro, que juga a casa, crits i aplaudiments; si marca el Polo, uns quants aplaudiments. |
| `whistle` | `count` bufets, com `SFX.whistle(dur, n)`. Per sota de 0,5 s fa el bufet curt (faltes, sortides, gol) i, a partir d'aquí, el llarg (servei inicial, finals de quart). |
| `intro_end`, `quarter_end` | Aplaudiments. |
| `pc` | El públic s'anima. |
| `switch`, `wipe` | Clic i «whoosh», al bus Interfície. |
| Pilota que toca la gespa després d'anar per l'aire | Toc suau, més fort com més de pressa cau. La simulació no emet aquest esdeveniment: es detecta per l'alçada de la pilota. |

- `restart` i `replay_end` no tenen so propi: ja hi ha el xiulet i la cortineta.
- Una prova llegeix tots els tipus d'esdeveniment que emet `src/sim/` i comprova que cadascun té un so o una raó per no tenir-ne.

**El murmuri del públic:**

- Puja quan la pilota s'acosta a una porteria i als córners curts.
- Salta amb els gols, les aturades i el pal, i torna a baixar sol en uns 4 s, com `SFX.crowd()`.
- Amb la pausa baixa 10 dB.
- Provant el joc, l'usuari el va trobar massa fort dues vegades.
  - En total, el murmuri ha baixat 16 dB i els crits i aplaudiments, 10–11 dB.
  - Qui el vulgui més fort el pot pujar a Opcions › So › Ambient.
- Al menú, el partit de demostració sona 10 dB més fluix.

**Altres detalls:**

- Si la simulació avança molts passos en un sol fotograma (escenaris de proves), no sona res.
- Els botons dels menús fan un toc en rebre el focus amb el teclat o el comandament, i un clic en prémer-los (`UiSounds`).

### 3. Busos i saturació

- Quatre busos: General (Master), Ambient, Efectes i Interfície (`AudioBuses`). Els volums es desen a les opcions (fase 5).
- **Limitador:** el Master porta un `AudioEffectHardLimiter` amb el sostre a −0,5 dBFS. Per molts sons que coincideixin, no pot saturar.
- **Marge:** la barreja s'ha ajustat amb mesures (vegeu «Mesures»). Amb la barreja final, ni al pitjor moment (quan coincideixen el gol, el xiulet i els crits) el limitador no ha de treballar: el pic queda a −4,4 dBFS.
- **Com es mesura:** `tools/audio_check.sh` grava el so d'un partit amb el Movie Maker de Godot (60 s amb la llavor 1, que té tres gols) i en mesura el pic i les mostres retallades.

### 4. Vibració del comandament (`Rumble`)

Només per a l'equip de l'humà, mai a la repetició. Es pot desactivar a Opcions › So.

| Situació | Vibració |
|---|---|
| Xut o cop propi | Proporcional a la velocitat de la pilota. |
| Entrada pròpia | Cop sec. |
| Ens prenen la pilota | Més forta que una entrada pròpia. |
| Gol a favor | Llarga i forta. |
| Gol en contra | Curta i suau. |

### 5. Sense pantalla no sona res

- Amb `--headless` (proves i `tools/smoke.sh`), Godot no té sortida d'àudio i el mesclador no allibera els sons que s'aturen. En tancar, avisaria de fuites.
- Per això `MatchSound` i `UiSounds` no reprodueixen res sense pantalla. `MatchSound` apunta igualment què hauria sonat a `played`, i les proves ho comproven.
- Amb finestra, en tancar el joc (Surt, la creu de la finestra o els escenaris), `quit_game()` fa callar el so i espera 0,15 s abans de sortir.

## Mesures

`bash tools/audio_check.sh`, amb el so gravat pel Movie Maker de Godot (llavor 1):

| Barreja | Durada | Pic | Mostres retallades | Segon més fort | Mitjana |
|---|---|---|---|---|---|
| Primera, sense guany | 60 s (tres gols) | −4,2 dBFS | 0 | −19,6 dB RMS (el primer gol) | −29,9 dB RMS |
| Segona: +4 dB, i el públic +5 dB més | 15 s (el primer gol) | −0,5 dBFS (el sostre del limitador) | 0 | −15,7 dB RMS | −23,6 dB RMS |
| Final, després de la prova de l'usuari: el públic −8 dB i el xiulet nou | 15 s (el primer gol) | −4,4 dBFS | 0 | −18,3 dB RMS | −27,4 dB RMS |

La primera barreja era massa fluixa. A la segona, el pic del gol superava per poc el sostre i el limitador el retallava a −0,5 dBFS, sense cap mostra retallada. L'usuari va trobar el públic massa fort i s'ha baixat: ara el pic queda lluny del sostre. Gravar 60 s amb el Movie Maker triga uns 17 minuts.

## Com es comprova

- **Proves:** `tests/game/test_audio.gd`, 11 proves.
  - Cada tipus d'esdeveniment de la simulació té so.
  - Cada esdeveniment demana el so que li toca.
  - El gol baix sona a la taula de fons i el gol alt a la xarxa; el públic crida als gols de l'Iluro.
  - El nombre de bufets del xiulet.
  - Els volums segons la velocitat de la pilota.
  - El banc de sons és complet.
  - Hi ha un sol limitador al Master.
  - Els volums de les opcions s'apliquen.
  - La vibració es desa i vibra quan toca.
- **Saturació:** `bash tools/audio_check.sh [segons] [llavor]` deixa el so a `build/audio/so.wav`, que es pot escoltar.

## Què queda pendent

- Cal escoltar-ho a mà: sentir com sona, els volums relatius i la vibració amb un comandament físic. Els sons s'han triat i ajustat sense escoltar-los.
- No hi ha el so de la pilota rodant per la gespa ni el de la conducció.
