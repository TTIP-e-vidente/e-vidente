# Bitácora

Cambios importantes que anotamos para no perder de vista la evolución del proyecto.

Esta página no reemplaza documentos de entrega. Su rol es dejar trazabilidad clara de qué se hizo, por qué se hizo, qué problema resolvió, qué impacto tuvo para el jugador y qué evidencia técnica lo respalda.

## Navegación por etapas

- [Pre-POC](Pre-POC.md)
- [POC](01-POC.md)
- [Entrega 1](02-Entrega-1.md)
- [Entrega 2](03-Entrega-2.md)
- [Próximas entregas](04-Entrega-3.md)
- [Entrega final](05-Entrega-Final.md)

Estado de rutas de entrega:
- Falta confirmar si ya están creados `01-POC.md`, `02-Entrega-1.md`, `03-Entrega-2.md`, `04-Entrega-3.md` y `05-Entrega-Final.md`.

## Lo que pasó recientemente

Acá están los cambios más nuevos y relevantes para demo, defensa TTIP y continuidad técnica.

### [ BUG / GAMEPLAY] 2026-05-13 | Corrección del comportamiento del plato

Se corrigió un problema en la actividad de arrastre donde la interacción con el plato podía generar respuestas inconsistentes para ciertos intentos incorrectos.

Qué problema resolvió:
- En la práctica, había casos donde el feedback no era suficientemente consistente cuando un ítem se soltaba en una condición inválida.

Qué se ajustó:
- Se reforzó el flujo de intento incorrecto en el ítem arrastrable.
- Se dejó señal explícita para el caso incorrecto.
- Se mantuvo la recuperación visual para no cortar la interacción.

Impacto para el jugador:
- El gameplay se siente más estable.
- Se reducen respuestas confusas durante la actividad.
- La demo queda más predecible para exposición.

Evidencia:
- `project/items/ItemLevel.gd`
- `project/niveles/manager_level.gd`
- Commit: `7738db4` (Resuelvo bug del plato)

Falta confirmar:
- ID o referencia formal del bug en ticket externo.

### [ UI / PROGRESO] 2026-05-10 | Barra de progreso durante la actividad

Se incorporó y consolidó una barra de progreso para que el jugador entienda cuánto avanzó dentro de la secuencia del nodo.

Qué problema resolvió:
- Antes, el avance podía sentirse opaco en actividades encadenadas.

Qué se implementó:
- Indicador visual de avance en escenas de modalidad.
- Actualización del progreso con contexto `actual/total` del juego activo.
- Unificación del criterio visual para evitar duplicidad de indicadores.

Impacto para el jugador:
- Ahora entiende cuánto le falta para terminar.
- La experiencia se siente más guiada.
- Se reduce incertidumbre entre un juego interno y el siguiente.

Evidencia:
- `project/interface/progress_bar.gd`
- `project/interface/Progress_Bar.tscn`
- `project/preguntas/pregunta.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/niveles/nivel_1/Level.gd`
- Commit: `e02c1d8` (Feature/barra progreso)

### [ UX / CIERRE] 2026-05-10 | Estado de lección terminada y finalización de nodo

Se agregó una instancia clara de finalización para comunicar cierre de lección/nodo y sostener una salida ordenada al mapa.

Qué problema resolvió:
- El cierre podía sentirse abrupto cuando terminaba la actividad.

Qué se implementó:
- Pantalla de finalización de partida con métricas.
- Registro de finalización en estado global para mostrarla en el momento correcto.
- Retorno controlado al mapa después del cierre.

Impacto para el jugador:
- La actividad ya no termina de forma abrupta.
- Se refuerza la sensación de logro.
- El flujo de demo queda más defendible de punta a punta.

Evidencia:
- `project/mapas/Finalización-Partida.tscn`
- `project/mapas/finalización_partida.gd`
- `project/mapas/completo/finalizacion_de_nodo.gd`
- `project/mapas/MapScene.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- Commit: `893b57a` (Lección Completa)

### [ GAMEPLAY / MODALIDAD] Falta confirmar fecha exacta | Vinculación de conceptos como nueva modalidad

Se incorporó `vinculacion_conceptos` dentro del flujo de partida por nodo, sin abrir un camino paralelo al resto de modalidades.

Qué problema resolvió:
- El nodo tenía menos variedad de interacción y menor capacidad de trabajar relaciones conceptuales.

Qué se implementó:
- Nuevo modo `vinculacion_conceptos` en routing y continuidad.
- Integración de escena y runtime dentro del mismo esquema post-juego.
- Cobertura en smoke del recorrido que incluye la modalidad.

Impacto para el jugador:
- El contenido educativo gana variedad.
- Los nodos pueden mezclar más de una forma de actividad.
- La arquitectura muestra extensibilidad real, no teórica.

Evidencia:
- `project/sistemas/ModalidadRouter.gd`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/vincular/VincularConceptos.tscn`
- `project/tests/vertical_slice_smoke_test.gd`
- `project/contenido/mapa/vinculaciones.json`

