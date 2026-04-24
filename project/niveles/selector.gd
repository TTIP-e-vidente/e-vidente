extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const RACHA_SCENE := preload("res://interface/components/Racha.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_DURATION := 0.15

@onready var background_music: AudioStreamPlayer2D = $Background
@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

@onready var celiaquia: TextureButton = $MenuBar/Celiaquia
@onready var veganismo: TextureButton = $MenuBar/Veganismo
@onready var vegan_gf: TextureButton = $"MenuBar/Vegan-GF"
@onready var cetogenica: TextureButton = $MenuBar/Cetogenica
@onready var diabetes: TextureButton = $MenuBar/Diabetes
@onready var autismo: TextureButton = $MenuBar/Autismo

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
	_play_background_music()
	_set_resume_overlay_visible(false)
	_build_hud()

	_set_button_enabled(diabetes, false)
	_set_button_enabled(autismo, false)

	for b in buttons:
		if b.material:
			b.material = b.material.duplicate()
		_button_base_scales[b] = b.scale
		b.mouse_entered.connect(_on_button_hover.bind(b, true))
		b.mouse_exited.connect(_on_button_hover.bind(b, false))


func _set_resume_overlay_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible


func _on_celiaquia_pressed() -> void:
	_bounce_button(celiaquia)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_map(get_tree())


func _on_veganismo_pressed() -> void:
	_bounce_button(veganismo)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "veganismo")


func _on_vegan_gf_pressed() -> void:
	_bounce_button(vegan_gf)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "veganismo_celiaquia")


func _on_cetogenica_pressed() -> void:
	_bounce_button(cetogenica)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "cetogenica")


func _on_diabetes_pressed() -> void:
	_bounce_button(diabetes)
	await get_tree().create_timer(0.15).timeout
	# hacer que vaya al mapa de diabetes


func _on_autismo_pressed() -> void:
	_bounce_button(autismo)
	await get_tree().create_timer(0.15).timeout
	# hacer que vaya al mapa de autismo


func _on_continue_pressed() -> void:
	_resume_current_save()


func _on_play_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_resume_overlay_visible(false)


func _on_play_close_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_mode_pressed() -> void:
	_set_resume_overlay_visible(false)


func _set_button_enabled(button: BaseButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(5, 5, 5, 1)


func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _play_background_music() -> void:
	background_music.play()


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null


# --- Hover scale animation ---

func _on_button_hover(button: TextureButton, entered: bool) -> void:
	if button.disabled:
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

func _build_hud() -> void:
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
		_connect_streak_badge()

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
	_profile_toggle_btn.pressed.connect(_on_profile_toggle_pressed)
	hud_root.add_child(_profile_toggle_btn)

	_profile_overlay = preload("res://interface/components/ProfileOverlayPanel.tscn").instantiate()
	hud_root.add_child(_profile_overlay)
	_profile_overlay.resume_pressed.connect(_on_overlay_resume_pressed)
	_profile_overlay.save_pressed.connect(_on_overlay_guardar_pressed)
	_profile_overlay.edit_profile_pressed.connect(_on_overlay_edit_profile_pressed)
	_profile_overlay.reset_progress_pressed.connect(_on_overlay_reset_pressed)
	_profile_overlay.close_requested.connect(_on_overlay_close_requested)


# --- Profile overlay callbacks ---

func _on_profile_toggle_pressed() -> void:
	_profile_toggle_btn.visible = false
	_profile_overlay.show_overlay()


func _connect_streak_badge() -> void:
	if _racha_badge == null or not _racha_badge.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_pressed")
	if not _racha_badge.is_connected("pressed", callback):
		_racha_badge.connect("pressed", callback)


func _on_racha_pressed() -> void:
	if _profile_overlay != null:
		_profile_overlay.hide_overlay()
	if _profile_toggle_btn != null:
		_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_streak(get_tree(), RESUME_FALLBACK_SCENE)


func _on_overlay_close_requested() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.hide_overlay()


func _on_overlay_resume_pressed() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.hide_overlay()
	_resume_current_save()


func _on_overlay_edit_profile_pressed() -> void:
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, RESUME_FALLBACK_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_guardar_pressed() -> void:
	SaveManager.save_progress_to_disk()
	_profile_overlay.refresh()


func _on_overlay_reset_pressed() -> void:
	SaveManager.reset_all_progress()
	_profile_overlay.visible = false
	_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_mode_selector(get_tree())


func _open_archivero() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _open_questions_mode() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _quit_game() -> void:
	get_tree().quit()


func _resume_current_save() -> void:
	if not SaveManager.can_resume_current_save():
		_set_resume_overlay_visible(false)
		return
	var resume_state := SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _bounce_button(button: Control) -> void:
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
