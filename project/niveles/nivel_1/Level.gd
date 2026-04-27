extends Node
class_name Level

signal run_completed

## --- Configuración ---

const DEFAULT_TRACK_KEY            := "celiaquia"
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter             := preload("res://niveles/GameSceneRouter.gd")
const GameStreakTrackerScript      := preload(
	"res://niveles/progress/GameStreakTracker.gd"
)
const GameStreakDebugScript := preload(
	"res://niveles/progress/GameStreakDebug.gd"
)
const COMPLETION_BLACK_AND_WHITE_SHADER := preload(
	"res://niveles/level_completion_black_and_white.gdshader"
)
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK   := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")
const COMPLETION_DIM_COLOR := Color(0.72, 0.72, 0.72, 1.0)

## --- Guardado rápido ---

const SAVE_FEEDBACK_DEFAULT_TITLE       := "Guardado local"
const SAVE_FEEDBACK_SUCCESS_TITLE_COLOR := Color(0.215686, 0.337255, 0.231373, 1)
const SAVE_FEEDBACK_SUCCESS_BODY_COLOR  := Color(0.266667, 0.227451, 0.156863, 0.96)
const SAVE_FEEDBACK_ERROR_TITLE_COLOR   := Color(0.568627, 0.184314, 0.141176, 1)
const SAVE_FEEDBACK_ERROR_BODY_COLOR    := Color(0.403922, 0.160784, 0.121569, 0.96)

## --- Exports ---

@export var track_key_override    := ""
@export var background_music_path := DEFAULT_BACKGROUND_MUSIC_PATH
@export_group("Completion")
@export var grayscale_on_completion := true

## --- Nodos de escena ---

@onready var back_button:        Button              = $Atrás
@onready var next_chapter_button: Button             = $Adelante
@onready var adelante_1: Sprite2D					 = $Adelante/adelante1
@onready var adelante_2: Sprite2D 					 = $Adelante/adelante2
@onready var adelante_3: Sprite2D 					 = $Adelante/adelante3
@onready var teaching_sprite:    Sprite2D            = $Ensenanza
@onready var menu_area:          Area2D              = $Menú
@onready var lupa_area:          Area2D              = $Lupa
@onready var manager_level                           = $ManagerLevel

## Guardado rápido (UI)
@onready var save_progress_button:  Button         = $SaveProgressButton
@onready var save_feedback_backdrop: PanelContainer = $SaveFeedbackBackdrop
@onready var save_feedback_title: Label = (
	$SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackTitle
)
@onready var save_feedback_label: Label = (
	$SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackLabel
)

## --- Estado runtime ---
var save_feedback_timer:   Timer  = null
var active_track_key:      String = ""
var _pending_streak_feedback: Dictionary = {}
var _current_run_completion_handled := false
var _completion_visual_original_materials: Dictionary = {}
var _completion_visual_original_modulates: Dictionary = {}


func _ready() -> void:
	_start_level_flow()
	_configure_quick_save_feedback()



## --- Arranque ---

func _start_level_flow() -> void:
	var configured_key := track_key_override.strip_edges()
	active_track_key = configured_key if not configured_key.is_empty() else DEFAULT_TRACK_KEY
	_pending_streak_feedback = {}
	_current_run_completion_handled = false
	Item_level.is_dragging = null
	_restore_post_completion_state()
	next_chapter_button.disabled = true
	_play_level_audio()
	if manager_level == null:
		push_error("Level no pudo inicializar el runtime de ManagerLevel.")
	else:
		manager_level.start_level_session(active_track_key, self)
	var resolved_level_number := _valid_level_number(active_track_key)
	if resolved_level_number > 0:
		SaveManager.set_resume_to_level(active_track_key, resolved_level_number)


func _play_level_audio() -> void:
	if background_music_path.strip_edges().is_empty():
		return
	var ruta_musica: String = background_music_path.strip_edges()
	MusicManager.reproducir_musica(ruta_musica)


