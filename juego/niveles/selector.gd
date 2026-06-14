extends Node2D
class_name ModeSelector

const RACHA_SCENE_PATH := "res://interface/components/Racha.tscn"
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const PROFILE_OVERLAY_SCENE_PATH := "res://interface/components/ProfileOverlayPanel.tscn"

const AUTISMO_SELECTOR_PATH := "res://assets-sistema/selector/autismo-selector.png"
const CANDADO_SELECTOR_PATH := "res://assets-sistema/selector/candado-selector.png"
const CELIAQUIA_SELECTOR_PATH := "res://assets-sistema/selector/celiaquia-selector.png"
const DIABETES_SELECTOR_PATH := "res://assets-sistema/selector/diabetes-selector.png"
const KETO_SELECTOR_PATH := "res://assets-sistema/selector/keto-selector.png"
const VEGAN_GF_SELECTOR_PATH := "res://assets-sistema/selector/vegan-gf-selector.png"
const VEGAN_SELECTOR_PATH := "res://assets-sistema/selector/vegan-selector.png"

const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const MUSICA_FONDO_PREDETERMINADA := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

@onready var celiaquia_i: Sprite2D = $"MenuBar/VBoxContainer/HBoxContainer/Celiaquia/imagen-restriccion"
@onready var veganismo_i: Sprite2D = $"MenuBar/VBoxContainer/HBoxContainer/Veganismo/imagen-restriccion"
@onready var vegan_gf_i: Sprite2D = $"MenuBar/VBoxContainer/HBoxContainer/Vegan-GF/imagen-restriccion"
@onready var cetogenica_i: Sprite2D = $"MenuBar/VBoxContainer/HBoxContainer2/Cetogenica/imagen-restriccion"
@onready var diabetes_i: Sprite2D = $"MenuBar/VBoxContainer/HBoxContainer2/Diabetes/imagen-restriccion"
@onready var autismo_i: Sprite2D = $"MenuBar/VBoxContainer/HBoxContainer2/Autismo/imagen-restriccion"

@onready var celiaquia: Label = $MenuBar/VBoxContainer/HBoxContainer/Celiaquia/Label
@onready var veganismo: Label = $MenuBar/VBoxContainer/HBoxContainer/Veganismo/Label
@onready var vegan_gf: Label = $"MenuBar/VBoxContainer/HBoxContainer/Vegan-GF/Label"
@onready var cetogenica: Label = $MenuBar/VBoxContainer/HBoxContainer2/Cetogenica/Label
@onready var diabetes: Label = $MenuBar/VBoxContainer/HBoxContainer2/Diabetes/Label
@onready var autismo: Label = $MenuBar/VBoxContainer/HBoxContainer2/Autismo/Label

@onready var diabetesB: TextureButton = $MenuBar/VBoxContainer/HBoxContainer2/Diabetes
@onready var autismoB: TextureButton = $MenuBar/VBoxContainer/HBoxContainer2/Autismo

const DESTINO_MAPA := "mapa"
const DESTINO_PISTA := "pista"

const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_DURATION := 0.15
const BUTTON_BOUNCE_OFFSET := Vector2(0, 4)
const BUTTON_BOUNCE_DOWN_DURATION := 0.05
const BUTTON_BOUNCE_UP_DURATION := 0.08
const BUTTON_NAVIGATION_DELAY := 0.15

const TRACK_VEGANISMO := "veganismo"
const TRACK_VEGANISMO_CELIAQUIA := "veganismo_celiaquia"
const TRACK_CETOGENICA := "cetogenica"

@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

@onready var btn_atras: Button = $"Atrás"


var _profile_overlay: ProfileOverlayPanel
var _profile_toggle_btn: Button
var _racha_badge: Control


func _ready() -> void:
	celiaquia.text = "Celiaquía"
	veganismo.text = "Veganismo"
	vegan_gf.text = "Vegan-gf"
	cetogenica.text = "Keto"
	diabetes.text = "Diabetes"
	autismo.text = "Autismo"
	celiaquia_i.texture = load(CELIAQUIA_SELECTOR_PATH) as Texture2D
	veganismo_i.texture = load(VEGAN_SELECTOR_PATH) as Texture2D
	vegan_gf_i.texture = load(VEGAN_GF_SELECTOR_PATH) as Texture2D
	cetogenica_i.texture = load(KETO_SELECTOR_PATH) as Texture2D
	diabetes_i.texture = load(CANDADO_SELECTOR_PATH) as Texture2D
	autismo_i.texture = load(CANDADO_SELECTOR_PATH) as Texture2D
	
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()
	_establecer_reanudar_superposicion_visible(false)
	_configurar_botones()
	_construir_hud()


