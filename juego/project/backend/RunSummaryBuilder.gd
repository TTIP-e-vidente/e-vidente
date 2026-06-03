class_name RunSummaryBuilder
extends RefCounted

static func build(
	restriction: String,
	node_id: String,
	game_type: String,
	score: int,
	accuracy: float,
	correct_answers: int,
	wrong_answers: int,
	exp_to_add: int,
	completed: bool,
	duration_seconds: int,
) -> Dictionary:
	return {
		"clientRunId": _generate_client_run_id(),
		"restriction": restriction,
		"nodeId": node_id,
		"gameType": game_type,
		"score": score,
		"accuracy": accuracy,
		"correctAnswers": correct_answers,
		"wrongAnswers": wrong_answers,
		"expToAdd": exp_to_add,
		"completed": completed,
		"durationSeconds": duration_seconds,
		"finishedAt": Time.get_datetime_string_from_system(true),
	}


static func _generate_client_run_id() -> String:
	var timestamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var millis := int(Time.get_unix_time_from_system() * 1000.0)
	return "run_%s_%d_%d" % [timestamp, millis, randi()]