func _configure_quick_save_feedback() -> void:
	save_progress_button.tooltip_text = "Guardar este avance en el dispositivo"
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false
	save_feedback_title.text = SAVE_FEEDBACK_DEFAULT_TITLE
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	save_feedback_label.text = ""
	if is_instance_valid(save_feedback_timer):
		return
	save_feedback_timer = Timer.new()
	save_feedback_timer.name = "SaveFeedbackResetTimer"
	save_feedback_timer.one_shot = true
	save_feedback_timer.wait_time = 3.0
	save_feedback_timer.timeout.connect(_on_save_feedback_timeout)
	add_child(save_feedback_timer)


func _exit_tree() -> void:
	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()


## --- Navegación y gameplay ---

func _on_atras_pressed() -> void:
	if is_run_completed():
		return
	if active_track_key == DEFAULT_TRACK_KEY:
		GameSceneRouter.go_to_map(get_tree())
	else:
		GameSceneRouter.go_to_track_book(get_tree(), active_track_key)


func is_run_completed() -> bool:
	return _current_run_completion_handled


func complete_current_run() -> void:
	if _current_run_completion_handled:
		return

	var track_key := active_track_key
	var level_number := _valid_level_number(track_key)
	if level_number <= 0:
		return

	_current_run_completion_handled = true
	_lock_completed_run()

	# --- Flujo de racha (lineal, todo acá) ---
	# 1. Capturar racha previa para calcular el feedback post-partida
	var previous_streak: Dictionary = Global.get_streak_state()

	# 2. Registrar progreso y actividad de racha
	Global.mark_level_completed(track_key, level_number)
	Global.record_streak_activity(
		"level_completed",
		{"track_key": track_key, "level_number": level_number}
	)

	# 3. Persistir todo a disco
	SaveManager.record_level_completed(track_key, level_number)

	# 4. Preparar el feedback de racha para mostrarlo al avanzar
	var updated_streak: Dictionary = Global.get_streak_state()
	_pending_streak_feedback = GameStreakTrackerScript.build_feedback(
		previous_streak,
		updated_streak,
		true
	)

	_show_completed_run_feedback()
	run_completed.emit()

func _show_completed_run_feedback() -> void:
	var chapter_fijo := _current_level_number()
	while is_inside_tree() and is_run_completed() and _current_level_number() == chapter_fijo:
		adelante_2.show()
		await get_tree().create_timer(0.60).timeout
		adelante_2.hide()
		await get_tree().create_timer(0.60).timeout
		adelante_1.show()
		await get_tree().create_timer(0.60).timeout
		adelante_1.hide()
		await get_tree().create_timer(0.60).timeout
		adelante_3.show()
		await get_tree().create_timer(0.60).timeout
		adelante_3.hide()
		await get_tree().create_timer(0.60).timeout

func _on_adelante_pressed() -> void:
	if not is_run_completed():
		return
	if bool(_pending_streak_feedback.get("should_show", false)):
		var pending_feedback: Dictionary = _pending_streak_feedback.duplicate(true)
		var continue_target: Dictionary = _build_post_completion_continue_target(pending_feedback)
		_pending_streak_feedback = {}
		GameSceneRouter.go_to_streak(
			get_tree(),
			"",
			pending_feedback,
			continue_target
		)
		return
	_go_to_post_completion_destination()


## --- Guardado rápido ---

func _on_save_progress_button_pressed() -> void:
	if is_run_completed():
		return
	if manager_level == null or not is_instance_valid(manager_level):
		_show_save_feedback(
			"No se pudo guardar",
			"No se pudo acceder al runtime del nivel para guardar.",
			false
		)
		return

	var track_key := active_track_key
	var resolved_level_number := _valid_level_number(track_key)
	if resolved_level_number <= 0:
		_show_save_feedback(
			"No se pudo guardar",
			"No se pudo resolver el capitulo activo para guardar.",
			false
		)
		return

	var saved_positive_count: int = manager_level.store_partial_level_state(track_key)
	SaveManager.set_resume_to_level(track_key, resolved_level_number)
	SaveManager.record_manual_save()
	if SaveManager.has_save_error():
		var error := SaveManager.get_last_save_error()
		_show_save_feedback(
			"No se pudo guardar",
			error if not error.is_empty() else "Reintenta de nuevo en unos segundos",
			false
		)
		return
	_show_save_success_feedback(saved_positive_count)


