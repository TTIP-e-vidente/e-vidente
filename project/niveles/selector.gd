extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const STREAK_SEAL_SCENE := preload("res://interface/components/StreakDailySeal.tscn")
const STREAK_BADGE_SCENE := preload("res://interface/components/StreakBadge.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_DURATION := 0.15

@onready var background_music: AudioStreamPlayer2D = $Background
@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

@onready var celiaquia: TextureButton = $MenuBar/Celiaquia
@onready var veganismo: TextureButton = $MenuBar/Veganismo
@onready var vegan_gf: TextureButton = $"MenuBar/Vegan-GF"
@onready var cetogenica: TextureButton = $MenuBar/Cetogenica
@onready var diabetes: TextureButton = $MenuBar/Diabetes
@onready var autismo: TextureButton = $MenuBar/Autismo

@onready var buttons := [
	celiaquia,
	veganismo,
	vegan_gf,
	cetogenica,
	diabetes,
	autismo
]

var _profile_overlay: Control
var _profile_toggle_btn: Button
var _close_profile_btn: Button
var _avatar_label: Label
var _username_label: Label
var _email_label: Label
var _age_label: Label
var _progress_label: Label
var _profile_streak_badge: Node
var _save_status_label: Label
var _resume_hint_label: Label
var _resume_btn: Button
var _guardar_btn: Button
var _session_panel: PanelContainer
var _overlay_backdrop: ColorRect
var _button_base_scales: Dictionary = {}
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	_play_background_music()
	_set_resume_overlay_visible(false)
	_build_hud()

	_set_button_enabled(diabetes, false)
	_set_button_enabled(autismo, false)

	for b in buttons:
		if b.material:
			b.material = b.material.duplicate()
		_button_base_scales[b] = b.scale
		b.mouse_entered.connect(_on_button_hover.bind(b, true))
		b.mouse_exited.connect(_on_button_hover.bind(b, false))


func _set_resume_overlay_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible


func _on_celiaquia_pressed() -> void:
	_bounce_button(celiaquia)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_map(get_tree())


func _on_veganismo_pressed() -> void:
	_bounce_button(veganismo)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "veganismo")


func _on_vegan_gf_pressed() -> void:
	_bounce_button(vegan_gf)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "veganismo_celiaquia")


func _on_cetogenica_pressed() -> void:
	_bounce_button(cetogenica)
	await get_tree().create_timer(0.15).timeout
	GameSceneRouter.go_to_track_book(get_tree(), "cetogenica")


func _on_diabetes_pressed() -> void:
	_bounce_button(diabetes)
	await get_tree().create_timer(0.15).timeout
	# hacer que vaya al mapa de diabetes


func _on_autismo_pressed() -> void:
	_bounce_button(autismo)
	await get_tree().create_timer(0.15).timeout
	# hacer que vaya al mapa de autismo


func _on_continue_pressed() -> void:
	_resume_current_save()


func _on_play_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_resume_overlay_visible(false)


func _on_play_close_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_mode_pressed() -> void:
	_set_resume_overlay_visible(false)