Falta confirmar:
- Fecha única de corte para declarar la modalidad como cerrada en todos los tracks.

### [ GAMEPLAY / ARQUITECTURA] 2026-05-05 | Partida por nodo con múltiples juegos internos

Se consolidó el modelo donde un nodo puede ejecutar una secuencia de juegos internos, evitando hardcodeo de escenas y habilitando composición por datos.

Qué problema resolvió:
- Un nodo rígido limita variaciones de gameplay y obliga a cambios de código para cada ajuste de contenido.

Qué se implementó:
- Armado de `plan_de_partida` con `juegos` internos y continuidad.
- APIs globales para iniciar, consultar, avanzar y finalizar partida de nodo.
- Orquestación mapa -> apertura -> juego -> continuidad -> cierre.

Impacto para el jugador y para producto:
- Un nodo puede combinar más de una actividad sin hardcodear escenas.
- Se escala contenido con menor costo de mantenimiento.
- El diseño pedagógico gana flexibilidad.

Evidencia:
- `wiki/Partida-por-nodo.md`
- `project/mapas/logica/ArmadorDePartida.gd`
- `project/mapas/logica/AbridorDeNodoJugable.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- Commit: `30760ef` (multi-game node support)

### [ CONTENIDO] 2026-05-03 | Contenido JSON desacoplado para nodos jugables

Se reforzó el desacople entre lógica del juego y contenido de actividades, priorizando nodos definidos por JSON.

Qué problema resolvió:
- Con contenido embebido en escenas, cada cambio de actividad obligaba a tocar código o assets de gameplay.

Qué se implementó:
- Contrato de carga/validación de contenido por nodo.
- Soporte de modos y normalización de payload para runtime.
- Mapa con nodos que contienen `games` y rutas JSON.

Impacto:
- Se pueden sumar actividades por JSON sin tocar la arquitectura base.
- Mejora mantenibilidad de contenido.
- Facilita expansión de recorridos.

Evidencia:
- `wiki/Contenido-JSON-Nodos.md`
- `project/sistemas/contenido/CargadorDeContenidoDeNodo.gd`
- `project/sistemas/contenido/ValidadorDeContenidoDeNodo.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- `project/niveles/nodos/celiaquia/*.json`
- Commit: `6850568` (JSON content flow)

### [ TESTING / CI] Falta confirmar fecha exacta | Validaciones de smoke y CI por objetivos

Se ordenó la validación en CI para cubrir flujo jugable mínimo y salud técnica sin mezclar objetivos.

Qué valida el smoke:
- Arranque de flujo principal y paso por mapa/gameplay.
- Nodos críticos del runtime y contratos mínimos de escena.
- Cierre y retorno en flujo de finalización.

Qué cubre CI hoy:
- `Docs / Tracking`: trazabilidad documental en PR.
- `Technical Health`: guardrails de estructura y lint condicional.
- `Gameplay Smoke`: flujo mínimo jugable con import headless y logs.

Qué queda fuera:
- Persistencia profunda, todos los tracks y UI fina por modalidad.

Por qué reduce riesgo para la demo:
- Detecta temprano roturas visibles de navegación y gameplay.
- Evita merges sin documentación mínima.
- Mantiene un gate liviano para iterar sin perder control.

Evidencia:
- `wiki/CI.md`
- `.github/workflows/docs-pr.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/gameplay-smoke-pr.yml`
- `project/tests/vertical_slice_smoke_test.gd`
- `scripts/run-godot-validation.sh`
- `scripts/run-godot-validation.ps1`

Falta confirmar:
- Fecha exacta de consolidación final del esquema actual de workflows.

## Organizado por categoría

### Bugs / Estabilidad
- **2026-05-13** - **Corrección del plato** - Se ajustó la interacción de arrastre para evitar respuestas inconsistentes en intentos incorrectos.

### UI & Progreso
- **2026-05-10** - **Barra de progreso** - El jugador ahora ve su avance dentro de la secuencia del nodo con un indicador consistente.

### UX & Cierre
- **2026-05-10** - **Lección terminada / finalización de nodo** - Se agregó un cierre explícito con retorno ordenado al mapa.

### Gameplay & Modalidades
- **2026-05-05** - **Partida por nodo** - Un nodo puede combinar varios juegos internos sin hardcodear escenas.
- **Falta confirmar fecha** - **Vinculación de conceptos** - Modalidad integrada al mismo flujo de continuidad del nodo.

