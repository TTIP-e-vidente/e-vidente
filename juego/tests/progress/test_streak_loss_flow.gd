extends GdUnitTestSuite
class_name TestStreakLossFlow

const GameStreakTracker := preload("res://niveles/progress/GameStreakTracker.gd")
const StreakLossFlow := preload("res://niveles/progress/StreakLossFlow.gd")
const StreakLossMessagePanelScene := preload(
	"res://interface/components/StreakLossMessagePanel.tscn"
)
const SaveManagerScript := preload("res://interface/SaveManager.gd")
const SaveDataSchemaScript := preload("res://interface/save_local/data/SaveDataSchema.gd")

const PATH_TITLE := "MessagePanel/MarginContainer/VBoxContainer/TitleLabel"
const PATH_STREAK_COUNT := "MessagePanel/MarginContainer/VBoxContainer/StreakCountLabel"
const PATH_DETAIL := "MessagePanel/MarginContainer/VBoxContainer/DetailLabel"
const PATH_BEST := "MessagePanel/MarginContainer/VBoxContainer/BestLabel"
const PATH_CONTINUE := "MessagePanel/MarginContainer/VBoxContainer/ContinueButton"


func test_construir_feedback_perdida_expone_datos_de_ui() -> void:
	var feedback: Dictionary = GameStreakTracker.construir_feedback_perdida(
		4,
		{"best_count": 6}
	)

	assert_str(str(feedback.get("feedback_key", ""))).is_equal("lost")
	assert_int(int(feedback.get("current_count", -1))).is_equal(0)
	assert_int(int(feedback.get("previous_count", 0))).is_equal(4)
	assert_int(int(feedback.get("best_count", 0))).is_equal(6)
	assert_str(str(feedback.get("title", ""))).is_equal("Tu racha se cortó")
	assert_str(str(feedback.get("message", ""))).contains("4")


func test_panel_muestra_titulo_contador_y_mejor_racha() -> void:
	var panel: StreakLossMessagePanel = (
		StreakLossMessagePanelScene.instantiate() as StreakLossMessagePanel
	)
	assert_object(panel).is_not_null()
	add_child(panel)
	await get_tree().process_frame

	var feedback: Dictionary = GameStreakTracker.construir_feedback_perdida(
		3,
		{"best_count": 5}
	)
	panel.mostrar(feedback)

	var title_label := panel.get_node_or_null(PATH_TITLE) as Label
	var streak_label := panel.get_node_or_null(PATH_STREAK_COUNT) as Label
	var detail_label := panel.get_node_or_null(PATH_DETAIL) as Label
	var best_label := panel.get_node_or_null(PATH_BEST) as Label

	assert_object(title_label).is_not_null()
	assert_object(streak_label).is_not_null()
	assert_object(detail_label).is_not_null()
	assert_object(best_label).is_not_null()
	assert_bool(panel.visible).is_true()
	assert_str(title_label.text).is_equal("Tu racha se cortó")
	assert_str(streak_label.text).is_equal("0")
	assert_str(detail_label.text).contains("3")
	assert_str(best_label.text).is_equal("Mejor racha: 5 días")
	assert_bool(best_label.visible).is_true()

	panel.queue_free()


func test_panel_oculta_mejor_racha_si_no_hay_historial() -> void:
	var panel: StreakLossMessagePanel = (
		StreakLossMessagePanelScene.instantiate() as StreakLossMessagePanel
	)
	add_child(panel)
	await get_tree().process_frame

	panel.mostrar(
		{
			"title": "Tu racha se cortó",
			"message": "Empezá de nuevo.",
			"best_count": 0,
			"previous_count": 0,
		}
	)

	var best_label := panel.get_node_or_null(PATH_BEST) as Label
	assert_object(best_label).is_not_null()
	assert_bool(best_label.visible).is_false()

	panel.queue_free()


func test_presentar_feedback_remueve_overlay_al_continuar() -> void:
	var host := Node2D.new()
	add_child(host)

	var feedback: Dictionary = GameStreakTracker.construir_feedback_perdida(
		2,
		{"best_count": 2}
	)
	_programar_cierre_overlay(host)

	await StreakLossFlow.presentar_feedback(host, feedback)

	assert_int(host.get_child_count()).is_equal(0)
	host.queue_free()


func test_save_manager_evaluar_perdida_con_racha_vencida() -> void:
	var save_manager := SaveManagerScript.new()
	var today := Time.get_date_string_from_system(false)
	var hace_tres_dias := _dia_anterior(_dia_anterior(_dia_anterior(today)))

	save_manager.save_data = SaveDataSchemaScript.new().datos_guardado_predeterminados()
	var progress: Dictionary = save_manager.save_data.get("progress", {}) as Dictionary
	progress["progress_system_states"] = {
		"streak": {
			"current_count": 5,
			"best_count": 5,
			"last_activity_day": hace_tres_dias,
		},
	}
	save_manager.save_data["progress"] = progress

	var resultado: Dictionary = save_manager.evaluar_perdida_racha_pendiente()

	assert_true(bool(resultado.get("should_show", false)))
	var feedback: Variant = resultado.get("feedback", {})
	assert_true(feedback is Dictionary)
	assert_str(str((feedback as Dictionary).get("feedback_key", ""))).is_equal("lost")

	var streak_guardada: Dictionary = (
		(save_manager.save_data.get("progress", {}) as Dictionary)
		.get("progress_system_states", {}) as Dictionary
	).get("streak", {}) as Dictionary
	assert_int(int(streak_guardada.get("current_count", -1))).is_equal(0)
	assert_int(int(streak_guardada.get("best_count", 0))).is_equal(5)


func _programar_cierre_overlay(host: Node) -> void:
	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(
		func() -> void:
			if not is_instance_valid(host) or host.get_child_count() == 0:
				return
			var layer := host.get_child(0)
			if layer == null or layer.get_child_count() == 0:
				return
			var continue_button := layer.get_child(0).get_node_or_null(PATH_CONTINUE) as Button
			if continue_button != null:
				continue_button.pressed.emit()
	)


func _dia_anterior(today: String) -> String:
	var unix_today := int(Time.get_unix_time_from_datetime_string(today))
	return Time.get_date_string_from_unix_time(
		unix_today - GameStreakTracker.SECONDS_PER_DAY
	)
