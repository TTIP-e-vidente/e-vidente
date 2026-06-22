class_name ScopeTabButton
extends Button

# Pestaña de categoría del leaderboard. Estilos definidos en ScopeTabButton.tscn.


var scope: String = ""


func _ready() -> void:
	toggle_mode = true
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	focus_mode = Control.FOCUS_NONE


func configurar(etiqueta: String, scope_valor: String) -> void:
	text = etiqueta
	scope = scope_valor
