## Muestra un texto carácter a carácter, como si alguien lo estuviera escribiendo.
## Uso: _typewriter.iniciar(self, func(t): mi_label.text = t, "Texto a mostrar")
## Llamar iniciar() de nuevo cancela la animación anterior automáticamente.
class_name TypewriterEffect
extends RefCounted

## Cursor visual que parpadea mientras se escribe.
const CURSOR := "▌"

## Segundos entre cada carácter (más bajo = más rápido).
var character_delay: float = 0.035
## Pausa antes de empezar a escribir.
var initial_delay: float = 0.15
## Pausa al terminar, antes de retornar al llamador.
var after_finish_delay: float = 0.10
## Si es true, un toque o clic muestra el texto completo de inmediato.
var allow_skip: bool = true

# Cada llamada a iniciar() incrementa este número.
# El loop lo compara consigo mismo para saber si fue reemplazado por una llamada más nueva.
var _id_llamada_vigente: int = 0
var _en_progreso: bool = false
var _salto_solicitado: bool = false


## Devuelve true si hay una animación activa.
func esta_escribiendo() -> bool:
	return _en_progreso


## Pide saltar la animación actual. Llamar desde _input() de la escena.
func solicitar_salto() -> void:
	_salto_solicitado = true


## Inicia la animación. Es awaitable o se puede llamar sin await (segundo plano).
func iniciar(nodo_escena: Node, aplicar_texto: Callable, texto_completo: String) -> void:
	_salto_solicitado = false
	_id_llamada_vigente += 1
	var mi_id := _id_llamada_vigente
	_en_progreso = true

	aplicar_texto.call("")

	if initial_delay > 0.0:
		await nodo_escena.get_tree().create_timer(initial_delay).timeout
		if mi_id != _id_llamada_vigente:
			return

	for cantidad_visible in range(texto_completo.length()):
		if mi_id != _id_llamada_vigente:
			return

		if allow_skip and _salto_solicitado:
			aplicar_texto.call(texto_completo)
			break

		var fragmento_visible: String = texto_completo.substr(0, cantidad_visible + 1)
		var es_ultimo_caracter: bool = (cantidad_visible == texto_completo.length() - 1)
		if not es_ultimo_caracter:
			fragmento_visible += CURSOR

		aplicar_texto.call(fragmento_visible)
		await nodo_escena.get_tree().create_timer(character_delay).timeout

	if mi_id != _id_llamada_vigente:
		return

	_en_progreso = false
	aplicar_texto.call(texto_completo)

	if after_finish_delay > 0.0:
		await nodo_escena.get_tree().create_timer(after_finish_delay).timeout
