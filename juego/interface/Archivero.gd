extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"

# Root scene nodes
var reestablecer_progreso_dialog: ConfirmationDialog
var mode_selection_streak_badge: Node

# Profile overlay panel and its controls
var profile_overlay: Control
var profile_toggle_button: Button
var close_profile_button: Button
var profile_summary_panel: PanelContainer
var profile_history_panel: PanelContainer
var history_toggle_button: Button
var reestablecer_progreso_button: Button