func _configurar_botones() -> void:
	_establecer_boton_habilitado(diabetesB, false)
	_establecer_boton_habilitado(autismoB, false)

func _establecer_reanudar_superposicion_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible


func _establecer_boton_habilitado(button: TextureButton, enabled: bool) -> void:
	button.disabled = enabled
	button.modulate = Color(1, 1, 1, 1.0) if enabled else Color(1, 1, 1, 0.4)


# --- Navegación principal -----------------------------------------------------
func _on_celiaquia_pressed() -> void:
	await _abrir_destino_boton(celiaquia, DESTINO_MAPA)


func _on_veganismo_pressed() -> void:
	await _abrir_destino_boton(veganismo, DESTINO_PISTA, TRACK_VEGANISMO)


func _on_vegan_gf_pressed() -> void:
	await _abrir_destino_boton(vegan_gf, DESTINO_PISTA, TRACK_VEGANISMO_CELIAQUIA)


func _on_cetogenica_pressed() -> void:
	await _abrir_destino_boton(cetogenica, DESTINO_PISTA, TRACK_CETOGENICA)


func _on_diabetes_presionado() -> void:
	await _abrir_destino_boton(diabetes, DESTINO_PISTA)


func _on_autismo_presionado() -> void:
	await _abrir_destino_boton(autismo, DESTINO_PISTA)


func _abrir_destino_boton(
	_button: Control,
	destination_type: String,
	track_key: String = ""
) -> void:
	await get_tree().create_timer(BUTTON_NAVIGATION_DELAY).timeout

	match destination_type:
		DESTINO_MAPA:
			GameSceneRouter.ir_al_mapa(get_tree())
		DESTINO_PISTA:
			if track_key.is_empty():
				return
			GameSceneRouter.go_to_track_book(get_tree(), track_key)


func _on_continuar_presionado() -> void:
	_reanudar_actual_guardar()


func _on_reproducir_fondo_gui_entrada(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_establecer_reanudar_superposicion_visible(false)


func _on_reproducir_cerrar_presionado() -> void:
	_establecer_reanudar_superposicion_visible(false)


func _on_modo_presionado() -> void:
	_establecer_reanudar_superposicion_visible(false)


func _on_atras_presionado() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _reanudar_actual_guardar() -> void:
	if not SaveManager.puede_reanudar_guardado_actual():
		_establecer_reanudar_superposicion_visible(false)
		return
	var resume_state: Dictionary = SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.ir_a_reanudar(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


# --- Sonido y animaciones -----------------------------------------------------
func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO_PREDETERMINADA)







# --- HUD ----------------------------------------------------------------------
func _construir_hud() -> void:
	var hud_layer: CanvasLayer = _crear_hud_layer()
	var hud_root: Control = _crear_hud_root(hud_layer)
	_agregar_insignia_racha(hud_root)
	_agregar_boton_perfil(hud_root)
	_agregar_superposicion_perfil(hud_root)
	_conectar_senales_guardado()


func _crear_hud_layer() -> CanvasLayer:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)
	return hud_layer


func _crear_hud_root(hud_layer: CanvasLayer) -> Control:
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)
	return hud_root


func _exit_tree() -> void:
	_desconectar_senales_guardado()


func _conectar_senales_guardado() -> void:
	if SaveManager == null or not SaveManager.has_method("cargar_datos"):
		return
	if not SaveManager.is_connected("progress_loaded", _al_actualizar_racha):
		SaveManager.connect("progress_loaded", _al_actualizar_racha)


func _desconectar_senales_guardado() -> void:
	if SaveManager == null or not SaveManager.has_method("cargar_datos"):
		return
	if SaveManager.is_connected("progress_loaded", _al_actualizar_racha):
		SaveManager.disconnect("progress_loaded", _al_actualizar_racha)


func _al_actualizar_racha(_profile: Dictionary) -> void:
	if _racha_badge != null and _racha_badge.has_method("renderizar"):
		_racha_badge.call("renderizar")


