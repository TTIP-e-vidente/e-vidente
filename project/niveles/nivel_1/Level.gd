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
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")
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


func _ready() -> void:
	_initialize_level_scene()
	_configure_quick_save_feedback()


func _initialize_level_scene() -> void:
	active_track_key = _resolve_configured_track_key()
	victory.hide()
	next_chapter_button.disabled = true
	_play_level_audio()
	if manager_level != null and manager_level.has_method("initialize_level_runtime"):
		manager_level.call("initialize_level_runtime", self)
	else:
		push_error("Level no pudo inicializar el runtime de ManagerLevel.")
	SaveManager.set_resume_to_level(
		_resolve_level_track_key(),
		_current_level_number()
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
	save_progress_button.icon = SAVE_ICON_IDLE
	save_progress_button.tooltip_text = MANUAL_SAVE_TOOLTIP
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
	GameSceneRouter.go_to_track_book(get_tree(), _resolve_level_track_key())


func _victory() -> void:
	var track_key := _resolve_level_track_key()
	var level_number := _current_level_number()
	victory.show()
	victory.play("victory")
	next_chapter_button.disabled = false
	teaching_sprite.show()
	Global.mark_level_completed(track_key, level_number)
	Global.clear_partial_level_state(track_key, level_number)
	SaveManager.record_level_completed(track_key, level_number)


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
	var partial_save_result: Dictionary = manager_level.store_partial_level_state(
		_resolve_level_track_key()
	)
	SaveManager.record_manual_save()
	var save_status: Dictionary = SaveManager.get_save_status()
	if str(save_status.get("state", "")) == "error":
		var last_error := str(save_status.get("last_error", "")).strip_edges()
		_show_save_feedback(
			SAVE_FEEDBACK_ERROR_TITLE,
			(
				last_error
				if not last_error.is_empty()
				else SAVE_FEEDBACK_DEFAULT_ERROR_MESSAGE
			),
			false
		)
		return

	var progress_count := int(
		partial_save_result.get(
			"progress_count",
			partial_save_result.get("placed_positive_count", 0)
		)
	)
	var save_feedback_title := (
		SAVE_FEEDBACK_PARTIAL_TITLE
		if progress_count > 0
		else SAVE_FEEDBACK_DEFAULT_TITLE
	)
	var message_lines: Array[String] = []
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	if saved_time.is_empty():
		message_lines.append(SAVE_FEEDBACK_DEFAULT_TIME_LINE)
	else:
		message_lines.append("Guardado a las %s" % saved_time)

	if progress_count <= 0:
		message_lines.append(
			"Capitulo %d listo para retomar" % _current_level_number()
		)
	else:
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
		message_lines.append("%d %s" % [progress_count, progress_label])

	_show_save_feedback(
		save_feedback_title,
		"\n".join(message_lines),
		true
	)


func _resolve_configured_track_key() -> String:
	var configured_track_key := track_key_override.strip_edges()
	return configured_track_key if not configured_track_key.is_empty() else DEFAULT_TRACK_KEY


func _resolve_level_track_key() -> String:
	if active_track_key.is_empty():
		active_track_key = _resolve_configured_track_key()
	return active_track_key


func _get_resume_track_key() -> String:
	return _resolve_level_track_key()


func _show_save_feedback(title: String, message: String, success: bool) -> void:
	save_feedback_backdrop.visible = true
	save_feedback_title.text = title
	save_feedback_label.text = message
	if success:
		save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
		save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
		save_progress_button.icon = SAVE_ICON_OK
	else:
		save_feedback_title.modulate = SAVE_FEEDBACK_ERROR_TITLE_COLOR
		save_feedback_label.modulate = SAVE_FEEDBACK_ERROR_BODY_COLOR
		save_progress_button.icon = SAVE_ICON_IDLE

	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
		save_feedback_timer.start()


func _on_save_feedback_timeout() -> void:
	if not is_inside_tree():
		return
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false


func _current_level_number() -> int:
	return int(Global.current_level)
