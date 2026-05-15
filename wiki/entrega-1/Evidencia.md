# Entrega 1

| Funcionalidad | Evidencia | Estado |
|---|---|---|
| Selección de capítulo | [project/interface/libro.gd](../../project/interface/libro.gd), [project/interface/libro-vegan.gd](../../project/interface/libro-vegan.gd), [project/interface/Libro-Vegan-GF.gd](../../project/interface/Libro-Vegan-GF.gd) | Confirmada |
| Desafío de arrastre | [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd), [project/niveles/manager_level.gd](../../project/niveles/manager_level.gd), [project/items/ItemLevel.gd](../../project/items/ItemLevel.gd) | Confirmada |
| Contenido por Resources | [project/resources/level_resource.gd](../../project/resources/level_resource.gd), [project/resources/level_item.gd](../../project/resources/level_item.gd), `project/items/*.tres` | Confirmada |
| Progreso por capítulos | [project/niveles/global.gd](../../project/niveles/global.gd), [project/interface/libro.gd](../../project/interface/libro.gd), [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd) | Confirmada |
| Enseñanza al completar | [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd), [project/niveles/ensenanzas.gd](../../project/niveles/ensenanzas.gd), [project/niveles/ensenanzaveganismo.gd](../../project/niveles/ensenanzaveganismo.gd) | Confirmada |
| Workflow de CI | [CI.md](../CI.md), [.github/workflows/ci.yml](../../.github/workflows/ci.yml) | Parcial |



| Tema | Evidencia documental | Estado |
|---|---|---|
| Mapa con nodos jugables | [Architecture.md](../Architecture.md), [Bitacora.md](../Bitacora.md) | Falta confirmar |
| Partida por nodo | [Partida-por-nodo.md](../Partida-por-nodo.md), [Bitacora.md](../Bitacora.md) | Falta confirmar |
| Persistencia local explícita | [Persistencia-Local.md](../Persistencia-Local.md), [Bitacora.md](../Bitacora.md) | Falta confirmar |
| Preguntas y vinculación como modalidades integradas | [Architecture.md](../Architecture.md), [Bitacora.md](../Bitacora.md) | Falta confirmar |
| JSON de contenido en `project/` | [Contenido-JSON-Nodos.md](../Contenido-JSON-Nodos.md) | Falta confirmar |



| Área | Archivo o documento | Qué demuestra |
|---|---|---|
| Estado global | [project/niveles/global.gd](../../project/niveles/global.gd) | Recorridos, capítulos y flags de completado |
| Orquestación de nivel | [project/niveles/manager_level.gd](../../project/niveles/manager_level.gd) | Cómo se arma el desafío a partir del estado |
| Gameplay principal | [project/niveles/nivel_1/Level.gd](../../project/niveles/nivel_1/Level.gd) | Resolución del desafío y victoria |
| Selector de capítulos | [project/interface/libro.gd](../../project/interface/libro.gd) | Desbloqueo y entrada al capítulo |
| Modelo de contenido | [project/resources/level_resource.gd](../../project/resources/level_resource.gd), [project/resources/level_item.gd](../../project/resources/level_item.gd) | Qué datos necesita cada capítulo y cada ítem |
| Catálogo de alimentos | `project/items/*.tres` | Instancias concretas del contenido jugable |
| Modelo conceptual | [Modelo-Entidad-Relacion.md](../Modelo-Entidad-Relacion.md) | Entidades de negocio y trazabilidad con código |

