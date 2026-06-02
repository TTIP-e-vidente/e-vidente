extends RefCounted
class_name ResultadoDeMiniJuego

var exito: bool = true
var aciertos: int = 0
var errores: int = 0
var intentos: int = 1
var duracion_ms: int = 0
var modalidad: String = ""


## Mini juego jugado perfecto: 1 acierto, 0 errores, 1 intento.
static func crear_correcto(tipo_modalidad: String, duracion: int = 0) -> ResultadoDeMiniJuego:
	var r := ResultadoDeMiniJuego.new()
	r.exito = true
	r.aciertos = 1
	r.errores = 0
	r.intentos = 1
	r.duracion_ms = duracion
	r.modalidad = tipo_modalidad
	return r


## Mini juego con al menos un error: 0 aciertos, 1 error, 1 intento.
static func crear_con_error(tipo_modalidad: String, duracion: int = 0) -> ResultadoDeMiniJuego:
	var r := ResultadoDeMiniJuego.new()
	r.exito = false
	r.aciertos = 0
	r.errores = 1
	r.intentos = 1
	r.duracion_ms = duracion
	r.modalidad = tipo_modalidad
	return r


## Mini juego con stats exactos (para modalidades con múltiples intentos).
static func crear_detallado(
	tipo_modalidad: String,
	p_aciertos: int,
	p_errores: int,
	p_intentos: int,
	p_duracion_ms: int = 0
) -> ResultadoDeMiniJuego:
	var r := ResultadoDeMiniJuego.new()
	r.modalidad = tipo_modalidad
	r.aciertos = maxi(0, p_aciertos)
	r.errores = maxi(0, p_errores)
	r.intentos = maxi(1, p_intentos)
	r.duracion_ms = maxi(0, p_duracion_ms)
	r.exito = r.errores == 0
	return r


static func desde_diccionario(data: Dictionary) -> ResultadoDeMiniJuego:
	return crear_detallado(
		str(data.get("modalidad", "")),
		int(data.get("aciertos", 0)),
		int(data.get("errores", 0)),
		int(data.get("intentos", 1)),
		int(data.get("duracion_ms", 0))
	)


func a_diccionario() -> Dictionary:
	return {
		"exito": exito,
		"aciertos": aciertos,
		"errores": errores,
		"intentos": intentos,
		"duracion_ms": duracion_ms,
		"modalidad": modalidad,
	}
