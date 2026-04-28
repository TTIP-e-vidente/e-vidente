# 🧠🍽️ E-VIDENTE

Un juego de puzzle educativo donde aprender sobre alimentación nunca fue tan evidente… o tan desafiante.

## 🎮 Sobre el proyecto

E-VIDENTE es un videojuego web de tipo rompecabezas que combina entretenimiento y aprendizaje, desafiando al jugador a preparar platos adecuados según distintas condiciones alimenticias como celiaquía, veganismo o combinaciones entre ellas .

A través de mecánicas simples pero profundas, el juego busca generar conciencia sobre restricciones alimentarias que no siempre son evidentes para todos.

## ✨ Idea principal

El jugador asume el rol de un asistente culinario que debe armar platos para distintos personajes, cada uno con requerimientos específicos.

<br>🥗 Acciones varias de arrastre, combinatoria, elección
<br>🔍 Usar una lupa para inspeccionar alimentos
<br>⚠️ Recibir feedback inmediato (aciertos/errores)
<br>📊 Terminar cada partida con un resumen educativo
<br>🔥 Generar una racha por días jugados

## 🎯 Objetivo
<br>Completar la alimentación del personaje correctamente respetando sus condiciones
<br>Aprender a identificar ingredientes problemáticos
<br>Desbloquear progreso y conocimiento

## 🧩 Género
<br>Puzzle / Rompecabezas
<br>Educativo (serious game / Juego serio)
<br>Single-player

## 👥 Público objetivo
Edad: 10 – 60 años
Orientado a cualquier persona interesada en aprender sobre alimentación y sus restricciones

## 🚀 Features principales
<br>MVP
<br>✅ Sistema de reglas por ingredientes (gluten, lácteos, carne, etc.)
<br>✅ Runs cortas (3–8 minutos)
<br>✅ Feedback inmediato educativo
<br>✅ Sistema de puntuación (score, rachas, penalizaciones)
<br>✅ Perfil con progreso (niveles)
<br>✅ Leaderboards (global / semanal)
<br>✅ Logros desbloqueables
<br>✅ Persistencia de partidas

## 💾 Persistencia local

La demo ahora incluye guardado local sin backend ni servicios externos.

<br>✅ Perfil local único por dispositivo, sin login obligatorio
<br>✅ Persistencia local de usuario, edad, mail y avatar/foto
<br>✅ Progreso por capítulos, resumen de avance y recuperación desde backup local
<br>✅ Historial local de eventos relevantes dentro del Archivero

## 🎨 Estilo visual

Inspirado en una estética “dibujada a mano” tipo cuaderno, con:
<br>Líneas de tinta
<br>Texturas de papel
<br>Animaciones simples pero expresivas
<br>Feedback visual fuerte (sellos, efectos, reacciones)

## 🧱 Stack tecnológico

Godot 

## 👨‍💻 Equipo
<br>Agustin Di Santo
<br>Margarita Cortizas

##  Filosofía del proyecto

E-VIDENTE busca demostrar que los videojuegos pueden ser:
<br>Divertidos 🎮
<br>Educativos 📚
<br>Accesibles 🌍

Y que aprender sobre otras realidades también puede ser parte del juego.

## 📌 Estado del proyecto

🚧 En desarrollo

## Cómo leer el flujo de nodos jugables

1. El flujo empieza en `project/mapas/MapScene.gd`, cuando el jugador toca un nodo del mapa.
2. `MapScene.gd` arma el `session_context`, le pide el JSON a `project/preguntas/NodeContentLoader.gd` y recibe siempre `{ ok, data, error }`.
3. Desde ese punto se usa solo el formato oficial `node_data`: `id`, `theme`, `title`, `difficulty`, `mode`, `content`.
4. `project/mapas/PlayableNodeRouter.gd` mira `node_data.mode` y devuelve la escena jugable.
5. `project/preguntas/pregunta.gd` ejecuta `quiz_choice` y `project/mapas/drag_drop/DragDropNode.gd` ejecuta `drag_drop`.
6. `project/preguntas/QuestionJsonLoader.gd` existe solo como adaptador temporal para que `pregunta.gd` siga usando `ThemePreg/Preguntas`.
7. Para crear un nodo nuevo alcanza con agregar o editar un JSON en `project/niveles/nodos/` y apuntar el nodo del mapa a esa clave.
8. Para agregar una modalidad futura hay que sumar su validación en `NodeContentLoader.gd`, su ruta en `PlayableNodeRouter.gd` y su escena jugable.

## Estructura de contenido

- `project/niveles/nodos/`: JSON de nodos jugables del mapa.
- `project/preguntas/`: escena y adaptador de modalidad `quiz_choice`.
- `project/mapas/`: mapa, routing y apertura de nodos.
- `project/mapas/drag_drop/DragDropNode.tscn`: modalidad `drag_drop` MVP.
