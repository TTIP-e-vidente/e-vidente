extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameStreakTrackerScript := preload("res://niveles/progress/GameStreakTracker.gd")
const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)
const ContinuidadDePartidaDeNodoScript := preload(
	"res://mapas/core/ContinuidadDePartidaDeNodo.gd"
)
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const CLAVE_PISTA_PREDETERMINADA := "celiaquia"
const ESCENA_RETORNO_PREDETERMINADA := GameSceneRouter.MAP_SCENE_PATH

@onready var label_pregunta: Label = $Control/LabelPregunta
@onready var titulo_nivel: Label = $TituloNivel/Label
@onready var contenedor_izquierda: VBoxContainer = $Control/VBoxIzquierda
@onready var contenedor_derecha: VBoxContainer = $Control/VBoxDerecha
@onready var boton_atras: Button = $"Atrás"
@onready var indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego
@onready var _continuar_juego = $ContinuarJuego

var seleccion_izquierda: ConceptoItem = null
var seleccion_derecha: ConceptoItem = null

var pares_completados := 0
var total_pares := 0
var clave_pista := CLAVE_PISTA_PREDETERMINADA
var nivel_id := 1
var bloqueado := false
var ya_continuo := false

var _nodo_actual: String = ""
var _tiene_sesion_de_mapa := false
var _pertenece_a_partida_de_nodo := false
var _ruta_escena_de_retorno := ESCENA_RETORNO_PREDETERMINADA
var _mensaje_error_bloqueante := ""
var _retroalimentacion_racha_post_juego: Dictionary = {}
var _estado_flujo_post_juego: Dictionary = {}
var _datos_de_ejecucion: Dictionary = {}
var _items_izquierda: Array[ConceptoItem] = []
var _items_derecha: Array[ConceptoItem] = []


func _ready() -> void:
	_recolectar_items()
	_conectar_continuar_juego()
	if boton_atras != null:
		boton_atras.pressed.connect(_on_atras_presionado)
	configurar_desde_sesion()
	_configurar_indicador_de_progreso_de_juego()
	if not _mensaje_error_bloqueante.is_empty():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	_aplicar_runtime_en_escena()


func _recolectar_items() -> void:
	_items_izquierda = _extraer_conceptos(contenedor_izquierda)
	_items_derecha = _extraer_conceptos(contenedor_derecha)


func _extraer_conceptos(contenedor: VBoxContainer) -> Array[ConceptoItem]:
	var items: Array[ConceptoItem] = []
	for child in contenedor.get_children():
		var item: ConceptoItem = child as ConceptoItem
		if item == null:
			continue
		item.seleccionado.connect(_on_item_seleccionado)
		items.append(item)
	return items


func _conectar_continuar_juego() -> void:
	if _continuar_juego == null:
		return
	if _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.connect("continuar_solicitado", Callable(self, "_al_solicitar_continuar"))


func configurar_desde_sesion() -> void:
	_reiniciar_estado_local()
	var contexto_sesion: Dictionary = _obtener_contexto_jugable_actual()
	if contexto_sesion.is_empty():
		_mensaje_error_bloqueante = "No hay una sesión activa para este juego."
		return
	_aplicar_contexto_de_sesion(contexto_sesion)
	_cargar_datos_de_vinculacion(contexto_sesion)


func _aplicar_contexto_de_sesion(contexto_sesion: Dictionary) -> void:
	clave_pista = _leer_clave_pista_de_sesion(contexto_sesion)
	nivel_id = _leer_numero_de_nivel_de_sesion(contexto_sesion)
	_nodo_actual = _leer_clave_nodo_de_sesion(contexto_sesion)
	_pertenece_a_partida_de_nodo = _leer_pertenece_a_partida_de_nodo(contexto_sesion)
	_ruta_escena_de_retorno = GameSceneRouter.read_return_to(
		contexto_sesion,
		ESCENA_RETORNO_PREDETERMINADA
	)
	_tiene_sesion_de_mapa = not _nodo_actual.is_empty()


