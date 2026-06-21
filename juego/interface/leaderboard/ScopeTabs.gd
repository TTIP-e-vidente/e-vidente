class_name ScopeTabs
extends ScrollContainer

# Selector scrolleable de categorías (scopes) del leaderboard.


signal scope_cambiado(scope: String)


const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"


@export var categoria_inicial: String = "global_xp"


var _scope_activo: String = ""
var _botones: Array[Button] = []
var _contenedor: HBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_contenedor = HBoxContainer.new()
	_contenedor.add_theme_constant_override("separation", 4)
	_contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_contenedor)
	_construir_botones()
	seleccionar(categoria_inicial)


func seleccionar(scope: String) -> void:
	_scope_activo = scope
	var categorias := LeaderboardScopeCatalog.obtener_categorias()
	for i in _botones.size():
		if i < categorias.size():
			_botones[i].button_pressed = str(categorias[i].get("scope", "")) == scope


func obtener_scope_activo() -> String:
	return _scope_activo


func _construir_botones() -> void:
	var rubik: Font = load(RUBIK_FONT_PATH) as Font
	for categoria in LeaderboardScopeCatalog.obtener_categorias():
		var boton := Button.new()
		boton.text = str(categoria.get("etiqueta", ""))
		boton.toggle_mode = true
		boton.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		boton.focus_mode = Control.FOCUS_NONE
		if rubik != null:
			boton.add_theme_font_override("font", rubik)
		_aplicar_estilo_boton(boton)
		var scope_del_boton: String = str(categoria.get("scope", ""))
		boton.pressed.connect(func() -> void: _al_presionar_tab(scope_del_boton))
		_contenedor.add_child(boton)
		_botones.append(boton)


func _aplicar_estilo_boton(boton: Button) -> void:
	var inactivo := StyleBoxFlat.new()
	inactivo.bg_color = Color(0.204, 0.247, 0.173, 0.08)
	inactivo.set_corner_radius_all(10)
	inactivo.content_margin_left = 10
	inactivo.content_margin_right = 10
	inactivo.content_margin_top = 8
	inactivo.content_margin_bottom = 8

	var activo := StyleBoxFlat.new()
	activo.bg_color = MiPaleta.VERDE_BOSQUE
	activo.set_corner_radius_all(10)
	activo.content_margin_left = 10
	activo.content_margin_right = 10
	activo.content_margin_top = 8
	activo.content_margin_bottom = 8

	var hover := inactivo.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.204, 0.247, 0.173, 0.14)

	boton.add_theme_stylebox_override("normal", inactivo)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", activo)
	boton.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1))
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)
	boton.add_theme_color_override("font_hover_color", MiPaleta.VERDE_BOSQUE)


func _al_presionar_tab(scope: String) -> void:
	if scope == _scope_activo:
		return
	_scope_activo = scope
	seleccionar(scope)
	scope_cambiado.emit(scope)
