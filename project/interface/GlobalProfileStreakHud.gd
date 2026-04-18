extends CanvasLayer

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const STREAK_SEAL_SCENE := preload("res://interface/components/StreakDailySeal.tscn")
const STREAK_BADGE_SCENE := preload("res://interface/components/StreakBadge.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const PROFILE_EDITOR_SCENE_PATH := "res://interface/auth.tscn"
const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const INTRO_SCENE_PATH := "res://niveles/intro.tscn"
const SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"

var _hud_root: Control
var _streak_seal: Control
var _profile_button: Button
var _last_scene_path := ""

# Profile overlay nodes
var _profile_overlay: Control
var _overlay_backdrop: ColorRect
var _session_panel: PanelContainer
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


func _ready() -> void:
	layer = 75
	_build_hud()
	_build_profile_overlay()
	_connect_save_manager_signals()
	get_tree().node_added.connect(_on_tree_node_added)
	_refresh_hud()


func _exit_tree() -> void:
	_disconnect_save_manager_signals()
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)


func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "GlobalProfileStreakHudRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_streak_seal = STREAK_SEAL_SCENE.instantiate() as Control
	if _streak_seal != null:
		_streak_seal.name = "GlobalStreakDailySeal"
		_streak_seal.anchor_left = 1.0
		_streak_seal.anchor_top = 0.0
		_streak_seal.anchor_right = 1.0
		_streak_seal.anchor_bottom = 0.0
		_streak_seal.offset_left = -152.0
		_streak_seal.offset_top = 16.0
		_streak_seal.offset_right = -16.0
		_streak_seal.offset_bottom = 152.0
		_hud_root.add_child(_streak_seal)

	_profile_button = Button.new()
	_profile_button.name = "GlobalProfileButton"
	_profile_button.script = PROFILE_BUTTON_SCRIPT
	_profile_button.anchor_left = 1.0
	_profile_button.anchor_top = 1.0
	_profile_button.anchor_right = 1.0
	_profile_button.anchor_bottom = 1.0
	_profile_button.offset_left = -256.0
	_profile_button.offset_top = -84.0
	_profile_button.offset_right = -16.0
	_profile_button.offset_bottom = -16.0
	_profile_button.tooltip_text = "Mi progreso"
	_profile_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_button.pressed.connect(_on_profile_button_pressed)
	_hud_root.add_child(_profile_button)


func _build_profile_overlay() -> void:
	_profile_overlay = Control.new()
	_profile_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_profile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_overlay.visible = false
	add_child(_profile_overlay)

	_overlay_backdrop = ColorRect.new()
	_overlay_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_backdrop.color = Color(0.04, 0.05, 0.04, 0.0)
	_overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_backdrop.gui_input.connect(_on_overlay_backdrop_input)
	_profile_overlay.add_child(_overlay_backdrop)

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

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	header_row.add_child(_make_chip("Perfil activo", Color(0.31, 0.373, 0.267, 1.0), Color.WHITE))
	header_row.add_child(_make_chip("Guardado local", Color(0.204, 0.247, 0.173, 0.10), Color(0.18, 0.165, 0.122, 0.82)))

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

	# Title
	var title := Label.new()
	title.text = "Mi progreso"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1.0))
	vbox.add_child(title)

	# Summary panel (avatar + info)
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
	summary_panel.add_child(summary_row)

	# Avatar circle
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

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	info_col.add_child(sep)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.78))
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_progress_label)

	# Streak badge
	_profile_streak_badge = STREAK_BADGE_SCENE.instantiate()
	vbox.add_child(_profile_streak_badge)

	# Status row (save + resume)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	vbox.add_child(status_row)

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

	# Actions row
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
	var edit_normal: StyleBoxFlat = edit_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if edit_normal:
		edit_normal.border_width_left = 2
		edit_normal.border_width_top = 2
		edit_normal.border_width_right = 2
		edit_normal.border_width_bottom = 2
		edit_normal.border_color = Color(0.204, 0.247, 0.173, 0.12)
	edit_btn.pressed.connect(_on_overlay_edit_profile_pressed)
	actions_row.add_child(edit_btn)

	# Reset row
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