func _agregar_insignia_racha(hud_root: Control) -> void:
	var racha_scene: PackedScene = load(RACHA_SCENE_PATH) as PackedScene
	if racha_scene == null:
		return
	var racha_badge: Control = racha_scene.instantiate() as Control
	if racha_badge == null:
		return

	_racha_badge = racha_badge
	racha_badge.anchor_left = 0.0
	racha_badge.anchor_top = 0.0
	racha_badge.anchor_right = 0.0
	racha_badge.anchor_bottom = 0.0
	racha_badge.offset_left = 16.0
	racha_badge.offset_top = 16.0
	racha_badge.offset_right = 152.0
	racha_badge.offset_bottom = 152.0
	hud_root.add_child(racha_badge)
	_conectar_insignia_racha()


func _agregar_boton_perfil(hud_root: Control) -> void:
	_profile_toggle_btn = Button.new()
	_profile_toggle_btn.script = PROFILE_BUTTON_SCRIPT
	_profile_toggle_btn.anchor_left = 1.0
	_profile_toggle_btn.anchor_top = 0.0
	_profile_toggle_btn.anchor_right = 1.0
	_profile_toggle_btn.anchor_bottom = 0.0
	_profile_toggle_btn.offset_left = -152.0
	_profile_toggle_btn.offset_top = 16.0
	_profile_toggle_btn.offset_right = -16.0
	_profile_toggle_btn.offset_bottom = 84.0
	_profile_toggle_btn.tooltip_text = ""
	_profile_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_toggle_btn.pressed.connect(_on_perfil_alternar_presionado)
	hud_root.add_child(_profile_toggle_btn)


func _agregar_superposicion_perfil(hud_root: Control) -> void:
	var profile_overlay_scene: PackedScene = load(PROFILE_OVERLAY_SCENE_PATH) as PackedScene
	if profile_overlay_scene == null:
		return
	_profile_overlay = profile_overlay_scene.instantiate() as ProfileOverlayPanel
	if _profile_overlay == null:
		return
	hud_root.add_child(_profile_overlay)
	_profile_overlay.resume_pressed.connect(_on_superposicion_reanudar_presionado)
	_profile_overlay.save_pressed.connect(_on_superposicion_guardar_presionado)
	_profile_overlay.edit_profile_pressed.connect(_on_superposicion_edit_perfil_presionado)
	_profile_overlay.reestablecer_progreso_pressed.connect(_on_superposicion_reiniciar_presionado)
	_profile_overlay.logout_pressed.connect(_on_superposicion_logout_presionado)
	_profile_overlay.close_requested.connect(_on_superposicion_cerrar_solicitado)


func _on_perfil_alternar_presionado() -> void:
	_profile_toggle_btn.visible = false
	_profile_overlay.mostrar_superposicion()


func _conectar_insignia_racha() -> void:
	if _racha_badge == null or not _racha_badge.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionado")
	if not _racha_badge.is_connected("pressed", callback):
		_racha_badge.connect("pressed", callback)


func _on_racha_presionado() -> void:
	if _profile_overlay != null:
		_profile_overlay.ocultar_superposicion()
	if _profile_toggle_btn != null:
		_profile_toggle_btn.visible = true
	GameSceneRouter.ir_a_racha(get_tree(), RESUME_FALLBACK_SCENE)


func _on_superposicion_cerrar_solicitado() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.ocultar_superposicion()


func _on_superposicion_reanudar_presionado() -> void:
	_profile_toggle_btn.visible = true
	_profile_overlay.ocultar_superposicion()
	_reanudar_actual_guardar()


func _on_superposicion_edit_perfil_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, RESUME_FALLBACK_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_superposicion_guardar_presionado() -> void:
	_profile_overlay.refrescar()


func _on_superposicion_reiniciar_presionado() -> void:
	var result: Dictionary = await SaveManager.reiniciar_todo_progreso()
	if not result.get("ok", false):
		return
	_profile_overlay.visible = false
	_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_mode_selector(get_tree())


func _on_superposicion_logout_presionado() -> void:
	await AuthApi.cerrar_sesion()
	_profile_overlay.visible = false
	_profile_toggle_btn.visible = true
	GameSceneRouter.go_to_main_menu(get_tree())


func _abrir_archivero() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_modo_preguntas() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _salir_juego() -> void:
	get_tree().quit()