func _show_save_success_feedback(saved_positive_count: int) -> void:
	var title := "Guardado parcial" if saved_positive_count > 0 else SAVE_FEEDBACK_DEFAULT_TITLE
	var saved_time := SaveManager.get_last_saved_at().get_slice(" ", 1)
	var time_line := (
		"Guardado a las %s" % saved_time
		if not saved_time.is_empty()
		else "Guardado en este dispositivo"
	)
	var detail_lines: Array[String] = [time_line]
	var run_line: String = manager_level.get_current_run_save_label()
	if not run_line.is_empty():
		detail_lines.append(run_line)
	detail_lines.append(manager_level.format_partial_save_progress(saved_positive_count))
	_show_save_feedback(title, "\n".join(detail_lines), true)


## --- Racha y feedback post-partida ---

func _show_save_feedback(title: String, message: String, success: bool) -> void:
	_show_feedback_card(
		title,
		message,
		SAVE_FEEDBACK_SUCCESS_TITLE_COLOR if success else SAVE_FEEDBACK_ERROR_TITLE_COLOR,
		SAVE_FEEDBACK_SUCCESS_BODY_COLOR if success else SAVE_FEEDBACK_ERROR_BODY_COLOR
	)
	save_progress_button.icon = SAVE_ICON_OK if success else SAVE_ICON_IDLE


func _build_post_completion_continue_target(streak_feedback: Dictionary = {}) -> Dictionary:
	var continue_target: Dictionary
	if active_track_key == DEFAULT_TRACK_KEY:
		continue_target = {"type": "map"}
		_append_mock_streak_preview(continue_target, streak_feedback)
		return continue_target

	var next_level: int = _current_level_number() + 1
	var level_count: int = Global.get_track_level_count(active_track_key)
	if next_level <= level_count:
		continue_target = {
			"type": "track_level",
			"track_key": active_track_key,
			"level_number": next_level
		}
		_append_mock_streak_preview(continue_target, streak_feedback)
		return continue_target

	continue_target = {
		"type": "track_book",
		"track_key": active_track_key
	}
	_append_mock_streak_preview(continue_target, streak_feedback)
	return continue_target


func _append_mock_streak_preview(
	continue_target: Dictionary,
	streak_feedback: Dictionary = {}
) -> void:
	if not GameStreakDebugScript.is_preview_enabled():
		return
	var current_count: int = int(streak_feedback.get("current_count", 0))
	if current_count <= 0 or current_count >= GameStreakDebugScript.PREVIEW_MAX_COUNT:
		return
	var preview_counts: Array[int] = []
	for preview_count in range(
		current_count + 1,
		GameStreakDebugScript.PREVIEW_MAX_COUNT + 1
	):
		preview_counts.append(preview_count)
	if preview_counts.is_empty():
		return
	continue_target[GameStreakDebugScript.PREVIEW_COUNTS_KEY] = preview_counts


func _go_to_post_completion_destination() -> void:
	var continue_target: Dictionary = _build_post_completion_continue_target()
	match str(continue_target.get("type", "")).strip_edges():
		"map":
			GameSceneRouter.go_to_map(get_tree())
		"track_level":
			GameSceneRouter.go_to_track_level(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges(),
				int(continue_target.get("level_number", -1))
			)
		"track_book":
			GameSceneRouter.go_to_track_book(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges()
			)
		_:
			GameSceneRouter.go_to_mode_selector(get_tree())


func _show_feedback_card(
	title: String,
	message: String,
	title_color: Color,
	body_color: Color
) -> void:
	save_feedback_title.text = title
	save_feedback_label.text = message
	save_feedback_title.modulate = title_color
	save_feedback_label.modulate = body_color

	save_feedback_backdrop.modulate = Color(1, 1, 1, 0.0)
	save_feedback_backdrop.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(save_feedback_backdrop, "modulate:a", 1.0, 0.22)

	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
		save_feedback_timer.start()


