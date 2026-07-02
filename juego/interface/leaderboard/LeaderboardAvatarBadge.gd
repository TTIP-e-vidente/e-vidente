class_name LeaderboardAvatarBadge
extends Control

# Badge circular de avatar para filas del leaderboard.
# Usa cache local + endpoint público cuando hay avatar_key.


const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"

@export var avatar_size: int = 36

const COLORES_INICIAL: Array[Color] = [
	MiPaleta.VERDE_BOSQUE,
	MiPaleta.ORO_CLARO,
	MiPaleta.NARANJA_TIERRA,
	MiPaleta.AZUL_BRILLANTE,
	MiPaleta.MARRON_ROJIZO,
]


var _fondo: PanelContainer
var _texture: TextureRect
var _inicial: Label
var _user_id: String = ""
var _avatar_key: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(avatar_size, avatar_size)
	_construir_nodos()
	if not LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.connect(_al_avatar_cargado)


func mostrar_para_entrada(entrada: Dictionary, es_propio: bool) -> void:
	var nombre := _resolver_nombre(entrada)
	_user_id = str(entrada.get("user_id", ""))
	_avatar_key = str(entrada.get("avatar_key", ""))

	if es_propio:
		var tex_propia: Texture2D = SaveManager.obtener_textura_avatar_usuario_actual()
		if tex_propia != null:
			_mostrar_textura(tex_propia)
			return

	_aplicar_avatar_remoto_o_inicial(nombre)


func _aplicar_avatar_remoto_o_inicial(nombre: String) -> void:
	if not _user_id.is_empty() and not _avatar_key.is_empty():
		var tex_cache := LeaderboardAvatarCache.obtener_textura(_user_id, _avatar_key)
		if tex_cache != null:
			_mostrar_textura(tex_cache)
			return
	_mostrar_inicial(nombre, _user_id)


func _al_avatar_cargado(user_id: String, tex: Texture2D) -> void:
	if user_id == _user_id and tex != null:
		_mostrar_textura(tex)


func _construir_nodos() -> void:
	var tam := maxi(avatar_size, 24)
	_fondo = PanelContainer.new()
	_fondo.custom_minimum_size = Vector2(tam, tam)
	_fondo.clip_contents = true
	add_child(_fondo)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = MiPaleta.VERDE_BOSQUE
	estilo.set_corner_radius_all(int(tam / 2.0))
	_fondo.add_theme_stylebox_override("panel", estilo)

	var center := CenterContainer.new()
	_fondo.add_child(center)

	_texture = TextureRect.new()
	_texture.custom_minimum_size = Vector2(tam - 4, tam - 4)
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture.visible = false
	center.add_child(_texture)

	_inicial = Label.new()
	_inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inicial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rubik: Font = load(RUBIK_FONT_PATH) as Font
	if rubik != null:
		_inicial.add_theme_font_override("font", rubik)
	_inicial.add_theme_font_size_override("font_size", maxi(12, int(tam / 2.0) - 2))
	_inicial.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(_inicial)


func _mostrar_textura(tex: Texture2D) -> void:
	_texture.texture = tex
	_texture.visible = true
	_inicial.visible = false


func _mostrar_inicial(nombre: String, user_id: String) -> void:
	_texture.visible = false
	_inicial.visible = true
	_inicial.text = _extraer_inicial(nombre)
	var estilo := _fondo.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		estilo.bg_color = _color_para_usuario(user_id)


func _resolver_nombre(entrada: Dictionary) -> String:
	return LeaderboardFormat.resolver_nombre_entrada(entrada)


func _extraer_inicial(nombre: String) -> String:
	var limpio := nombre.strip_edges()
	if limpio.is_empty():
		return "?"
	return limpio.substr(0, 1).to_upper()


func _color_para_usuario(user_id: String) -> Color:
	if user_id.is_empty():
		return MiPaleta.VERDE_BOSQUE
	var idx := absi(user_id.hash()) % COLORES_INICIAL.size()
	return COLORES_INICIAL[idx]