func _cargar_datos_de_vinculacion(contexto_sesion: Dictionary) -> void:

	var ruta_json: String = _leer_ruta_json_de_sesion(contexto_sesion)
	if ruta_json.is_empty():
		_mensaje_error_bloqueante = "Falta json_path para la vinculación."
		return

	var resultado_nodo: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta_json)
	if not bool(resultado_nodo.get("ok", false)):
		_mensaje_error_bloqueante = str(
			resultado_nodo.get("error", "No se pudo cargar el contenido de vinculación.")
		)
		return

	var resultado_runtime: Dictionary = NodeContentLoaderScript.convertir_vinculacion_a_runtime(
		resultado_nodo.get("data", {})
	)
	if not bool(resultado_runtime.get("ok", false)):
		_mensaje_error_bloqueante = str(
			resultado_runtime.get("error", "No se pudo preparar la vinculación.")
		)
		return

	_datos_de_ejecucion = resultado_runtime.get("data", {}).duplicate(true)


func _reiniciar_estado_local() -> void:
	seleccion_izquierda = null
	seleccion_derecha = null
	pares_completados = 0
	total_pares = 0
	bloqueado = false
	ya_continuo = false
	_nodo_actual = ""
	_tiene_sesion_de_mapa = false
	_pertenece_a_partida_de_nodo = false
	_ruta_escena_de_retorno = ESCENA_RETORNO_PREDETERMINADA
	_mensaje_error_bloqueante = ""
	_retroalimentacion_racha_post_juego = {}
	_estado_flujo_post_juego = {}
	_datos_de_ejecucion = {}


func _obtener_contexto_jugable_actual() -> Dictionary:
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	if not juego_actual.is_empty():
		return juego_actual
	return Global.obtener_sesion_nodo_jugable_activo()


func _configurar_indicador_de_progreso_de_juego() -> void:
	if indicador_de_progreso_de_juego == null:
		return
	var contexto: Dictionary = Global.obtener_contexto_de_progreso_de_juego()
	indicador_de_progreso_de_juego.show()
	indicador_de_progreso_de_juego.actualizar(
		_leer_titulo_para_indicador(contexto),
		_leer_indice_para_indicador(contexto),
		_leer_total_para_indicador(contexto)
	)


func _leer_clave_pista_de_sesion(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("track_key", CLAVE_PISTA_PREDETERMINADA)).strip_edges()


func _leer_numero_de_nivel_de_sesion(contexto_sesion: Dictionary) -> int:
	return int(contexto_sesion.get("level_number", 1))


func _leer_clave_nodo_de_sesion(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("node_key", "")).strip_edges()


func _leer_ruta_json_de_sesion(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("json_path", "")).strip_edges()


func _leer_pertenece_a_partida_de_nodo(contexto_sesion: Dictionary) -> bool:
	return bool(contexto_sesion.get("pertenece_a_partida_de_nodo", false))


func _leer_titulo_para_indicador(contexto: Dictionary) -> String:
	return str(contexto.get("titulo", contexto.get("titulo_nodo", ""))).strip_edges()


func _leer_indice_para_indicador(contexto: Dictionary) -> int:
	return int(contexto.get("actual", contexto.get("indice_juego_actual", 1)))


func _leer_total_para_indicador(contexto: Dictionary) -> int:
	return int(contexto.get("total", contexto.get("total_juegos", 1)))


func _aplicar_runtime_en_escena() -> void:
	titulo_nivel.text = "Celiaquía"
	label_pregunta.text = str(
		_datos_de_ejecucion.get("instruccion", "Relacioná correctamente")
	).strip_edges()

	var conceptos_izquierda: Array = _datos_de_ejecucion.get("conceptos_izquierda", [])
	var conceptos_derecha: Array = _datos_de_ejecucion.get("conceptos_derecha", [])
	total_pares = mini(conceptos_izquierda.size(), conceptos_derecha.size())
	if total_pares <= 0:
		_mostrar_error_bloqueante("La vinculación no tiene pares suficientes.")
		return
	if total_pares > _items_izquierda.size() or total_pares > _items_derecha.size():
		_mostrar_error_bloqueante("La escena de vinculación no tiene suficientes espacios visuales.")
		return

	_configurar_lado(_items_izquierda, conceptos_izquierda, "izquierda")
	var conceptos_derecha_barajados: Array = conceptos_derecha.duplicate(true)
	conceptos_derecha_barajados.shuffle()
	_configurar_lado(_items_derecha, conceptos_derecha_barajados, "derecha")


func _configurar_lado(
	items_escena: Array[ConceptoItem],
	conceptos: Array,
	lado: String
) -> void:
	for indice in range(items_escena.size()):
		var item: ConceptoItem = items_escena[indice]
		if indice >= conceptos.size():
			item.hide()
			item.disabled = true
			item.bloqueado = true
			continue

		var concepto: Dictionary = conceptos[indice] as Dictionary
		item.show()
		item.disabled = false
		item.bloqueado = false
		item.modulate = Color.WHITE
		item.lado = lado
		item.par_id = _firmar_id_par(str(concepto.get("id_par", "")).strip_edges())
		item.ajustar_titulo(str(concepto.get("texto", "")).strip_edges())


