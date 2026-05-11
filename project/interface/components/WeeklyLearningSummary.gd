extends PanelContainer
class_name WeeklyLearningSummary

const RUBIK_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")

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


func set_weekly_data(data: Dictionary) -> void:
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
	return {
		"topic": "Celiaquia",
		"completed": 5,
		"total": 20,
		"key_learning": "El sello sin TACC ayuda a identificar alimentos seguros.",
		"suggestion": "Practica contaminacion cruzada para reforzar decisiones."
	}


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

	_subtitle_label.text = "Esta semana reforzaste"
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
