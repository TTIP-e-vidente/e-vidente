# User Stories — Entrega 3

Historias de usuario de la Entrega 3. Epic: [UNQ-8](https://tip-unq.atlassian.net/browse/UNQ-8). Estado de tickets: [Evidencia](Entrega-3-Evidencia#tickets-jira).

---

## US-01 — Contar con infraestructura de persistencia en PostgreSQL

**Actor/es:** Equipo de desarrollo
**Funcionalidad:** Levantar PostgreSQL local con Docker, validar conexión, modelar las entidades del jugador y relevar qué datos locales deben migrarse primero.
**Valor que aporta:** El equipo tiene un entorno reproducible y un esquema claro para persistir perfil, progreso y partidas sin depender solo del save local de Godot.

### Criterios de aceptación

- Dado que el desarrollador sigue la documentación, cuando ejecuta Docker Compose, entonces PostgreSQL levanta con credenciales por variables de entorno y volumen persistente.
- Dado que el backend está corriendo, cuando se prueba la conexión, entonces se puede insertar y consultar un dato de prueba del jugador.
- Dado el save local actual, cuando se releva la persistencia, entonces quedan documentados los datos críticos a migrar y los que quedan fuera de alcance.
- Dado el modelo acordado, cuando se aplican migraciones, entonces existen tablas para usuario, perfil, progreso acumulado y resumen de partidas.

### Tickets relacionados

- UNQ-85 — Configurar PostgreSQL local con Docker
- UNQ-87 — Validar conexión inicial con PostgreSQL
- UNQ-162 — Modelar entidades principales del jugador en PostgreSQL
- UNQ-161 — Identificar datos locales críticos a migrar

**Cómo se valida:** `docker compose up` levanta la base; un endpoint o prueba mínima inserta y consulta datos; el DER y las migraciones reflejan usuario, perfil, progreso y partidas; el relevamiento de datos locales está documentado.

### Estado

En revisión (UNQ-161 terminado).

---

## US-02 — Crear cuenta e iniciar sesión en el juego

**Actor/es:** Jugador
**Funcionalidad:** Registrarse e iniciar sesión desde el flujo del juego, con pantallas diseñadas de forma clara y coherente con la estética de E-VIDENTE.
**Valor que aporta:** El jugador puede asociar su progreso a una cuenta personal sin abandonar la experiencia ni enfrentar formularios confusos.

### Criterios de aceptación

- Dado que el jugador es nuevo, cuando elige registrarse, entonces puede ingresar los datos mínimos y recibe confirmación o error claro.
- Dado que el jugador ya tiene cuenta, cuando inicia sesión con credenciales válidas, entonces accede a su sesión y puede continuar jugando.
- Dado que las credenciales son incorrectas o el email ya existe, cuando intenta registrarse o loguearse, entonces el sistema informa el error sin bloquear el flujo offline.
- Dado que el jugador navega por login o registro, cuando ve las pantallas, entonces la interfaz mantiene coherencia visual con el resto del juego.

### Tickets relacionados

- UNQ-65 — Diseñar registro de usuario
- UNQ-171 — Diseñar pantalla de login de usuario
- UNQ-90 — Implementar registro de usuario
- UNQ-91 — Implementar login de usuario

**Cómo se valida:** completar registro con datos válidos, rechazar duplicados y credenciales inválidas, iniciar sesión y recuperar sesión; las pantallas respetan el diseño acordado y permiten seguir en modo offline.

### Estado

**Lista para cierre** — UNQ-65, UNQ-171, UNQ-90 y UNQ-91 terminados en Jira (10 jun 2026).

---

## US-03 — Sincronizar progreso local con la cuenta en PostgreSQL

**Actor/es:** Jugador registrado
**Funcionalidad:** Migrar el progreso guardado localmente hacia el backend al iniciar sesión, guardar cada partida finalizada en PostgreSQL y reintentar la sincronización si falla la conexión.
**Valor que aporta:** El jugador conserva su avance en la nube sin perder el respaldo local ni quedar bloqueado ante errores de red o del servidor.

### Criterios de aceptación

- Dado que existe progreso local previo, cuando el jugador inicia sesión, entonces el sistema puede migrarlo al backend sin duplicar partidas ni experiencia ya sincronizada.
- Dado que el jugador termina una partida, cuando hay sesión activa, entonces se guarda primero localmente y luego se intenta sincronizar el resumen con PostgreSQL.
- Dado que el backend no está disponible, cuando falla la sincronización, entonces el progreso queda marcado como pendiente y se conserva localmente.
- Dado que la conexión vuelve, cuando el sistema reintenta, entonces puede enviar los resúmenes pendientes sin acoplar la lógica de gameplay a llamadas HTTP directas.

### Tickets relacionados

- UNQ-160 — Migrar y sincronizar progreso local del jugador con PostgreSQL
- UNQ-163 — Guardar resumen de partida en PostgreSQL

**Cómo se valida:** jugar offline, iniciar sesión y verificar migración; finalizar partida con sesión activa y confirmar persistencia remota; simular caída del backend y verificar cola local + reintento.

### Estado

En revisión.

---

## US-04 — Consultar el perfil en una pantalla dedicada

**Actor/es:** Jugador
**Funcionalidad:** Ver nombre, avatar, métricas de progreso, racha y una acción clara para continuar la partida desde una escena de perfil completa, no solo un modal.
**Valor que aporta:** El jugador entiende su estado personal en un solo lugar ordenado, con lectura rápida y continuidad hacia el mapa.

### Criterios de aceptación

- Dado que el jugador accede al perfil, cuando se abre la pantalla, entonces ve nombre, avatar y métricas principales en una jerarquía visual clara.
- Dado que el perfil está visible, cuando revisa su información, entonces puede ver progreso de partidas y estado de racha.
- Dado que quiere seguir jugando, cuando elige continuar, entonces vuelve al flujo principal sin errores.
- Dado que aún no hay todos los datos remotos, cuando la pantalla carga, entonces puede mostrar datos locales o mockeados sin romper la navegación.

### Tickets relacionados

- UNQ-107 — Diseñar pantalla de perfil de usuario
- UNQ-27 — Implementar escena de perfil de usuario

**Cómo se valida:** navegar al perfil desde el flujo principal, verificar layout y métricas, volver al mapa con la acción de continuar; la escena deja de depender exclusivamente de un modal.

### Estado

En curso — UNQ-107 (diseño) terminado; UNQ-27 (implementación) en progreso.

---

## US-05 — Unificar partidas del mapa en un nodo reutilizable

**Actor/es:** Creador de contenido / equipo de desarrollo
**Funcionalidad:** Representar cualquier partida del mapa con un único tipo de nodo que admita múltiples modalidades (preguntas, arrastre, vincular, enseñanzas, etc.) definidas por configuración JSON.
**Valor que aporta:** Agregar o combinar modalidades en una partida no requiere nuevos tipos de nodo ni cambios manuales en el editor por cada variante.

### Criterios de aceptación

- Dado el mapa de celiaquía, cuando una partida incluye varias modalidades, entonces un solo tipo de nodo las orquesta según la configuración.
- Dado que se refactoriza el mapa, cuando las partidas existentes siguen jugables, entonces no se rompe compatibilidad con temáticas actuales.
- Dado un nodo de partida, cuando cambia el JSON de contenido, entonces las modalidades se asignan dinámicamente sin depender del tipo visual del nodo.

### Tickets relacionados

- UNQ-170 — Implementar Partidas como un Nodo único que admita muchas modalidades de juego

**Cómo se valida:** recorrer partidas del mapa con distintas combinaciones de modalidades; verificar que el layout y el flujo de partida se mantienen tras la unificación.

### Estado

En revisión.

---

## US-06 — Cargar enseñanzas y su feedback desde JSON

**Actor/es:** Jugador / equipo de contenido
**Funcionalidad:** Desacoplar las enseñanzas educativas y su feedback visual para que títulos, textos, recursos y estados se configuren en archivos JSON, con diseño visual coherente.
**Valor que aporta:** Se pueden sumar o editar contenidos educativos sin tocar código y el jugador recibe acompañamiento visual más claro durante el aprendizaje.

### Criterios de aceptación

- Dado un archivo JSON de enseñanzas, cuando el juego lo carga, entonces muestra títulos, textos y recursos parametrizados.
- Dado que se agrega una enseñanza nueva, cuando se actualiza el JSON, entonces no hace falta modificar scripts de la modalidad.
- Dado el diseño de feedback acordado, cuando el jugador avanza por una enseñanza, entonces los estados visuales refuerzan la comprensión sin romper la estética general.

### Tickets relacionados

- UNQ-167 — Diseñar feedback enseñanzas
- UNQ-168 — Implementar feedback enseñanzas mediante JSON

**Cómo se valida:** cargar enseñanzas desde JSON en runtime, agregar una entrada nueva solo editando contenido, verificar que el feedback diseñado se integra con la lógica actual.

### Estado

En curso — UNQ-167 (diseño) terminado; UNQ-168 en progreso.

---

## US-07 — Validar la UX/UI de la modalidad Preguntas con tests automatizados

**Actor/es:** Equipo de desarrollo
**Funcionalidad:** Ejecutar un test automatizado que recorra la modalidad de Preguntas como un test de frontend en Godot: carga de pantalla, enunciado, opciones, selección, feedback y acción para avanzar.
**Valor que aporta:** El equipo detecta regresiones visibles de la modalidad antes del merge y tiene evidencia objetiva de que el jugador no queda bloqueado en la interfaz.

### Criterios de aceptación

- Dado que corre la suite con GdUnit4, cuando se ejecuta el test de Preguntas, entonces valida presencia del contenedor principal, enunciado y opciones visibles.
- Dado que el test simula una respuesta, cuando el jugador selecciona una opción, entonces verifica feedback visual y posibilidad de continuar.
- Dado un push al repositorio, cuando el CI corre los tests, entonces el resultado queda visible para el equipo.

### Tickets relacionados

- UNQ-172 — Implementar test automatizado de UX/UI para modalidad de preguntas

**Cómo se valida:** ejecutar `test_modalidad_preguntas_ux_ui.gd` (o suite equivalente) con 0 failures; el test cubre carga → interacción → feedback → continuidad sin validar balance pedagógico profundo.

### Estado

En curso.

---

## US-08 — Mejorar la lectura visual de los alimentos en pantalla

**Actor/es:** Jugador
**Funcionalidad:** Mostrar las imágenes de comidas con un borde o contorno que las separe del fondo y mejore su visibilidad en las modalidades donde aparecen.
**Valor que aporta:** El jugador distingue mejor los alimentos interactivos, lo que reduce confusión y mejora accesibilidad visual.

### Criterios de aceptación

- Dado que el jugador ve comidas en una actividad, cuando se renderizan los sprites, entonces tienen un contorno que las separa del fondo.
- Dado distintas resoluciones y escenas con alimentos, cuando se muestran los assets, entonces el tratamiento visual es coherente con el estilo del juego.

### Tickets relacionados

- UNQ-166 — Generar un borde blanco en las comidas para mejor percepción

**Cómo se valida:** recorrido visual por modalidades con comidas (arrastre, catálogo, etc.) verificando contorno visible y consistencia gráfica.

### Estado

Terminada.

---

## Resumen de lo que hicimos en el sprint

### Infraestructura y persistencia

Levantamos PostgreSQL con Docker, validamos la conexión y modelamos las entidades del jugador. Relevamos qué datos locales migrar primero: perfil, puntaje, EXP, partidas, nodos, racha, desbloqueos.

### Cuenta y sesión

Registro y login quedaron integrados al flujo del juego. Los cuatro tickets de US-02 están **terminados** en Jira. Si el backend no responde, el jugador sigue offline.

### Sincronización

Al loguearse migra el save local. Al terminar una partida guarda el resumen remoto. Si falla la red, encola y reintenta — sin acoplar el gameplay a HTTP.

### Mapa y contenido

Avanzamos el nodo único de partida con modalidades por JSON (UNQ-170).

### Calidad y educación

Enseñanzas hacia JSON, feedback visual diseñado, tests UX/UI para Preguntas en marcha. Comidas con borde blanco cerrado (UNQ-166).

### Qué falta cerrar

Tickets en **Revisión** (infra, sync, nodo único), escena de perfil (UNQ-27), enseñanzas JSON (UNQ-168) y test UX Preguntas (UNQ-172).

Tabla ticket ↔ Jira: **[Evidencia](Entrega-3-Evidencia#tickets-jira-del-sprint)**.

---

## Decisiones tomadas durante la iteración

- **Agrupar 17 tickets del sprint en 8 user stories** — mantiene la misma lógica de bloques coherentes que Entrega 1 y 2.
- **Save local primero, sync después** — el juego nunca depende del backend para jugar; la cuenta suma persistencia remota.
- **Backend opcional en demo** — registro, login y sync funcionan cuando el API está levantado; offline sigue siendo válido.
- **Separar diseño (DESING) de implementación (Historia/Tarea)** — login, registro, perfil y feedback educativo siguen el mismo patrón que entregas anteriores.
- **Tests de UX/UI acotados a interfaz** — UNQ-172 valida flujo visible, no balance ni reglas pedagógicas profundas.

---