func _set_button_enabled(button: BaseButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(5, 5, 5, 1)


func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _play_background_music() -> void:
	background_music.play()


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null


# --- Hover scale animation ---

func _on_button_hover(button: TextureButton, entered: bool) -> void:
	if button.disabled:
		return
	var base_scale: Vector2 = _button_base_scales.get(button, button.scale)
	var target: Vector2 = base_scale * HOVER_SCALE if entered else base_scale
	if _hover_tweens.has(button) and is_instance_valid(_hover_tweens[button]):
		_hover_tweens[button].kill()
	var tw := create_tween()
	tw.tween_property(button, "scale", target, HOVER_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tweens[button] = tw


# --- HUD (streak + profile button) ---

func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)

	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	var streak_seal := STREAK_SEAL_SCENE.instantiate() as Control
	if streak_seal != null:
		streak_seal.anchor_left = 0.0
		streak_seal.anchor_top = 0.0
		streak_seal.anchor_right = 0.0
		streak_seal.anchor_bottom = 0.0
		streak_seal.offset_left = 16.0
		streak_seal.offset_top = 16.0
		streak_seal.offset_right = 152.0
		streak_seal.offset_bottom = 152.0
		hud_root.add_child(streak_seal)

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
	_profile_toggle_btn.tooltip_text = "Mi progreso"
	_profile_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_toggle_btn.pressed.connect(_on_profile_toggle_pressed)
	hud_root.add_child(_profile_toggle_btn)

	_build_profile_overlay(hud_root)


# --- Profile overlay (improved design) ---

func _build_profile_overlay(parent: Control) -> void:
	_profile_overlay = Control.new()
	_profile_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_profile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_overlay.visible = false
	parent.add_child(_profile_overlay)

	# Backdrop (starts transparent for fade-in)
	_overlay_backdrop = ColorRect.new()
	_overlay_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_backdrop.color = Color(0.04, 0.05, 0.04, 0.0)
	_overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_backdrop.gui_input.connect(_on_overlay_backdrop_input)
	_profile_overlay.add_child(_overlay_backdrop)

	# Right-side panel (~490px, anchored right, starts off-screen for slide-in)
	_session_panel = PanelContainer.new()
	_session_panel.anchor_left = 1.0
	_session_panel.anchor_top = 0.0
	_session_panel.anchor_right = 1.0
	_session_panel.anchor_bottom = 1.0
	_session_panel.offset_left = -490.0
	_session_panel.offset_top = 12.0
	_session_panel.offset_right = -16.0
	_session_panel.offset_bottom = -12.0
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.995, 0.992, 0.985, 1.0)
	panel_sb.corner_radius_top_left = 28
	panel_sb.corner_radius_top_right = 28
	panel_sb.corner_radius_bottom_left = 28
	panel_sb.corner_radius_bottom_right = 28
	panel_sb.shadow_color = Color(0, 0, 0, 0.12)
	panel_sb.shadow_size = 32
	panel_sb.shadow_offset = Vector2(-4, 2)
	_session_panel.add_theme_stylebox_override("panel", panel_sb)
	_profile_overlay.add_child(_session_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_session_panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# --- Header row: chips + close ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	var active_chip := _make_chip("Perfil activo", Color(0.31, 0.373, 0.267, 1.0), Color.WHITE)
	header_row.add_child(active_chip)

	var save_chip := _make_chip("Guardado local", Color(0.204, 0.247, 0.173, 0.10), Color(0.18, 0.165, 0.122, 0.82))
	header_row.add_child(save_chip)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	_close_profile_btn = Button.new()
	_close_profile_btn.text = "✕"
	_close_profile_btn.flat = true
	_close_profile_btn.custom_minimum_size = Vector2(36, 36)
	_close_profile_btn.add_theme_font_size_override("font_size", 22)
	_close_profile_btn.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.45))
	_close_profile_btn.add_theme_color_override("font_hover_color", Color(0.278, 0.251, 0.184, 0.85))
	_close_profile_btn.pressed.connect(_close_profile_overlay)
	header_row.add_child(_close_profile_btn)

	# --- Title ---
	var title := Label.new()
	title.text = "Mi progreso"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1.0))
	vbox.add_child(title)

	# --- Summary panel (muted bg, avatar + info) ---
	var summary_panel := PanelContainer.new()
	var summary_sb := StyleBoxFlat.new()
	summary_sb.bg_color = Color(0.962, 0.957, 0.937, 1.0)
	summary_sb.corner_radius_top_left = 20
	summary_sb.corner_radius_top_right = 20
	summary_sb.corner_radius_bottom_left = 20
	summary_sb.corner_radius_bottom_right = 20
	summary_sb.border_width_left = 1
	summary_sb.border_width_top = 1
	summary_sb.border_width_right = 1
	summary_sb.border_width_bottom = 1
	summary_sb.border_color = Color(0.204, 0.247, 0.173, 0.08)
	summary_sb.content_margin_left = 20.0
	summary_sb.content_margin_top = 18.0
	summary_sb.content_margin_right = 20.0
	summary_sb.content_margin_bottom = 18.0
	summary_panel.add_theme_stylebox_override("panel", summary_sb)
	vbox.add_child(summary_panel)

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 16)
	summary_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	summary_panel.add_child(summary_row)

	# Avatar circle with initials
	var avatar_container := CenterContainer.new()
	avatar_container.custom_minimum_size = Vector2(56, 56)
	summary_row.add_child(avatar_container)

	var avatar_bg := PanelContainer.new()
	avatar_bg.custom_minimum_size = Vector2(56, 56)
	var avatar_sb := StyleBoxFlat.new()
	avatar_sb.bg_color = Color(0.31, 0.373, 0.267, 0.85)
	avatar_sb.corner_radius_top_left = 28
	avatar_sb.corner_radius_top_right = 28
	avatar_sb.corner_radius_bottom_left = 28
	avatar_sb.corner_radius_bottom_right = 28
	avatar_bg.add_theme_stylebox_override("panel", avatar_sb)
	avatar_container.add_child(avatar_bg)

	var avatar_center := CenterContainer.new()
	avatar_bg.add_child(avatar_center)

	_avatar_label = Label.new()
	_avatar_label.text = "?"
	_avatar_label.add_theme_font_size_override("font_size", 22)
	_avatar_label.add_theme_color_override("font_color", Color.WHITE)
	_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_center.add_child(_avatar_label)

	# Info column
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 3)
	summary_row.add_child(info_col)

	_username_label = Label.new()
	_username_label.add_theme_font_size_override("font_size", 17)
	_username_label.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1.0))
	info_col.add_child(_username_label)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 10)
	info_col.add_child(meta_row)

	_email_label = Label.new()
	_email_label.add_theme_font_size_override("font_size", 12)
	_email_label.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.58))
	meta_row.add_child(_email_label)

	_age_label = Label.new()
	_age_label.add_theme_font_size_override("font_size", 12)
	_age_label.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.58))
	meta_row.add_child(_age_label)

	# Separator line
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	info_col.add_child(sep)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.78))
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_progress_label)

	# Streak badge component
	_profile_streak_badge = STREAK_BADGE_SCENE.instantiate()
	vbox.add_child(_profile_streak_badge)

	# --- Status row (save + resume cards) ---
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	vbox.add_child(status_row)

	# Save card
	var save_card := _make_status_card()
	status_row.add_child(save_card)

	var save_vbox := VBoxContainer.new()
	save_vbox.add_theme_constant_override("separation", 4)
	save_card.add_child(save_vbox)

	var save_title := Label.new()
	save_title.text = "Guardado"
	save_title.add_theme_font_size_override("font_size", 12)
	save_title.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.5))
	save_vbox.add_child(save_title)

	_save_status_label = Label.new()
	_save_status_label.add_theme_font_size_override("font_size", 14)
	_save_status_label.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1.0))
	_save_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_vbox.add_child(_save_status_label)

	# Resume card
	var resume_card := _make_status_card()
	status_row.add_child(resume_card)

	var resume_vbox := VBoxContainer.new()
	resume_vbox.add_theme_constant_override("separation", 6)
	resume_card.add_child(resume_vbox)

	_resume_hint_label = Label.new()
	_resume_hint_label.add_theme_font_size_override("font_size", 12)
	_resume_hint_label.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.5))
	resume_vbox.add_child(_resume_hint_label)

	_resume_btn = _make_action_button("Continuar", Color(0.31, 0.373, 0.267, 1.0), Color.WHITE, 14, 12)
	_resume_btn.custom_minimum_size = Vector2(0, 34)
	_resume_btn.pressed.connect(_on_overlay_resume_pressed)
	resume_vbox.add_child(_resume_btn)

	# --- Actions row: Guardar ahora + Editar perfil ---
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 12)
	vbox.add_child(actions_row)

	_guardar_btn = _make_action_button("Guardar ahora", Color(0.31, 0.373, 0.267, 1.0), Color.WHITE, 15, 18)
	_guardar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guardar_btn.custom_minimum_size = Vector2(0, 46)
	_guardar_btn.pressed.connect(_on_overlay_guardar_pressed)
	actions_row.add_child(_guardar_btn)

	var edit_btn := _make_action_button("Editar perfil", Color(1, 1, 1, 0.92), Color(0.14, 0.13, 0.09, 1.0), 15, 18)
	edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_btn.custom_minimum_size = Vector2(0, 46)
	# Add border to edit button
	var edit_normal: StyleBoxFlat = edit_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if edit_normal:
		edit_normal.border_width_left = 2
		edit_normal.border_width_top = 2
		edit_normal.border_width_right = 2
		edit_normal.border_width_bottom = 2
		edit_normal.border_color = Color(0.204, 0.247, 0.173, 0.12)
	edit_btn.pressed.connect(_on_overlay_edit_profile_pressed)
	actions_row.add_child(edit_btn)

	# --- Secondary: Reiniciar progreso ---
	var secondary_row := HBoxContainer.new()
	secondary_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(secondary_row)

	var reset_btn := Button.new()
	reset_btn.text = "Reiniciar progreso"
	reset_btn.flat = true
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.add_theme_color_override("font_color", Color(0.72, 0.20, 0.15, 0.7))
	reset_btn.add_theme_color_override("font_hover_color", Color(0.72, 0.20, 0.15, 1.0))
	reset_btn.pressed.connect(_on_overlay_reset_pressed)
	secondary_row.add_child(reset_btn)


