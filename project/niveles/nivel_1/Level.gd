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
const SAVE_ICON_IDLE_PATH := "res://assets-sistema/interfaz/logro-sin-realizar.png"
const SAVE_ICON_OK_PATH := "res://assets-sistema/interfaz/logro-realizado.png"
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const SAVE_FEEDBACK_SUCCESS_TITLE_COLOR := Color(0.215686, 0.337255, 0.231373, 1)
const SAVE_FEEDBACK_SUCCESS_BODY_COLOR := Color(0.266667, 0.227451, 0.156863, 0.96)
const SAVE_FEEDBACK_ERROR_TITLE_COLOR := Color(0.568627, 0.184314, 0.141176, 1)
const SAVE_FEEDBACK_ERROR_BODY_COLOR := Color(0.403922, 0.160784, 0.121569, 0.96)

@export var track_key_override := ""
@export var background_music_path := DEFAULT_BACKGROUND_MUSIC_PATH
@onready var background: AudioStreamPlayer2D = $Background
@onready var victory: AnimatedSprite2D = $Victory
@onready var next_chapter_button: Button = $Adelante
@onready var teaching_sprite: Sprite2D = $Ensenanza
@onready var manager_level = $ManagerLevel
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
var save_icon_idle: Texture2D = null
var save_icon_ok: Texture2D = null


func _ready() -> void:
	_start_level_flow()
	_configure_quick_save_feedback()


func _start_level_flow() -> void:
	active_track_key = _resolve_configured_track_key()
	_prepare_level_session()
	_play_level_audio()
	_start_gameplay_runtime()
	_register_level_resume_target()


func _initialize_level_scene() -> void:
	_start_level_flow()


func _prepare_level_session() -> void:
	victory.hide()
	next_chapter_button.disabled = true


func _start_gameplay_runtime() -> void:
	if manager_level == null:
		push_error("Level no pudo inicializar el runtime de ManagerLevel.")
		return
	manager_level.start_level_session(self)


func _register_level_resume_target() -> void:
	var track_key := _resolve_level_track_key()
	var level_count: int = Global.get_track_level_count(track_key)
	if level_count <= 0:
		return
	SaveManager.set_resume_to_level(
		track_key,
		clampi(_current_level_number(), 1, level_count)
	)


func _play_level_audio() -> void:
	if not is_instance_valid(background):
		return

	var music_path: String = background_music_path.strip_edges()
	if music_path.is_empty():
		background.stop()
		background.stream = null
		return

	if background.stream == null or background.stream.resource_path != music_path:
		var loaded_stream: Variant = load(music_path)
		if not loaded_stream is AudioStream:
			push_warning(
				"Level no pudo cargar la musica de fondo en %s." % music_path
			)
			background.stream = null
			return
		background.stream = loaded_stream

	background.play()


func _configure_quick_save_feedback() -> void:
	_ensure_quick_save_icons_loaded()
	save_progress_button.tooltip_text = MANUAL_SAVE_TOOLTIP
	_reset_save_feedback_visual_state()
	save_feedback_title.text = SAVE_FEEDBACK_DEFAULT_TITLE
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	save_feedback_label.text = ""
	if is_instance_valid(save_feedback_timer):
		return
	save_feedback_timer = Timer.new()
	save_feedback_timer.name = "SaveFeedbackResetTimer"
	save_feedback_timer.one_shot = true
	save_feedback_timer.wait_time = SAVE_FEEDBACK_RESET_WAIT_TIME
	save_feedback_timer.timeout.connect(_on_save_feedback_timeout)
	add_child(save_feedback_timer)


func _ensure_quick_save_icons_loaded() -> void:
	if save_icon_idle == null:
		save_icon_idle = _load_texture_or_null(SAVE_ICON_IDLE_PATH)
	if save_icon_ok == null:
		save_icon_ok = _load_texture_or_null(SAVE_ICON_OK_PATH)


