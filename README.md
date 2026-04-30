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

## Flujo de nodo jugable

1. `project/mapas/MapScene.gd` maneja el mapa.
2. `project/preguntas/NodeContentLoader.gd` carga el JSON del nodo.
3. `project/mapas/PlayableNodeRouter.gd` elige escena por `mode`.
4. `quiz_choice` abre `project/preguntas/pregunta.tscn`.
5. `drag_drop` abre `project/niveles/nivel_1/Level.tscn`.
6. La modalidad termina y llama `Global.solicitar_continuar(node_key_actual)`.
7. `MapScene.gd` consume esa intención y abre el siguiente nodo del mapa.
8. `project/mapas/drag_drop/DragDropNode.tscn` queda como legacy/back-up y no forma parte del flujo principal.

## Responsabilidades del mapa

- `MapScene.gd`: orquesta el mapa, carga contenido y abre nodos jugables.
- `LevelNode.gd`: representa un nodo visual clickeable y emite `nodo_seleccionado`.
- `MapNodeData.gd`: describe datos simples del nodo del mapa.
- `MapProgress.gd`: resuelve progreso, desbloqueo y siguiente nodo.
- Las modalidades no deciden el siguiente nodo.

Para agregar un nodo nuevo:

- autorizarlo visualmente en el mapa con `LevelNode.tscn` o el board del mapa.
- crear su JSON en `project/niveles/nodos/<track_key>/<node_key>.json`.

Para agregar una modalidad nueva:

- definir su `mode` y validar su `content` en `NodeContentLoader.gd` y `NodeContentValidator.gd`.
- rutear la escena en `PlayableNodeRouter.gd` y crear la nueva escena jugable.

Los nombres `question_*` quedan solo como compatibilidad legacy interna, no como API nueva.

## Estructura de contenido jugable

- `project/niveles/nodos/celiaquia/`: contenido real de nodos jugables del track.
- `project/niveles/nodos/ejemplos/`: ejemplos oficiales y legacy de referencia.
- `project/preguntas/`: modalidad `quiz_choice` y su adaptador temporal, no el sistema completo.
- `project/mapas/`: mapa, routing y contexto de apertura.
- `project/niveles/nivel_1/`: modalidad oficial `drag_drop` basada en `Level.tscn` y `Level.gd`.
- `project/mapas/drag_drop/`: legacy/back-up; no es el flujo principal de `drag_drop`.
- `mode` define la modalidad; `content` contiene solo los datos especificos de esa modalidad.