func _make_chip(text: String, bg_color: Color, font_color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = bg_color
	chip_sb.corner_radius_top_left = 10
	chip_sb.corner_radius_top_right = 10
	chip_sb.corner_radius_bottom_left = 10
	chip_sb.corner_radius_bottom_right = 10
	chip_sb.content_margin_left = 10.0
	chip_sb.content_margin_top = 4.0
	chip_sb.content_margin_right = 10.0
	chip_sb.content_margin_bottom = 4.0
	chip.add_theme_stylebox_override("panel", chip_sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", font_color)
	chip.add_child(lbl)
	return chip


func _make_status_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.975, 0.972, 0.960, 1.0)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.204, 0.247, 0.173, 0.10)
	sb.shadow_color = Color(0.08, 0.07, 0.04, 0.06)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 16.0
	sb.content_margin_top = 14.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", sb)
	return card


func _make_action_button(text: String, bg_color: Color, font_color: Color, font_size: int, radius: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", font_color)
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = bg_color
	normal_sb.corner_radius_top_left = radius
	normal_sb.corner_radius_top_right = radius
	normal_sb.corner_radius_bottom_left = radius
	normal_sb.corner_radius_bottom_right = radius
	normal_sb.content_margin_left = 16.0
	normal_sb.content_margin_top = 10.0
	normal_sb.content_margin_right = 16.0
	normal_sb.content_margin_bottom = 10.0
	btn.add_theme_stylebox_override("normal", normal_sb)
	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = bg_color.darkened(0.08)
	btn.add_theme_stylebox_override("hover", hover_sb)
	var pressed_sb := normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	return btn


func _format_save_status(state: String) -> String:
	match state:
		"error":
			return "Error al guardar"
		"dirty":
			return "Cambios sin guardar"
		"saved":
			return "Guardado recientemente"
		_:
			return "Sin datos"


func _refresh_profile_overlay() -> void:
	var profile: Dictionary = SaveManager.get_current_user_profile()
	var save_status: Dictionary = SaveManager.get_save_status()

	var username: String = str(
		profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)
	).strip_edges()
	if username.is_empty():
		username = SaveManager.DEFAULT_PROFILE_NAME
	_username_label.text = username

	# Avatar initials (first letter of each word, max 2)
	var parts := username.split(" ", false)
	var initials := ""
	for i in mini(parts.size(), 2):
		if not parts[i].is_empty():
			initials += parts[i][0].to_upper()
	_avatar_label.text = initials if not initials.is_empty() else "?"

	var email: String = str(profile.get("email", "")).strip_edges()
	_email_label.text = email if not email.is_empty() else "Sin correo"

	var age: String = str(profile.get("age", "")).strip_edges()
	_age_label.text = ("Edad: " + age) if not age.is_empty() else ""

	var summary_text := Global.format_progress_summary_text(
		Global.get_progress_summary()
	).strip_edges()
	_progress_label.text = (
		summary_text
		if not summary_text.is_empty()
		else "Todavia no hay capitulos completos"
	)

	# Refresh streak badge component if it has a refresh method
	if _profile_streak_badge.has_method("refresh"):
		_profile_streak_badge.call("refresh")

	var state: String = str(save_status.get("state", "idle")).strip_edges()
	_save_status_label.text = _format_save_status(state)

	# Resume hint
	var can_resume: bool = SaveManager.can_resume_current_save()
	if can_resume:
		_resume_hint_label.text = "Continuar partida"
	else:
		_resume_hint_label.text = "Sin partida activa"
	_resume_btn.visible = can_resume
	_resume_btn.disabled = not can_resume


