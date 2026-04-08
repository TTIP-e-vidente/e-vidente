extends VBoxContainer

const TRACK_CARD_SCENE := preload("res://interface/container.tscn")


func _ready() -> void:
	rebuild_track_cards()


func rebuild_track_cards() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	for track_definition in Global.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		if track_key.is_empty():
			continue
		var track_card := TRACK_CARD_SCENE.instantiate()
		if track_card == null:
			continue
		track_card.name = "Track_%s" % track_key.replace("-", "_")
		add_child(track_card)
		if track_card is Control:
			(track_card as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if track_card.has_method("configure"):
			track_card.call_deferred("configure", track_definition)
