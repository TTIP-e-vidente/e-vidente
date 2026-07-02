extends RefCounted
class_name StreakReminderNudgeHelper

const SCENE_PATH := "res://interface/auth/StreakReminderNudge.tscn"


static func instalar_en(padre: Node, al_accion: Callable) -> CanvasLayer:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var nudge: CanvasLayer = scene.instantiate() as CanvasLayer
	if nudge == null:
		return null
	padre.add_child(nudge)
	if nudge.has_signal("accion_solicitada") and al_accion.is_valid():
		nudge.accion_solicitada.connect(al_accion)
	return nudge


static func refrescar(nudge: CanvasLayer, ocultar: bool = false) -> void:
	if not is_instance_valid(nudge):
		return
	if ocultar:
		nudge.visible = false
		return
	if nudge.has_method("refrescar"):
		nudge.refrescar()
