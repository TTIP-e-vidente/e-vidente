# Arquitectura

Estado: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md) · Cambios: [Bitacora](Bitacora.md)

## Flujo jugador

Inicio → iniciar sesión o jugar sin conexión → menú → elegir restricción → mapa → partida(s) del nodo → guardado (exp, racha).

## Dónde tocar qué

| Área | Archivos |
|------|----------|
| Arranque | `interface/evidente.gd`, `intro`, `niveles/selector.gd` |
| Navegación | `niveles/GameSceneRouter.gd` |
| Save | `interface/SaveManager.gd`, `save_local/*`, `niveles/global.gd` |
| Mapa | `mapas/MapScene.gd`, `LevelNode.gd`, `MapNodeData.gd` |
| Contenido | `contenido/mapa/*.json`, `NodeContentLoader.gd` — [guía](../juego/contenido/README.md) |
| Gameplay | `nivel_1/Level.gd`, `preguntas/`, `vincular/`, `completar/` |
| API | `juego/API/backend/*`, `BACKEND/` |
| Audio | `managers/MusicManager.gd` |
| Racha | `niveles/progress/GameStreakTracker.gd` |
| Items | `items/*.tres` + `items_celiaquia.json` |
| Colores | `colours/miPaleta.gd` |


## Otros docs

[Como-Empezar](Como-Empezar) · [contenido/README](../juego/contenido/README.md) · [BACKEND/README](../BACKEND/README.md) · [CI](CI) · [MER](MER) · [Mer-Hub](Mer-Hub)
