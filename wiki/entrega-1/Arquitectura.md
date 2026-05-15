# Arquitectura — Entrega 1

Demo local en Godot. Sin backend, sin base de datos, sin servicios externos.

## Flujo confirmado

```
libro.gd → Global.current_level → manager_level.gd → LevelResource → Level.gd → ItemLevel + .tres → Ensenanza
```

El jugador selecciona un capítulo desde el libro de recorrido. El libro actualiza `current_level`. `manager_level.gd` carga el `LevelResource` del capítulo. `Level.gd` ejecuta el desafío de arrastre. Al completar, marca el capítulo como listo y muestra la enseñanza.

## Componentes confirmados

| Componente | Rol |
|---|---|
| `libro.gd` / `libro-vegan.gd` / `Libro-Vegan-GF.gd` | Selección de capítulo por recorrido |
| `global.gd` | Estado global: `current_level`, flags de completado |
| `manager_level.gd` | Arma el `LevelResource` activo |
| `Level.gd` | Ejecuta la actividad y marca victoria |
| `level_resource.gd` / `level_item.gd` / `.tres` | Definición de contenido del capítulo |
| `ItemLevel.gd` | Comportamiento visual del ítem arrastrable |
| `ensenanzas.gd` / `ensenanzaveganismo.gd` | Catálogo de enseñanzas por recorrido |

## Falta confirmar

`MapScene.gd`, `GameSceneRouter.gd`, `SaveManager.gd`, `pregunta.gd`, `vincular_conceptos.gd`, `ArmadorDePartida.gd`, `ContinuidadDePartidaDeNodo.gd`, barra de progreso, contenido por JSON.


