extends Control
class_name StreakLossMessagePanel

signal continue_pressed

const RUBIK_SPRAY_FONT_PATH := "res://fonts/RubikSprayPaint-Regular.ttf"
const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"
const RUBIK_ITALIC_FONT_PATH := "res://fonts/Rubik-Italic-VariableFont_wght.ttf"
const MobileUiLayoutHelperScript := preload("res://interface/helpers/MobileUiLayoutHelper.gd")

@onready var _overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var _message_panel: PanelContainer = $MessagePanel
@onready var _title_label: Label = (
	$MessagePanel/MarginContainer/VBoxContainer/TitleLabel
)
@onready var _streak_count_label: Label = $MessagePanel/MarginContainer/VBoxContainer/StreakCountLabel
@onready var _detail_label: Label = $MessagePanel/MarginContainer/VBoxContainer/DetailLabel
@onready var _best_label: Label = $MessagePanel/MarginContainer/VBoxContainer/BestLabel
@onready var _continue_button: Button = $MessagePanel/MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	visible = false
	_overlay_backdrop.gui_input.connect(_on_entrada_fondo)
	_continue_button.pressed.connect(_on_boton_continuar_presionado)
	_aplicar_fuentes()
	get_viewport().size_changed.connect(_ajustar_layout_movil)


func mostrar(feedback: Dictionary) -> void:
	if feedback.is_empty():
		return

	var title: String = str(feedback.get("title", "Tu racha se cortó")).strip_edges()
	var message: String = str(feedback.get("message", "")).strip_edges()
	var best_count: int = maxi(
		0,
		int(feedback.get("best_count", feedback.get("previous_count", 0)))
	)

	_title_label.text = title
	_streak_count_label.text = "0"
	_detail_label.text = message if not message.is_empty() else title
	_best_label.text = (
		"Mejor racha: %d %s" % [best_count, "día" if best_count == 1 else "días"]
		if best_count > 0
		else ""
	)
	_best_label.visible = best_count > 0
	_ajustar_layout_movil()
	visible = true


func ocultar() -> void:
	visible = false


func _aplicar_fuentes() -> void:
	var spray_font: Font = load(RUBIK_SPRAY_FONT_PATH) as Font
	var rubik_font: Font = load(RUBIK_FONT_PATH) as Font
	var rubik_italic_font: Font = load(RUBIK_ITALIC_FONT_PATH) as Font

	if spray_font != null and is_instance_valid(_streak_count_label):
		_streak_count_label.add_theme_font_override("font", spray_font)
	if rubik_font != null:
		for lbl: Label in [_title_label, _best_label]:
			if is_instance_valid(lbl):
				lbl.add_theme_font_override("font", rubik_font)
	if rubik_italic_font != null and is_instance_valid(_detail_label):
		_detail_label.add_theme_font_override("font", rubik_italic_font)


func _ajustar_layout_movil() -> void:
	if not is_instance_valid(_message_panel):
		return
	var viewport := get_viewport().get_visible_rect().size
	MobileUiLayoutHelperScript.aplicar_modal_centrado(_message_panel, viewport, 640.0, 440.0)
	MobileUiLayoutHelperScript.asegurar_minimo_tactil(_continue_button)


func _on_boton_continuar_presionado() -> void:
	ocultar()
	continue_pressed.emit()


func _on_entrada_fondo(event: InputEvent) -> void:
	if MobileUiLayoutHelperScript.cerrar_si_toque_fondo(event):
		_on_boton_continuar_presionado()
