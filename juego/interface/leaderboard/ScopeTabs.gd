class_name ScopeTabs
extends ScrollContainer

# Selector scrolleable de categorías (scopes) del leaderboard.


signal scope_cambiado(scope: String)


const TAB_BUTTON_SCENE := preload("res://interface/leaderboard/ScopeTabButton.tscn")


@export var categoria_inicial: String = "global_xp"


var _scope_activo: String = ""
var _botones: Array[ScopeTabButton] = []


@onready var _contenedor: HBoxContainer = %TabsHBox


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	var categorias := LeaderboardScopeCatalog.obtener_categorias()
	for i in _botones.size():
		if i < categorias.size():
			_botones[i].button_pressed = str(categorias[i].get("scope", "")) == scope


func obtener_scope_activo() -> String:
	return _scope_activo


func _construir_botones() -> void:
	if not is_instance_valid(_contenedor):
		return
	for categoria in LeaderboardScopeCatalog.obtener_categorias():
		var boton := TAB_BUTTON_SCENE.instantiate() as ScopeTabButton
		if boton == null:
			continue
		var scope_del_boton: String = str(categoria.get("scope", ""))
		boton.configurar(str(categoria.get("etiqueta", "")), scope_del_boton)
		boton.pressed.connect(func() -> void: _al_presionar_tab(scope_del_boton))
		_contenedor.add_child(boton)
		_botones.append(boton)


func _al_presionar_tab(scope: String) -> void:
	if scope == _scope_activo:
		return
	_scope_activo = scope
	seleccionar(scope)
	scope_cambiado.emit(scope)
