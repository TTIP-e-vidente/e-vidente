extends CanvasLayer

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const COMPLETION_LAYER := 70

var _track_key: String = GameTrackCatalog.TRACK_CELIAQUIA

const CONTENT_PATH := "OverlayRoot/MarginContainer/CenterContainer/Card/MarginContainer/Content"

@onready var subtitle_label: Label = get_node(CONTENT_PATH + "/Subtitle")
@onready var detail_label: Label = (
	get_node(CONTENT_PATH + "/SummaryPanel/MarginContainer/DetailLabel")
)
@onready var continue_button: Button = get_node(CONTENT_PATH + "/ButtonRow/ContinueButton")

func _ready() -> void:
	layer = COMPLETION_LAYER
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_copy()
	if continue_button != null:
		continue_button.grab_focus()


func configure_for_track(track_key: String) -> void:
	_track_key = track_key.strip_edges()
	if is_node_ready():
		_refresh_copy()


func _refresh_copy() -> void:
	if subtitle_label == null or detail_label == null:
		return
	var track_label: String = GameTrackCatalog.obtener_etiqueta_pista(_track_key, "este modo")
	subtitle_label.text = "Terminaste el mapa de %s" % track_label


func _on_continuar_pressed() -> void:
	get_tree().paused = false
	print("[MapCompletion] close_reward_returning_to_map")
	queue_free()
