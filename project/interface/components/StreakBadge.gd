class_name StreakBadge
extends PanelContainer

const STATUS_INACTIVE := "inactive"
const STATUS_PENDING_TODAY := "pending_today"
const STATUS_ACTIVE_TODAY := "active_today"

const PLACEHOLDER_ICON_ACTIVE := "R"
const PLACEHOLDER_ICON_PENDING := "..."
const PLACEHOLDER_ICON_INACTIVE := "-"
const DEFAULT_STATUS_TEXT := "Racha diaria"
const DEFAULT_NUMBER_TEXT := "0"

@export var status_text: String = DEFAULT_STATUS_TEXT:
	set(value):
		_status_text = _normalize_text(value, DEFAULT_STATUS_TEXT)
		_refresh_ui()
	get:
		return _status_text

@export var number_text: String = DEFAULT_NUMBER_TEXT:
	set(value):
		_number_text = _normalize_text(value, DEFAULT_NUMBER_TEXT)
		_refresh_ui()
	get:
		return _number_text

@export_enum("inactive", "pending_today", "active_today") var status_key: String = STATUS_INACTIVE:
	set(value):
		_status_key = _normalize_status_key(value)
		_refresh_ui()
	get:
		return _status_key

var _status_text: String = DEFAULT_STATUS_TEXT
var _number_text: String = DEFAULT_NUMBER_TEXT
var _status_key: String = STATUS_INACTIVE
var _detail_text := ""
var _today_text := ""
var _best_text := ""
var _last_text := ""

@onready var icon_label: Label = $MarginContainer/ContentRow/IconBadge/MarginContainer/IconLabel
@onready var title_label: Label = $MarginContainer/ContentRow/TextColumn/TitleLabel
@onready var count_label: Label = $MarginContainer/ContentRow/TextColumn/CountLabel
@onready var detail_label: Label = $MarginContainer/ContentRow/TextColumn/DetailLabel
@onready var meta_row: HBoxContainer = $MarginContainer/ContentRow/TextColumn/MetaRow
@onready var today_chip: PanelContainer = $MarginContainer/ContentRow/TextColumn/MetaRow/TodayChip
@onready var best_chip: PanelContainer = $MarginContainer/ContentRow/TextColumn/MetaRow/BestChip
@onready var last_chip: PanelContainer = $MarginContainer/ContentRow/TextColumn/MetaRow/LastChip
@onready var today_chip_label: Label = $MarginContainer/ContentRow/TextColumn/MetaRow/TodayChip/MarginContainer/TodayChipLabel
@onready var best_chip_label: Label = $MarginContainer/ContentRow/TextColumn/MetaRow/BestChip/MarginContainer/BestChipLabel
@onready var last_chip_label: Label = $MarginContainer/ContentRow/TextColumn/MetaRow/LastChip/MarginContainer/LastChipLabel


func _ready() -> void:
	render()


func set_badge(number_value: int, next_status_text: String, next_status_key: String = STATUS_INACTIVE) -> void:
	_clear_auxiliary_texts()
	_set_core_content(str(max(0, number_value)), next_status_text, next_status_key)
	_refresh_ui()


func render(streak_view_model: Dictionary = {}) -> void:
	_apply_view_model(_resolve_view_model(streak_view_model))


func _resolve_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	return Global.get_streak_view_model()


func _apply_view_model(streak_view_model: Dictionary) -> void:
	var next_status_key: String = str(streak_view_model.get("status_key", STATUS_INACTIVE))
	var current_count: int = int(streak_view_model.get("current_count", 0))
	var best_count: int = int(streak_view_model.get("best_count", 0))
	var last_type_label: String = str(
		streak_view_model.get("last_activity_type_label", "actividad valida")
	).strip_edges()
	var last_track_label: String = str(streak_view_model.get("last_track_label", "")).strip_edges()

	_set_core_content(
		_format_count_label(current_count),
		str(streak_view_model.get("status_title", DEFAULT_STATUS_TEXT)),
		next_status_key
	)
	_detail_text = str(streak_view_model.get("status_detail", "")).strip_edges()
	_today_text = str(streak_view_model.get("today_status_label", "Hoy falta")).strip_edges()
	_best_text = "Mejor %d %s" % [best_count, _format_day_label(best_count)]
	_last_text = _format_last_chip_label(last_type_label, last_track_label)
	_refresh_ui()


func _set_core_content(
	next_number_text: String,
	next_status_text: String,
	next_status_key: String
) -> void:
	_number_text = _normalize_text(next_number_text, DEFAULT_NUMBER_TEXT)
	_status_text = _normalize_text(next_status_text, DEFAULT_STATUS_TEXT)
	_status_key = _normalize_status_key(next_status_key)


func _clear_auxiliary_texts() -> void:
	_detail_text = ""
	_today_text = ""
	_best_text = ""
	_last_text = ""


func _refresh_ui() -> void:
	if not is_node_ready():
		return

	title_label.text = _status_text
	count_label.text = _number_text
	detail_label.text = _detail_text
	detail_label.visible = not _detail_text.is_empty()

	today_chip_label.text = _today_text
	today_chip.visible = not _today_text.is_empty()
	best_chip_label.text = _best_text
	best_chip.visible = not _best_text.is_empty()
	last_chip_label.text = _last_text
	last_chip.visible = not _last_text.is_empty()
	meta_row.visible = today_chip.visible or best_chip.visible or last_chip.visible

	icon_label.text = _resolve_icon_text(_status_key)
	_modulate_for_status(_status_key)


func _normalize_text(value: String, fallback: String) -> String:
	var normalized_value: String = value.strip_edges()
	if normalized_value.is_empty():
		return fallback
	return normalized_value


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
	return "%d %s seguidos" % [current_count, _format_day_label(current_count)]


func _format_last_chip_label(last_type_label: String, last_track_label: String) -> String:
	if last_track_label.is_empty():
		return "Ultima: %s" % last_type_label
	return "Ultima: %s en %s" % [last_type_label, last_track_label]


func _resolve_icon_text(next_status_key: String) -> String:
	match next_status_key:
		STATUS_ACTIVE_TODAY:
			return PLACEHOLDER_ICON_ACTIVE
		STATUS_PENDING_TODAY:
			return PLACEHOLDER_ICON_PENDING
		_:
			return PLACEHOLDER_ICON_INACTIVE


func _modulate_for_status(next_status_key: String) -> void:
	match next_status_key:
		STATUS_ACTIVE_TODAY:
			self_modulate = Color(0.98, 1.0, 0.94, 1.0)
		STATUS_PENDING_TODAY:
			self_modulate = Color(1.0, 0.98, 0.92, 1.0)
		_:
			self_modulate = Color(0.96, 0.96, 0.96, 1.0)


func _format_day_label(count: int) -> String:
	return "dia" if count == 1 else "dias"
