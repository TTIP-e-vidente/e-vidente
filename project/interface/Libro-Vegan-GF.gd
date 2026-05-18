extends Libro
class_name LibroVeganGLF

const TRACK_KEY := "veganismo_celiaquia"


func _ready() -> void:
	super._ready()
	titulo_nivel.text = "Vegano gluten-free"


func _obtener_clave_pista() -> String:
	return TRACK_KEY
