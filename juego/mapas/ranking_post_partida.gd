extends Node2D

# Escena 2 del flujo post-partida: ranking, preferencia invitado y salida al mapa.


@onready var _titulo: Label = $Titulo
@onready var _subtitulo: Label = $Subtitulo
@onready var _card_ranking: RankingResumenPostPartida = $UiAnchor/RankingContainer/RankingResumenPostPartida
@onready var _continuar_label: Label = $Continuar/Label
@onready var _continuar_btn: TextureButton = $Continuar
@onready var _link_iniciar_sesion: LinkButton = $UiAnchor/IniciarSesionCompetir
@onready var _checkbox_omitir_ranking: CheckBox = $UiAnchor/CheckboxOmitirRanking

var _scope_ranking: String = LeaderboardApi.SCOPE_XP_GLOBAL


func _ready() -> void:
	_actualizar_textos_encabezado()
	_configurar_boton_continuar()
	_configurar_preferencia_ranking()
	_configurar_link_iniciar_sesion()
	_aplicar_estilos_panel_inferior()

	if is_instance_valid(_continuar_btn) and not _continuar_btn.pressed.is_connected(continuar_al_mapa):
		_continuar_btn.pressed.connect(continuar_al_mapa)

	if is_instance_valid(_card_ranking):
		_card_ranking.ver_ranking_solicitado.connect(_abrir_leaderboard_completo)
		_card_ranking.iniciar_sesion_solicitado.connect(_al_iniciar_sesion)

	call_deferred("_cargar_ranking")


func _actualizar_textos_encabezado() -> void:
	if is_instance_valid(_titulo):
		_titulo.text = LeaderboardFormat.titulo_ranking_post_partida()
	if is_instance_valid(_subtitulo):
		var subtitulo: String = LeaderboardFormat.subtitulo_ranking_post_partida().strip_edges()
		_subtitulo.text = subtitulo
		_subtitulo.visible = not subtitulo.is_empty()


func _configurar_boton_continuar() -> void:
	if is_instance_valid(_continuar_label):
		_continuar_label.text = LeaderboardFormat.texto_saltar_ranking()


func _configurar_preferencia_ranking() -> void:
	if not is_instance_valid(_checkbox_omitir_ranking):
		return
	if AuthApi.esta_logueado():
		_checkbox_omitir_ranking.visible = false
		return
	_checkbox_omitir_ranking.visible = true
	_checkbox_omitir_ranking.text = LeaderboardFormat.texto_no_volver_a_mostrar_ranking()
	_checkbox_omitir_ranking.button_pressed = SaveManager.omitir_ranking_post_partida_invitado()


func _configurar_link_iniciar_sesion() -> void:
	if not is_instance_valid(_link_iniciar_sesion):
		return
	_link_iniciar_sesion.text = LeaderboardFormat.texto_iniciar_sesion_para_competir()
	_link_iniciar_sesion.visible = not AuthApi.esta_logueado()
	if not _link_iniciar_sesion.pressed.is_connected(_al_iniciar_sesion):
		_link_iniciar_sesion.pressed.connect(_al_iniciar_sesion)


func _aplicar_estilos_panel_inferior() -> void:
	var texto_secundario := Color(0.22, 0.24, 0.27, 1.0)
	var link_normal := MiPaleta.VERDE_BOSQUE
	var link_hover := MiPaleta.HOVER

	if is_instance_valid(_subtitulo):
		_subtitulo.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42, 1))
		_subtitulo.add_theme_font_size_override("font_size", 18)

	if is_instance_valid(_checkbox_omitir_ranking):
		_checkbox_omitir_ranking.add_theme_color_override("font_color", texto_secundario)
		_checkbox_omitir_ranking.add_theme_color_override("font_hover_color", link_normal)
		_checkbox_omitir_ranking.add_theme_font_size_override("font_size", 15)

	if is_instance_valid(_link_iniciar_sesion):
		_link_iniciar_sesion.add_theme_color_override("font_color", link_normal)
		_link_iniciar_sesion.add_theme_color_override("font_hover_color", link_hover)
		_link_iniciar_sesion.add_theme_font_size_override("font_size", 16)


func _cargar_ranking() -> void:
	if not is_instance_valid(_card_ranking):
		return
	_scope_ranking = await PostPartidaFlow.cargar_ranking_en_card(_card_ranking, get_tree())


func _abrir_leaderboard_completo(scope: String = "") -> void:
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = _scope_ranking
	LeaderboardOverlayHelper.abrir(get_tree(), scope_final)


func _al_iniciar_sesion() -> void:
	var helper := AuthLoginOverlayHelper.new()
	var inicio_ok := await helper.mostrar_y_esperar(self, AuthLoginOverlayHelper.FLUJO_JUEGO)
	if not inicio_ok:
		return
	_actualizar_textos_encabezado()
	if is_instance_valid(_link_iniciar_sesion):
		_link_iniciar_sesion.visible = false
	if is_instance_valid(_checkbox_omitir_ranking):
		_checkbox_omitir_ranking.visible = false
	_cargar_ranking()
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)


func continuar_al_mapa() -> void:
	if is_instance_valid(_checkbox_omitir_ranking) and _checkbox_omitir_ranking.visible:
		PostPartidaFlow.persistir_preferencia_omitir_ranking(_checkbox_omitir_ranking.button_pressed)
	PostPartidaFlow.finalizar_flujo_y_ir_al_mapa(get_tree())


func _on_continuar_presionado() -> void:
	continuar_al_mapa()
