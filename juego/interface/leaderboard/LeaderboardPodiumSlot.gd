class_name LeaderboardPodiumSlot
extends VBoxContainer

# Casillero del podio (1°, 2° o 3°).


@export var altura_pedestal: int = 36
@export var escala_rank: float = 1.0
@export var avatar_size: int = 44
@export var color_pedestal: Color = Color(0.859, 0.753, 0.318, 0.22)
@export var color_borde_pedestal: Color = Color(0.859, 0.753, 0.318, 0.55)


@onready var _avatar: LeaderboardAvatarBadge = %AvatarBadge
@onready var _label_nombre: Label = %NombreLabel
@onready var _label_puntaje: Label = %ScoreLabel
@onready var _label_rank: Label = %RankLabel
@onready var _pedestal: PanelContainer = %Pedestal


const AVATAR_SIZE_EMPATE := 22

# Colores por defecto (no-propio), calcados de los que trae LeaderboardPodiumSlot.tscn.
# "remove_theme_color_override" borraba el override cargado desde la escena y
# dejaba el label con el color por defecto del Theme global (ilegible sobre el
# fondo claro): reaplicar estos valores explícitos es lo que evita ese vacío.
const COLOR_NOMBRE_DEFECTO := Color(0.2784314, 0.2509804, 0.18431373, 1)
const COLOR_PUNTAJE_DEFECTO := Color(0.25882354, 0.47058824, 0.36862746, 1)
const COLOR_NOMBRE_PROPIO := Color(0.22, 0.38, 0.30, 1)
const COLOR_PUNTAJE_PROPIO := Color(0.25882354, 0.47058824, 0.36862746, 1)

var _entradas: Array = []
var _scope: String = "global_xp"
var _es_propio: bool = false
var _fila_avatares_empate: HBoxContainer = null


func _enter_tree() -> void:
	if is_instance_valid(_avatar):
		_avatar.avatar_size = avatar_size


func _ready() -> void:
	if is_instance_valid(_pedestal):
		_pedestal.custom_minimum_size.y = altura_pedestal
		_aplicar_estilo_pedestal()
	if is_instance_valid(_label_rank):
		_label_rank.add_theme_font_size_override("font_size", int(22 * escala_rank))


func limpiar() -> void:
	_entradas = []
	visible = false
	if is_instance_valid(_label_nombre):
		_label_nombre.text = ""
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = ""
	if is_instance_valid(_label_rank):
		_label_rank.text = ""
	_limpiar_fila_avatares_empate()


## entradas: una o más filas empatadas en el mismo puesto (RANK() les da el mismo
## número). Si hay más de una, se muestran todos los nombres y un avatar chico
## por cada empatado extra, en vez de quedarse solo con el primero.
func poblar(entradas: Array, id_propio: String, scope: String) -> void:
	if entradas.is_empty():
		limpiar()
		return

	_entradas = entradas
	_scope = scope
	var primera: Dictionary = entradas[0] as Dictionary
	_es_propio = _alguno_es_propio(entradas, id_propio)
	visible = true

	var posicion := int(primera.get("rank", 0))
	var puntaje := int(primera.get("score", 0))
	var nombre := _nombre_combinado(entradas)

	if is_instance_valid(_label_rank):
		_label_rank.text = LeaderboardFormat.texto_posicion(posicion)
		_label_rank.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_posicion_tarjeta_clara(posicion)
		)
	if is_instance_valid(_label_nombre):
		_label_nombre.text = nombre
		_label_nombre.add_theme_color_override(
			"font_color",
			COLOR_NOMBRE_PROPIO if _es_propio else COLOR_NOMBRE_DEFECTO
		)
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = LeaderboardFormat.formatear_score(puntaje, scope)
		_label_puntaje.add_theme_color_override(
			"font_color",
			COLOR_PUNTAJE_PROPIO if _es_propio else COLOR_PUNTAJE_DEFECTO
		)
	if is_instance_valid(_avatar):
		_avatar.mostrar_para_entrada(primera, _es_propio_entrada(primera, id_propio))
	_poblar_fila_avatares_empate(entradas, id_propio)
	_aplicar_estilo_pedestal()


