# ≡ƒôï Bit├ícora

Cambios importantes que anotamos para no perder de vista la evoluci├│n del proyecto.

Esta p├ígina no reemplaza documentos de entrega. Su rol es dejar trazabilidad clara de qu├⌐ se hizo, por qu├⌐ se hizo, qu├⌐ problema resolvi├│, qu├⌐ impacto tuvo para el jugador y qu├⌐ evidencia t├⌐cnica lo respalda.

## Navegaci├│n por etapas

- [Pre-POC](Pre-POC.md)
- [POC](01-POC.md)
- [Entrega 1](02-Entrega-1.md)
- [Entrega 2](03-Entrega-2.md)
- [Pr├│ximas entregas](04-Entrega-3.md)
- [Entrega final](05-Entrega-Final.md)

Estado de rutas de entrega:
- Falta confirmar si ya est├ín creados `01-POC.md`, `02-Entrega-1.md`, `03-Entrega-2.md`, `04-Entrega-3.md` y `05-Entrega-Final.md`.

## Lo que pas├│ recientemente

Ac├í est├ín los cambios m├ís nuevos y relevantes para demo, defensa TTIP y continuidad t├⌐cnica.

### [≡ƒÉ₧ BUG / GAMEPLAY] 2026-05-13 | Correcci├│n del comportamiento del plato

Se corrigi├│ un problema en la actividad de arrastre donde la interacci├│n con el plato pod├¡a generar respuestas inconsistentes para ciertos intentos incorrectos.

Qu├⌐ problema resolvi├│:
- En la pr├íctica, hab├¡a casos donde el feedback no era suficientemente consistente cuando un ├¡tem se soltaba en una condici├│n inv├ílida.

Qu├⌐ se ajust├│:
- Se reforz├│ el flujo de intento incorrecto en el ├¡tem arrastrable.
- Se dej├│ se├▒al expl├¡cita para el caso incorrecto.
- Se mantuvo la recuperaci├│n visual para no cortar la interacci├│n.

Impacto para el jugador:
- El gameplay se siente m├ís estable.
- Se reducen respuestas confusas durante la actividad.
- La demo queda m├ís predecible para exposici├│n.

Evidencia:
- `project/items/ItemLevel.gd`
- `project/niveles/manager_level.gd`
- Commit: `7738db4` (Resuelvo bug del plato)

Falta confirmar:
- ID o referencia formal del bug en ticket externo.

### [≡ƒôè UI / PROGRESO] 2026-05-10 | Barra de progreso durante la actividad

Se incorpor├│ y consolid├│ una barra de progreso para que el jugador entienda cu├ínto avanz├│ dentro de la secuencia del nodo.

Qu├⌐ problema resolvi├│:
- Antes, el avance pod├¡a sentirse opaco en actividades encadenadas.

Qu├⌐ se implement├│:
- Indicador visual de avance en escenas de modalidad.
- Actualizaci├│n del progreso con contexto `actual/total` del juego activo.
- Unificaci├│n del criterio visual para evitar duplicidad de indicadores.

Impacto para el jugador:
- Ahora entiende cu├ínto le falta para terminar.
- La experiencia se siente m├ís guiada.
- Se reduce incertidumbre entre un juego interno y el siguiente.

Evidencia:
- `project/interface/progress_bar.gd`
- `project/interface/Progress_Bar.tscn`
- `project/preguntas/pregunta.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/niveles/nivel_1/Level.gd`
- Commit: `e02c1d8` (Feature/barra progreso)

### [Γ£à UX / CIERRE] 2026-05-10 | Estado de lecci├│n terminada y finalizaci├│n de nodo

Se agreg├│ una instancia clara de finalizaci├│n para comunicar cierre de lecci├│n/nodo y sostener una salida ordenada al mapa.

Qu├⌐ problema resolvi├│:
- El cierre pod├¡a sentirse abrupto cuando terminaba la actividad.

