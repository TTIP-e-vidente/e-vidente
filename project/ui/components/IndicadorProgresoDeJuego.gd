extends CanvasLayer

const ANCHO_MINIMO_PANEL := 240.0
const MAXIMO_CARACTERES_TITULO := 28

@onready var _contenedor_margen: MarginContainer = $CapaHud/ContenedorMargen
@onready var _panel: PanelContainer = $CapaHud/ContenedorMargen/ColumnaHud/FilaSuperior/Panel
@onready var _texto_contexto: Label = $CapaHud/ContenedorMargen/ColumnaHud/FilaSuperior/Panel/Padding/Fila/TextoContexto
@onready var _texto_progreso: Label = $CapaHud/ContenedorMargen/ColumnaHud/FilaSuperior/Panel/Padding/Fila/TextoProgreso

var _entrada_sutil_reproducida := false


func _ready() -> void:
	if _panel != null:
		_panel.custom_minimum_size = Vector2(ANCHO_MINIMO_PANEL, 0.0)
	_reproducir_entrada_sutil()


func configurar(contexto: Dictionary) -> void:
	var indice_juego_actual: int = int(contexto.get("actual", contexto.get("indice_juego_actual", 1)))
	var total_juegos: int = int(contexto.get("total", contexto.get("total_juegos", 1)))
	var titulo: String = str(contexto.get("titulo", contexto.get("titulo_nodo", ""))).strip_edges()
	var dificultad: int = int(contexto.get("dificultad", 0))
	if titulo.is_empty() and dificultad > 0:
		titulo = "Dificultad %d" % dificultad
	actualizar(titulo, indice_juego_actual, total_juegos)


func actualizar(titulo: String, indice_juego_actual: int, total_juegos: int) -> void:
	var total_juegos_seguro: int = max(1, total_juegos)
	var indice_juego_seguro: int = clampi(max(1, indice_juego_actual), 1, total_juegos_seguro)
	var titulo_limpio: String = _acortar_titulo_para_hud(titulo)
	var tiene_contexto: bool = not titulo_limpio.is_empty()

	_texto_contexto.visible = tiene_contexto
	_texto_contexto.text = titulo_limpio
	_texto_progreso.text = "Juego %d/%d" % [indice_juego_seguro, total_juegos_seguro]


func _acortar_titulo_para_hud(titulo: String) -> String:
	var titulo_limpio: String = titulo.strip_edges().replace("\n", " ")
	while titulo_limpio.contains("  "):
		titulo_limpio = titulo_limpio.replace("  ", " ")
	if titulo_limpio.length() <= MAXIMO_CARACTERES_TITULO:
		return titulo_limpio
	return titulo_limpio.substr(0, MAXIMO_CARACTERES_TITULO - 3).strip_edges() + "..."


func _reproducir_entrada_sutil() -> void:
	if _entrada_sutil_reproducida:
		return
	if _panel == null:
		return
	_entrada_sutil_reproducida = true
	_panel.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)