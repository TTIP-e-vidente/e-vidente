extends Level
class_name LevelVeganGluten

const BOOK_TRACK_KEY := "veganismo_celiaquia"


func _ready():
	super._ready()


func _get_resume_track_key() -> String:
	return BOOK_TRACK_KEY

func _on_atrás_pressed():
	get_tree().change_scene_to_file("res://interface/Libro-Vegan-GF.tscn")

func _victory():
	victory.show()
	victory.play("victory")
	adelante.disabled = false
	ensenanza.show()
	Global.items_level_vegan_gf[Global.current_level][6] = true
	Global.clear_partial_level_state(_get_resume_track_key(), Global.current_level)
	SaveManager.record_level_completed(_get_resume_track_key(), Global.current_level)

func _on_adelante_pressed():
	if Global.current_level <= 5: 
		Global.current_level += 1
		get_tree().change_scene_to_file("res://niveles/nivel_3/Level-Vegan-GF.tscn")
	else:
		get_tree().change_scene_to_file("res://niveles/intro.tscn")
