extends CanvasLayer
class_name ModalCierreAprendizaje

signal continuar_solicitado

const TITULO_FALLBACK := ""

@onready var _control_raiz: Control = $Control
@onready var _label_titulo: Label = (
	$Control/CenterContainer/TarjetaCierre/MargenTarjeta/ColumnaTarjeta/LabelTitulo
)
@onready var _imagen_ensenanza: TextureRect = (
	$Control/CenterContainer/TarjetaCierre/MargenTarjeta/ColumnaTarjeta/PanelContenido/MargenContenido/ColumnaContenido/ImagenEnsenanza
)
@onready var _texto_ensenanza: Label = (
	$Control/CenterContainer/TarjetaCierre/MargenTarjeta/ColumnaTarjeta/PanelContenido/MargenContenido/ColumnaContenido/TextoEnsenanza
)
@onready var _continuar_juego: Control = (
	$Control/CenterContainer/TarjetaCierre/MargenTarjeta/ColumnaTarjeta/ContinuarJuego
)


func _ready() -> void:
	ocultar()
	if is_instance_valid(_continuar_juego) and _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.continuar_solicitado.connect(_al_solicitar_continuar)


func mostrar_con_texto(titulo: String, texto: String, para_siguiente_juego: bool, segundos: int = 5) -> void:
	push_warning("ModalCierreAprendizaje: se intento mostrar una ensenanza textual.")
	ocultar()


func mostrar_con_imagen(titulo: String, textura: Texture2D, para_siguiente_juego: bool, segundos: int = 5) -> void:
	_label_titulo.text = _con_fallback(titulo, TITULO_FALLBACK)
	_imagen_ensenanza.texture = textura
	_imagen_ensenanza.show()
	_texto_ensenanza.text = ""
	_texto_ensenanza.hide()
	_mostrar_y_activar_continuacion(para_siguiente_juego, segundos)


func ocultar() -> void:
	if is_instance_valid(_control_raiz):
		_control_raiz.hide()
	if is_instance_valid(_continuar_juego) and _continuar_juego.has_method("ocultar"):
		_continuar_juego.call("ocultar")


func esta_visible() -> bool:
	return is_instance_valid(_control_raiz) and _control_raiz.visible


func _mostrar_y_activar_continuacion(para_siguiente_juego: bool, segundos: int) -> void:
	_control_raiz.show()
	if not is_instance_valid(_continuar_juego):
		return
	if para_siguiente_juego:
		_continuar_juego.call("mostrar_para_siguiente_juego", segundos)
	else:
		_continuar_juego.call("mostrar_para_finalizar", segundos)


func _con_fallback(texto: String, fallback: String) -> String:
	var limpio := str(texto).strip_edges()
	return limpio if not limpio.is_empty() else fallback


func _al_solicitar_continuar() -> void:
	continuar_solicitado.emit()
