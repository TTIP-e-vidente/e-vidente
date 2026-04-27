extends CanvasLayer
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const COMPLETION_LAYER := 70

var _track_key: String = GameTrackCatalog.TRACK_CELIAQUIA

@onready var subtitle_label: Label = $OverlayRoot/MarginContainer/CenterContainer/Card/MarginContainer/Content/Subtitle
@onready var detail_label: Label = $OverlayRoot/MarginContainer/CenterContainer/Card/MarginContainer/Content/SummaryPanel/MarginContainer/DetailLabel
@onready var continue_button: Button = $OverlayRoot/MarginContainer/CenterContainer/Card/MarginContainer/Content/ContinueButton

func _ready() -> void:
	layer = COMPLETION_LAYER
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
	GameSceneRouter.go_to_mode_selector(get_tree())
