extends SceneTree

const ESCENA_INDICADOR := preload("res://interface/components/IndicadorProgresoDeJuego.tscn")

const TIEMPO_MAXIMO_DE_PRUEBA := 8.0
const RUTA_TEXTO_CONTEXTO := "CapaHud/ContenedorMargen/ColumnaHud/FilaSuperior/Panel/Padding/Fila/TextoContexto"
const RUTA_TEXTO_PROGRESO := "CapaHud/ContenedorMargen/ColumnaHud/FilaSuperior/Panel/Padding/Fila/TextoProgreso"

var fallo := false
var prueba_finalizada := false


func _initialize() -> void:
	iniciar_timeout_de_seguridad()
	call_deferred("ejecutar_prueba")


func iniciar_timeout_de_seguridad() -> void:
	var temporizador: SceneTreeTimer = create_timer(TIEMPO_MAXIMO_DE_PRUEBA)
	temporizador.timeout.connect(fallar_por_timeout)


func fallar_por_timeout() -> void:
	if prueba_finalizada:
		return
	finalizar_con_error("La prueba del indicador de pregunta superó el tiempo máximo.")


func ejecutar_prueba() -> void:
	var indicador: CanvasLayer = ESCENA_INDICADOR.instantiate() as CanvasLayer
	root.add_child(indicador)
	await process_frame

	indicador.configurar(
		{
			"titulo": "Pregunta segura",
			"actual": 2,
			"total": 5,
		}
	)
	await process_frame

	var texto_contexto: Label = indicador.get_node_or_null(RUTA_TEXTO_CONTEXTO) as Label
	var texto_progreso: Label = indicador.get_node_or_null(RUTA_TEXTO_PROGRESO) as Label
	_verificar(texto_contexto != null, "El indicador debería exponer el label de contexto.")
	_verificar(texto_progreso != null, "El indicador debería exponer el label de progreso.")
	if not fallo:
		_verificar(texto_contexto.visible, "El título del juego debería quedar visible.")
		_verificar(texto_contexto.text == "Pregunta segura", "El indicador debería mostrar el título recibido.")
		_verificar(texto_progreso.text == "Juego 2/5", "El indicador debería mostrar Juego 2/5.")

	if is_instance_valid(indicador):
		indicador.queue_free()

	if fallo:
		finalizar_con_error()
		return
	finalizar_ok()


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("INDICADOR PREGUNTA TEST FAILED: %s" % mensaje)


func finalizar_ok() -> void:
	_cerrar_prueba(0)


func finalizar_con_error(mensaje: String = "") -> void:
	if not mensaje.is_empty() and not fallo:
		printerr("INDICADOR PREGUNTA TEST FAILED: %s" % mensaje)
	fallo = true
	_cerrar_prueba(1)


func _cerrar_prueba(codigo_salida: int) -> void:
	if prueba_finalizada:
		return
	prueba_finalizada = true
	quit(codigo_salida)
