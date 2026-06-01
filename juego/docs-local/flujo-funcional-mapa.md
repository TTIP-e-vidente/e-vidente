# Flujo funcional del mapa de nodos

Este documento describe el flujo real desde que se carga el JSON del mapa hasta que
el jugador vuelve al mapa con el progreso actualizado. Sirve como mapa de "qué archivo
toca cada cosa".

## Flujo simplificado (camino feliz)

```
JSON del mapa
  └─ CargadorDeMapa.load_map()            (carga + valida + normaliza)
       └─ MapScene.cargar_mapa()          (guarda nodos_mapa)
            └─ MapScene.actualizar_estados_de_nodos()
                 ├─ SaveManager.get_all_node_progress()   (ÚNICA lectura de progreso)
                 ├─ AvanceDeNodo.get_node_state()          (desbloqueo/completado)
                 └─ MapBoard.configurar_nodos(nodos, estados)
                      └─ LevelNode.configurar()            (render por nodo)

Click en un nodo
  └─ MapBoard.node_selected
       └─ MapScene.al_seleccionar_nodo()
            └─ FlujoDeNodoJugable.seleccionar_nodo()
                 ├─ AvanceDeNodo.get_node_state()  (¿desbloqueado?)
                 └─ AbridorDeNodoJugable.abrir_nodo()
                      └─ NodoRuntime.iniciar()
                           ├─ ArmadorDePartida.construir_plan_de_partida()
                           └─ ContinuidadDePartidaDeNodo.abrir_juego_actual()
                                └─ GameSceneRouter (abre la escena del minijuego)

Fin del minijuego
  └─ PostGameFlowController.finalizar_actividad()
       └─ NodoRuntime.avanzar_actividad()
            └─ ContinuidadDePartidaDeNodo.continuar_o_finalizar_partida()
                 ├─ (si quedan juegos) abre el siguiente
                 └─ (si terminó)
                      ├─ _registrar_exp_finalizacion()  → SaveManager.add_exp()
                      │                                   + Global.establecer_ultima_finalizacion()
                      └─ _guardar_precision_nodo()       → SaveManager.save_node_accuracy()
                                                          + Global.marcar_nodo_jugable_completado()

Pantalla de resultado
  └─ finalización_partida.gd lee Global.obtener_y_limpiar_ultima_finalizacion()
       └─ "Continuar" → MapScene (re-ejecuta actualizar_estados_de_nodos)
```

## Qué archivo toca cada responsabilidad

| Responsabilidad | Archivo |
| --- | --- |
| Carga del JSON del mapa | `mapas/logica/CargadorDeMapa.gd` |
| Validación / normalización | `CargadorDeMapa.gd` + `sistemas/contenido/Content*` |
| Modelo de un nodo | `mapas/core/MapNodeData.gd` |
| Arma los nodos del mapa | `CargadorDeMapa.build_nodes()` |
| Muestra los nodos | `mapas/MapBoard.gd` + `mapas/LevelNode.gd` |
| Decide si un nodo está disponible | `mapas/logica/AvanceDeNodo.gd` |
| Abre la partida | `flow/map/flujo_de_nodo_jugable.gd` → `AbridorDeNodoJugable.gd` → `sistemas/NodoRuntime.gd` |
| Arma la secuencia de juegos | `mapas/logica/ArmadorDePartida.gd` |
| Avanza / finaliza la partida | `mapas/logica/ContinuidadDePartidaDeNodo.gd` |
| Registra el resultado (EXP + precisión) | `ContinuidadDePartidaDeNodo.gd` → `interface/SaveManager.gd` |
| Reglas de EXP y precisión | `sistemas/NodoProgressionRules.gd` |
| Pantalla de resultado | `mapas/finalización_partida.gd` |
| Lectura de progreso para el mapa | `mapas/MapScene.gd` (único punto que lee `SaveManager`) |

## Tareas comunes

- **Mover o agregar un nodo:** editar el JSON del mapa (`contenido/mapa/celiaquia_mapa.json`)
  y el `.tscn` visual (`MapBoard.tscn` / `MapChapterNode.tscn` / `MapQuestionNode.tscn`).
  La lógica de carga vive en `CargadorDeMapa.gd`.
- **Cambiar la imagen de un nodo:** en el `.tscn` visual del nodo (`MapChapterNode.tscn` /
  `MapQuestionNode.tscn`), no en código.
- **Apertura de partida:** `flow/map/flujo_de_nodo_jugable.gd` valida disponible/bloqueado;
  `AbridorDeNodoJugable.gd` es el punto de entrada que delega en `NodoRuntime.gd`.
- **Progreso / estrella:** se guarda en `ContinuidadDePartidaDeNodo.gd` vía `SaveManager.gd`
  y se lee/aplica en `MapScene.gd` (que lo pasa a `MapBoard.gd`).
- **Navegación de escenas:** `sistemas/GameSceneRouter` (solo cambia escenas; no sabe de
  JSON, progreso ni diseño).

## Reglas de EXP y precisión (NO inventar fórmulas nuevas)

- EXP base por dificultad: `{ FÁCIL: 6, MEDIA: 8, DIFÍCIL: 12 }` en `NodoProgressionRules.gd`.
- EXP final = `round(exp_base * precision_ratio)`, acotado a `[0, exp_base]`.
- Precisión = `round(aciertos / intentos * 100)`; ratio `aciertos / intentos`.
- La precisión que muestra el mapa y la pantalla de resultado proviene del resultado real.
  **"Completado" no implica 100%.**

## Archivos congelados (no tocar sin justificación)

- `sistemas/NodoProgressionRules.gd` (reglas EXP / precisión).
- `mapas/logica/ArmadorDePartida.gd` (selección random, dificultad, modalidades).
- Todos los `.tscn` visuales, colores, `modulate`, Tween, AnimationPlayer, StyleBox,
  Theme, shaders, íconos y texturas.

## Qué NO tocar para no romper el diseño

- No editar `.tscn` visuales ni propiedades visuales.
- No cambiar reglas de EXP, dificultad ni modalidades.
- No cambiar el JSON de contenido salvo necesidad explícita.
