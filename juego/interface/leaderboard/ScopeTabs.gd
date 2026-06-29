class_name ScopeTabs
extends ScrollContainer

# Selector scrolleable de categorías (scopes) del leaderboard.


signal scope_cambiado(scope: String)


const TAB_BUTTON_SCENE := preload("res://interface/leaderboard/ScopeTabButton.tscn")
const TAB_BUTTON_LIGHT_SCENE := preload("res://interface/leaderboard/ScopeTabButtonLight.tscn")


@export var categoria_inicial: String = "global_xp"
@export var tema_claro: bool = false
@export var diseno_en_filas: bool = false
@export var columnas_en_filas: int = 3


var _scope_activo: String = ""
var _botones: Array[ScopeTabButton] = []
var _contenedor_tabs: Container


@onready var _contenedor: HBoxContainer = %TabsHBox


func _ready() -> void:
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if diseno_en_filas:
		_contenedor.visible = false
		var grid := GridContainer.new()
		grid.columns = maxi(1, columnas_en_filas)
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(grid)
		_contenedor_tabs = grid
		custom_minimum_size.y = 78
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		_contenedor_tabs = _contenedor
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_construir_botones()
	seleccionar(categoria_inicial)


func _gui_input(event: InputEvent) -> void:
	if not _es_rueda_vertical(event):
		return
	var scroll_padre := _buscar_scroll_vertical_padre()
	if scroll_padre == null:
		return
	var barra := scroll_padre.get_v_scroll_bar()
	if barra == null:
		return
	var paso := barra.page * 0.18
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
		barra.value = maxf(barra.min_value, barra.value - paso)
	else:
		barra.value = minf(barra.max_value, barra.value + paso)
	accept_event()


func _es_rueda_vertical(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return false
	var boton := (event as InputEventMouseButton).button_index
	return boton == MOUSE_BUTTON_WHEEL_UP or boton == MOUSE_BUTTON_WHEEL_DOWN


func _buscar_scroll_vertical_padre() -> ScrollContainer:
	var nodo := get_parent()
	while nodo != null:
		if nodo is ScrollContainer and nodo != self:
			var scroll := nodo as ScrollContainer
			if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				return scroll
		nodo = nodo.get_parent()
	return null


func seleccionar(scope: String) -> void:
	_scope_activo = scope
	var categorias := LeaderboardScopeCatalog.obtener_categorias_visibles()
	for i in _botones.size():
		if i < categorias.size():
			_botones[i].button_pressed = str(categorias[i].get("scope", "")) == scope


func obtener_scope_activo() -> String:
	return _scope_activo


func _construir_botones() -> void:
	var contenedor := _contenedor_tabs if _contenedor_tabs != null else _contenedor
	if not is_instance_valid(contenedor):
		return
	for categoria in LeaderboardScopeCatalog.obtener_categorias_visibles():
		var scene_tab := TAB_BUTTON_LIGHT_SCENE if tema_claro else TAB_BUTTON_SCENE
		var boton := scene_tab.instantiate() as ScopeTabButton
		if boton == null:
			continue
		var scope_del_boton: String = str(categoria.get("scope", ""))
		var etiqueta := str(categoria.get("etiqueta_tab", categoria.get("etiqueta", "")))
		boton.configurar(etiqueta, scope_del_boton, true)
		boton.pressed.connect(func() -> void: _al_presionar_tab(scope_del_boton))
		contenedor.add_child(boton)
		_botones.append(boton)


func _al_presionar_tab(scope: String) -> void:
	if scope == _scope_activo:
		return
	_scope_activo = scope
	seleccionar(scope)
	scope_cambiado.emit(scope)