func _firmar_id_par(id_par: String) -> int:
	var firma := 0
	for indice in range(id_par.length()):
		firma = int((firma * 31 + id_par.unicode_at(indice) + indice + 1) % 2147483647)
	return firma


func _on_item_seleccionado(item: ConceptoItem) -> void:
	if bloqueado or item == null or item.bloqueado:
		return

	if item.lado == "izquierda":
		_reemplazar_seleccion_actual(&"izquierda", item)
	elif item.lado == "derecha":
		_reemplazar_seleccion_actual(&"derecha", item)
	else:
		return

	_validar_si_corresponde()


func _reemplazar_seleccion_actual(lado: StringName, item: ConceptoItem) -> void:
	if lado == &"izquierda":
		_resetear_color_si_corresponde(seleccion_izquierda)
		seleccion_izquierda = item
	else:
		_resetear_color_si_corresponde(seleccion_derecha)
		seleccion_derecha = item
	item.modulate = Color.YELLOW


func _validar_si_corresponde() -> void:
	if seleccion_izquierda == null or seleccion_derecha == null:
		return

	bloqueado = true
	if seleccion_izquierda.par_id == seleccion_derecha.par_id:
		_conexion_correcta()
		return
	_conexion_incorrecta()


func _conexion_correcta() -> void:
	seleccion_izquierda.disabled = true
	seleccion_derecha.disabled = true
	seleccion_izquierda.bloqueado = true
	seleccion_derecha.bloqueado = true
	seleccion_izquierda.modulate = Color(0.6, 1.0, 0.6)
	seleccion_derecha.modulate = Color(0.6, 1.0, 0.6)
	pares_completados += 1
	_limpiar_seleccion()
	bloqueado = false

	if pares_completados >= total_pares:
		_finalizar_vinculacion()


func _conexion_incorrecta() -> void:
	seleccion_izquierda.modulate = Color(1.0, 0.5, 0.5)
	seleccion_derecha.modulate = Color(1.0, 0.5, 0.5)
	await get_tree().create_timer(0.5).timeout
	_resetear_color_si_corresponde(seleccion_izquierda)
	_resetear_color_si_corresponde(seleccion_derecha)
	_limpiar_seleccion()
	bloqueado = false


func _limpiar_seleccion() -> void:
	seleccion_izquierda = null
	seleccion_derecha = null


func _resetear_color_si_corresponde(item: ConceptoItem) -> void:
	if item == null or item.bloqueado:
		return
	item.modulate = Color.WHITE


func _finalizar_vinculacion() -> void:
	bloqueado = true
	var racha_anterior: Dictionary = Global.obtener_estado_racha()
	_guardar_progreso_de_vinculacion()
	var racha_actualizada: Dictionary = Global.obtener_estado_racha()
	_preparar_flujo_post_juego(racha_anterior, racha_actualizada)
	_mostrar_cierre_de_vinculacion()


func _guardar_progreso_de_vinculacion() -> void:
	if _tiene_sesion_de_mapa:
		Global.marcar_nodo_jugable_completado(clave_pista, _nodo_actual)
		Global.registrar_actividad_racha(
			"map_node_completed",
			{
				"track_key": clave_pista,
				"level_number": nivel_id,
				"node_key": _nodo_actual,
				"mode": NodeContentLoaderScript.MODE_VINCULACION_CONCEPTOS,
			}
		)
		return

	Global.marcar_nivel_completado(clave_pista, nivel_id)
	Global.registrar_actividad_racha(
		"level_completed",
		{"track_key": clave_pista, "level_number": nivel_id}
	)
	SaveManager.registrar_nivel_completado(clave_pista, nivel_id)


func _preparar_flujo_post_juego(
	racha_anterior: Dictionary,
	racha_actualizada: Dictionary
) -> void:
	_retroalimentacion_racha_post_juego = GameStreakTrackerScript.build_feedback(
		racha_anterior,
		racha_actualizada,
		true
	)
	_estado_flujo_post_juego = PostGameFlowControllerScript.build_post_game_flow_state(
		racha_anterior,
		racha_actualizada,
		_construir_contexto_de_finalizacion(),
		_retroalimentacion_racha_post_juego
	)


