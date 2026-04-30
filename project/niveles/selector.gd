extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const RACHA_SCENE := preload("res://interface/components/Racha.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const PROFILE_OVERLAY_SCENE := preload("res://interface/components/ProfileOverlayPanel.tscn")

const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const MUSICA_FONDO_PREDETERMINADA := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

const DESTINO_MAPA := "mapa"
const DESTINO_PISTA := "pista"

const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_DURATION := 0.15
const BUTTON_BOUNCE_OFFSET := Vector2(0, 4)
const BUTTON_BOUNCE_DOWN_DURATION := 0.05
const BUTTON_BOUNCE_UP_DURATION := 0.08
const BUTTON_NAVIGATION_DELAY := 0.15

const TRACK_VEGANISMO := "veganismo"
const TRACK_VEGANISMO_CELIAQUIA := "veganismo_celiaquia"
const TRACK_CETOGENICA := "cetogenica"

@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

@onready var celiaquia: TextureButton = $MenuBar/Celiaquia
@onready var veganismo: TextureButton = $MenuBar/Veganismo
@onready var vegan_gf: TextureButton = $"MenuBar/Vegan-GF"
@onready var cetogenica: TextureButton = $MenuBar/Cetogenica
@onready var diabetes: TextureButton = $MenuBar/Diabetes
@onready var autismo: TextureButton = $MenuBar/Autismo
@onready var btn_atras: Button = $"Atrás"

@onready var mode_buttons: Array[TextureButton] = [
	celiaquia,
	veganismo,
	vegan_gf,
	cetogenica,
	diabetes,
	autismo
]

var _profile_overlay: ProfileOverlayPanel
var _profile_toggle_btn: Button
var _racha_badge: Control
var _button_base_scales: Dictionary = {}
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()
	_establecer_reanudar_superposicion_visible(false)
	_configurar_botones()
	_construir_hud()


func _configurar_botones() -> void:
	_establecer_boton_habilitado(diabetes, false)
	_establecer_boton_habilitado(autismo, false)

	for button in mode_buttons:
		_registrar_animacion_boton(button)
	_registrar_animacion_boton(btn_atras)


func _registrar_animacion_boton(button: Control) -> void:
	if button.material:
		button.material = button.material.duplicate()
	_button_base_scales[button] = button.scale
	button.mouse_entered.connect(_on_boton_sobrevuelo.bind(button, true))
	button.mouse_exited.connect(_on_boton_sobrevuelo.bind(button, false))


func _establecer_reanudar_superposicion_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible


func _establecer_boton_habilitado(button: BaseButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(5, 5, 5, 1)


# --- Navegación principal -----------------------------------------------------
func _on_celiaquia_presionado() -> void:
	await _abrir_destino_boton(celiaquia, DESTINO_MAPA)


func _on_veganismo_presionado() -> void:
	await _abrir_destino_boton(veganismo, DESTINO_PISTA, TRACK_VEGANISMO)


func _on_vegan_gf_presionado() -> void:
	await _abrir_destino_boton(vegan_gf, DESTINO_PISTA, TRACK_VEGANISMO_CELIAQUIA)


func _on_cetogenica_presionado() -> void:
	await _abrir_destino_boton(cetogenica, DESTINO_PISTA, TRACK_CETOGENICA)


func _on_diabetes_presionado() -> void:
	await _abrir_destino_boton(diabetes, DESTINO_PISTA)


func _on_autismo_presionado() -> void:
	await _abrir_destino_boton(autismo, DESTINO_PISTA)


func _abrir_destino_boton(
	button: Control,
	destination_type: String,
	track_key: String = ""
) -> void:
	_rebote_boton(button)
	await get_tree().create_timer(BUTTON_NAVIGATION_DELAY).timeout

	match destination_type:
		DESTINO_MAPA:
			GameSceneRouter.go_to_map(get_tree())
		DESTINO_PISTA:
			if track_key.is_empty():
				return
			GameSceneRouter.go_to_track_book(get_tree(), track_key)


func _on_continuar_presionado() -> void:
	_reanudar_actual_guardar()


func _on_reproducir_fondo_gui_entrada(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_establecer_reanudar_superposicion_visible(false)


func _on_reproducir_cerrar_presionado() -> void:
	_establecer_reanudar_superposicion_visible(false)


func _on_modo_presionado() -> void:
	_establecer_reanudar_superposicion_visible(false)


func _on_atras_presionado() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _reanudar_actual_guardar() -> void:
	if not SaveManager.puede_reanudar_guardado_actual():
		_establecer_reanudar_superposicion_visible(false)
		return
	var resume_state: Dictionary = SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


# --- Sonido y animaciones -----------------------------------------------------
func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO_PREDETERMINADA)


func _on_boton_sobrevuelo(button: Control, entered: bool) -> void:
	if button is BaseButton and button.disabled:
		return

	var base_scale: Vector2 = _button_base_scales.get(button, button.scale)
	var target_scale: Vector2 = base_scale * HOVER_SCALE if entered else base_scale

	if _hover_tweens.has(button) and is_instance_valid(_hover_tweens[button]):
		_hover_tweens[button].kill()

	var tween := create_tween()
	var tweener := tween.tween_property(button, "scale", target_scale, HOVER_DURATION)
	tweener.set_trans(Tween.TRANS_BACK)
	tweener.set_ease(Tween.EASE_OUT)
	_hover_tweens[button] = tween


func _rebote_boton(button: Control) -> void:
	var original_position: Vector2 = button.position
	var tween := create_tween()
	var down_tweener := tween.tween_property(
		button,
		"position",
		original_position + BUTTON_BOUNCE_OFFSET,
		BUTTON_BOUNCE_DOWN_DURATION
	)
	down_tweener.set_trans(Tween.TRANS_SINE)
	down_tweener.set_ease(Tween.EASE_OUT)
	var up_tweener := tween.tween_property(
		button,
		"position",
		original_position,
		BUTTON_BOUNCE_UP_DURATION
	)
	up_tweener.set_trans(Tween.TRANS_BOUNCE)
	up_tweener.set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	for button in mode_buttons:
		_actualizar_shader_boton(button, mouse_position)


func _actualizar_shader_boton(button: TextureButton, mouse_position: Vector2) -> void:
	var material: ShaderMaterial = button.material as ShaderMaterial
	if material == null:
		return

	var button_rect: Rect2 = button.get_global_rect()
	var mouse_uv: Vector2 = (mouse_position - button_rect.position) / button_rect.size
	mouse_uv.x = clamp(mouse_uv.x, 0.0, 1.0)
	mouse_uv.y = clamp(mouse_uv.y, 0.0, 1.0)

	var button_center: Vector2 = button_rect.position + button_rect.size / 2.0
	var mouse_distance: float = mouse_position.distance_to(button_center)
	if mouse_distance < 200.0:
		material.set_shader_parameter("mouse_pos", mouse_uv)
		return

	material.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))


