# User Stories — Entrega 2

## US-01 — Ver transiciones suaves al navegar entre pantallas

**Actor/es:** Jugador
**Funcionalidad:** Al moverse entre el mapa, una partida y la pantalla de resultados, el juego presenta transiciones animadas en lugar de cambios bruscos de escena.
**Valor que aporta:** El jugador percibe el juego como una experiencia fluida y pulida, no como pantallas que cortan abruptamente.

### Criterios de aceptación

- Dado que el jugador elige un nodo en el mapa, cuando comienza la partida, entonces se ejecuta una transición animada antes de mostrar la actividad.
- Dado que el jugador completa una actividad, cuando pasa a la pantalla de resultados, entonces la transición es suave y no hay parpadeo.
- Dado que el jugador vuelve al mapa desde resultados, cuando aparece el mapa, entonces la transición mantiene la continuidad visual.

### Tickets relacionados

- UNQ-111 — Transición suave de mapa a partida
- UNQ-112 — Transición suave de partida a resultados
- UNQ-113 — Transición suave de resultados a mapa

**Cómo se valida:** se puede completar el ciclo mapa → partida → resultados → mapa con transiciones animadas en todas las etapas, sin cortes visuales abruptos.

### Estado

Terminada.

---

## US-02 — Experimentar una interfaz visualmente renovada

**Actor/es:** Jugador
**Funcionalidad:** Todas las pantallas principales del juego (intro, selector, mapa, progress bar, pregunta, vincular, completar palabra, lección completa y arrastre) presentan una estética cohesiva y renovada.
**Valor que aporta:** El jugador percibe el juego como un producto cuidado y profesional, lo que aumenta la confianza y el disfrute.

### Criterios de aceptación

- Dado que el jugador navega por el juego, cuando pasa por cualquier pantalla principal, entonces la interfaz muestra la nueva estética con colores, tipografías e íconos consistentes.
- Dado que el jugador inicia una actividad de Pregunta o Vincular, cuando ve los botones de opciones, entonces estos tienen la nueva apariencia gráfica (sketch rectangles).
- Dado que el jugador está en la modalidad Arrastre, cuando ve la pantalla de juego, entonces el diseño es coherente con el resto de las pantallas.

### Tickets relacionados

- UNQ-28 — Implementar feedback layer visual

**Cómo se valida:** recorrido visual completo por todas las pantallas principales sin encontrar pantallas con la estética anterior sin actualizar.

### Estado

Terminada.

---

## US-03 — Recibir felicitación especial al completar una partida perfecta

**Actor/es:** Jugador
**Funcionalidad:** Al completar una partida sin errores, el juego muestra una animación especial con estrellas y una pantalla de cierre diferenciada que comunica el logro.
**Valor que aporta:** El jugador siente que su desempeño excelente es reconocido de forma especial, lo que refuerza la motivación para seguir jugando bien.

### Criterios de aceptación

- Dado que el jugador completa las tres actividades de una partida sin errores, cuando llega a la pantalla de cierre, entonces aparece una animación de estrellas.
- Dado que la pantalla de cierre se muestra, cuando el resultado fue perfecto, entonces el diseño visual es distinto al de una partida regular.
- Dado que la pantalla de cierre se muestra, cuando el resultado fue regular, entonces no se muestran las estrellas de perfecto.

### Tickets relacionados

- UNQ-102 — Implementar felicitación por lección perfecta
- UNQ-101 — Implementar felicitación por completar 3 modalidades sin errores dentro de una partida

**Cómo se valida:** completar una partida sin errores activa la animación de estrellas; completar con al menos un error no la activa.

### Estado

Terminada.

---

## US-04 — Ver el objetivo de la actividad en la modalidad Arrastre

**Actor/es:** Jugador
**Funcionalidad:** Al iniciar una actividad de Arrastre (Plato), el jugador ve un mensaje que describe qué tipo de comida debe preparar y para quién, usando un efecto de escritura progresiva.
**Valor que aporta:** El jugador entiende el contexto de la actividad antes de interactuar, lo que mejora el aprendizaje y reduce confusión.

### Criterios de aceptación

- Dado que el jugador inicia una actividad de Arrastre, cuando la pantalla carga, entonces aparece un texto que describe la comida objetivo y la restricción alimentaria.
- Dado que el texto aparece, cuando empieza a mostrarse, entonces se escribe de forma progresiva con el efecto typewriter.
- Dado que el contenido viene del JSON del nodo, cuando cambia el nodo, entonces el mensaje refleja el objetivo correcto de ese nodo.

### Tickets relacionados

- UNQ-142 — Implementar Mensaje de Plato con el tipo de comida y restricción al que pertenece

**Cómo se valida:** iniciar una actividad de Arrastre muestra el mensaje correcto tomado del JSON del nodo activo, con efecto typewriter.

### Estado

Terminada.

---

## US-05 — Resolver la modalidad Completar Palabra

**Actor/es:** Jugador
**Funcionalidad:** El jugador puede resolver una nueva modalidad educativa en la que debe elegir la palabra correcta para completar una oración, con opciones cargadas desde JSON.
**Valor que aporta:** Agrega variedad al aprendizaje y refuerza vocabulario específico sobre celiaquía mediante una mecánica diferente a las ya existentes.

### Criterios de aceptación

- Dado que el nodo del mapa incluye una actividad de tipo completar, cuando el jugador la inicia, entonces ve una oración con una palabra faltante y opciones para completarla.
- Dado que el jugador elige la opción correcta, cuando confirma, entonces recibe feedback positivo y la actividad avanza.
- Dado que el jugador elige una opción incorrecta, cuando confirma, entonces recibe feedback negativo y puede reintentar.
- Dado que el contenido viene del JSON, cuando cambia el nodo, entonces la oración y las opciones reflejan el contenido correcto.

### Tickets relacionados

- UNQ-95 — Implementar nueva modalidad de juego — completar con opciones de palabras

**Cómo se valida:** completar una actividad de tipo Completar Palabra desde el mapa de Celiaquía, verificando que las opciones cargan del JSON y el feedback funciona correctamente.

### Estado

Terminada.

---

## US-06 — Robutez en el código mediante tests 

**Actor/es:** Desarrollador / equipo
**Funcionalidad:** El pipeline de carga de preguntas desde JSON está cubierto por tests automatizados que corren en cada push y dan feedback inmediato ante regresiones.
**Valor que aporta:** El equipo puede modificar el código de carga de contenido con confianza de que los tests detectarán cualquier ruptura antes de llegar a producción.

### Criterios de aceptación

- Dado que existe un archivo JSON de preguntas, cuando se ejecuta la suite de tests, entonces se valida que el archivo abre, la carga retorna OK, existen opciones correctas e incorrectas, y el evaluador funciona correctamente.
- Dado que se hace un push al repositorio, cuando el CI ejecuta los tests, entonces el resultado es visible en la pull request.

### Tickets relacionados

- Sin ticket formal — iniciativa técnica del equipo

**Cómo se valida:** `8 test cases | 0 errors | 0 failures` en GdUnit4 al correr la suite `carga_json_preguntas_test.gd`.

### Estado

Terminada.