func _connect_save_manager_signals() -> void:
	if SaveManager == null:
		return
	if not SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.connect(_on_save_manager_changed)
	if not SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.connect(_on_save_manager_profile_changed)
	if not SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.connect(_on_save_manager_profile_changed)
	if not SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.connect(_on_save_manager_profile_changed)


func _disconnect_save_manager_signals() -> void:
	if SaveManager == null:
		return
	if SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.disconnect(_on_save_manager_changed)
	if SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.disconnect(_on_save_manager_profile_changed)
	if SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.disconnect(_on_save_manager_profile_changed)
	if SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.disconnect(_on_save_manager_profile_changed)


func _on_tree_node_added(_node: Node) -> void:
	call_deferred("_refresh_hud")


func _on_save_manager_changed(_status: Dictionary) -> void:
	_refresh_hud()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	var scene_path := _get_current_scene_path()
	if scene_path != _last_scene_path:
		_last_scene_path = scene_path
		_apply_scene_visibility(scene_path)
		# Close overlay when scene changes
		if _profile_overlay != null and _profile_overlay.visible:
			_profile_overlay.visible = false
			_profile_button.visible = true
	if _streak_seal != null and _streak_seal.has_method("render"):
		_streak_seal.call("render")


func _apply_scene_visibility(scene_path: String) -> void:
	var hidden_scenes := [
		ARCHIVERO_SCENE_PATH,
		PROFILE_EDITOR_SCENE_PATH,
		SPLASH_SCENE_PATH,
		INTRO_SCENE_PATH,
		SELECTOR_SCENE_PATH,
	]
	var is_level_scene := scene_path.begins_with("res://niveles/nivel_")
	_hud_root.visible = not hidden_scenes.has(scene_path) and not is_level_scene


# --- Profile overlay logic ---

func _on_profile_button_pressed() -> void:
	_refresh_profile_overlay()
	_profile_overlay.visible = true
	_profile_button.visible = false

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
	_profile_button.visible = true
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


func _refresh_profile_overlay() -> void:
	var profile: Dictionary = SaveManager.get_current_user_profile()
	var save_status: Dictionary = SaveManager.get_save_status()

	var username: String = str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)).strip_edges()
	if username.is_empty():
		username = SaveManager.DEFAULT_PROFILE_NAME
	_username_label.text = username

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

	var summary_text := Global.format_progress_summary_text(Global.get_progress_summary()).strip_edges()
	_progress_label.text = summary_text if not summary_text.is_empty() else "Todavia no hay capitulos completos"

	if _profile_streak_badge.has_method("refresh"):
		_profile_streak_badge.call("refresh")

	var state: String = str(save_status.get("state", "idle")).strip_edges()
	_save_status_label.text = _format_save_status(state)

	var can_resume: bool = SaveManager.can_resume_current_save()
	_resume_hint_label.text = "Continuar partida" if can_resume else "Sin partida activa"
	_resume_btn.visible = can_resume
	_resume_btn.disabled = not can_resume


func _on_overlay_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_profile_overlay()


func _on_overlay_resume_pressed() -> void:
	_close_profile_overlay()
	if not SaveManager.can_resume_current_save():
		return
	var resume_state := SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _on_overlay_edit_profile_pressed() -> void:
	SaveManager.save_progress_to_disk()
	var current_scene_path := _get_current_scene_path()
	if current_scene_path.is_empty():
		current_scene_path = RESUME_FALLBACK_SCENE
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, current_scene_path)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_guardar_pressed() -> void:
	SaveManager.save_progress_to_disk()
	_refresh_profile_overlay()


func _on_overlay_reset_pressed() -> void:
	SaveManager.reset_all_progress()
	_refresh_profile_overlay()


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


func _get_current_scene_path() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return ""
	return str(get_tree().current_scene.scene_file_path).strip_edges()
