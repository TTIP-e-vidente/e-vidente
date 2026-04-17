class_name StreakBadge
extends PanelContainer

## Estados posibles del badge de racha.
const STATUS_INACTIVE      := "inactive"
const STATUS_PENDING_TODAY := "pending_today"
const STATUS_ACTIVE_TODAY  := "active_today"

const DEFAULT_STATUS_TEXT := "Racha diaria"
const DEFAULT_NUMBER_TEXT := "0"

var _status_text: String = DEFAULT_STATUS_TEXT
var _number_text: String = DEFAULT_NUMBER_TEXT
var _status_key:  String = STATUS_INACTIVE
var _detail_text: String = ""

@onready var title_label:  Label = $MarginContainer/ContentRow/TextColumn/TitleLabel
@onready var count_label:  Label = $MarginContainer/ContentRow/TextColumn/CountLabel
@onready var detail_label: Label = $MarginContainer/ContentRow/TextColumn/DetailLabel


func _ready() -> void:
	render()


## Renderiza el badge a partir del view model global (o uno pasado como parámetro).
func render(streak_view_model: Dictionary = {}) -> void:
	_apply_view_model(_resolve_view_model(streak_view_model))


## Actualización directa sin pasar por view model.
func set_badge(number_value: int, next_status_text: String, next_status_key: String = STATUS_INACTIVE) -> void:
	_detail_text = ""
	_number_text  = _normalize_text(str(max(0, number_value)), DEFAULT_NUMBER_TEXT)
	_status_text  = _normalize_text(next_status_text, DEFAULT_STATUS_TEXT)
	_status_key   = _normalize_status_key(next_status_key)
	_refresh_ui()


# --- Internos ---

func _resolve_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	return Global.get_streak_view_model()


func _apply_view_model(vm: Dictionary) -> void:
	var next_status_key: String = str(vm.get("status_key", STATUS_INACTIVE))
	var current_count:   int    = int(vm.get("current_count", 0))

	_number_text = _format_count_label(current_count)
	_status_text = str(vm.get("status_title", DEFAULT_STATUS_TEXT))
	_status_key  = _normalize_status_key(next_status_key)
	_detail_text = str(vm.get("status_detail", "")).strip_edges()
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_node_ready():
		return

	title_label.text  = _status_text
	count_label.text  = _number_text
	detail_label.text = _detail_text
	detail_label.visible = not _detail_text.is_empty()

	_apply_badge_modulate(_status_key)


func _apply_badge_modulate(status_key: String) -> void:
	match status_key:
		STATUS_ACTIVE_TODAY:
			self_modulate = Color(0.98, 1.0, 0.94, 1.0)
		STATUS_PENDING_TODAY:
			self_modulate = Color(1.0, 0.98, 0.92, 1.0)
		_:
			self_modulate = Color(0.96, 0.96, 0.96, 1.0)


func _normalize_text(value: String, fallback: String) -> String:
	var v := value.strip_edges()
	return v if not v.is_empty() else fallback


func _normalize_status_key(value: String) -> String:
	match value.strip_edges():
		STATUS_ACTIVE_TODAY:
			return STATUS_ACTIVE_TODAY
		STATUS_PENDING_TODAY:
			return STATUS_PENDING_TODAY
		_:
			return STATUS_INACTIVE


func _format_count_label(current_count: int) -> String:
	if current_count <= 0:
		return "0 dias"
	return "%d %s %s" % [current_count, "dia" if current_count == 1 else "dias", "seguido" if current_count == 1 else "seguidos"]
