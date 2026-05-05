extends SceneTree

const ContinuidadDeCorridaDeNodoScript := preload("res://mapas/core/ContinuidadDeCorridaDeNodo.gd")

const ESCENA_PREGUNTA := "res://preguntas/pregunta.tscn"
const JSON_PREGUNTA := "res://contenido/nodos/celiaquia/preguntas/eliminar_gluten.json"
const TIEMPO_MAXIMO_DE_PRUEBA := 8.0

var fallo := false
var prueba_finalizada := false
var preparaciones_de_siguiente_juego := 0
var finalizaciones_de_corrida := 0


func _initialize() -> void:
	iniciar_timeout_de_seguridad()
	call_deferred("ejecutar_prueba")


func iniciar_timeout_de_seguridad() -> void:
	var temporizador: SceneTreeTimer = create_timer(TIEMPO_MAXIMO_DE_PRUEBA)
	temporizador.timeout.connect(fallar_por_timeout)


func fallar_por_timeout() -> void:
	if prueba_finalizada:
		return
	finalizar_con_error("La prueba de flujo progresivo de nodo superó el tiempo máximo.")


func ejecutar_prueba() -> void:
	await process_frame

	var estado_global: Node = root.get_node_or_null("/root/Global")
	_verificar(estado_global != null, "La prueba necesita el autoload Global.")
	if fallo:
		finalizar_con_error()
		return

	_limpiar_estado_global(estado_global)
	estado_global.call("iniciar_corrida_de_nodo", _construir_plan_de_prueba())

	_verificar(
		ContinuidadDeCorridaDeNodoScript.hay_siguiente_juego(self),
		"La corrida de prueba debería tener un siguiente juego."
	)

	var abrio_siguiente_juego: bool = ContinuidadDeCorridaDeNodoScript.continuar_o_finalizar_corrida(
		self,
		Callable(self, "_registrar_preparacion_de_siguiente_juego"),
		Callable(self, "_registrar_finalizacion_de_corrida")
	)
	_verificar(abrio_siguiente_juego, "La continuidad debería abrir el siguiente juego.")
	await _esperar_escena(ESCENA_PREGUNTA)

	var corrida_activa: Dictionary = estado_global.call("obtener_corrida_de_nodo_actual")
	var juego_actual: Dictionary = estado_global.call("obtener_juego_actual_del_nodo")
	_verificar(preparaciones_de_siguiente_juego == 1, "La continuidad debería preparar un solo siguiente juego.")
	_verificar(finalizaciones_de_corrida == 0, "La corrida no debería finalizar en la primera continuidad.")
	_verificar(
		int(corrida_activa.get("indice_juego_actual", -1)) == 1,
		"La corrida debería avanzar al segundo juego."
	)
	_verificar(
		int(juego_actual.get("indice_juego_actual", -1)) == 1,
		"Global debería exponer el segundo juego como juego actual."
	)
	_verificar(
		not ContinuidadDeCorridaDeNodoScript.hay_siguiente_juego(self),
		"Después de avanzar, ya no debería quedar otro juego."
	)

	var termino_corrida: bool = ContinuidadDeCorridaDeNodoScript.continuar_o_finalizar_corrida(
		self,
		Callable(self, "_registrar_preparacion_de_siguiente_juego"),
		Callable(self, "_registrar_finalizacion_de_corrida")
	)
	_verificar(not termino_corrida, "La última continuidad debería finalizar la corrida.")
	_verificar(finalizaciones_de_corrida == 1, "La finalización de corrida debería ejecutarse una vez.")
	_verificar(
		(estado_global.call("obtener_corrida_de_nodo_actual") as Dictionary).is_empty(),
		"La corrida activa debería quedar vacía al finalizar."
	)
	_verificar(
		(estado_global.call("obtener_juego_actual_del_nodo") as Dictionary).is_empty(),
		"El juego actual debería limpiarse al finalizar la corrida."
	)

	_detener_audio()
	_cerrar_escena_actual()
	_limpiar_estado_global(estado_global)

	if fallo:
		finalizar_con_error()
		return
	finalizar_ok()


func _construir_plan_de_prueba() -> Dictionary:
	return {
		"clave_nodo": "nodo_prueba",
		"titulo_nodo": "Nodo de prueba",
		"clave_pista": "celiaquia",
		"escena_de_retorno": "res://mapas/MapScene.tscn",
		"dificultad": 2,
		"numero_nivel": 1,
		"indice_juego_actual": 0,
		"total_juegos": 2,
		"juegos": [
			{
				"mode": "drag_drop",
				"json_path": "res://contenido/nodos/celiaquia/arrastre/receta_1_desayuno.json",
				"titulo": "Primer juego",
				"dificultad": 1,
				"clave_nodo_de_origen": "receta_1_desayuno",
			},
			{
				"mode": "quiz_choice",
				"json_path": JSON_PREGUNTA,
				"titulo": "Segundo juego",
				"dificultad": 2,
				"clave_nodo_de_origen": "eliminar_gluten",
			},
		],
	}


func _esperar_escena(ruta_escena: String) -> void:
	for _indice_espera in range(60):
		if fallo or prueba_finalizada:
			return
		await process_frame
		if current_scene != null and current_scene.scene_file_path == ruta_escena:
			return
	_verificar(false, "No se llegó a la escena esperada: %s" % ruta_escena)


func _registrar_preparacion_de_siguiente_juego() -> void:
	preparaciones_de_siguiente_juego += 1


func _registrar_finalizacion_de_corrida() -> void:
	finalizaciones_de_corrida += 1


func _limpiar_estado_global(estado_global: Node) -> void:
	if estado_global == null:
		return
	estado_global.call("finalizar_corrida_de_nodo")
	estado_global.call("limpiar_sesion_nodo_jugable_activo")
	if estado_global.has_method("reiniciar_progreso"):
		estado_global.call("reiniciar_progreso")


func _cerrar_escena_actual() -> void:
	if not is_instance_valid(current_scene):
		return
	var escena_actual: Node = current_scene
	current_scene = null
	escena_actual.free()


func _detener_audio() -> void:
	for audio_crudo in root.find_children("*", "AudioStreamPlayer", true, false):
		var audio: AudioStreamPlayer = audio_crudo as AudioStreamPlayer
		if audio == null:
			continue
		audio.stop()
		audio.stream = null
	for audio_crudo in root.find_children("*", "AudioStreamPlayer2D", true, false):
		var audio_2d: AudioStreamPlayer2D = audio_crudo as AudioStreamPlayer2D
		if audio_2d == null:
			continue
		audio_2d.stop()
		audio_2d.stream = null


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("FLUJO PROGRESIVO TEST FAILED: %s" % mensaje)


func finalizar_ok() -> void:
	_cerrar_prueba(0)


func finalizar_con_error(mensaje: String = "") -> void:
	if not mensaje.is_empty() and not fallo:
		printerr("FLUJO PROGRESIVO TEST FAILED: %s" % mensaje)
	fallo = true
	_cerrar_prueba(1)


func _cerrar_prueba(codigo_salida: int) -> void:
	if prueba_finalizada:
		return
	prueba_finalizada = true
	quit(codigo_salida)