Qu├⌐ se implement├│:
- Pantalla de finalizaci├│n de partida con m├⌐tricas.
- Registro de finalizaci├│n en estado global para mostrarla en el momento correcto.
- Retorno controlado al mapa despu├⌐s del cierre.

Impacto para el jugador:
- La actividad ya no termina de forma abrupta.
- Se refuerza la sensaci├│n de logro.
- El flujo de demo queda m├ís defendible de punta a punta.

Evidencia:
- `project/mapas/Finalizaci├│n-Partida.tscn`
- `project/mapas/finalizaci├│n_partida.gd`
- `project/mapas/completo/finalizacion_de_nodo.gd`
- `project/mapas/MapScene.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- Commit: `893b57a` (Lecci├│n Completa)

### [≡ƒº⌐ GAMEPLAY / MODALIDAD] Falta confirmar fecha exacta | Vinculaci├│n de conceptos como nueva modalidad

Se incorpor├│ `vinculacion_conceptos` dentro del flujo de partida por nodo, sin abrir un camino paralelo al resto de modalidades.

Qu├⌐ problema resolvi├│:
- El nodo ten├¡a menos variedad de interacci├│n y menor capacidad de trabajar relaciones conceptuales.

Qu├⌐ se implement├│:
- Nuevo modo `vinculacion_conceptos` en routing y continuidad.
- Integraci├│n de escena y runtime dentro del mismo esquema post-juego.
- Cobertura en smoke del recorrido que incluye la modalidad.

Impacto para el jugador:
- El contenido educativo gana variedad.
- Los nodos pueden mezclar m├ís de una forma de actividad.
- La arquitectura muestra extensibilidad real, no te├│rica.

Evidencia:
- `project/sistemas/ModalidadRouter.gd`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/vincular/VincularConceptos.tscn`
- `project/tests/vertical_slice_smoke_test.gd`
- `project/contenido/mapa/vinculaciones.json`

Falta confirmar:
- Fecha ├║nica de corte para declarar la modalidad como cerrada en todos los tracks.

### [≡ƒº⌐ GAMEPLAY / ARQUITECTURA] 2026-05-05 | Partida por nodo con m├║ltiples juegos internos

Se consolid├│ el modelo donde un nodo puede ejecutar una secuencia de juegos internos, evitando hardcodeo de escenas y habilitando composici├│n por datos.

Qu├⌐ problema resolvi├│:
- Un nodo r├¡gido limita variaciones de gameplay y obliga a cambios de c├│digo para cada ajuste de contenido.

Qu├⌐ se implement├│:
- Armado de `plan_de_partida` con `juegos` internos y continuidad.
- APIs globales para iniciar, consultar, avanzar y finalizar partida de nodo.
- Orquestaci├│n mapa -> apertura -> juego -> continuidad -> cierre.

Impacto para el jugador y para producto:
- Un nodo puede combinar m├ís de una actividad sin hardcodear escenas.
- Se escala contenido con menor costo de mantenimiento.
- El dise├▒o pedag├│gico gana flexibilidad.

Evidencia:
- `wiki/Partida-por-nodo.md`
- `project/mapas/logica/ArmadorDePartida.gd`
- `project/mapas/logica/AbridorDeNodoJugable.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- Commit: `30760ef` (multi-game node support)

### [≡ƒôª CONTENIDO] 2026-05-03 | Contenido JSON desacoplado para nodos jugables

Se reforz├│ el desacople entre l├│gica del juego y contenido de actividades, priorizando nodos definidos por JSON.

Qu├⌐ problema resolvi├│:
- Con contenido embebido en escenas, cada cambio de actividad obligaba a tocar c├│digo o assets de gameplay.

Qu├⌐ se implement├│:
- Contrato de carga/validaci├│n de contenido por nodo.
- Soporte de modos y normalizaci├│n de payload para runtime.
- Mapa con nodos que contienen `games` y rutas JSON.

Impacto:
- Se pueden sumar actividades por JSON sin tocar la arquitectura base.
- Mejora mantenibilidad de contenido.
- Facilita expansi├│n de recorridos.

Evidencia:
- `wiki/Contenido-JSON-Nodos.md`
- `project/sistemas/contenido/CargadorDeContenidoDeNodo.gd`
- `project/sistemas/contenido/ValidadorDeContenidoDeNodo.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- `project/niveles/nodos/celiaquia/*.json`
- Commit: `6850568` (JSON content flow)

