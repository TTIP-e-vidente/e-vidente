extends RefCounted
class_name ResultadoDeNodo

const _Reglas := preload("res://nodo/ReglasDeProgresoDeNodo.gd")

var exp_base: int = 0
var exp_ganada: int = 0
var precision: int = 100
var porcentaje_error: int = 0
var tiempo: String = "0:00"
var duracion_ms: int = 0
var aciertos: int = 0
var errores: int = 0
var intentos: int = 1
var nodo_id: String = ""
var titulo_nodo: String = ""


## Construye el resultado desde un acumulador de estadísticas ya finalizado.
static func desde_estadisticas(
	estadisticas: EstadisticasDeNodo,
	p_exp_base: int,
	p_nodo_id: String,
	p_titulo: String
) -> ResultadoDeNodo:
	var r := ResultadoDeNodo.new()
	var stats: Dictionary = estadisticas.a_diccionario()
	r.aciertos = int(stats.get("aciertos", 0))
	r.errores = int(stats.get("errores", 0))
	r.intentos = int(stats.get("intentos", 1))
	r.precision = int(stats.get("precision", 100))
	r.porcentaje_error = int(stats.get("porcentaje_error", 0))
	r.duracion_ms = estadisticas.obtener_duracion_ms()
	r.tiempo = _Reglas.formatear_tiempo(r.duracion_ms)
	var ratio := _Reglas.calcular_ratio_precision(r.aciertos, r.intentos)
	r.exp_base = p_exp_base
	r.exp_ganada = _Reglas.calcular_exp_final(p_exp_base, ratio)
	r.nodo_id = p_nodo_id
	r.titulo_nodo = p_titulo
	return r


## Construye desde un Dictionary (compat con el sistema legacy de Global).
static func desde_diccionario(data: Dictionary) -> ResultadoDeNodo:
	var r := ResultadoDeNodo.new()
	r.exp_base = int(data.get("exp_base", 0))
	r.exp_ganada = int(data.get("exp_ganada", 0))
	r.precision = int(data.get("precision", 100))
	r.porcentaje_error = int(data.get("porcentaje_error", data.get("error_percent", 0)))
	r.tiempo = str(data.get("tiempo", "0:00"))
	r.duracion_ms = int(data.get("duracion_ms", data.get("duration_ms", 0)))
	r.aciertos = int(data.get("aciertos", data.get("correct", 0)))
	r.errores = int(data.get("errores", data.get("errors", 0)))
	r.intentos = int(data.get("intentos", data.get("attempts", 1)))
	r.nodo_id = str(data.get("nodo_id", data.get("node_key", "")))
	r.titulo_nodo = str(data.get("titulo_nodo", ""))
	return r


func a_diccionario() -> Dictionary:
	return {
		"exp_base": exp_base,
		"exp_ganada": exp_ganada,
		"precision": precision,
		"porcentaje_error": porcentaje_error,
		"tiempo": tiempo,
		"duracion_ms": duracion_ms,
		"aciertos": aciertos,
		"errores": errores,
		"intentos": intentos,
		"nodo_id": nodo_id,
		"titulo_nodo": titulo_nodo,
	}
