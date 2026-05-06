extends Libro
class_name LibroKeto

const TRACK_KEY := "cetogenica"

func _ready(): 
	titulo_nivel.text ="Cetogénica"
	
func _obtener_clave_pista() -> String:
	return TRACK_KEY