### Contenido
- **2026-05-03** - **Contenido JSON desacoplado** - El contenido jugable se define por JSON con contrato de carga y validación.
- **2026-05-13** - **Actualización de catálogo celiaquía** - Se ajustó catálogo de ítems y archivos de contenido para sostener actividades del track.

### Persistencia
- **2026-04-02** - **Persistencia local base** - Se consolidó guardado de perfil y progreso local sin backend.
- **2026-04-04** - **Multi-partida interna** - El formato pasó a soportar más de una sesión por perfil.
- **2026-04-06** - **Guardado parcial** - Se guarda progreso parcial para retomar actividades.

### Infraestructura
- **Falta confirmar fecha** - **Split de workflows por objetivo** - Se separó documentación, salud técnica y smoke jugable en pipelines distintos.

### Testing / CI
- **Falta confirmar fecha** - **Smoke test vertical** - Se validó el flujo mínimo jugable y contratos críticos de escena/runtime.
- **Falta confirmar fecha** - **Script de validación local** - Se estandarizó ejecución local por modo (`technical`, `smoke`, `ci`, `full`).

## Historial completo

No se borra historial útil. Esta sección conserva contexto por etapa y ayuda a reconstruir decisiones.

### Pre-POC

- Historial previo completo en [Pre-POC.md](Pre-POC.md).

### POC

- Falta confirmar consolidación de POC en [01-POC.md](01-POC.md).
- Mientras tanto, el contexto técnico relevante queda repartido entre [Architecture.md](Architecture.md), [Partida-por-nodo.md](Partida-por-nodo.md) y esta Bitácora.

### Entrega 1

#### 2026-04-02 | Persistencia local + CI base
Se agregó persistencia local de usuario con progreso y se formalizó validación inicial en CI para sostener la continuidad de demo.

#### 2026-04-04 | Persistencia multi-partida interna
El formato dejó de depender de un único save implícito y pasó a soportar varias sesiones por perfil, aunque la UI visible prioriza continuidad simple.

#### 2026-04-06 | Guardado parcial por nivel
Se incorporó guardado parcial de avance para retomar actividades sin reiniciar desde cero.

#### 2026-04-08 | Endurecimiento de quick save
Se ajustó serialización para tolerar estados incompletos y sostener compatibilidad.

#### 2026-05-03 | Mejora de flujo JSON en mapa
Se reforzó el esquema de nodos desde JSON para reducir acoplamiento con escenas.

#### 2026-05-05 | Partida por nodo multi-juego
Se habilitó secuencia de juegos internos por nodo con continuidad.

#### 2026-05-10 | Barra de progreso
Se incorporó visual de avance en modalidad para mejorar lectura de progreso.

#### 2026-05-10 | Lección completa
Se agregó escena y flujo de finalización para cierre más claro.

#### 2026-05-10 a 2026-05-12 | Vinculación integrada
Se integró modalidad de vinculación al flujo de nodo y continuidad compartida con el resto de modalidades.

#### 2026-05-13 | Bug del plato
Se corrigió comportamiento inconsistente en arrastre sobre plato.

#### 2026-05-14 | Mapa completo
Se actualizaron elementos visuales del mapa para reflejar continuidad del recorrido.

### Entrega 2

- Falta confirmar alcance y versión final de [03-Entrega-2.md](03-Entrega-2.md).

### Próximas entregas

- Falta confirmar hoja de ruta consolidada en [04-Entrega-3.md](04-Entrega-3.md).

## Insumo para Entrega 1

> La síntesis formal de la Entrega 1 se encuentra en [02-Entrega-1.md](02-Entrega-1.md).

Estos avances deberían pasar a [02-Entrega-1.md](02-Entrega-1.md) como núcleo defendible de producto:

- Persistencia local: el jugador puede retomar su progreso sin depender de servicios externos.
- Guardado parcial: evita reinicios completos y mejora continuidad de uso.
- Contenido JSON desacoplado: sumar o ajustar actividades requiere menos cambios de código.
- Partida por nodo: un nodo puede combinar varios juegos internos sin hardcodear escenas.
- Barra de progreso: el jugador ahora entiende cuánto le falta para terminar.
- Lección terminada: la actividad ya no termina de forma abrupta y deja un cierre legible.
- Vinculación de conceptos: agrega variedad pedagógica y demuestra extensibilidad del flujo.
- Correcciones de estabilidad: reduce errores visibles en gameplay durante demo.
- Validaciones CI / smoke test: baja riesgo de regresiones en navegación y flujo jugable mínimo.