# --- HUD ----------------------------------------------------------------------
func _construir_hud() -> void:
	var hud_layer: CanvasLayer = _crear_hud_layer()
	var hud_root: Control = _crear_hud_root(hud_layer)
	_agregar_insignia_racha(hud_root)
	_agregar_boton_perfil(hud_root)
	_agregar_superposicion_perfil(hud_root)


func _crear_hud_layer() -> CanvasLayer:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)
	return hud_layer


func _crear_hud_root(hud_layer: CanvasLayer) -> Control:
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)
	return hud_root


func _agregar_insignia_racha(hud_root: Control) -> void:
	var racha_badge: Control = RACHA_SCENE.instantiate() as Control
	if racha_badge == null:
		return

	_racha_badge = racha_badge
	racha_badge.anchor_left = 0.0
	racha_badge.anchor_top = 0.0
	racha_badge.anchor_right = 0.0
	racha_badge.anchor_bottom = 0.0
	racha_badge.offset_left = 16.0
	racha_badge.offset_top = 16.0
	racha_badge.offset_right = 152.0
	racha_badge.offset_bottom = 152.0
	hud_root.add_child(racha_badge)
	_conectar_insignia_racha()


func _agregar_boton_perfil(hud_root: Control) -> void:
	_profile_toggle_btn = Button.new()
	_profile_toggle_btn.script = PROFILE_BUTTON_SCRIPT
	_profile_toggle_btn.anchor_left = 1.0
	_profile_toggle_btn.anchor_top = 0.0
	_profile_toggle_btn.anchor_right = 1.0
	_profile_toggle_btn.anchor_bottom = 0.0
	_profile_toggle_btn.offset_left = -152.0
	_profile_toggle_btn.offset_top = 16.0
	_profile_toggle_btn.offset_right = -16.0
	_profile_toggle_btn.offset_bottom = 84.0
	_profile_toggle_btn.tooltip_text = "Mi progreso"
	_profile_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_toggle_btn.pressed.connect(_on_perfil_alternar_presionado)
	hud_root.add_child(_profile_toggle_btn)


func _agregar_superposicion_perfil(hud_root: Control) -> void:
	_profile_overlay = PROFILE_OVERLAY_SCENE.instantiate() as ProfileOverlayPanel
	if _profile_overlay == null:
		return
	hud_root.add_child(_profile_overlay)
	_profile_overlay.resume_pressed.connect(_on_superposicion_reanudar_presionado)
	_profile_overlay.save_pressed.connect(_on_superposicion_guardar_presionado)
	_profile_overlay.edit_profile_pressed.connect(_on_superposicion_edit_perfil_presionado)
	_profile_overlay.reset_progress_pressed.connect(_on_superposicion_reiniciar_presionado)
	_profile_overlay.close_requested.connect(_on_superposicion_cerrar_solicitado)


func _on_perfil_alternar_presionado() -> void:
	_profile_toggle_btn.visible = false
	_profile_overlay.mostrar_superposicion()


func _conectar_insignia_racha() -> void:
	if _racha_badge == null or not _racha_badge.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionado")
	if not _racha_badge.is_connected("pressed", callback):
		_racha_badge.connect("pressed", callback)


func _on_racha_presionado() -> void:
	if _profile_overlay != null:
		_profile_overlay.ocultar_superposicion()
	if _profile_toggle_btn != null:
		_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_streak(get_tree(), RESUME_FALLBACK_SCENE)


func _on_superposicion_cerrar_solicitado() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.ocultar_superposicion()


func _on_superposicion_reanudar_presionado() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.ocultar_superposicion()
	_reanudar_actual_guardar()


func _on_superposicion_edit_perfil_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, RESUME_FALLBACK_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_superposicion_guardar_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	_profile_overlay.refrescar()


func _on_superposicion_reiniciar_presionado() -> void:
	SaveManager.reiniciar_todo_progreso()
	_profile_overlay.visible = false
	_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_archivero() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_modo_preguntas() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _salir_juego() -> void:
	get_tree().quit()
