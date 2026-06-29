class_name ScopeTabButton
extends Button

# Pestaña de categoría del leaderboard. Estilos definidos en ScopeTabButton.tscn.


var scope: String = ""


func _ready() -> void:
	toggle_mode = true
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	focus_mode = Control.FOCUS_NONE


func configurar(etiqueta: String, scope_valor: String, disponible: bool = true) -> void:
	scope = scope_valor
	if disponible:
		text = etiqueta
		disabled = false
		modulate = Color.WHITE
	else:
		text = "%s · próx." % etiqueta
		disabled = true
		modulate = Color(0.55, 0.55, 0.55, 0.85)
