extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background: AudioStreamPlayer2D = $Background
@onready var play_backdrop: ColorRect = $PlayBackdrop
@onready var play_panel: PanelContainer = $PlayPanel
@onready var play_title: Label = $PlayPanel/MarginContainer/Content/Title
@onready var play_badge: Label = $PlayPanel/MarginContainer/Content/HeaderRow/StatusChip/MarginContainer/StatusBadge
@onready var play_subtitle: Label = $PlayPanel/MarginContainer/Content/Subtitle
@onready var resume_summary: Label = $PlayPanel/MarginContainer/Content/SummaryPanel/MarginContainer/ResumeSummary
@onready var continue_button: Button = $PlayPanel/MarginContainer/Content/ContinueButton
@onready var mode_button: Button = $PlayPanel/MarginContainer/Content/ModeButton

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const QUESTIONS_SCENE := "res://preguntas/pregunta.tscn"

func _ready() -> void:
	background.play()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(ARCHIVERO_SCENE)


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file(QUESTIONS_SCENE)


func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	var resume_state := SaveManager.load_progress_and_get_resume_state(false)
	get_tree().change_scene_to_file(str(resume_state.get("scene_path", ARCHIVERO_SCENE)))

func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_intro(get_tree())
