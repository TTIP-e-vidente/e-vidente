extends PanelContainer
class_name WeeklyLearningSummary

const RUBIK_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")
const ImportadorProgresoOnlineScript := preload(
	"res://API/backend/sync/ImportadorProgresoOnline.gd"
)
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

@onready var _title_label: Label = $VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var _topic_label: Label = $VBoxContainer/TopicLabel
@onready var _progress_value_label: Label = $VBoxContainer/ProgressValueLabel
@onready var _progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var _key_learning_label: Label = $VBoxContainer/KeyLearningLabel
@onready var _suggestion_label: Label = $VBoxContainer/SuggestionLabel

var _weekly_data: Dictionary = {}


func _ready() -> void:
	_aplicar_fuentes()
	refrescar()


func establecer_datos_semanales(data: Dictionary) -> void:
	_weekly_data = data.duplicate(true)
	refrescar()


func refrescar() -> void:
	var data := _obtener_datos_semanales()
	_actualizar_vista(data)
	_animar_entrada()


func _aplicar_fuentes() -> void:
	var labels: Array[Label] = [
		_title_label,
		_subtitle_label,
		_topic_label,
		_progress_value_label,
		_key_learning_label,
		_suggestion_label,
	]
	for label: Label in labels:
		if is_instance_valid(label):
			label.add_theme_font_override("font", RUBIK_FONT)


func _obtener_datos_semanales() -> Dictionary:
	if not _weekly_data.is_empty():
		return _weekly_data
	return _construir_desde_progreso_local()


func _construir_desde_progreso_local() -> Dictionary:
	var track_key := _resolver_pista_activa()
	var node_progress: Dictionary = {}
	if SaveManager != null:
		node_progress = SaveManager.obtener_todo_progreso_nodos()
	return ImportadorProgresoOnlineScript.construir_resumen_semanal_desde_save(
		track_key,
		node_progress
	)


func _resolver_pista_activa() -> String:
	if SaveManager == null:
		return GameTrackCatalog.TRACK_CELIAQUIA
	var resume_state: Dictionary = SaveManager.obtener_estado_reanudacion()
	var track_key := str(resume_state.get("track_key", "")).strip_edges()
	if not track_key.is_empty() and GameTrackCatalog.tiene_pista(track_key):
		return track_key
	return GameTrackCatalog.TRACK_CELIAQUIA


func _actualizar_vista(data: Dictionary) -> void:
	var topic: String = str(data.get("topic", "Tema principal"))
	var completed: int = int(data.get("completed", 0))
	var total: int = maxi(int(data.get("total", 1)), 1)
	var key_learning: String = str(
		data.get("key_learning", "Repasa el concepto clave trabajado esta semana.")
	)
	var suggestion: String = str(
		data.get("suggestion", "Continua practicando para consolidar lo aprendido.")
	)

	_subtitle_label.text = (
		"Progreso del mapa"
		if completed <= 0
		else "Esta semana reforzaste"
	)
	_topic_label.text = topic
	_progress_value_label.text = "%d de %d desafios completados" % [completed, total]
	_progress_bar.max_value = float(total)
	_progress_bar.value = clampf(float(completed), 0.0, float(total))
	_key_learning_label.text = key_learning
	_suggestion_label.text = suggestion


func _animar_entrada() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.28)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
