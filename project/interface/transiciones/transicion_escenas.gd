extends CanvasLayer

@onready var animation_player: AnimationPlayer = $ColorRect/AnimationPlayer
@onready var animation_player_2: AnimationPlayer = $ColorRect2/AnimationPlayer2

var is_transitioning := false

func _ready():
	# ALWAYS: las animaciones de transición deben completarse aunque el árbol esté pausado
	# (por ejemplo, cuando CapituloCompletado llama get_tree().paused = true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	$ColorRect.visible = false
	$ColorRect2.visible = false
	
func change_scene(target_scene: String):

	$ColorRect.visible = true

	animation_player.play("close")
	await animation_player.animation_finished

	get_tree().change_scene_to_file(target_scene)

	animation_player.play("open")
	await animation_player.animation_finished

	$ColorRect.visible = false

func change_normal_scene(target_scene: String):
	$ColorRect2.visible = true
	
	animation_player_2.play("close_normal")
	await animation_player_2.animation_finished

	get_tree().change_scene_to_file(target_scene)

	animation_player_2.play("open_normal")
	await animation_player_2.animation_finished

	$ColorRect2.visible = false
