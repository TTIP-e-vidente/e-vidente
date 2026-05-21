# Estrella de precisión para nodos del mapa.
# Hijos requeridos: StarEmpty (Sprite2D base) y StarFill (Sprite2D + ShaderMaterial con fill_amount).
@tool
extends Node2D
class_name StarProgress

const SHADER_PARAM := "fill_amount"

@export_range(0.0, 1.0, 0.01) var fill_amount: float = 0.0:
	set(value):
		fill_amount = clampf(value, 0.0, 1.0)
		_refresh()

# min_accuracy_to_show: por debajo de este % la estrella se oculta (0 = siempre visible).
@export_range(0, 100, 5) var min_accuracy_to_show: int = 1

@onready var star_empty: Sprite2D = get_node_or_null("StarEmpty")
@onready var star_fill: Sprite2D = get_node_or_null("StarFill")


func _ready() -> void:
	_refresh()


func set_progress(accuracy: float) -> void:
	fill_amount = accuracy


func _refresh() -> void:
	if not is_node_ready():
		return
	visible = fill_amount >= float(min_accuracy_to_show) / 100.0
	if star_fill == null:
		return

	var mat: Material = star_fill.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(SHADER_PARAM, fill_amount)
	else:
		star_fill.modulate.a = remap(fill_amount, 0.0, 1.0, 0.25, 1.0)
