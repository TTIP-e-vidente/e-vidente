# HELPER_INTERNO
# HUD del mapa: racha (arriba-izquierda), ProfileButton (arriba-derecha), bloque EXP.
extends CanvasLayer

signal back_requested

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const RUBIK_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")
const RUBIK_SPRAY_FONT := preload("res://fonts/RubikSprayPaint-Regular.ttf")
const EXP_POR_NIVEL := 30

@onready var racha: Control = $HudRoot/RachaAnchor/Racha
@onready var profile_button: Button = $HudRoot/TopRightAnchor/ProfileButton
@onready var profile_overlay: ProfileOverlayPanel = $ProfileOverlayPanel

var _nivel_label: Label = null
var _exp_bar: ProgressBar = null
var _exp_detalle_label: Label = null
var _exp_tween: Tween = null
@onready var _map_exp_numero: Label = $HudRoot/ExpMapaAnchor/VBox/ExpNumero
@onready var _map_exp_titulo: Label = $HudRoot/ExpMapaAnchor/VBox/ExpTitle


func _ready() -> void:
	_ocultar_superposicion_perfil()
	_conectar_insignia_racha()
	_conectar_senales_guardado()
	_agregar_nivel_exp_a_overlay()
	_aplicar_fuentes_bloque_exp_mapa()
	_actualizar_hud()


func _exit_tree() -> void:
	_desconectar_senales_guardado()


func _conectar_senales_guardado() -> void:
	if SaveManager == null:
		return
	if not SaveManager.save_status_changed.is_connected(_al_cambiar_estado_guardado):
		SaveManager.save_status_changed.connect(_al_cambiar_estado_guardado)
	if not SaveManager.progress_loaded.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_loaded.connect(_al_cambiar_perfil_guardado)
	if not SaveManager.progress_saved.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_saved.connect(_al_cambiar_perfil_guardado)
	if not SaveManager.user_registered.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.user_registered.connect(_al_cambiar_perfil_guardado)


func _desconectar_senales_guardado() -> void:
	if SaveManager == null:
		return
	if SaveManager.save_status_changed.is_connected(_al_cambiar_estado_guardado):
		SaveManager.save_status_changed.disconnect(_al_cambiar_estado_guardado)
	if SaveManager.progress_loaded.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_loaded.disconnect(_al_cambiar_perfil_guardado)
	if SaveManager.progress_saved.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_saved.disconnect(_al_cambiar_perfil_guardado)
	if SaveManager.user_registered.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.user_registered.disconnect(_al_cambiar_perfil_guardado)


func _actualizar_hud() -> void:
	if racha != null and racha.has_method("render"):
		racha.call("render")
	if profile_button != null and profile_button.has_method("refresh_profile_icon"):
		profile_button.call("refresh_profile_icon")
	if profile_overlay != null and profile_overlay.visible:
		profile_overlay.refrescar()
	_actualizar_panel_nivel_exp()
	_actualizar_bloque_exp_mapa()


func _conectar_insignia_racha() -> void:
	if racha == null or not racha.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionado")
	if not racha.is_connected("pressed", callback):
		racha.connect("pressed", callback)


func _on_profile_button_pressed() -> void:
	_mostrar_superposicion_perfil()


func _on_racha_presionado() -> void:
	var ruta_escena_actual: String = _obtener_ruta_escena_retorno()
	if ruta_escena_actual == GameSceneRouter.STREAK_SCENE_PATH:
		return
	_ocultar_superposicion_perfil()
	GameSceneRouter.go_to_streak(get_tree(), ruta_escena_actual)


func _on_back_button_pressed() -> void:
	back_requested.emit()


func _on_superposicion_cerrar_solicitado() -> void:
	_ocultar_superposicion_perfil()


func _on_superposicion_reanudar_presionado() -> void:
	_ocultar_superposicion_perfil()
	if not SaveManager.puede_reanudar_guardado_actual():
		return
	var estado_reanudacion: Dictionary = SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.go_to_resume(get_tree(), estado_reanudacion, _obtener_ruta_escena_retorno())


func _on_superposicion_edit_perfil_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, _obtener_ruta_escena_retorno())
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_save_pressed() -> void:
	SaveManager.guardar_progreso_en_disco()
	_actualizar_hud()


func _on_superposicion_reiniciar_presionado() -> void:
	SaveManager.reiniciar_todo_progreso()
	_ocultar_superposicion_perfil()
	GameSceneRouter.go_to_mode_selector(get_tree())


func _al_cambiar_estado_guardado(_status: Dictionary) -> void:
	_actualizar_hud()


func _al_cambiar_perfil_guardado(_profile: Dictionary) -> void:
	_actualizar_hud()


# ─── Nivel y EXP (dentro del drawer/overlay de perfil) ─────────────────────

func _calcular_nivel(total_exp: int) -> int:
	return int(total_exp / EXP_POR_NIVEL) + 1


func _calcular_exp_inicio_nivel(nivel: int) -> int:
	return (nivel - 1) * EXP_POR_NIVEL


func _calcular_ratio_exp(total_exp: int) -> float:
	var nivel := _calcular_nivel(total_exp)
	var inicio := _calcular_exp_inicio_nivel(nivel)
	return clampf(float(total_exp - inicio) / float(EXP_POR_NIVEL), 0.0, 1.0)


