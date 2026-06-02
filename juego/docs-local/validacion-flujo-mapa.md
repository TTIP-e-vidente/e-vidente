# Checklist de validación del flujo del mapa

Usá esta lista antes de cada demo o entrega. Los items marcados con `[AUTO]` están
cubiertos por los smoke tests. Los marcados con `[MANUAL]` requieren verificación visual.

---

## Apertura del mapa

- [AUTO] El mapa carga correctamente desde `celiaquia_mapa.json`.
- [AUTO] Se renderizan exactamente 30 nodos.
- [AUTO] Todos los nodos son instancias válidas de `MapNode.tscn`.
- [MANUAL] El mapa muestra el fondo y el scroll funciona.

---

## Estados visuales de los nodos

- [MANUAL] Nodos bloqueados se ven en gris opaco (no transparentes como bugs).
- [MANUAL] Nodo disponible pulsa suavemente en loop (no está quieto).
- [MANUAL] Nodo completado tiene tinte verde suave.
- [MANUAL] Ícono del nodo corresponde al modo del nodo (quiz/drag/vincular/completar).

---

## Interacción: nodo disponible

- [AUTO] Un nodo con `default_unlocked=true` emite `nodo_seleccionado` en MapFlow.
- [AUTO] Un nodo disponible no emite `nodo_bloqueado`.
- [MANUAL] El clic en el primer nodo abre la escena jugable correcta.
- [MANUAL] El mini-juego carga el contenido del nodo.

---

## Interacción: nodo bloqueado

- [AUTO] MapFlow emite `nodo_bloqueado` para nodo con prerequisito incumplido.
- [AUTO] MapFlow no emite `nodo_seleccionado` para nodo bloqueado.
- [MANUAL] Al clicar nodo bloqueado aparece el label "Este nodo todavía está bloqueado."
- [MANUAL] El label desaparece solo en ~2 segundos.
- [MANUAL] El label no bloquea input ni abre modal.
- [MANUAL] Clicar repetido un nodo bloqueado no apila múltiples labels.

---

## Completar un nodo y volver

- [AUTO] Completar el nodo 1 desbloquea el nodo 2.
- [AUTO] `get_node_state` devuelve `STATE_COMPLETED` para nodo marcado como completado.
- [MANUAL] Al volver al mapa, el scroll vuelve a la posición anterior.
- [MANUAL] El nodo completado se ve verde (no igual a un nodo disponible).
- [MANUAL] El siguiente nodo ahora tiene el pulso de "disponible".

---

## Guardar y cargar progreso

- [AUTO] `get_all_node_progress` devuelve progreso para nodos completados.
- [MANUAL] Cerrar y reabrir el juego mantiene los nodos completados.
- [MANUAL] El scroll y el estado visual se restauran correctamente.

---

## Ausencia de errores

- [MANUAL] No hay errores rojos en la consola de Godot al abrir el mapa.
- [MANUAL] No hay errores al clicar cualquier nodo (disponible o bloqueado).
- [MANUAL] No hay errores al completar un nodo y volver.

---

## Notas de demo

Si algún item `[MANUAL]` falla antes de la demo, prioridad de corrección:

1. Toast de nodo bloqueado no aparece → revisar `MapScene._mostrar_toast_bloqueado()`
2. Nodos no se renderizan → revisar `MapBoard.configurar_nodos()`
3. Estado visual incorrecto → revisar `MapNode._aplicar_color_de_estado()`
4. Nodo disponible no abre partida → revisar `AbridorDeNodoJugable.abrir_nodo()`
