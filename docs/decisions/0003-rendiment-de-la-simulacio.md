# 0003 · Rendiment de la simulació: es queda en GDScript

**Data:** 5 de novembre de 2026 · **Estat:** acceptada

## Context

El pla demanava que un partit es pogués simular sense gràfics en menys de 3 s. A la fase 1, un partit triga uns 10 s en un sol procés de GDScript. Ja s'hi han aplicat totes les optimitzacions que no canvien el resultat (vegeu `0002`). Per arribar a 3 s caldria portar `src/sim/` a C++ amb GDExtension, amb tot el que comporta:
- instal·lar Visual Studio Build Tools, SCons i godot-cpp;
- reescriure la simulació;
- afegir un pas de compilació;
- incloure una DLL a l'exportació.

## Decisió

Ens quedem amb el rendiment actual, en GDScript. El criteri del pla passa a ser de rendiment efectiu: **50 partits en menys de 3 minuts**, repartits entre els nuclis del PC de desenvolupament (`bash tools/sim.sh 50`). Ara triguen entre 2 i 3 minuts.

## Per què

- Per jugar no hi ha cap diferència. La simulació avança en temps real, i cada pas costa uns 0,2 ms d'un fotograma de 16,7 ms.
- Només afecta les simulacions massives d'equilibrat, que són poc freqüents. Per detectar errors n'hi ha prou amb la comparació amb l'oracle, que triga uns segons.
- Mantenir un sol llenguatge sense compilació és més simple i és el motiu pel qual el pla va triar GDScript.

## Quan revisar-ho

- Si l'equilibrat necessita milers de partits sovint. 1.000 partits triguen uns 50 minuts.
- Si el perfilador de la fase 7 mostra que la simulació pesa en ordinadors modestos.

En aquest cas, l'oracle (`tests/sim/test_oracle.gd`) serviria per validar una versió en C++ pas a pas.
