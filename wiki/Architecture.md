# 🎬 Architecture

> Este documento es el punto de entrada en inglés. El contenido completo está en [Arquitectura-General.md](Arquitectura-General.md).

---

## Flujo principal

```
Splash (evidente.tscn)
  └─ Intro (intro.tscn)
       └─ Selector (selector.tscn)
            └─ Mapa (MapScene.tscn)
                 └─ Gameplay
                      ├─ Drag & Drop (niveles/nivel_1/Level.tscn)
                      ├─ Quiz       (preguntas/pregunta.tscn)
                      └─ Vincular   (vincular/VincularConceptos.tscn)
```

## Sistemas clave

| Sistema | Archivo principal | Qué hace |
|---|---|---|
| Entrada y Menú | `interface/evidente.gd` | Arranque y navegación |
| Progreso/Guardado | `interface/SaveManager.gd` | Guardar y recuperar avance |
| Gameplay | `niveles/nivel_1/Level.gd` | Flujo jugable |
| Mapa | `mapas/MapScene.gd` | Navegación por nodos |
| Contenido | `sistemas/contenido/CargadorDeContenidoDeNodo.gd` | Carga JSON de nodos |
| Audio | `managers/MusicManager.gd` | Música centralizada |

## Qué tocar según qué querés cambiar

| Quiero cambiar... | Archivo/s |
|---|---|
| Pantalla de inicio | `interface/evidente.tscn`, `interface/evidente.gd` |
| Flujo post-partida | `flow/results/`, `flow/session/` |
| Mecánica de arrastre | `items/ItemLevel.gd`, `niveles/nivel_1/Level.gd` |
| Contenido de un nodo | `contenido/nodos/<clave>.json` |
| Lógica del mapa | `mapas/MapScene.gd`, `mapas/LevelNode.gd` |

## Documentación extendida

- Diagrama completo y descripción de sistemas → [Arquitectura-General.md](Arquitectura-General.md)
- Últimos cambios → [Bitacora.md](Bitacora.md)