func _mostrar_cierre_de_vinculacion() -> void:
	label_pregunta.text = _resolver_texto_de_cierre()
	_mostrar_continuacion()


func _mostrar_continuacion() -> void:
	ya_continuo = false
	if _continuar_juego == null:
		return
	if _hay_siguiente_juego_de_partida():
		_continuar_juego.call("mostrar_para_siguiente_juego", 5)
		return
	_continuar_juego.call("mostrar_para_finalizar", 5)


func _hay_siguiente_juego_de_partida() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())


func _resolver_texto_de_cierre() -> String:
	var texto_retroalimentacion: String = str(
		_datos_de_ejecucion.get("retroalimentacion_ok", "")
	).strip_edges()
	var texto_ensenanza: String = str(_datos_de_ejecucion.get("ensenanza", "")).strip_edges()
	var partes: Array[String] = []
	if not texto_retroalimentacion.is_empty():
		partes.append(texto_retroalimentacion)
	if not texto_ensenanza.is_empty():
		partes.append(texto_ensenanza)
	if partes.is_empty():
		partes.append("¡Muy bien! Ya podés seguir con el próximo juego.")
	return "\n".join(partes)


func continuar_al_siguiente_juego() -> void:
	_al_solicitar_continuar()


func _al_solicitar_continuar() -> void:
	if ya_continuo:
		return
	ya_continuo = true
	_limpiar_elementos_temporales()
	_continuar_despues_de_ensenanza(true)


func _continuar_partida_de_nodo_si_corresponde() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(
		get_tree(),
		Callable(self, "_limpiar_elementos_temporales"),
		Callable(self, "_limpiar_estado_de_partida_local")
	)


func _continuar_despues_de_ensenanza(temporizador_finalizado: bool) -> void:
	if _continuar_partida_de_nodo_si_corresponde():
		return

	if _estado_flujo_post_juego.is_empty():
		_volver_a_escena_de_mapa()
		return

	PostGameFlowControllerScript.navigate_after_teaching(
		get_tree(),
		_tomar_estado_flujo_post_juego(),
		_tomar_retroalimentacion_racha_post_juego(),
		temporizador_finalizado
	)


func _limpiar_elementos_temporales() -> void:
	if _continuar_juego != null and _continuar_juego.has_method("ocultar"):
		_continuar_juego.call("ocultar")


func _limpiar_estado_de_partida_local() -> void:
	_limpiar_elementos_temporales()
	_pertenece_a_partida_de_nodo = false


func _tomar_estado_flujo_post_juego() -> Dictionary:
	var estado_flujo: Dictionary = _estado_flujo_post_juego.duplicate(true)
	_estado_flujo_post_juego = {}
	return estado_flujo


func _tomar_retroalimentacion_racha_post_juego() -> Dictionary:
	var retroalimentacion: Dictionary = _retroalimentacion_racha_post_juego.duplicate(true)
	_retroalimentacion_racha_post_juego = {}
	return retroalimentacion


func _construir_contexto_de_finalizacion() -> Dictionary:
	return {
		"source": "vinculacion",
		"level": {
			"track_key": clave_pista,
			"number": nivel_id,
			"track_level_count": Global.obtener_pista_nivel_cantidad(clave_pista),
			"is_default_track": clave_pista == CLAVE_PISTA_PREDETERMINADA,
		},
		"map": {
			"came_from_map": _tiene_sesion_de_mapa,
			"node_key": _nodo_actual if _tiene_sesion_de_mapa else null,
		},
		"navigation": {
			"return_to": _ruta_escena_de_retorno,
		},
		"debug": {
			"created_by": "vincular_conceptos._construir_contexto_de_finalizacion",
		},
	}


func _mostrar_error_bloqueante(mensaje: String) -> void:
	bloqueado = true
	_limpiar_elementos_temporales()
	label_pregunta.text = mensaje
	for item in _items_izquierda:
		item.disabled = true
		item.bloqueado = true
	for item in _items_derecha:
		item.disabled = true
		item.bloqueado = true


func _on_atras_presionado() -> void:
	if _pertenece_a_partida_de_nodo:
		Global.finalizar_partida_de_nodo()
		Global.limpiar_sesion_nodo_jugable_activo()
	_volver_a_escena_de_mapa()


func _volver_a_escena_de_mapa() -> void:
	_limpiar_elementos_temporales()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_de_retorno
	)