func _agregar_nivel_exp_a_overlay() -> void:
	if profile_overlay == null:
		return
	var vbox: VBoxContainer = profile_overlay.get_node_or_null(
		"SessionPanel/ScrollContainer/MarginContainer/VBoxContainer"
	)
	if vbox == null:
		return

	# Card con estilo consistente con ProfileOverlayPanel
	var card := PanelContainer.new()
	card.name = "NivelExpCard"
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.962, 0.957, 0.937, 1.0)
	card_style.corner_radius_top_left = 20
	card_style.corner_radius_top_right = 20
	card_style.corner_radius_bottom_left = 20
	card_style.corner_radius_bottom_right = 20
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.204, 0.247, 0.173, 0.08)
	card_style.content_margin_left = 20.0
	card_style.content_margin_right = 20.0
	card_style.content_margin_top = 16.0
	card_style.content_margin_bottom = 16.0
	card.add_theme_stylebox_override("panel", card_style)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 6)
	card.add_child(inner_vbox)

	var nivel_prefix := Label.new()
	nivel_prefix.text = "Nivel"
	nivel_prefix.add_theme_font_override("font", RUBIK_FONT)
	nivel_prefix.add_theme_font_size_override("font_size", 13)
	nivel_prefix.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.58))
	inner_vbox.add_child(nivel_prefix)

	_nivel_label = Label.new()
	_nivel_label.name = "NivelLabel"
	_nivel_label.text = "1"
	_nivel_label.add_theme_font_override("font", RUBIK_FONT)
	_nivel_label.add_theme_font_size_override("font_size", 34)
	_nivel_label.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1.0))
	inner_vbox.add_child(_nivel_label)

	_exp_bar = ProgressBar.new()
	_exp_bar.name = "ExpBar"
	_exp_bar.min_value = 0.0
	_exp_bar.max_value = 100.0
	_exp_bar.value = 0.0
	_exp_bar.show_percentage = false
	_exp_bar.custom_minimum_size = Vector2(0.0, 10.0)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.80, 0.80, 0.80, 1.0)
	bar_bg.corner_radius_top_left = 5
	bar_bg.corner_radius_top_right = 5
	bar_bg.corner_radius_bottom_left = 5
	bar_bg.corner_radius_bottom_right = 5
	_exp_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.31, 0.373, 0.267, 1.0)
	bar_fill.corner_radius_top_left = 5
	bar_fill.corner_radius_top_right = 5
	bar_fill.corner_radius_bottom_left = 5
	bar_fill.corner_radius_bottom_right = 5
	_exp_bar.add_theme_stylebox_override("fill", bar_fill)
	inner_vbox.add_child(_exp_bar)

	_exp_detalle_label = Label.new()
	_exp_detalle_label.name = "ExpDetalleLabel"
	_exp_detalle_label.text = "0 / %d EXP" % EXP_POR_NIVEL
	_exp_detalle_label.add_theme_font_override("font", RUBIK_FONT)
	_exp_detalle_label.add_theme_font_size_override("font_size", 12)
	_exp_detalle_label.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.58))
	inner_vbox.add_child(_exp_detalle_label)

	# Insertar antes de StatusRow para que aparezca después del resumen de perfil
	var status_row: Control = vbox.get_node_or_null("StatusRow")
	vbox.add_child(card)
	if status_row != null:
		vbox.move_child(card, status_row.get_index())


func _aplicar_fuentes_bloque_exp_mapa() -> void:
	# Fonts se aplican en runtime; el layout (posición/tamaño) lo maneja el TSCN.
	if is_instance_valid(_map_exp_titulo):
		_map_exp_titulo.add_theme_font_override("font", RUBIK_FONT)
		_map_exp_titulo.add_theme_font_size_override("font_size", 13)
		_map_exp_titulo.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40, 1.0))
		_map_exp_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if is_instance_valid(_map_exp_numero):
		_map_exp_numero.add_theme_font_override("font", RUBIK_SPRAY_FONT)
		_map_exp_numero.add_theme_font_size_override("font_size", 36)
		_map_exp_numero.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10, 1.0))
		_map_exp_numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _actualizar_bloque_exp_mapa() -> void:
	if not is_instance_valid(_map_exp_numero):
		return
	var total_exp: int = 0
	if SaveManager != null:
		total_exp = SaveManager.get_total_exp()
	_map_exp_numero.text = str(total_exp)


func _actualizar_panel_nivel_exp() -> void:
	if _nivel_label == null or _exp_bar == null:
		return
	var total_exp: int = 0
	if SaveManager != null:
		total_exp = SaveManager.get_total_exp()
	var nivel: int = _calcular_nivel(total_exp)
	var ratio: float = _calcular_ratio_exp(total_exp)
	var exp_en_nivel: int = total_exp - _calcular_exp_inicio_nivel(nivel)

	_nivel_label.text = str(nivel)
	if _exp_detalle_label != null:
		_exp_detalle_label.text = "%d / %d EXP" % [exp_en_nivel, EXP_POR_NIVEL]
	var target := ratio * 100.0
	if _exp_tween != null and _exp_tween.is_valid():
		_exp_tween.kill()
	_exp_tween = create_tween()
	_exp_tween.tween_property(_exp_bar, "value", target, 0.35)


func _mostrar_superposicion_perfil() -> void:
	_actualizar_panel_nivel_exp()
	profile_button.visible = false
	profile_overlay.mostrar_superposicion()


func _ocultar_superposicion_perfil() -> void:
	profile_button.visible = true
	profile_overlay.ocultar_superposicion()


func _obtener_ruta_escena_retorno() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return MAP_SCENE_PATH
	var ruta_escena: String = str(get_tree().current_scene.scene_file_path).strip_edges()
	return ruta_escena if not ruta_escena.is_empty() else MAP_SCENE_PATH
