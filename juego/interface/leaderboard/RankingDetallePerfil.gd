class_name RankingDetallePerfil
extends PanelContainer

# Sección detallada del ranking embebida en el perfil.


signal ver_tabla_completa_solicitada(scope: String)
signal iniciar_sesion_solicitado


@onready var _label_invitado: Label = %LabelInvitado
@onready var _hub: LeaderboardPosicionesHub = %PosicionesHub
@onready var _pestanias: ScopeTabs = %ScopeTabs
@onready var _card: ProgresoPuestoCard = %ProgresoCard
@onready var _mini_list: LeaderboardMiniList = %MiniList
@onready var _boton_tabla: Button = %BotonTablaCompleta

var _scope_activo: String = LeaderboardApi.SCOPE_XP_GLOBAL
var _esperando_leaderboard: bool = false


func _ready() -> void:
	if is_instance_valid(_hub):
		_hub.scope_presionado.connect(_al_hub_scope_presionado)
	if is_instance_valid(_pestanias):
		_pestanias.scope_cambiado.connect(_al_cambiar_scope)
	if is_instance_valid(_card):
		_card.ver_ranking_solicitado.connect(_al_ver_ranking_desde_card)
		_card.iniciar_sesion_solicitado.connect(func() -> void: iniciar_sesion_solicitado.emit())
	if is_instance_valid(_boton_tabla):
		_boton_tabla.pressed.connect(_al_presionar_tabla_completa)


func cargar(scope: String = "", forzar: bool = false) -> void:
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = LeaderboardOverlayHelper.scope_desde_arbol(get_tree())

	_scope_activo = scope_final
	if is_instance_valid(_pestanias):
		_pestanias.seleccionar(scope_final)

	if not AuthApi.esta_logueado():
		_mostrar_invitado()
		return

	_ocultar_invitado()
	if forzar:
		LeaderboardService.invalidar_cache(scope_final)
	if is_instance_valid(_hub):
		_hub.cargar(forzar)
	await _refrescar_scope(scope_final, forzar)


func _mostrar_invitado() -> void:
	if is_instance_valid(_label_invitado):
		_label_invitado.text = LeaderboardFormat.hint_meta_modo_invitado()
		_label_invitado.visible = true
	if is_instance_valid(_hub):
		_hub.visible = false
	if is_instance_valid(_card):
		_card.mostrar_invitacion_login()
	if is_instance_valid(_boton_tabla):
		_boton_tabla.text = "Abrir tabla completa"
	call_deferred("_cargar_mini_tabla_invitado")


func _ocultar_invitado() -> void:
	if is_instance_valid(_label_invitado):
		_label_invitado.visible = false
	if is_instance_valid(_boton_tabla):
		_boton_tabla.text = "Abrir tabla completa"


func _al_cambiar_scope(scope: String) -> void:
	_scope_activo = scope
	if not AuthApi.esta_logueado():
		if is_instance_valid(_card):
			_card.mostrar_invitacion_login()
		call_deferred("_cargar_mini_tabla_invitado")
		return
	await _refrescar_scope(scope)


func _refrescar_scope(scope: String, forzar: bool = false) -> void:
	if is_instance_valid(_card):
		await _card.cargar_y_mostrar(scope, forzar)

	_cargar_mini_tabla(scope)


func _cargar_mini_tabla(scope: String) -> void:
	if not is_instance_valid(_mini_list):
		return

	var id_propio := str(BackendSession.obtener_usuario_en_cache().get("id", ""))
	var resumen := LeaderboardService.obtener_resumen_desde_cache(scope)
	if not resumen.is_empty() and _mini_list.poblar_desde_nearby(resumen, id_propio, scope):
		return

	var datos := LeaderboardService.obtener_desde_cache(scope)
	if datos.is_empty():
		if not _esperando_leaderboard:
			_esperando_leaderboard = true
			if not LeaderboardService.leaderboard_cargado.is_connected(_al_leaderboard_cargado):
				LeaderboardService.leaderboard_cargado.connect(_al_leaderboard_cargado)
		LeaderboardService.cargar(scope, false)
		return

	_esperando_leaderboard = false
	_poblar_mini_lista(datos)


func _al_leaderboard_cargado(scope: String, datos: Dictionary) -> void:
	if not _esperando_leaderboard:
		return
	if scope.ends_with(":mas"):
		return
	if scope != _scope_activo:
		return
	_esperando_leaderboard = false
	_poblar_mini_lista(datos)


func _poblar_mini_lista(datos: Dictionary) -> void:
	if not is_instance_valid(_mini_list):
		return
	var id_propio := str(BackendSession.obtener_usuario_en_cache().get("id", ""))

	var resumen := LeaderboardService.obtener_resumen_desde_cache(_scope_activo)
	if not resumen.is_empty() and _mini_list.poblar_desde_nearby(resumen, id_propio, _scope_activo):
		return

	_mini_list.poblar(datos, id_propio, 8)


func _al_ver_ranking_desde_card(scope: String) -> void:
	ver_tabla_completa_solicitada.emit(scope)


func _al_presionar_tabla_completa() -> void:
	ver_tabla_completa_solicitada.emit(_scope_activo)


func _al_hub_scope_presionado(scope: String) -> void:
	_scope_activo = scope
	if is_instance_valid(_pestanias):
		_pestanias.seleccionar(scope)
	ver_tabla_completa_solicitada.emit(scope)


func _cargar_mini_tabla_invitado() -> void:
	if AuthApi.esta_logueado() or not is_instance_valid(_mini_list):
		return

	var scope := _scope_activo
	var datos := LeaderboardService.obtener_desde_cache(scope)
	if datos.is_empty():
		if not LeaderboardService.leaderboard_cargado.is_connected(_al_leaderboard_invitado):
			LeaderboardService.leaderboard_cargado.connect(_al_leaderboard_invitado, CONNECT_ONE_SHOT)
		LeaderboardService.cargar(scope, false)
		return

	_mini_list.poblar(datos, "", 8)


func _al_leaderboard_invitado(scope_cargado: String, datos: Dictionary) -> void:
	if scope_cargado.ends_with(":mas"):
		return
	if not is_instance_valid(_mini_list) or AuthApi.esta_logueado():
		return
	if str(datos.get("scope", scope_cargado)) != _scope_activo:
		return
	_mini_list.poblar(datos, "", 8)


func _exit_tree() -> void:
	if LeaderboardService.leaderboard_cargado.is_connected(_al_leaderboard_cargado):
		LeaderboardService.leaderboard_cargado.disconnect(_al_leaderboard_cargado)
