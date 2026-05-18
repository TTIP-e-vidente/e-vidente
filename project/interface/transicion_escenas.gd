extends CanvasLayer

@onready var animation_player: AnimationPlayer = $ColorRect/AnimationPlayer

var is_transitioning := false

func _ready():
	$ColorRect.visible = false
	
	
func change_scene(target_scene: String):

	$ColorRect.visible = true

	animation_player.play("close")
	await animation_player.animation_finished

	get_tree().change_scene_to_file(target_scene)

	animation_player.play("open")
	await animation_player.animation_finished

	$ColorRect.visible = false