func _load_texture_or_null(texture_path: String) -> Texture2D:
	if not ResourceLoader.exists(texture_path, "Texture2D"):
		push_warning("Level no encontro la textura de UI en %s." % texture_path)
		return null
	var loaded_texture: Variant = ResourceLoader.load(texture_path, "Texture2D")
	if loaded_texture is Texture2D:
		return loaded_texture
	push_warning("Level no pudo cargar la textura de UI en %s." % texture_path)
	return null


func _exit_tree() -> void:
	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
	if is_instance_valid(background):
		background.stop()
		background.stream = null


func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_track_book(get_tree(), _resolve_level_track_key())


func complete_current_run() -> void:
	var track_key := _resolve_level_track_key()
	var level_number := _current_level_number()
	_show_completed_run_feedback()
	var completion_result: Dictionary = _persist_completed_level(track_key, level_number)
	_show_level_completed_feedback(completion_result)


func _show_completed_run_feedback() -> void:
	victory.show()
	victory.play("victory")
	next_chapter_button.disabled = false
	teaching_sprite.show()


func _persist_completed_level(track_key: String, level_number: int) -> Dictionary:
	var level_count: int = Global.get_track_level_count(track_key)
	if level_count <= 0:
		return {}

	var resolved_level_number: int = clampi(level_number, 1, level_count)
	Global.mark_level_completed(track_key, resolved_level_number)
	return SaveManager.record_level_completed(
		track_key,
		resolved_level_number
	)


func _victory() -> void:
	complete_current_run()


func _on_adelante_pressed() -> void:
	var track_key := _resolve_level_track_key()
	var level_number := _current_level_number()
	if level_number >= Global.get_track_level_count(track_key):
		GameSceneRouter.go_to_main_menu(get_tree())
		return
	GameSceneRouter.go_to_track_level(get_tree(), track_key, level_number + 1)


func _on_save_progress_button_pressed() -> void:
	_save_current_level_progress()


func _save_current_level_progress() -> void:
	if manager_level == null or not is_instance_valid(manager_level):
		_show_save_error_feedback(
			{"last_error": "No se pudo acceder al runtime del nivel para guardar."}
		)
		return

	var track_key := _resolve_level_track_key()
	var level_count: int = Global.get_track_level_count(track_key)
	if level_count <= 0:
		_show_save_error_feedback(
			{"last_error": "No se pudo resolver el capitulo activo para guardar."}
		)
		return

	var resolved_level_number: int = clampi(_current_level_number(), 1, level_count)
	var partial_save_result: Dictionary = manager_level.store_partial_level_state(track_key)
	SaveManager.set_resume_to_level(track_key, resolved_level_number)
	SaveManager.record_manual_save()
	var save_status: Dictionary = SaveManager.get_save_status()
	if _save_failed(save_status):
		_show_save_error_feedback(save_status)
		return
	_show_save_success_feedback(partial_save_result, save_status)


func _save_failed(save_status: Dictionary) -> bool:
	return str(save_status.get("state", "")) == "error"


func _show_save_error_feedback(save_status: Dictionary) -> void:
	var last_error := str(save_status.get("last_error", "")).strip_edges()
	var error_message := (
		last_error
		if not last_error.is_empty()
		else SAVE_FEEDBACK_DEFAULT_ERROR_MESSAGE
	)
	_show_save_feedback(SAVE_FEEDBACK_ERROR_TITLE, error_message, false)


func _show_save_success_feedback(
	partial_save_result: Dictionary,
	save_status: Dictionary
) -> void:
	var progress_count: int = _read_saved_progress_count(partial_save_result)
	_show_save_feedback(
		_resolve_save_feedback_title(progress_count),
		_build_save_feedback_message(partial_save_result, save_status, progress_count),
		true
	)


func _read_saved_progress_count(partial_save_result: Dictionary) -> int:
	return int(
		partial_save_result.get(
			"progress_count",
			partial_save_result.get("placed_positive_count", 0)
		)
	)


