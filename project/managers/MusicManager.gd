extends Node
class_name MusicManager
## Gestor centralizado de música de fondo con soporte para loop automático.
##
## Evita que la música se corte en sesiones prolongadas detectando el fin
## de la pista y reiniciándola automáticamente.


# === Signals ===

signal musica_iniciada(ruta_audio: String)
signal musica_finalizada


# === Constants ===

const VOLUMEN_PREDETERMINADO_DB := 0.0
const DURACION_TRANSICION_FADE := 0.5


# === Private Variables ===

var _reproductor_musica: AudioStreamPlayer = null
var _ruta_musica_actual: String = ""
var _volumen_objetivo_db: float = VOLUMEN_PREDETERMINADO_DB
var _es_primera_reproduccion: bool = true


# === Lifecycle ===

func _ready() -> void:
	_configurar_reproductor_musica()


func _process(_delta: float) -> void:
	if _reproductor_musica == null or not _reproductor_musica.playing:
		return
	
	if _reproductor_musica.stream == null:
		return
	
	# Detectar si la música terminó y reiniciarla
	var duracion_total: float = _reproductor_musica.stream.get_length()
	var posicion_actual: float = _reproductor_musica.get_playback_position()
	
	# Si estamos cerca del final (dentro de 0.1 segundos), reiniciar
	if posicion_actual >= (duracion_total - 0.1):
		_reiniciar_musica_actual()


# === API Pública ===

## Reproduce una pista de música con loop automático.
## Si ya hay música reproduciéndose, la detiene y comienza la nueva.
func reproducir_musica(ruta_audio: String) -> void:
	if ruta_audio.strip_edges().is_empty():
		return
	
	var stream_audio: AudioStream = load(ruta_audio) as AudioStream
	if stream_audio == null:
		printerr("No se pudo cargar la música: ", ruta_audio)
		return
	
	# Si es la misma música que ya está reproduciéndose, no hacer nada
	if _ruta_musica_actual == ruta_audio and _reproductor_musica.playing:
		return
	
	_detener_musica_actual()
	_ruta_musica_actual = ruta_audio
	_reproductor_musica.stream = stream_audio
	_reproductor_musica.volume_db = _volumen_objetivo_db
	_reproductor_musica.play()
	
	musica_iniciada.emit(ruta_audio)


## Detiene la música actual de forma gradual (fade out).
func detener_musica(con_transicion: bool = true) -> void:
	if con_transicion and _reproductor_musica.playing:
		_hacer_fade_out()
	else:
		_detener_musica_actual()


## Cambia el volumen de la música de forma gradual.
func establecer_volumen(volumen_lineal: float) -> void:
	_volumen_objetivo_db = linear_to_db(clamp(volumen_lineal, 0.0, 1.0))
	
	if _reproductor_musica.playing:
		var tween := create_tween()
		tween.tween_property(
			_reproductor_musica,
			"volume_db",
			_volumen_objetivo_db,
			DURACION_TRANSICION_FADE
		)


## Pausa la música sin detenerla completamente.
func pausar_musica() -> void:
	if _reproductor_musica != null and _reproductor_musica.playing:
		_reproductor_musica.stream_paused = true


## Reanuda la música si está pausada.
func reanudar_musica() -> void:
	if _reproductor_musica != null and _reproductor_musica.stream_paused:
		_reproductor_musica.stream_paused = false


## Obtiene el estado actual de reproducción.
func esta_reproduciendo() -> bool:
	if _reproductor_musica == null:
		return false
	return _reproductor_musica.playing and not _reproductor_musica.stream_paused


## Obtiene la ruta de la música actual.
func obtener_musica_actual() -> String:
	return _ruta_musica_actual


# === Métodos Privados ===

func _configurar_reproductor_musica() -> void:
	if _reproductor_musica != null:
		return
	
	_reproductor_musica = AudioStreamPlayer.new()
	_reproductor_musica.name = "MusicManagerPlayer"
	_reproductor_musica.bus = &"Master"
	add_child(_reproductor_musica)


func _reiniciar_musica_actual() -> void:
	if _ruta_musica_actual.is_empty() or _reproductor_musica == null:
		return
	
	_reproductor_musica.play()


func _detener_musica_actual() -> void:
	if _reproductor_musica == null:
		return
	
	_reproductor_musica.stop()
	_reproductor_musica.stream = null
	_ruta_musica_actual = ""


func _hacer_fade_out() -> void:
	if _reproductor_musica == null or not _reproductor_musica.playing:
		return
	
	var tween := create_tween()
	tween.tween_property(
		_reproductor_musica,
		"volume_db",
		-80.0,
		DURACION_TRANSICION_FADE
	)
	await tween.finished
	_detener_musica_actual()
	musica_finalizada.emit()