func _on_profile_toggle_pressed() -> void:
	_refresh_profile_overlay()
	_profile_overlay.visible = true
	_profile_toggle_btn.visible = false

	# Slide-in from right + backdrop fade
	var panel_target_x := _session_panel.offset_left
	_session_panel.offset_left = panel_target_x + 120.0
	_session_panel.offset_right = _session_panel.offset_right + 120.0
	_session_panel.modulate.a = 0.0
	_overlay_backdrop.color.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay_backdrop, "color:a", 0.38, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_session_panel, "offset_left", panel_target_x, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_session_panel, "offset_right", -16.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_session_panel, "modulate:a", 1.0, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _close_profile_overlay() -> void:
	_profile_toggle_btn.visible = true

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay_backdrop, "color:a", 0.0, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_session_panel, "offset_left", _session_panel.offset_left + 80.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_session_panel, "offset_right", _session_panel.offset_right + 80.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_session_panel, "modulate:a", 0.0, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		_profile_overlay.visible = false
		_session_panel.offset_left = -490.0
		_session_panel.offset_right = -16.0
		_session_panel.modulate.a = 1.0
	)


func _on_overlay_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_profile_overlay()


func _on_overlay_resume_pressed() -> void:
	_close_profile_overlay()
	_resume_current_save()


