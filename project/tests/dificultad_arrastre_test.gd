extends SceneTree

const DificultadArrastreScript := preload("res://niveles/nivel_1/DificultadArrastre.gd")

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
	finalizar_con_error("La prueba de dificultad de arrastre superó el tiempo máximo.")


func ejecutar_prueba() -> void:
	var elementos_dificultad_1: int = DificultadArrastreScript.limitar_elementos_por_dificultad(1)
	var elementos_dificultad_3: int = DificultadArrastreScript.limitar_elementos_por_dificultad(3)
	var elementos_dificultad_5: int = DificultadArrastreScript.limitar_elementos_por_dificultad(5)

	var distractores_dificultad_1: int = DificultadArrastreScript.obtener_cantidad_de_distractores_por_dificultad(1)
	var distractores_dificultad_3: int = DificultadArrastreScript.obtener_cantidad_de_distractores_por_dificultad(3)
	var distractores_dificultad_5: int = DificultadArrastreScript.obtener_cantidad_de_distractores_por_dificultad(5)

	_verificar(elementos_dificultad_1 < elementos_dificultad_3, "La dificultad 1 debería usar menos elementos que la 3.")
	_verificar(elementos_dificultad_3 < elementos_dificultad_5, "La dificultad 3 debería usar menos elementos que la 5.")
	_verificar(distractores_dificultad_1 == 0, "La dificultad 1 debería arrancar sin distractores.")
	_verificar(distractores_dificultad_3 == 1, "La dificultad 3 debería usar un distractor simple.")
	_verificar(distractores_dificultad_5 > distractores_dificultad_3, "La dificultad 5 debería usar más distractores que la 3.")
	_verificar(DificultadArrastreScript.deberia_mostrar_ayuda_visual(1), "La dificultad 1 debería mostrar ayuda visual.")
	_verificar(not DificultadArrastreScript.deberia_mostrar_ayuda_visual(5), "La dificultad 5 debería reducir la ayuda visual.")

	if fallo:
		finalizar_con_error()
		return
	finalizar_ok()


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("DIFICULTAD ARRASTRE TEST FAILED: %s" % mensaje)


func finalizar_ok() -> void:
	_cerrar_prueba(0)


func finalizar_con_error(mensaje: String = "") -> void:
	if not mensaje.is_empty() and not fallo:
		printerr("DIFICULTAD ARRASTRE TEST FAILED: %s" % mensaje)
	fallo = true
	_cerrar_prueba(1)


func _cerrar_prueba(codigo_salida: int) -> void:
	if prueba_finalizada:
		return
	prueba_finalizada = true
	quit(codigo_salida)
