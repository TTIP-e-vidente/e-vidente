extends Node2D

@onready var background = $Background
@onready var avatar_preview: TextureRect = $SessionPanel/MarginContainer/ProfileContent/AvatarPreview
@onready var avatar_state: Label = $SessionPanel/MarginContainer/ProfileContent/AvatarState
@onready var username_label: Label = $SessionPanel/MarginContainer/ProfileContent/UsernameLabel
@onready var email_label: Label = $SessionPanel/MarginContainer/ProfileContent/EmailLabel
@onready var age_label: Label = $SessionPanel/MarginContainer/ProfileContent/AgeLabel
@onready var progress_label: Label = $SessionPanel/MarginContainer/ProfileContent/ProgressLabel
@onready var save_status_label: Label = $SessionPanel/MarginContainer/ProfileContent/SaveStatusLabel
@onready var history_text: RichTextLabel = $HistoryPanel/MarginContainer/HistoryContent/HistoryText

var start_position
var archive_highlighted = false

const AUTH_SCENE := "res://interface/auth.tscn"

func _ready():
	if not SaveManager.is_authenticated():
		get_tree().change_scene_to_file(AUTH_SCENE)
		return

	background.play()
	_refresh_dashboard()


func _refresh_dashboard() -> void:
	var profile := SaveManager.get_current_user_profile()
	var summary := Global.get_progress_summary()

	username_label.text = "Usuario: %s" % profile.get("username", "-")
	email_label.text = "Mail: %s" % profile.get("email", "-")
	age_label.text = "Edad: %s" % str(profile.get("age", "-"))
	progress_label.text = "Avance total: %d/%d capitulos\nCeliaquia: %d/6\nVeganismo: %d/6\nVeganismo + Celiaquia: %d/6" % [
		summary.get("total", 0),
		summary.get("max_total", 18),
		summary.get("celiaquia", 0),
		summary.get("veganismo", 0),
		summary.get("veganismo_celiaquia", 0)
	]
	save_status_label.text = "Ultimo guardado: %s" % profile.get("updated_at", "sin datos")

	var avatar_texture := SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state.text = "Foto local cargada" if avatar_texture != null else "Sin foto disponible"

	var history := SaveManager.get_current_user_history()
	if history.is_empty():
		history_text.text = "Todavia no hay eventos guardados."
		return

	var lines: Array[String] = []
	for entry in history:
		lines.append("%s | %s" % [entry.get("timestamp", ""), entry.get("message", "")])
	history_text.text = "\n".join(lines)
	
func _on_mouse_entered():
	$Anim.play("select")
	archive_highlighted = true

func _on_mouse_exited():
	$Anim.play("deselect")
	archive_highlighted = false


func _on_atrás_pressed():
	SaveManager.save_current_user_progress()
	get_tree().change_scene_to_file("res://niveles/intro.tscn")


func _on_guardar_pressed() -> void:
	SaveManager.record_manual_save()
	_refresh_dashboard()


func _on_cerrar_sesion_pressed() -> void:
	SaveManager.logout()
	get_tree().change_scene_to_file(AUTH_SCENE)
