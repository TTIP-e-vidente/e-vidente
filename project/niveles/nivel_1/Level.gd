extends Node
class_name Level

const DEFAULT_TRACK_KEY := "celiaquia"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")
const SAVE_FEEDBACK_SUCCESS_TITLE_COLOR := Color(0.215686, 0.337255, 0.231373, 1)
const SAVE_FEEDBACK_SUCCESS_BODY_COLOR := Color(0.266667, 0.227451, 0.156863, 0.96)
const SAVE_FEEDBACK_ERROR_TITLE_COLOR := Color(0.568627, 0.184314, 0.141176, 1)
const SAVE_FEEDBACK_ERROR_BODY_COLOR := Color(0.403922, 0.160784, 0.121569, 0.96)

@export var track_key_override := ""
@onready var background: AudioStreamPlayer2D = $Background
@onready var victory: AnimatedSprite2D = $Victory
@onready var next_chapter_button: Button = $Adelante
@onready var teaching_sprite: Sprite2D = $Ensenanza
@onready var manager_level: ManagerLevel = $ManagerLevel
@onready var save_progress_button: Button = $SaveProgressButton
@onready var save_feedback_backdrop: PanelContainer = $SaveFeedbackBackdrop
@onready var save_feedback_title: Label = (
	$SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackTitle
)
@onready var save_feedback_label: Label = (
	$SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackLabel
)

var save_feedback_timer: Timer


func _ready() -> void:
	_start_level_flow()
	_configure_quick_save_feedback()


func _start_level_flow() -> void:
	_prepare_level_scene()
	_play_level_audio()
	_initialize_level_runtime()
	_register_current_resume_target()


func _prepare_level_scene() -> void:
	victory.hide()
	next_chapter_button.disabled = true


func _play_level_audio() -> void:
	background.play()


func _initialize_level_runtime() -> void:
	manager_level.initialize_level_runtime(self)


func _register_current_resume_target() -> void:
	SaveManager.set_resume_to_level(
		_resolve_level_track_key(),
		Global.current_level
	)


func _configure_quick_save_feedback() -> void:
	save_progress_button.icon = SAVE_ICON_IDLE
	save_progress_button.tooltip_text = "Guardar este avance en el dispositivo"
	save_feedback_backdrop.visible = false
	save_feedback_title.text = "Guardado local"
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	save_feedback_label.text = ""
	_ensure_save_feedback_timer()


func _ensure_save_feedback_timer() -> void:
	if save_feedback_timer != null:
		return
	save_feedback_timer = Timer.new()
	save_feedback_timer.name = "SaveFeedbackResetTimer"
	save_feedback_timer.one_shot = true
	save_feedback_timer.wait_time = 3.0
	save_feedback_timer.timeout.connect(_on_save_feedback_timeout)
	add_child(save_feedback_timer)


func _exit_tree() -> void:
	if save_feedback_timer != null:
		save_feedback_timer.stop()
	if background != null:
		background.stop()
		background.stream = null


func _on_atras_pressed() -> void:
	_return_to_track_book()


func _return_to_track_book() -> void:
	GameSceneRouter.go_to_track_book(get_tree(), _resolve_level_track_key())


func _victory() -> void:
	_complete_current_level()


func _complete_current_level() -> void:
	var track_key := _resolve_level_track_key()
	_show_level_completion_feedback()
	_persist_level_completion(track_key)


func _show_level_completion_feedback() -> void:
	victory.show()
	victory.play("victory")
	next_chapter_button.disabled = false
	teaching_sprite.show()


func _persist_level_completion(track_key: String) -> void:
	Global.mark_level_completed(track_key, Global.current_level)
	Global.clear_partial_level_state(track_key, Global.current_level)
	SaveManager.record_level_completed(track_key, Global.current_level)


func _on_adelante_pressed() -> void:
	_continue_to_next_chapter()


func _continue_to_next_chapter() -> void:
	_go_to_next_chapter_or_main_menu(_resolve_level_track_key())


func _go_to_next_chapter_or_main_menu(track_key: String) -> void:
	if Global.current_level >= Global.get_track_level_count(track_key):
		GameSceneRouter.go_to_main_menu(get_tree())
		return
	GameSceneRouter.go_to_track_level(get_tree(), track_key, Global.current_level + 1)


func _on_save_progress_button_pressed() -> void:
	_save_current_level_progress()


func _save_current_level_progress() -> void:
	var partial_save_result: Dictionary = manager_level.store_partial_level_state(
		_resolve_level_track_key()
	)
	SaveManager.record_manual_save()
	_render_manual_save_feedback(partial_save_result)


func _render_manual_save_feedback(partial_save_result: Dictionary) -> void:
	var save_status := SaveManager.get_save_status()
	var state := str(save_status.get("state", ""))
	if state == "error":
		_show_save_feedback(
			"No se pudo guardar",
			_format_save_error_message(save_status),
			false
		)
		return
	_show_save_feedback(
		_format_save_title(partial_save_result),
		_format_saved_message(save_status, partial_save_result),
		true
	)


func _resolve_level_track_key() -> String:
	if not track_key_override.strip_edges().is_empty():
		return track_key_override.strip_edges()
	return DEFAULT_TRACK_KEY


func _get_resume_track_key() -> String:
	return _resolve_level_track_key()


func _format_saved_message(
	save_status: Dictionary,
	partial_save_result: Dictionary
) -> String:
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	var lines: Array[String] = []
	var progress_count := int(
		partial_save_result.get(
			"progress_count",
			partial_save_result.get("placed_positive_count", 0)
		)
	)
	if saved_time.is_empty():
		lines.append("Guardado en este dispositivo")
	else:
		lines.append("Guardado a las %s" % saved_time)
	if progress_count <= 0:
		lines.append("Capitulo %d listo para retomar" % Global.current_level)
	else:
		var singular_label := str(
			partial_save_result.get("progress_unit_singular", "avance guardado")
		)
		var plural_label := str(
			partial_save_result.get("progress_unit_plural", singular_label)
		)
		var progress_label := singular_label if progress_count == 1 else plural_label
		lines.append("%d %s" % [progress_count, progress_label])
	return "\n".join(lines)


func _format_save_title(partial_save_result: Dictionary) -> String:
	if int(
		partial_save_result.get(
			"progress_count",
			partial_save_result.get("placed_positive_count", 0)
		)
	) > 0:
		return "Guardado parcial"
	return "Guardado local"


func _format_save_error_message(save_status: Dictionary) -> String:
	var last_error := str(save_status.get("last_error", "")).strip_edges()
	if not last_error.is_empty():
		return last_error
	return "Reintenta de nuevo en unos segundos"


func _show_save_feedback(title: String, message: String, success: bool) -> void:
	save_feedback_backdrop.visible = true
	save_feedback_title.text = title
	save_feedback_label.text = message
	save_feedback_title.modulate = (
		SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
		if success
		else SAVE_FEEDBACK_ERROR_TITLE_COLOR
	)
	save_feedback_label.modulate = (
		SAVE_FEEDBACK_SUCCESS_BODY_COLOR
		if success
		else SAVE_FEEDBACK_ERROR_BODY_COLOR
	)
	save_progress_button.icon = SAVE_ICON_OK if success else SAVE_ICON_IDLE
	if save_feedback_timer != null:
		save_feedback_timer.stop()
		save_feedback_timer.start()


func _on_save_feedback_timeout() -> void:
	if not is_inside_tree():
		return
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false
