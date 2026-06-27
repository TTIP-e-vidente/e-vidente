extends RefCounted
class_name MailVerifyNudgeHelper

const SCENE_PATH := "res://interface/auth/MailVerifyNudge.tscn"


static func instalar_en(padre: Node, al_verificar_ahora: Callable) -> CanvasLayer:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var nudge: CanvasLayer = scene.instantiate() as CanvasLayer
	if nudge == null:
		return null
	padre.add_child(nudge)
	if nudge.has_signal("verificar_ahora_solicitado") and al_verificar_ahora.is_valid():
		nudge.verificar_ahora_solicitado.connect(al_verificar_ahora)
	return nudge


static func refrescar(nudge: CanvasLayer, ocultar: bool = false) -> void:
	if not is_instance_valid(nudge):
		return
	if ocultar:
		nudge.visible = false
		return
	if nudge.has_method("refrescar"):
		nudge.refrescar()
