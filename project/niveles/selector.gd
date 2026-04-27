extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const RACHA_SCENE := preload("res://interface/components/Racha.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_DURATION := 0.15
const MUSICA_FONDO_PREDETERMINADA := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

@onready var celiaquia: TextureButton = $MenuBar/Celiaquia
@onready var veganismo: TextureButton = $MenuBar/Veganismo
@onready var vegan_gf: TextureButton = $"MenuBar/Vegan-GF"
@onready var cetogenica: TextureButton = $MenuBar/Cetogenica
@onready var diabetes: TextureButton = $MenuBar/Diabetes
@onready var autismo: TextureButton = $MenuBar/Autismo
@onready var btn_atras: Button = $"Atrás"

@onready var buttons := [
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
	_construir_hud()

	_establecer_boton_habilitado(diabetes, false)
	_establecer_boton_habilitado(autismo, false)

	for b in buttons:
		if b.material:
			b.material = b.material.duplicate()
		_button_base_scales[b] = b.scale
		b.mouse_entered.connect(_on_boton_sobrevuelo.bind(b, true))
		b.mouse_exited.connect(_on_boton_sobrevuelo.bind(b, false))

	_button_base_scales[btn_atras] = btn_atras.scale
	btn_atras.mouse_entered.connect(_on_boton_sobrevuelo.bind(btn_atras, true))
	btn_atras.mouse_exited.connect(_on_boton_sobrevuelo.bind(btn_atras, false))


func _establecer_reanudar_superposicion_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible


func _on_celiaquia_presionado() -> void:
	_rebote_boton(celiaquia)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_map(get_tree())


func _on_veganismo_presionado() -> void:
	_rebote_boton(veganismo)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "veganismo")


func _on_vegan_gf_presionado() -> void:
	_rebote_boton(vegan_gf)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "veganismo_celiaquia")


func _on_cetogenica_presionado() -> void:
	_rebote_boton(cetogenica)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "cetogenica")


func _on_diabetes_presionado() -> void:
	_rebote_boton(diabetes)
	await get_tree().create_timer(0.15).timeout


func _on_autismo_presionado() -> void:
	_rebote_boton(autismo)
	await get_tree().create_timer(0.15).timeout


func _on_continuar_presionado() -> void:
	_reanudar_actual_guardar()


func _on_reproducir_fondo_gui_entrada(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_establecer_reanudar_superposicion_visible(false)


func _on_reproducir_cerrar_presionado() -> void:
	_establecer_reanudar_superposicion_visible(false)


func _on_modo_presionado() -> void:
	_establecer_reanudar_superposicion_visible(false)


func _establecer_boton_habilitado(button: BaseButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(5, 5, 5, 1)


func _on_atras_presionado() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO_PREDETERMINADA)


func _exit_tree() -> void:
	pass


func _on_boton_sobrevuelo(button: Control, entered: bool) -> void:
	if button is BaseButton and button.disabled:
		return
	var base_scale: Vector2 = _button_base_scales.get(button, button.scale)
	var target: Vector2 = base_scale * HOVER_SCALE if entered else base_scale
	if _hover_tweens.has(button) and is_instance_valid(_hover_tweens[button]):
		_hover_tweens[button].kill()
	var tw := create_tween()
	tw.tween_property(button, "scale", target, HOVER_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tweens[button] = tw


# --- HUD (racha + profile button) ---

func _construir_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)

	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	var racha := RACHA_SCENE.instantiate() as Control
	if racha != null:
		_racha_badge = racha
		racha.anchor_left = 0.0
		racha.anchor_top = 0.0
		racha.anchor_right = 0.0
		racha.anchor_bottom = 0.0
		racha.offset_left = 16.0
		racha.offset_top = 16.0
		racha.offset_right = 152.0
		racha.offset_bottom = 152.0
		hud_root.add_child(racha)
		_conectar_insignia_racha()

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

	_profile_overlay = preload("res://interface/components/ProfileOverlayPanel.tscn").instantiate()
	hud_root.add_child(_profile_overlay)
	_profile_overlay.resume_pressed.connect(_on_superposicion_reanudar_presionado)
	_profile_overlay.save_pressed.connect(_on_superposicion_guardar_presionado)
	_profile_overlay.edit_profile_pressed.connect(_on_superposicion_edit_perfil_presionado)
	_profile_overlay.reset_progress_pressed.connect(_on_superposicion_reiniciar_presionado)
	_profile_overlay.close_requested.connect(_on_superposicion_cerrar_solicitado)


func _on_perfil_alternar_presionado() -> void:
	_profile_toggle_btn.visible = false
	_profile_overlay.show_overlay()


func _conectar_insignia_racha() -> void:
	if _racha_badge == null or not _racha_badge.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionado")
	if not _racha_badge.is_connected("pressed", callback):
		_racha_badge.connect("pressed", callback)


func _on_racha_presionado() -> void:
	if _profile_overlay != null:
		_profile_overlay.hide_overlay()
	if _profile_toggle_btn != null:
		_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_streak(get_tree(), RESUME_FALLBACK_SCENE)


func _on_superposicion_cerrar_solicitado() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.hide_overlay()


func _on_superposicion_reanudar_presionado() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.hide_overlay()
	_reanudar_actual_guardar()


func _on_superposicion_edit_perfil_presionado() -> void:
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, RESUME_FALLBACK_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_superposicion_guardar_presionado() -> void:
	SaveManager.save_progress_to_disk()
	_profile_overlay.refresh()


func _on_superposicion_reiniciar_presionado() -> void:
	SaveManager.reset_all_progress()
	_profile_overlay.visible = false
	_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_archivero() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_modo_preguntas() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _salir_juego() -> void:
	get_tree().quit()


func _reanudar_actual_guardar() -> void:
	if not SaveManager.can_resume_current_save():
		_establecer_reanudar_superposicion_visible(false)
		return
	var resume_state := SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _rebote_boton(button: Control) -> void:
	var original_pos := button.position
	var tween := create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(0, 4), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position", original_pos, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()

	for b in buttons:
		var btn := b as TextureButton
		var mat := btn.material as ShaderMaterial
		if mat:
			var rect: Rect2 = btn.get_global_rect()
			var uv: Vector2 = (mouse - rect.position) / rect.size
			uv.x = clamp(uv.x, 0.0, 1.0)
			uv.y = clamp(uv.y, 0.0, 1.0)
			var center: Vector2 = rect.position + rect.size / 2.0
			var dist := mouse.distance_to(center)
			if dist < 200:
				mat.set_shader_parameter("mouse_pos", uv)
			else:
				mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))