func obtener_entrada() -> Dictionary:
	return _entradas[0] as Dictionary if not _entradas.is_empty() else {}


func obtener_entradas() -> Array:
	return _entradas


func refrescar_avatar_si_coincide(user_id: String) -> void:
	if user_id.is_empty():
		return
	for i in _entradas.size():
		var entrada := _entradas[i] as Dictionary
		if user_id != str(entrada.get("user_id", "")):
			continue
		if i == 0 and is_instance_valid(_avatar):
			_avatar.mostrar_para_entrada(entrada, _es_propio)
		elif is_instance_valid(_fila_avatares_empate):
			var idx_extra := i - 1
			if idx_extra >= 0 and idx_extra < _fila_avatares_empate.get_child_count():
				var badge := _fila_avatares_empate.get_child(idx_extra) as LeaderboardAvatarBadge
				if is_instance_valid(badge):
					badge.mostrar_para_entrada(entrada, false)
		return


func _nombre_combinado(entradas: Array) -> String:
	var nombres: Array[String] = []
	for entrada in entradas:
		var nombre := LeaderboardFormat.resolver_nombre_entrada(entrada as Dictionary)
		if not nombre.is_empty() and nombre != "—":
			nombres.append(nombre)
	if nombres.is_empty():
		return "—"
	if nombres.size() == 1:
		return nombres[0]
	if nombres.size() == 2:
		return "%s y %s" % [nombres[0], nombres[1]]
	var todos_menos_ultimo := nombres.slice(0, nombres.size() - 1)
	return "%s y %s" % [", ".join(todos_menos_ultimo), nombres[nombres.size() - 1]]


func _alguno_es_propio(entradas: Array, id_propio: String) -> bool:
	if id_propio.is_empty():
		return false
	for entrada in entradas:
		if _es_propio_entrada(entrada as Dictionary, id_propio):
			return true
	return false


func _es_propio_entrada(entrada: Dictionary, id_propio: String) -> bool:
	return not id_propio.is_empty() and str(entrada.get("user_id", "")) == id_propio


func _poblar_fila_avatares_empate(entradas: Array, id_propio: String) -> void:
	_limpiar_fila_avatares_empate()
	if entradas.size() <= 1 or not is_instance_valid(_avatar):
		return

	_fila_avatares_empate = HBoxContainer.new()
	_fila_avatares_empate.alignment = BoxContainer.ALIGNMENT_CENTER
	_fila_avatares_empate.add_theme_constant_override("separation", 2)
	add_child(_fila_avatares_empate)
	move_child(_fila_avatares_empate, _avatar.get_index() + 1)

	for i in range(1, entradas.size()):
		var entrada := entradas[i] as Dictionary
		var badge := LeaderboardAvatarBadge.new()
		badge.avatar_size = AVATAR_SIZE_EMPATE
		# avatar_size debe quedar seteado ANTES de add_child(): _ready() lo lee
		# para construir el nodo del tamaño correcto y add_child() en un padre ya
		# dentro del árbol dispara _ready() de forma síncrona.
		_fila_avatares_empate.add_child(badge)
		badge.mostrar_para_entrada(entrada, _es_propio_entrada(entrada, id_propio))


func _limpiar_fila_avatares_empate() -> void:
	if is_instance_valid(_fila_avatares_empate):
		_fila_avatares_empate.queue_free()
	_fila_avatares_empate = null


func _aplicar_estilo_pedestal() -> void:
	if not is_instance_valid(_pedestal):
		return
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_pedestal
	estilo.border_color = color_borde_pedestal
	estilo.set_border_width_all(1)
	estilo.corner_radius_top_left = 8
	estilo.corner_radius_top_right = 8
	estilo.corner_radius_bottom_left = 2
	estilo.corner_radius_bottom_right = 2
	_pedestal.add_theme_stylebox_override("panel", estilo)
