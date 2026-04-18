extends Node
class_name Level

## --- Configuración ---

const DEFAULT_TRACK_KEY            := "celiaquia"
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter             := preload("res://niveles/GameSceneRouter.gd")
const GameStreakTrackerScript      := preload(
	"res://niveles/progress/GameStreakTracker.gd"
)
const STREAK_PROGRESS_OVERLAY_SCENE := preload(
	"res://interface/components/StreakProgressOverlay.tscn"
)
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK   := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")

## --- Guardado rápido ---

const SAVE_FEEDBACK_DEFAULT_TITLE       := "Guardado local"
const SAVE_FEEDBACK_SUCCESS_TITLE_COLOR := Color(0.215686, 0.337255, 0.231373, 1)
const SAVE_FEEDBACK_SUCCESS_BODY_COLOR  := Color(0.266667, 0.227451, 0.156863, 0.96)
const SAVE_FEEDBACK_ERROR_TITLE_COLOR   := Color(0.568627, 0.184314, 0.141176, 1)
const SAVE_FEEDBACK_ERROR_BODY_COLOR    := Color(0.403922, 0.160784, 0.121569, 0.96)

## --- Exports ---

@export var track_key_override    := ""
@export var background_music_path := DEFAULT_BACKGROUND_MUSIC_PATH
@export_group("Debug Demo")
@export var debug_force_streak_feedback    := false

## --- Nodos de escena ---

@onready var background:         AudioStreamPlayer2D = $Background
@onready var victory:            AnimatedSprite2D    = $Victory
@onready var next_chapter_button: Button             = $Adelante
@onready var adelante_1: Sprite2D					 = $Adelante/adelante1
@onready var adelante_2: Sprite2D 					 = $Adelante/adelante2
@onready var adelante_3: Sprite2D 					 = $Adelante/adelante3
@onready var teaching_sprite:    Sprite2D            = $Ensenanza
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
var streak_progress_overlay: Node = null
var _current_run_completion_handled := false


func _ready() -> void:
	_start_level_flow()
	_configure_quick_save_feedback()
	streak_progress_overlay = STREAK_PROGRESS_OVERLAY_SCENE.instantiate()
	if streak_progress_overlay != null:
		add_child(streak_progress_overlay)



## --- Arranque ---

func _start_level_flow() -> void:
	var configured_key := track_key_override.strip_edges()
	active_track_key = configured_key if not configured_key.is_empty() else DEFAULT_TRACK_KEY
	_current_run_completion_handled = false
	victory.hide()
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
	if not is_instance_valid(background) or background_music_path.strip_edges().is_empty():
		return
	var stream: Variant = load(background_music_path.strip_edges())
	if stream is AudioStream:
		background.stream = stream
		background.play()


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
	if is_instance_valid(background):
		background.stop()
		background.stream = null


## --- Navegación y gameplay ---

func _on_atras_pressed() -> void:
	if active_track_key == DEFAULT_TRACK_KEY:
		GameSceneRouter.go_to_map(get_tree())
	else:
		GameSceneRouter.go_to_track_book(get_tree(), active_track_key)


func complete_current_run() -> void:
	if _current_run_completion_handled:
		return
	_current_run_completion_handled = true

	next_chapter_button.disabled = false
	teaching_sprite.show()

	var track_key := active_track_key
	var level_number := _valid_level_number(track_key)
	var current_level := _current_level_number()
	if level_number <= 0:
		return

	# --- Flujo de racha (lineal, todo acá) ---
	# 1. Capturar estado de racha ANTES de registrar
	var previous_streak: Dictionary = Global.get_streak_state()

	# 2. Registrar progreso y actividad de racha
	Global.mark_level_completed(track_key, level_number)
	Global.record_streak_activity(
		"level_completed",
		{"track_key": track_key, "level_number": level_number}
	)

	# 3. Persistir todo a disco
	SaveManager.record_level_completed(track_key, level_number)
	_show_completed_run_feedback()
	# 4. Generar feedback de racha
	var updated_streak: Dictionary = Global.get_streak_state()
	var only_first_today: bool = not debug_force_streak_feedback
	var streak_feedback: Dictionary = GameStreakTrackerScript.build_feedback(
		previous_streak,
		updated_streak,
		only_first_today
	)

	# 5. Mostrar feedback
	_show_streak_feedback(streak_feedback)

