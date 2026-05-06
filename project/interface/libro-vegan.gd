extends Libro
class_name LibroVegan

const TRACK_KEY := "veganismo"


func _ready(): 
	titulo_nivel.text = "Veganismo"
	
func _obtener_clave_pista() -> String:
	return TRACK_KEY
