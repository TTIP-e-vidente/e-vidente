# Evidencia — Entrega 2

## Evidencia por user stories terminadas

| US | Descripción | Estado |
|---|---|---|
| US-01 | Transiciones suaves entre mapa, partida y resultados | Confirmado por código y demo |
| US-02 | Renovación gráfica de todas las pantallas principales | Confirmado por código y demo |
| US-03 | Felicitación especial por partida perfecta con estrellas | Confirmado por código y demo |
| US-04 | Mensaje de objetivo en modalidad Arrastre con TypewriterEffect | Confirmado por código y demo |
| US-05 | Modalidad Completar Palabra funcional con carga desde JSON | Confirmado por código y demo |
| US-06 | Suite de 8 tests automatizados con GdUnit4, todos passing | Confirmado por output de tests |

## Evidencia técnica en código

| Bloque | Archivos o módulos relacionados | Estado |
|---|---|---|
| Transiciones | `niveles/GameSceneRouter.gd`, escena de transición | Confirmado por código |
| Renovación gráfica | `preguntas/pregunta.tscn`, `vincular/VincularConceptos.tscn`, `completar/completar_palabra.tscn`, `mapas/`, `interface/`, assets en `assets-sistema/interfaz/` | Confirmado por código |
| Felicitación perfecta | `mapas/Finalización-Partida.tscn`, `mapas/estrellas.gd`, `mapas/StatsContainer.tscn` | Confirmado por código |
| Mensaje objetivo Arrastre | `interface/components/DragObjectiveText/DragObjectiveText.tscn`, `sistemas/TypewriterEffect.gd` | Confirmado por código |
| Completar Palabra | `completar/completar_palabra.gd`, `completar/CargadorCompletar.gd` | Confirmado por código |
| Tests | `tests/preguntas/carga_json_preguntas_test.gd` | Confirmado por output |

## Evidencia de tests automatizados

```
Run Test Suite: res://tests/preguntas/carga_json_preguntas_test.gd
carga_json_preguntas_test > test_fixture_json_se_puede_abrir          PASSED  2ms
carga_json_preguntas_test > test_carga_retorna_ok                     PASSED  3ms
carga_json_preguntas_test > test_tema_tiene_al_menos_una_pregunta      PASSED  3ms
carga_json_preguntas_test > test_pregunta_tiene_opciones               PASSED  6ms
carga_json_preguntas_test > test_existe_opcion_correcta                PASSED  7ms
carga_json_preguntas_test > test_existe_opcion_incorrecta              PASSED  5ms
carga_json_preguntas_test > test_evaluar_opcion_correcta               PASSED  6ms
carga_json_preguntas_test > test_evaluar_opcion_incorrecta             PASSED  7ms

Statistics: 8 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 51ms
```

## Evidencia de commits trazables

| Commit | Descripción | Verifica |
|---|---|---|
| `76991a3` | Sistema de transiciones con GameSceneRouter (#26) | US-01 |
| `48995fe` + `cd05ab4` | Transiciones implementadas y corregidas | US-01 |
| `93afea4`, `3fef3da`, `b470dcd`, `87c9ef7`, `7b54f54`, `e08982d`, `970826f`, `90e1b99`, `98d5f25`, `8292e68` | Renovación gráfica en todas las pantallas | US-02 |
| `b98b755`, `12bb0e0`, `726bd5f`, `7ecc60c` | Estrellas, felicitación, finalización partida | US-03 |
| `eacdc56`, `e3c7624`, `d889d66` | DragObjectiveText, TypewriterEffect | US-04 |
| `314088e`, `90e1b99` | Normalización datos Completar Palabra, nueva gráfica | US-05 |
| `8343778` | Tests GdUnit4 (#29) | US-06 |
| `f2a8aa8`, `3820cfe` | Bugs de compatibilidad arrastre y dimensiones pregunta | Bugs |
