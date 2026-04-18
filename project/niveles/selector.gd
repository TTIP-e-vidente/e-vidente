extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const colores := preload("res://colours/miPaleta.gd")
const STREAK_SEAL_SCENE := preload("res://interface/components/StreakDailySeal.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"

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

func _ready() -> void:
	_play_background_music()
	_set_resume_overlay_visible(false)
	_build_hud()
	
	_set_button_enabled(diabetes, false)
	_set_button_enabled(autismo, false)
	
	for b in buttons:
		if b.material:
			b.material = b.material.duplicate()

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


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)

	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	var streak_seal := STREAK_SEAL_SCENE.instantiate() as Control
	if streak_seal != null:
		streak_seal.anchor_left = 0.0
		streak_seal.anchor_top = 0.0
		streak_seal.anchor_right = 0.0
		streak_seal.anchor_bottom = 0.0
		streak_seal.offset_left = 16.0
		streak_seal.offset_top = 16.0
		streak_seal.offset_right = 152.0
		streak_seal.offset_bottom = 152.0
		hud_root.add_child(streak_seal)

	var profile_btn := Button.new()
	profile_btn.script = PROFILE_BUTTON_SCRIPT
	profile_btn.anchor_left = 1.0
	profile_btn.anchor_top = 0.0
	profile_btn.anchor_right = 1.0
	profile_btn.anchor_bottom = 0.0
	profile_btn.offset_left = -152.0
	profile_btn.offset_top = 16.0
	profile_btn.offset_right = -16.0
	profile_btn.offset_bottom = 84.0
	profile_btn.tooltip_text = "Mi progreso"
	profile_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	profile_btn.pressed.connect(_on_profile_pressed)
	hud_root.add_child(profile_btn)


func _on_profile_pressed() -> void:
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta("profile_return_scene", "res://niveles/selector.tscn")
	GameSceneRouter.go_to_profile_editor(get_tree())


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

func _bounce_button(button: Control):
	var tween = create_tween()
	
	var original_pos = button.position
	
	tween.tween_property(button, "position", original_pos + Vector2(0, 4), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(button, "position", original_pos, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
func _process(delta):
	var mouse = get_viewport().get_mouse_position()
	
	for b in buttons:
		var mat = b.material as ShaderMaterial
		if mat:
			var rect = b.get_global_rect()
			var uv = (mouse - rect.position) / rect.size
			
			uv.x = clamp(uv.x, 0.0, 1.0)
			uv.y = clamp(uv.y, 0.0, 1.0)
			
			var center = rect.position + rect.size / 2
			var dist = mouse.distance_to(center)
			
			if dist < 200:
				mat.set_shader_parameter("mouse_pos", uv)
			else:
				mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))	
