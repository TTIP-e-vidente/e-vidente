extends Libro
class_name LibroVeganGLF



func _ready(): 
	titulo_nivel.text = "Vegano gluten-free"
	
func _obtener_clave_pista() -> String:
	return "veganismo_celiaquia"
