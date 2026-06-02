@tool
extends Button

const BACKGROUND_TEXTURE := preload("res://assets-sistema/perfil/perfil-menu.png")
const BUTTON_MIN_SIZE := Vector2(220.0, 68.0)
const BACKGROUND_MARGIN := 6.0
const AVATAR_SCALE_IN_LEFT_TILE := 0.64

var _background_sprite: Sprite2D = null
var _avatar_sprite: Sprite2D = null


func _ready() -> void:
	flat = true
	text = ""
	icon = null
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_aplicar_sobrescrituras_estilo_vacio()
	_asegurar_nodos_visuales()
	refrescar_icono_perfil()


func _get_minimum_size() -> Vector2:
	return BUTTON_MIN_SIZE


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_RESIZED
		or what == NOTIFICATION_THEME_CHANGED
		or what == NOTIFICATION_FOCUS_ENTER
		or what == NOTIFICATION_FOCUS_EXIT
	):
		_distribuir_nodos_visuales()


func refrescar_icono_perfil() -> void:
	_asegurar_nodos_visuales()
	_refrescar_textura_avatar()
	_distribuir_nodos_visuales()


func _asegurar_nodos_visuales() -> void:
	var can_create_nodes: bool = not Engine.is_editor_hint()
	var legacy_sprite: Sprite2D = get_node_or_null("Perfil") as Sprite2D
	if legacy_sprite != null:
		legacy_sprite.visible = false

	if _background_sprite == null or not is_instance_valid(_background_sprite):
		_background_sprite = get_node_or_null("ProfileBackground") as Sprite2D
		if _background_sprite == null and can_create_nodes:
			_background_sprite = Sprite2D.new()
			_background_sprite.name = "ProfileBackground"
			add_child(_background_sprite)
	if _background_sprite != null:
		_background_sprite.centered = true
		_background_sprite.z_index = 0
		_background_sprite.texture = BACKGROUND_TEXTURE

	if _avatar_sprite == null or not is_instance_valid(_avatar_sprite):
		_avatar_sprite = get_node_or_null("AvatarPreview") as Sprite2D
		if _avatar_sprite == null and can_create_nodes:
			_avatar_sprite = Sprite2D.new()
			_avatar_sprite.name = "AvatarPreview"
			add_child(_avatar_sprite)
	if _avatar_sprite != null:
		_avatar_sprite.centered = true
		_avatar_sprite.z_index = 1


func _refrescar_textura_avatar() -> void:
	if _avatar_sprite == null:
		return
	if Engine.is_editor_hint():
		_avatar_sprite.texture = null
		_avatar_sprite.visible = false
		return
	var avatar_texture: Texture2D = null
	if SaveManager != null:
		avatar_texture = SaveManager.obtener_textura_avatar_usuario_actual()
	_avatar_sprite.texture = avatar_texture
	_avatar_sprite.visible = avatar_texture != null



func _distribuir_nodos_visuales() -> void:
	if not is_node_ready() or _background_sprite == null or _background_sprite.texture == null:
		return
	var texture_size: Vector2 = _background_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var available_width: float = maxf(1.0, size.x - BACKGROUND_MARGIN)
	var available_height: float = maxf(1.0, size.y - BACKGROUND_MARGIN)
	var scale_factor: float = minf(
		available_width / texture_size.x,
		available_height / texture_size.y
	)
	var scaled_size: Vector2 = texture_size * scale_factor
	_background_sprite.scale = Vector2.ONE * scale_factor
	_background_sprite.position = Vector2(
		size.x - BACKGROUND_MARGIN - scaled_size.x * 0.5,
		size.y * 0.5
	)

	if _avatar_sprite == null or not _avatar_sprite.visible or _avatar_sprite.texture == null:
		return
	var avatar_texture_size: Vector2 = _avatar_sprite.texture.get_size()
	if avatar_texture_size.x <= 0.0 or avatar_texture_size.y <= 0.0:
		return

	var left_tile_size: float = scaled_size.y
	var avatar_target_size: float = left_tile_size * AVATAR_SCALE_IN_LEFT_TILE
	var avatar_scale: float = minf(
		avatar_target_size / avatar_texture_size.x,
		avatar_target_size / avatar_texture_size.y
	)
	var background_top_left: Vector2 = _background_sprite.position - scaled_size * 0.5
	_avatar_sprite.scale = Vector2.ONE * avatar_scale
	_avatar_sprite.position = background_top_left + Vector2(
		left_tile_size * 0.5,
		scaled_size.y * 0.5
	)


func _aplicar_sobrescrituras_estilo_vacio() -> void:
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
