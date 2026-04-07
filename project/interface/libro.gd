extends Node2D
class_name Libro

@onready var background = $Background
@onready var cap_2 = $VBoxContainer/Cap2
@onready var cap_3 = $VBoxContainer/Cap3
@onready var cap_4 = $VBoxContainer/Cap4
@onready var cap_5 = $VBoxContainer/Cap5
@onready var cap_6 = $VBoxContainer/Cap6


func _ready() -> void:
	background.play()
	SaveManager.set_resume_to_book(_get_track_key())
	var book_progress := _get_book_progress()
	cap_2.disabled = not book_progress[1][Global.LEVEL_STATUS_INDEX]
	cap_3.disabled = not book_progress[2][Global.LEVEL_STATUS_INDEX]
	cap_4.disabled = not book_progress[3][Global.LEVEL_STATUS_INDEX]
	cap_5.disabled = not book_progress[4][Global.LEVEL_STATUS_INDEX]
	cap_6.disabled = not book_progress[5][Global.LEVEL_STATUS_INDEX]


func _get_track_key() -> String:
	return "celiaquia"


func _get_book_progress() -> Dictionary:
	return Global.items_level

func _on_button_pressed():
	get_tree().change_scene_to_file("res://interface/archivero.tscn")

func _on_cap_1_pressed():
	Global.current_level = 1
	get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")
	
func _on_cap_2_pressed():
	Global.current_level = 2
	get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")

func _on_cap_3_pressed():
	Global.current_level = 3
	get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")

func _on_cap_4_pressed():
	Global.current_level = 4
	get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")

func _on_cap_5_pressed():
	Global.current_level = 5
	get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")
	
func _on_cap_6_pressed():
	Global.current_level = 6
	get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")
