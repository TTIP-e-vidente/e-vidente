extends Node
class_name Level

const DEFAULT_TRACK_KEY := "celiaquia"
const MANUAL_SAVE_TOOLTIP := "Guardar este avance en el dispositivo"
const SAVE_FEEDBACK_DEFAULT_TITLE := "Guardado local"
const SAVE_FEEDBACK_PARTIAL_TITLE := "Guardado parcial"
const SAVE_FEEDBACK_ERROR_TITLE := "No se pudo guardar"
const SAVE_FEEDBACK_DEFAULT_TIME_LINE := "Guardado en este dispositivo"
const SAVE_FEEDBACK_DEFAULT_ERROR_MESSAGE := "Reintenta de nuevo en unos segundos"
const SAVE_FEEDBACK_RESET_WAIT_TIME := 3.0

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
var active_track_key := ""


func _ready() -> void:
	_initialize_level_scene()
	_configure_quick_save_feedback()


func _initialize_level_scene() -> void:
	active_track_key = _resolve_configured_track_key()
	_prepare_initial_scene_state()
	_play_level_audio()
	_initialize_level_runtime()
	_register_level_resume_target()


func _prepare_initial_scene_state() -> void:
	victory.hide()
	next_chapter_button.disabled = true


func _play_level_audio() -> void:
	background.play()


func _initialize_level_runtime() -> void:
	manager_level.initialize_level_runtime(self)


func _register_level_resume_target() -> void:
	SaveManager.set_resume_to_level(
		_resolve_level_track_key(),
		_current_level_number()
	)


func _configure_quick_save_feedback() -> void:
	_configure_save_progress_button()
	_reset_save_feedback_panel()
	_ensure_save_feedback_timer()


func _configure_save_progress_button() -> void:
	save_progress_button.icon = SAVE_ICON_IDLE
	save_progress_button.tooltip_text = MANUAL_SAVE_TOOLTIP


func _reset_save_feedback_panel() -> void:
	save_feedback_backdrop.visible = false
	save_feedback_title.text = SAVE_FEEDBACK_DEFAULT_TITLE
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	save_feedback_label.text = ""


func _ensure_save_feedback_timer() -> void:
	if is_instance_valid(save_feedback_timer):
		return
	save_feedback_timer = Timer.new()
	save_feedback_timer.name = "SaveFeedbackResetTimer"
	save_feedback_timer.one_shot = true
	save_feedback_timer.wait_time = SAVE_FEEDBACK_RESET_WAIT_TIME
	save_feedback_timer.timeout.connect(_on_save_feedback_timeout)
	add_child(save_feedback_timer)


func _exit_tree() -> void:
	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
	if is_instance_valid(background):
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
	var level_number := _current_level_number()
	_show_level_completion_feedback()
	_persist_level_completion(track_key, level_number)


func _show_level_completion_feedback() -> void:
	victory.show()
	victory.play("victory")
	next_chapter_button.disabled = false
	teaching_sprite.show()


func _persist_level_completion(track_key: String, level_number: int) -> void:
	Global.mark_level_completed(track_key, level_number)
	Global.clear_partial_level_state(track_key, level_number)
	SaveManager.record_level_completed(track_key, level_number)


func _on_adelante_pressed() -> void:
	_continue_to_next_chapter()


func _continue_to_next_chapter() -> void:
	var track_key := _resolve_level_track_key()
	var level_number := _current_level_number()
	if _is_last_track_level(track_key, level_number):
		GameSceneRouter.go_to_main_menu(get_tree())
		return
	GameSceneRouter.go_to_track_level(get_tree(), track_key, level_number + 1)


func _is_last_track_level(track_key: String, level_number: int) -> bool:
	return level_number >= Global.get_track_level_count(track_key)


func _on_save_progress_button_pressed() -> void:
	_save_current_level_progress()


func _save_current_level_progress() -> void:
	var partial_save_result := _store_partial_level_state()
	SaveManager.record_manual_save()
	_render_manual_save_feedback(SaveManager.get_save_status(), partial_save_result)


