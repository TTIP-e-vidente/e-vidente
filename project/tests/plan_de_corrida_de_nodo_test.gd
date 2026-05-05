extends SceneTree

const PlanDeCorridaDeNodoScript := preload("res://mapas/core/PlanDeCorridaDeNodo.gd")
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")

const TIEMPO_MAXIMO_DE_PRUEBA := 8.0

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
	finalizar_con_error("La prueba de plan de corrida superó el tiempo máximo.")


func ejecutar_prueba() -> void:
	_probar_regla_de_cantidad_de_juegos()
	_probar_construccion_de_plan()

	if fallo:
		finalizar_con_error()
		return
	finalizar_ok()


func _probar_regla_de_cantidad_de_juegos() -> void:
	var cantidades_esperadas: Array[int] = [1, 1, 2, 3, 4, 5, 5]
	for indice_nodo in range(cantidades_esperadas.size()):
		var cantidad_esperada: int = cantidades_esperadas[indice_nodo]
		var cantidad_obtenida: int = PlanDeCorridaDeNodoScript.obtener_cantidad_de_juegos_para_nodo(
			indice_nodo
		)
		_verificar(
			cantidad_obtenida == cantidad_esperada,
			"La regla 1,1,2,3,4,5 debería cumplirse para el índice %d." % indice_nodo
		)


func _probar_construccion_de_plan() -> void:
	var nodo = MapNodeDataScript.new()
	nodo.node_key = "receta_1_desayuno"
	nodo.title = "Prepara el desayuno"
	nodo.mode = "drag_drop"
	nodo.json_path = "res://contenido/nodos/celiaquia/arrastre/receta_1_desayuno.json"
	nodo.track_key = "celiaquia"
	nodo.index = 4
	nodo.difficulty = 2

	var plan_de_corrida: Dictionary = PlanDeCorridaDeNodoScript.construir_plan_de_corrida(nodo)
	_verificar(not plan_de_corrida.is_empty(), "El plan de corrida no debería quedar vacío.")
	if fallo:
		return

	var juegos: Array = plan_de_corrida.get("juegos", []) as Array
	_verificar(int(plan_de_corrida.get("total_juegos", 0)) == 4, "El nodo índice 4 debería generar 4 juegos.")
	_verificar(juegos.size() == 4, "El plan debería incluir 4 juegos construidos.")
	if fallo:
		return

	var primer_juego: Dictionary = juegos[0] as Dictionary
	var segundo_juego: Dictionary = juegos[1] as Dictionary
	_verificar(
		str(primer_juego.get("json_path", "")) == nodo.json_path,
		"El primer juego debería conservar el JSON del nodo seleccionado."
	)
	_verificar(
		str(primer_juego.get("mode", "")) == "drag_drop",
		"El primer juego debería respetar el modo original del nodo."
	)
	_verificar(
		str(segundo_juego.get("mode", "")) == "quiz_choice",
		"El segundo juego debería alternar al modo opuesto."
	)
	var dificultades_obtenidas: Array[int] = []

	for juego_crudo in juegos:
		var juego: Dictionary = juego_crudo as Dictionary
		dificultades_obtenidas.append(int(juego.get("dificultad", 0)))
		_verificar(
			int(juego.get("dificultad", 0)) >= 1,
			"Cada juego del plan debería exponer una dificultad simple."
		)

	_verificar(
		dificultades_obtenidas == [1, 2, 3, 4],
		"La corrida debería asignar dificultad progresiva por juego."
	)


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("PLAN DE CORRIDA TEST FAILED: %s" % mensaje)


func finalizar_ok() -> void:
	_cerrar_prueba(0)


func finalizar_con_error(mensaje: String = "") -> void:
	if not mensaje.is_empty() and not fallo:
		printerr("PLAN DE CORRIDA TEST FAILED: %s" % mensaje)
	fallo = true
	_cerrar_prueba(1)


func _cerrar_prueba(codigo_salida: int) -> void:
	if prueba_finalizada:
		return
	prueba_finalizada = true
	quit(codigo_salida)
