extends Libro
class_name LibroKeto

func _ready() -> void:
	super._ready()


func _get_track_key() -> String:
	return "cetogenica"


func _get_book_progress() -> Dictionary:
	return Global.items_level_keto
	
func _on_cap_1_pressed():
	Global.current_level = 1
	get_tree().change_scene_to_file("res://niveles/nivel_4/Level-Keto.tscn")
	
func _on_cap_2_pressed():
	Global.current_level = 2
	get_tree().change_scene_to_file("res://niveles/nivel_4/Level-Keto.tscn")
func _on_cap_3_pressed():
	Global.current_level = 3
	get_tree().change_scene_to_file("res://niveles/nivel_4/Level-Keto.tscn")

func _on_cap_4_pressed():
	Global.current_level = 4
	get_tree().change_scene_to_file("res://niveles/nivel_4/Level-Keto.tscn")

func _on_cap_5_pressed():
	Global.current_level = 5
	get_tree().change_scene_to_file("res://niveles/nivel_4/Level-Keto.tscn")
	
func _on_cap_6_pressed():
	Global.current_level = 6
	get_tree().change_scene_to_file("res://niveles/nivel_4/Level-Keto.tscn")

func _on_atras_pressed():
	get_tree().change_scene_to_file("res://interface/archivero.tscn")
