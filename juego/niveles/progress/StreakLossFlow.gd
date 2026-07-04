extends RefCounted
class_name StreakLossFlow

const StreakLossMessagePanelScene := preload(
	"res://interface/components/StreakLossMessagePanel.tscn"
)

const OVERLAY_LAYER := 15


static func mostrar_si_corresponde(host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	if SaveManager == null or not SaveManager.has_method("evaluar_perdida_racha_pendiente"):
		return

	var resultado: Dictionary = SaveManager.evaluar_perdida_racha_pendiente()
	if not bool(resultado.get("should_show", false)):
		return

	var feedback: Variant = resultado.get("feedback", {})
	if not feedback is Dictionary or (feedback as Dictionary).is_empty():
		return

	await presentar_feedback(host, feedback as Dictionary)

	# Recien aca, con el panel ya mostrado y cerrado por el jugador, se marca
	# como notificado. Si se marcara antes de este punto, un corte de escena
	# a mitad de camino perderia el aviso para siempre sin que nadie lo viera.
	var notify_day: String = str(resultado.get("notify_day", "")).strip_edges()
	if not notify_day.is_empty() and SaveManager.has_method("marcar_perdida_racha_notificada"):
		SaveManager.marcar_perdida_racha_notificada(notify_day)


static func presentar_feedback(host: Node, feedback: Dictionary) -> void:
	if host == null or not is_instance_valid(host) or feedback.is_empty():
		return
	await _presentar_panel(host, feedback)


static func _presentar_panel(host: Node, feedback: Dictionary) -> void:
	var panel: StreakLossMessagePanel = (
		StreakLossMessagePanelScene.instantiate() as StreakLossMessagePanel
	)
	if panel == null:
		push_error("StreakLossFlow: no se pudo instanciar StreakLossMessagePanel.tscn")
		return

	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = OVERLAY_LAYER
	host.add_child(overlay_layer)
	overlay_layer.add_child(panel)
	panel.mostrar(feedback)
	await panel.continue_pressed
	overlay_layer.queue_free()