func _store_partial_level_state() -> Dictionary:
	return manager_level.store_partial_level_state(_resolve_level_track_key())


func _render_manual_save_feedback(
	save_status: Dictionary,
	partial_save_result: Dictionary
) -> void:
	if _save_status_has_error(save_status):
		_show_save_feedback(
			SAVE_FEEDBACK_ERROR_TITLE,
			_format_save_error_message(save_status),
			false
		)
		return
	_show_save_feedback(
		_format_save_title(partial_save_result),
		_format_saved_message(save_status, partial_save_result),
		true
	)


func _save_status_has_error(save_status: Dictionary) -> bool:
	return str(save_status.get("state", "")) == "error"


func _resolve_configured_track_key() -> String:
	var configured_track_key := track_key_override.strip_edges()
	if configured_track_key.is_empty():
		return DEFAULT_TRACK_KEY
	return configured_track_key


func _resolve_level_track_key() -> String:
	if active_track_key.is_empty():
		active_track_key = _resolve_configured_track_key()
	return active_track_key


func _get_resume_track_key() -> String:
	return _resolve_level_track_key()


func _format_saved_message(
	save_status: Dictionary,
	partial_save_result: Dictionary
) -> String:
	var lines: Array[String] = [
		_build_saved_time_line(save_status),
		_build_saved_progress_line(partial_save_result)
	]
	return "\n".join(lines)


func _build_saved_time_line(save_status: Dictionary) -> String:
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	if saved_time.is_empty():
		return SAVE_FEEDBACK_DEFAULT_TIME_LINE
	return "Guardado a las %s" % saved_time


func _build_saved_progress_line(partial_save_result: Dictionary) -> String:
	var progress_count := _read_saved_progress_count(partial_save_result)
	if progress_count <= 0:
		return "Capitulo %d listo para retomar" % _current_level_number()
	return "%d %s" % [
		progress_count,
		_resolve_progress_label(partial_save_result, progress_count)
	]


func _read_saved_progress_count(partial_save_result: Dictionary) -> int:
	return int(
		partial_save_result.get(
			"progress_count",
			partial_save_result.get("placed_positive_count", 0)
		)
	)


func _resolve_progress_label(
	partial_save_result: Dictionary,
	progress_count: int
) -> String:
	var singular_label := str(
		partial_save_result.get("progress_unit_singular", "avance guardado")
	)
	var plural_label := str(
		partial_save_result.get("progress_unit_plural", singular_label)
	)
	return singular_label if progress_count == 1 else plural_label


func _format_save_title(partial_save_result: Dictionary) -> String:
	if _read_saved_progress_count(partial_save_result) > 0:
		return SAVE_FEEDBACK_PARTIAL_TITLE
	return SAVE_FEEDBACK_DEFAULT_TITLE


func _format_save_error_message(save_status: Dictionary) -> String:
	var last_error := str(save_status.get("last_error", "")).strip_edges()
	if not last_error.is_empty():
		return last_error
	return SAVE_FEEDBACK_DEFAULT_ERROR_MESSAGE


func _show_save_feedback(title: String, message: String, success: bool) -> void:
	save_feedback_backdrop.visible = true
	save_feedback_title.text = title
	save_feedback_label.text = message
	_apply_save_feedback_style(success)
	save_progress_button.icon = SAVE_ICON_OK if success else SAVE_ICON_IDLE
	_restart_save_feedback_timer()


func _apply_save_feedback_style(success: bool) -> void:
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


func _restart_save_feedback_timer() -> void:
	if not is_instance_valid(save_feedback_timer):
		return
	save_feedback_timer.stop()
	save_feedback_timer.start()


func _on_save_feedback_timeout() -> void:
	if not is_inside_tree():
		return
	_hide_save_feedback()


func _hide_save_feedback() -> void:
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false


func _current_level_number() -> int:
	return int(Global.current_level)