func _show_completed_run_feedback() -> void:
	
	next_chapter_button.disabled = false
	teaching_sprite.show()

	var chapter_fijo := _current_level_number()
	while _current_level_number() == chapter_fijo:
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
	if active_track_key == DEFAULT_TRACK_KEY:
		GameSceneRouter.go_to_map(get_tree())
	else:
		var next_level := _current_level_number() + 1
		var level_count := Global.get_track_level_count(active_track_key)
		if next_level <= level_count:
			GameSceneRouter.go_to_track_level(get_tree(), active_track_key, next_level)
		else:
			GameSceneRouter.go_to_track_book(get_tree(), active_track_key)


## --- Guardado rápido ---

func _on_save_progress_button_pressed() -> void:
	if manager_level == null or not is_instance_valid(manager_level):
		_show_save_feedback("No se pudo guardar", "No se pudo acceder al runtime del nivel para guardar.", false)
		return

	var track_key := active_track_key
	var resolved_level_number := _valid_level_number(track_key)
	if resolved_level_number <= 0:
		_show_save_feedback("No se pudo guardar", "No se pudo resolver el capitulo activo para guardar.", false)
		return

	var partial_save_result: Dictionary = manager_level.store_partial_level_state(track_key)
	SaveManager.set_resume_to_level(track_key, resolved_level_number)
	SaveManager.record_manual_save()
	var save_status: Dictionary = SaveManager.get_save_status()
	if str(save_status.get("state", "")) == "error":
		var error := str(save_status.get("last_error", "")).strip_edges()
		_show_save_feedback("No se pudo guardar", error if not error.is_empty() else "Reintenta de nuevo en unos segundos", false)
		return
	_show_save_success_feedback(partial_save_result, save_status)


func _show_save_success_feedback(partial: Dictionary, save_status: Dictionary) -> void:
	var count := int(partial.get("progress_count", partial.get("placed_positive_count", 0)))
	var title := "Guardado parcial" if count > 0 else SAVE_FEEDBACK_DEFAULT_TITLE
	var saved_time := str(save_status.get("last_saved_at", "")).get_slice(" ", 1)
	var time_line := "Guardado a las %s" % saved_time if not saved_time.is_empty() else "Guardado en este dispositivo"
	var progress_line: String
	if count <= 0:
		progress_line = "Capitulo %d listo para retomar" % Global.current_level
	else:
		var singular := str(partial.get("progress_unit_singular", "avance guardado"))
		var unit := singular if count == 1 else str(partial.get("progress_unit_plural", singular))
		progress_line = "%d %s" % [count, unit]
	_show_save_feedback(title, "%s\n%s" % [time_line, progress_line], true)


## --- Racha y feedback post-partida ---

func _show_save_feedback(title: String, message: String, success: bool) -> void:
	if is_instance_valid(streak_progress_overlay) and streak_progress_overlay.has_method("hide_overlay"):
		streak_progress_overlay.call("hide_overlay")
	_show_feedback_card(
		title,
		message,
		SAVE_FEEDBACK_SUCCESS_TITLE_COLOR if success else SAVE_FEEDBACK_ERROR_TITLE_COLOR,
		SAVE_FEEDBACK_SUCCESS_BODY_COLOR if success else SAVE_FEEDBACK_ERROR_BODY_COLOR
	)
	save_progress_button.icon = SAVE_ICON_OK if success else SAVE_ICON_IDLE


func _show_streak_feedback(feedback: Dictionary) -> void:
	if not bool(feedback.get("should_show", false)):
		return
	_reset_save_feedback_visual_state()
	if is_instance_valid(streak_progress_overlay) and streak_progress_overlay.has_method("show_feedback"):
		streak_progress_overlay.call("show_feedback", feedback)
	else:
		_show_feedback_card(
			str(feedback.get("title", "Racha activa")).strip_edges(),
			str(feedback.get("message", "")).strip_edges(),
			SAVE_FEEDBACK_SUCCESS_TITLE_COLOR,
			SAVE_FEEDBACK_SUCCESS_BODY_COLOR
		)
	save_progress_button.icon = SAVE_ICON_IDLE


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


func _valid_level_number(track_key: String) -> int:
	var level_count := Global.get_track_level_count(track_key)
	if level_count <= 0:
		return 0
	return clampi(Global.current_level, 1, level_count)

func _current_level_number() -> int:
	return int(Global.current_level)