func _on_overlay_edit_profile_pressed() -> void:
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, RESUME_FALLBACK_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_guardar_pressed() -> void:
	SaveManager.save_progress_to_disk()
	_refresh_profile_overlay()


func _on_overlay_reset_pressed() -> void:
	SaveManager.reset_all_progress()
	_refresh_profile_overlay()


func _open_archivero() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _open_questions_mode() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _quit_game() -> void:
	get_tree().quit()


func _resume_current_save() -> void:
	if not SaveManager.can_resume_current_save():
		_set_resume_overlay_visible(false)
		return
	var resume_state := SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _bounce_button(button: Control) -> void:
	var original_pos := button.position
	var tween := create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(0, 4), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position", original_pos, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()

	for b in buttons:
		var btn := b as TextureButton
		var mat := btn.material as ShaderMaterial
		if mat:
			var rect: Rect2 = btn.get_global_rect()
			var uv: Vector2 = (mouse - rect.position) / rect.size
			uv.x = clamp(uv.x, 0.0, 1.0)
			uv.y = clamp(uv.y, 0.0, 1.0)
			var center: Vector2 = rect.position + rect.size / 2
			var dist := mouse.distance_to(center)
			if dist < 200:
				mat.set_shader_parameter("mouse_pos", uv)
			else:
				mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))