func _resolve_save_feedback_title(progress_count: int) -> String:
	return (
		SAVE_FEEDBACK_PARTIAL_TITLE
		if progress_count > 0
		else SAVE_FEEDBACK_DEFAULT_TITLE
	)


func _build_save_feedback_message(
	partial_save_result: Dictionary,
	save_status: Dictionary,
	progress_count: int
) -> String:
	var message_lines: Array[String] = [
		_build_saved_time_line(save_status),
		_build_saved_progress_line(partial_save_result, progress_count)
	]
	return "\n".join(message_lines)


func _build_saved_time_line(save_status: Dictionary) -> String:
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	if saved_time.is_empty():
		return SAVE_FEEDBACK_DEFAULT_TIME_LINE
	return "Guardado a las %s" % saved_time


func _build_saved_progress_line(
	partial_save_result: Dictionary,
	progress_count: int
) -> String:
	if progress_count <= 0:
		return "Capitulo %d listo para retomar" % _current_level_number()

	var singular_label := str(
		partial_save_result.get(
			"progress_unit_singular",
			"avance guardado"
		)
	)
	var plural_label := str(
		partial_save_result.get("progress_unit_plural", singular_label)
	)
	var progress_label := (
		singular_label if progress_count == 1 else plural_label
	)
	return "%d %s" % [progress_count, progress_label]


func _resolve_configured_track_key() -> String:
	var configured_track_key := track_key_override.strip_edges()
	return configured_track_key if not configured_track_key.is_empty() else DEFAULT_TRACK_KEY


func _resolve_level_track_key() -> String:
	if active_track_key.is_empty():
		active_track_key = _resolve_configured_track_key()
	return active_track_key


func _get_resume_track_key() -> String:
	return _resolve_level_track_key()


func _show_level_completed_feedback(completion_result: Dictionary) -> void:
	_show_streak_feedback(_read_streak_feedback(completion_result))


func _read_streak_feedback(completion_result: Dictionary) -> Dictionary:
	var raw_streak_feedback: Variant = completion_result.get("streak_feedback", {})
	return raw_streak_feedback if raw_streak_feedback is Dictionary else {}


func _show_save_feedback(title: String, message: String, success: bool) -> void:
	_show_feedback_card(
		title,
		message,
		SAVE_FEEDBACK_SUCCESS_TITLE_COLOR if success else SAVE_FEEDBACK_ERROR_TITLE_COLOR,
		SAVE_FEEDBACK_SUCCESS_BODY_COLOR if success else SAVE_FEEDBACK_ERROR_BODY_COLOR
	)
	if success:
		save_progress_button.icon = save_icon_ok
	else:
		save_progress_button.icon = save_icon_idle


func _show_streak_feedback(streak_feedback: Dictionary) -> void:
	if not bool(streak_feedback.get("should_show", false)):
		return
	_show_feedback_card(
		str(streak_feedback.get("title", "Racha activa")).strip_edges(),
		str(streak_feedback.get("message", "")).strip_edges(),
		SAVE_FEEDBACK_SUCCESS_TITLE_COLOR,
		SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	)
	save_progress_button.icon = save_icon_idle


func _show_feedback_card(
	title: String,
	message: String,
	title_color: Color,
	body_color: Color
) -> void:
	save_feedback_backdrop.visible = true
	save_feedback_title.text = title
	save_feedback_label.text = message
	save_feedback_title.modulate = title_color
	save_feedback_label.modulate = body_color

	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
		save_feedback_timer.start()


func _reset_save_feedback_visual_state() -> void:
	save_progress_button.icon = save_icon_idle
	save_feedback_backdrop.visible = false


func _on_save_feedback_timeout() -> void:
	if not is_inside_tree():
		return
	_reset_save_feedback_visual_state()


func _current_level_number() -> int:
	return int(Global.current_level)