### [≡ƒº¬ TESTING / CI] Falta confirmar fecha exacta | Validaciones de smoke y CI por objetivos

Se orden├│ la validaci├│n en CI para cubrir flujo jugable m├¡nimo y salud t├⌐cnica sin mezclar objetivos.

Qu├⌐ valida el smoke:
- Arranque de flujo principal y paso por mapa/gameplay.
- Nodos cr├¡ticos del runtime y contratos m├¡nimos de escena.
- Cierre y retorno en flujo de finalizaci├│n.

Qu├⌐ cubre CI hoy:
- `Docs / Tracking`: trazabilidad documental en PR.
- `Technical Health`: guardrails de estructura y lint condicional.
- `Gameplay Smoke`: flujo m├¡nimo jugable con import headless y logs.

Qu├⌐ queda fuera:
- Persistencia profunda, todos los tracks y UI fina por modalidad.

Por qu├⌐ reduce riesgo para la demo:
- Detecta temprano roturas visibles de navegaci├│n y gameplay.
- Evita merges sin documentaci├│n m├¡nima.
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
- Fecha exacta de consolidaci├│n final del esquema actual de workflows.

## Organizado por categor├¡a

### ≡ƒÉ₧ Bugs / Estabilidad
- **2026-05-13** - **Correcci├│n del plato** - Se ajust├│ la interacci├│n de arrastre para evitar respuestas inconsistentes en intentos incorrectos.

### ≡ƒôè UI & Progreso
- **2026-05-10** - **Barra de progreso** - El jugador ahora ve su avance dentro de la secuencia del nodo con un indicador consistente.

### Γ£à UX & Cierre
- **2026-05-10** - **Lecci├│n terminada / finalizaci├│n de nodo** - Se agreg├│ un cierre expl├¡cito con retorno ordenado al mapa.

### ≡ƒº⌐ Gameplay & Modalidades
- **2026-05-05** - **Partida por nodo** - Un nodo puede combinar varios juegos internos sin hardcodear escenas.
- **Falta confirmar fecha** - **Vinculaci├│n de conceptos** - Modalidad integrada al mismo flujo de continuidad del nodo.

### ≡ƒôª Contenido
- **2026-05-03** - **Contenido JSON desacoplado** - El contenido jugable se define por JSON con contrato de carga y validaci├│n.
- **2026-05-13** - **Actualizaci├│n de cat├ílogo celiaqu├¡a** - Se ajust├│ cat├ílogo de ├¡tems y archivos de contenido para sostener actividades del track.

### ≡ƒÆ╛ Persistencia
- **2026-04-02** - **Persistencia local base** - Se consolid├│ guardado de perfil y progreso local sin backend.
- **2026-04-04** - **Multi-partida interna** - El formato pas├│ a soportar m├ís de una sesi├│n por perfil.
- **2026-04-06** - **Guardado parcial** - Se guarda progreso parcial para retomar actividades.

### ≡ƒöº Infraestructura
- **Falta confirmar fecha** - **Split de workflows por objetivo** - Se separ├│ documentaci├│n, salud t├⌐cnica y smoke jugable en pipelines distintos.

### ≡ƒº¬ Testing / CI
- **Falta confirmar fecha** - **Smoke test vertical** - Se valid├│ el flujo m├¡nimo jugable y contratos cr├¡ticos de escena/runtime.
- **Falta confirmar fecha** - **Script de validaci├│n local** - Se estandariz├│ ejecuci├│n local por modo (`technical`, `smoke`, `ci`, `full`).