func _reset_save_feedback_visual_state() -> void:
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false


func _on_save_feedback_timeout() -> void:
	if not is_inside_tree():
		return
	_reset_save_feedback_visual_state()


func _lock_completed_run() -> void:
	Item_level.is_dragging = null
	_set_gameplay_interactions_enabled(false)
	next_chapter_button.disabled = false
	teaching_sprite.show()
	_apply_completion_visual_state()


func _restore_post_completion_state() -> void:
	restore_completion_visual_state()
	_set_gameplay_interactions_enabled(true)
	teaching_sprite.hide()


func _set_gameplay_interactions_enabled(enabled: bool) -> void:
	if is_instance_valid(back_button):
		back_button.disabled = not enabled
		back_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if is_instance_valid(save_progress_button):
		save_progress_button.disabled = not enabled
		save_progress_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if is_instance_valid(menu_area):
		menu_area.set_deferred("monitoring", enabled)
		menu_area.set_deferred("monitorable", enabled)
	if is_instance_valid(lupa_area):
		lupa_area.set_deferred("monitoring", enabled)
		lupa_area.set_deferred("monitorable", enabled)
	if (
		is_instance_valid(manager_level)
		and manager_level.has_method("set_runtime_items_interactable")
	):
		manager_level.set_runtime_items_interactable(enabled)


func _apply_completion_visual_state() -> void:
	if not grayscale_on_completion:
		return

	var grayscale_material := ShaderMaterial.new()
	grayscale_material.shader = COMPLETION_BLACK_AND_WHITE_SHADER
	for runtime_node in find_children("*", "", true, false):
		if not runtime_node is CanvasItem:
			continue
		if _should_skip_completion_visual(runtime_node):
			continue

		var canvas_item := runtime_node as CanvasItem
		var node_id := canvas_item.get_instance_id()
		if not _completion_visual_original_modulates.has(node_id):
			_completion_visual_original_modulates[node_id] = canvas_item.modulate
		var original_modulate: Color = canvas_item.modulate
		canvas_item.modulate = Color(
			COMPLETION_DIM_COLOR.r,
			COMPLETION_DIM_COLOR.g,
			COMPLETION_DIM_COLOR.b,
			original_modulate.a
		)

		if canvas_item is Sprite2D or canvas_item is AnimatedSprite2D:
			if not _completion_visual_original_materials.has(node_id):
				_completion_visual_original_materials[node_id] = canvas_item.material
			canvas_item.material = grayscale_material


func _should_skip_completion_visual(runtime_node: Node) -> bool:
	if runtime_node == self:
		return true
	if is_instance_valid(next_chapter_button) and (
		runtime_node == next_chapter_button or next_chapter_button.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(teaching_sprite) and runtime_node == teaching_sprite:
		return true
	if is_instance_valid(save_feedback_backdrop) and (
		runtime_node == save_feedback_backdrop
		or save_feedback_backdrop.is_ancestor_of(runtime_node)
	):
		return true
	return false


func restore_completion_visual_state() -> void:
	if (
		_completion_visual_original_materials.is_empty()
		and _completion_visual_original_modulates.is_empty()
	):
		return

	for runtime_node in find_children("*", "", true, false):
		if not runtime_node is CanvasItem:
			continue

		var canvas_item := runtime_node as CanvasItem
		var node_id := canvas_item.get_instance_id()
		if _completion_visual_original_modulates.has(node_id):
			canvas_item.modulate = _completion_visual_original_modulates[node_id]
		if _completion_visual_original_materials.has(node_id):
			canvas_item.material = _completion_visual_original_materials[node_id]

	_completion_visual_original_materials.clear()
	_completion_visual_original_modulates.clear()


func _valid_level_number(track_key: String) -> int:
	var level_count := Global.get_track_level_count(track_key)
	if level_count <= 0:
		return 0
	return clampi(Global.current_level, 1, level_count)

func _current_level_number() -> int:
	return int(Global.current_level)
	
	
