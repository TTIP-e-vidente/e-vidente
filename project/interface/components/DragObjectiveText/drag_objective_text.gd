class_name DragObjectiveText
extends Control

@onready var action_label: Label = $ActionLabel
@onready var meal_label: Label = $MealLabel
@onready var meal_line: ColorRect = $MealLine
@onready var connector_label: Label = $ConnectorLabel
@onready var restriction_label: Label = $RestrictionLabel
@onready var restriction_line: ColorRect = $RestrictionLine

const _FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"
const ContentSchemaNormalizerScript := preload(
	"res://sistemas/contenido/ContentSchemaNormalizer.gd"
)


func _ready() -> void:
	_apply_fonts()
	_apply_style()
	_layout_nodes()


func set_objective(data: Dictionary) -> void:
	print_debug("[DragObjectiveText] set_objective data=", data)
	var parsed: Dictionary = _parse_objective(data)
	action_label.text = parsed["action"]
	meal_label.text = parsed["meal"]
	connector_label.text = parsed["connector"]
	restriction_label.text = parsed["restriction"]
	# La linea inferior pertenece al diseño original, se mantiene siempre.
	restriction_label.visible = not restriction_label.text.strip_edges().is_empty()
	_play_intro()


# --- Estilos y layout ------------------------------------------------------

func _apply_fonts() -> void:
	var base_font: FontFile = load(_FONT_PATH) as FontFile
	if base_font == null:
		return
	# Labels con mas peso visual usan weight alto del Rubik variable.
	var medium_font: FontVariation = FontVariation.new()
	medium_font.base_font = base_font
	medium_font.variation_opentype = {"wght": 500}
	var bold_font: FontVariation = FontVariation.new()
	bold_font.base_font = base_font
	bold_font.variation_opentype = {"wght": 700}
	action_label.add_theme_font_override("font", medium_font)
	connector_label.add_theme_font_override("font", medium_font)
	meal_label.add_theme_font_override("font", bold_font)
	restriction_label.add_theme_font_override("font", bold_font)


func _apply_style() -> void:
	action_label.add_theme_color_override("font_color", Color(0.10, 0.10, 0.095, 0.92))
	action_label.add_theme_font_size_override("font_size", 18)
	meal_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 0.98))
	meal_label.add_theme_font_size_override("font_size", 19)
	connector_label.add_theme_color_override("font_color", Color(0.09, 0.09, 0.085, 0.94))
	connector_label.add_theme_font_size_override("font_size", 19)
	restriction_label.add_theme_color_override("font_color", Color(0.06, 0.06, 0.055, 0.94))
	restriction_label.add_theme_font_size_override("font_size", 17)
	meal_line.color = Color(0.10, 0.10, 0.095, 0.72)
	restriction_line.color = Color(0.10, 0.10, 0.095, 0.68)


func _layout_nodes() -> void:
	custom_minimum_size = Vector2(340, 115)
	size = Vector2(340, 115)
	_setup_label(action_label, Vector2(42, 0), Vector2(72, 28), HORIZONTAL_ALIGNMENT_LEFT)
	_setup_label(meal_label, Vector2(114, 0), Vector2(210, 28), HORIZONTAL_ALIGNMENT_CENTER)
	_setup_label(connector_label, Vector2(60, 47), Vector2(230, 28), HORIZONTAL_ALIGNMENT_CENTER)
	_setup_label(restriction_label, Vector2(110, 72), Vector2(140, 24), HORIZONTAL_ALIGNMENT_CENTER)
	meal_line.position = Vector2(122, 31)
	meal_line.size = Vector2(190, 2)
	restriction_line.position = Vector2(62, 99)
	restriction_line.size = Vector2(215, 2)


func _setup_label(
	label: Label,
	pos: Vector2,
	label_size: Vector2,
	horizontal: int
) -> void:
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = horizontal
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Lectura de datos ------------------------------------------------------

func _parse_objective(data: Dictionary) -> Dictionary:
	return ContentSchemaNormalizerScript.normalize_drag_objective(data)


# --- Animacion -------------------------------------------------------------

func _play_intro() -> void:
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