## Historial completo

No se borra historial ├║til. Esta secci├│n conserva contexto por etapa y ayuda a reconstruir decisiones.

### Pre-POC

- Historial previo completo en [Pre-POC.md](Pre-POC.md).

### POC

- Falta confirmar consolidaci├│n de POC en [01-POC.md](01-POC.md).
- Mientras tanto, el contexto t├⌐cnico relevante queda repartido entre [Architecture.md](Architecture.md), [Partida-por-nodo.md](Partida-por-nodo.md) y esta Bit├ícora.

### Entrega 1

#### 2026-04-02 | Persistencia local + CI base
Se agreg├│ persistencia local de usuario con progreso y se formaliz├│ validaci├│n inicial en CI para sostener la continuidad de demo.

#### 2026-04-04 | Persistencia multi-partida interna
El formato dej├│ de depender de un ├║nico save impl├¡cito y pas├│ a soportar varias sesiones por perfil, aunque la UI visible prioriza continuidad simple.

#### 2026-04-06 | Guardado parcial por nivel
Se incorpor├│ guardado parcial de avance para retomar actividades sin reiniciar desde cero.

#### 2026-04-08 | Endurecimiento de quick save
Se ajust├│ serializaci├│n para tolerar estados incompletos y sostener compatibilidad.

#### 2026-05-03 | Mejora de flujo JSON en mapa
Se reforz├│ el esquema de nodos desde JSON para reducir acoplamiento con escenas.

#### 2026-05-05 | Partida por nodo multi-juego
Se habilit├│ secuencia de juegos internos por nodo con continuidad.

#### 2026-05-10 | Barra de progreso
Se incorpor├│ visual de avance en modalidad para mejorar lectura de progreso.

#### 2026-05-10 | Lecci├│n completa
Se agreg├│ escena y flujo de finalizaci├│n para cierre m├ís claro.

#### 2026-05-10 a 2026-05-12 | Vinculaci├│n integrada
Se integr├│ modalidad de vinculaci├│n al flujo de nodo y continuidad compartida con el resto de modalidades.

#### 2026-05-13 | Bug del plato
Se corrigi├│ comportamiento inconsistente en arrastre sobre plato.

#### 2026-05-14 | Mapa completo
Se actualizaron elementos visuales del mapa para reflejar continuidad del recorrido.

### Entrega 2

- Falta confirmar alcance y versi├│n final de [03-Entrega-2.md](03-Entrega-2.md).

### Pr├│ximas entregas

- Falta confirmar hoja de ruta consolidada en [04-Entrega-3.md](04-Entrega-3.md).

## Insumo para Entrega 1

> La s├¡ntesis formal de la Entrega 1 se encuentra en [02-Entrega-1.md](02-Entrega-1.md).

Estos avances deber├¡an pasar a [02-Entrega-1.md](02-Entrega-1.md) como n├║cleo defendible de producto:

- Persistencia local: el jugador puede retomar su progreso sin depender de servicios externos.
- Guardado parcial: evita reinicios completos y mejora continuidad de uso.
- Contenido JSON desacoplado: sumar o ajustar actividades requiere menos cambios de c├│digo.
- Partida por nodo: un nodo puede combinar varios juegos internos sin hardcodear escenas.
- Barra de progreso: el jugador ahora entiende cu├ínto le falta para terminar.
- Lecci├│n terminada: la actividad ya no termina de forma abrupta y deja un cierre legible.
- Vinculaci├│n de conceptos: agrega variedad pedag├│gica y demuestra extensibilidad del flujo.
- Correcciones de estabilidad: reduce errores visibles en gameplay durante demo.
- Validaciones CI / smoke test: baja riesgo de regresiones en navegaci├│n y flujo jugable m├¡nimo.
