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
| US-07 | TypewriterEffect en Preguntas — enunciado progresivo, salto por toque, sin mezcla de caracteres | Confirmado por validación manual |

## Evidencia técnica en código

| Bloque | Archivos o módulos relacionados | Estado |
|---|---|---|
| Transiciones | `niveles/GameSceneRouter.gd`, escena de transición | Confirmado por código |
| Renovación gráfica | `preguntas/pregunta.tscn`, `vincular/VincularConceptos.tscn`, `completar/completar_palabra.tscn`, `mapas/`, `interface/`, assets en `assets-sistema/interfaz/` | Confirmado por código |
| Felicitación perfecta | `mapas/Finalización-Partida.tscn`, `mapas/estrellas.gd`, `mapas/StatsContainer.tscn` | Confirmado por código |
| Mensaje objetivo Arrastre | `interface/components/DragObjectiveText/DragObjectiveText.tscn`, `sistemas/TypewriterEffect.gd` | Confirmado por código |
| Completar Palabra | `completar/completar_palabra.gd`, `completar/CargadorCompletar.gd` | Confirmado por código |
| TypewriterEffect en Preguntas | `preguntas/pregunta.gd`, `sistemas/TypewriterEffect.gd` | Confirmado por código y validación manual |
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
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/0ad2517c-9295-4d8e-84e6-66d3c7ac579b" />
<img width="458" height="319" alt="image" src="https://github.com/user-attachments/assets/b4fb34cb-135b-4f6b-a502-2ac2acfbff1a" />
<img width="459" height="319" alt="image" src="https://github.com/user-attachments/assets/d8101282-06f2-4557-bbd6-2d0bf437ddca" />
<img width="459" height="319" alt="image" src="https://github.com/user-attachments/assets/a6de5d5f-c159-464d-b6f8-dd8fb788d92d" />
<img width="459" height="319" alt="image" src="https://github.com/user-attachments/assets/912fa5de-df96-486e-b5ec-a48a51b0459e" />
<img width="458" height="319" alt="image" src="https://github.com/user-attachments/assets/d4348364-7bfc-40d4-9933-ded3705b3010" />
<img width="461" height="319" alt="image" src="https://github.com/user-attachments/assets/fe3032c9-861c-4751-9524-1f84a720f8f5" />
<img width="459" height="319" alt="image" src="https://github.com/user-attachments/assets/4711d54b-257c-4234-af99-884a65da42e8" />
<img width="459" height="317" alt="image" src="https://github.com/user-attachments/assets/57f6f055-fb73-48df-b915-5f2b8bbfe314" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/150d3e72-6fe2-43b8-81ca-92343652e55b" />
<img width="459" height="319" alt="image" src="https://github.com/user-attachments/assets/af4bbe3b-6b3b-4a85-8789-9ed851e6f02f" />
<img width="460" height="319" alt="image" src="https://github.com/user-attachments/assets/583d82d7-8c02-413a-9c2f-7024e958054a" />
<img width="459" height="320" alt="image" src="https://github.com/user-attachments/assets/59dff5b6-8a2e-41fb-a6ec-59a6cba4168b" />
<img width="461" height="319" alt="image" src="https://github.com/user-attachments/assets/544a29f2-4e0d-4a4a-ae1e-8ae6ee0afd0b" />




