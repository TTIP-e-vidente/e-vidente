extends Control

@onready var objective_label: Label = $ObjectiveLabel
@onready var objective_main: Label = $ObjectiveMain
@onready var objective_sub: Label = $ObjectiveSub


func set_objective(data: Dictionary) -> void:
	var lines: Dictionary = _extract_lines(data)
	objective_label.text = str(lines.get("label", "Prepará"))
	objective_main.text = str(lines.get("main", ""))
	objective_main.visible = not objective_main.text.strip_edges().is_empty()
	objective_sub.text = str(lines.get("sub", ""))
	objective_sub.visible = not objective_sub.text.strip_edges().is_empty()


func _extract_lines(data: Dictionary) -> Dictionary:
	var label_text: String = _first_text(
		data,
		PackedStringArray(["objective_label", "label"]),
		"Prepará"
	)

	if data.has("objective_main"):
		return {
			"label": label_text,
			"main": str(data.get("objective_main", "")),
			"sub": str(data.get("objective_sub", "")),
		}

	var message: String = _first_text(
		data,
		PackedStringArray(["objective_message", "message"]),
		""
	)
	if message.strip_edges().is_empty():
		return {"label": label_text, "main": "", "sub": ""}

	var parts: PackedStringArray = message.split("\n", true, 1)
	return {
		"label": label_text,
		"main": parts[0] if parts.size() > 0 else "",
		"sub": parts[1] if parts.size() > 1 else "",
	}


func _first_text(data: Dictionary, keys: PackedStringArray, fallback: String) -> String:
	for key in keys:
		if not data.has(key):
			continue
		var value: String = str(data.get(key, ""))
		if not value.strip_edges().is_empty():
			return value
	return fallback
