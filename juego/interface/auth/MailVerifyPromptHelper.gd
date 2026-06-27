extends RefCounted
class_name MailVerifyPromptHelper

const SCENE_PATH := "res://interface/auth/MailVerifyPrompt.tscn"


static func instalar_en(padre: Node, al_verificar: Callable, al_posponer: Callable = Callable()) -> CanvasLayer:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var prompt: CanvasLayer = scene.instantiate() as CanvasLayer
	if prompt == null:
		return null
	padre.add_child(prompt)
	if prompt.has_signal("verificar_solicitado") and al_verificar.is_valid():
		prompt.verificar_solicitado.connect(al_verificar)
	if prompt.has_signal("pospuesto") and al_posponer.is_valid():
		prompt.pospuesto.connect(al_posponer)
	return prompt
