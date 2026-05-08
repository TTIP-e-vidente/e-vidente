extends Libro
class_name LibroKeto

const TRACK_KEY := "cetogenica"


func _ready() -> void:
	super._ready()
	titulo_nivel.text = "Cetogenica"


func _obtener_clave_pista() -> String:
	return TRACK_KEY
