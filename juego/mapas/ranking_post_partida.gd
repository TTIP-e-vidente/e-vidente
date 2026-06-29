extends Node2D

# Escena 2 del flujo post-partida: ranking, preferencia invitado y salida al mapa.


@onready var _titulo: Label = $Titulo
@onready var _subtitulo: Label = $Subtitulo
@onready var _card_ranking: RankingResumenPostPartida = $UiAnchor/RankingContainer/RankingResumenPostPartida
@onready var _continuar_btn: Button = $UiAnchor/Continuar
@onready var _link_iniciar_sesion: LinkButton = $UiAnchor/FooterOpciones/IniciarSesionCompetir
@onready var _checkbox_omitir_ranking: CheckBox = $UiAnchor/FooterOpciones/CheckboxOmitirRanking
@onready var _footer_opciones: VBoxContainer = $UiAnchor/FooterOpciones

var _scope_ranking: String = LeaderboardApi.SCOPE_XP_GLOBAL


func _ready() -> void:
	_actualizar_textos_encabezado()
	_configurar_boton_continuar()
	_configurar_preferencia_ranking()
	_configurar_link_iniciar_sesion()

	if is_instance_valid(_continuar_btn) and not _continuar_btn.pressed.is_connected(continuar_al_mapa):
		_continuar_btn.pressed.connect(continuar_al_mapa)

	call_deferred("_cargar_ranking")


func _actualizar_textos_encabezado() -> void:
	if is_instance_valid(_titulo):
		_titulo.text = LeaderboardFormat.titulo_ranking_post_partida()
	if is_instance_valid(_subtitulo):
		var subtitulo: String = LeaderboardFormat.subtitulo_ranking_post_partida().strip_edges()
		if subtitulo.is_empty() and not AuthApi.esta_logueado():
			subtitulo = LeaderboardFormat.mensaje_progreso_no_suma()
		_subtitulo.text = subtitulo
		_subtitulo.visible = not subtitulo.is_empty()


func _configurar_boton_continuar() -> void:
	if is_instance_valid(_continuar_btn):
		_continuar_btn.text = LeaderboardFormat.texto_saltar_ranking()


func _configurar_preferencia_ranking() -> void:
	if not is_instance_valid(_footer_opciones):
		return
	if AuthApi.esta_logueado():
		_footer_opciones.visible = false
		return
	_footer_opciones.visible = true
	if is_instance_valid(_checkbox_omitir_ranking):
		_checkbox_omitir_ranking.text = LeaderboardFormat.texto_no_volver_a_mostrar_ranking()
		_checkbox_omitir_ranking.button_pressed = SaveManager.omitir_ranking_post_partida_invitado()
		if not _checkbox_omitir_ranking.toggled.is_connected(_al_cambiar_preferencia_omitir_ranking):
			_checkbox_omitir_ranking.toggled.connect(_al_cambiar_preferencia_omitir_ranking)


func _configurar_link_iniciar_sesion() -> void:
	if not is_instance_valid(_link_iniciar_sesion):
		return
	_link_iniciar_sesion.text = LeaderboardFormat.texto_iniciar_sesion_para_competir()
	_link_iniciar_sesion.visible = not AuthApi.esta_logueado()
	if not _link_iniciar_sesion.pressed.is_connected(_al_iniciar_sesion):
		_link_iniciar_sesion.pressed.connect(_al_iniciar_sesion)


func _al_cambiar_preferencia_omitir_ranking(omitir: bool) -> void:
	PostPartidaFlow.persistir_preferencia_omitir_ranking(omitir)


func _cargar_ranking() -> void:
	if not is_instance_valid(_card_ranking):
		return
	_scope_ranking = await PostPartidaFlow.cargar_ranking_en_card(_card_ranking, get_tree())


func _al_iniciar_sesion() -> void:
	var helper := AuthLoginOverlayHelper.new()
	var inicio_ok := await helper.mostrar_y_esperar(self, AuthLoginOverlayHelper.FLUJO_JUEGO)
	if not inicio_ok:
		return
	_actualizar_textos_encabezado()
	_configurar_preferencia_ranking()
	_configurar_link_iniciar_sesion()
	_cargar_ranking()
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)


func continuar_al_mapa() -> void:
	if is_instance_valid(_checkbox_omitir_ranking) and _checkbox_omitir_ranking.visible:
		PostPartidaFlow.persistir_preferencia_omitir_ranking(_checkbox_omitir_ranking.button_pressed)
	PostPartidaFlow.finalizar_flujo_y_ir_al_mapa(get_tree())


func _on_continuar_presionado() -> void:
	continuar_al_mapa()
