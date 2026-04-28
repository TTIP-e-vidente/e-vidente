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
2. `MapScene.gd` arma `contexto_sesion` con `track_key`, `node_key`, `node_json_path` y `return_scene_path`.
3. `project/preguntas/NodeContentLoader.gd` carga el JSON del nodo jugable y devuelve siempre `{ ok, data, error }`.
4. Si `ok` es `true`, `data` ya usa el contrato oficial: `id`, `theme`, `title`, `difficulty`, `mode`, `content`.
5. `project/mapas/PlayableNodeRouter.gd` mira `mode` y devuelve la escena jugable.
6. `project/preguntas/pregunta.gd` ejecuta `quiz_choice`; `project/mapas/drag_drop/DragDropNode.gd` ejecuta `drag_drop`.
7. `project/preguntas/QuestionJsonLoader.gd` queda solo como adaptador temporal de `quiz_choice` al modelo viejo `ThemePreg/Preguntas`.
8. Para crear un nodo nuevo, el path por convencion es `project/niveles/nodos/<track_key>/<node_key>.json`.
9. Para sumar una modalidad futura: agregar `mode`, validar `content`, rutear la escena y crear la nueva actividad.
10. En los nodos del mapa, la API principal ya usa `node_key`, `node_json_path` y `node_resource_path`; los nombres `question_*` quedan solo como compatibilidad legacy interna, no como API nueva.

## Estructura de contenido jugable

- `project/niveles/nodos/celiaquia/`: contenido real de nodos jugables del track.
- `project/niveles/nodos/ejemplos/`: ejemplos oficiales y legacy de referencia.
- `project/preguntas/`: modalidad `quiz_choice` y su adaptador temporal, no el sistema completo.
- `project/mapas/`: mapa, routing y contexto de apertura.
- `project/mapas/drag_drop/`: modalidad `drag_drop`.
- `mode` define la modalidad; `content` contiene solo los datos especificos de esa modalidad.
