extends RefCounted

const ENABLE_STREAK_PREVIEW_SEQUENCE := false
const PREVIEW_COUNTS_KEY := "mock_streak_counts"
const PREVIEW_MAX_COUNT := 7


static func is_preview_enabled() -> bool:
	return ENABLE_STREAK_PREVIEW_SEQUENCE


static func sanitize_target_for_runtime(continue_target: Dictionary) -> Dictionary:
	var sanitized_target: Dictionary = continue_target.duplicate(true)
	if not is_preview_enabled():
		sanitized_target.erase(PREVIEW_COUNTS_KEY)
	return sanitized_target


static func sanitize_continue_target(continue_target: Dictionary) -> Dictionary:
	return sanitize_target_for_runtime(continue_target)
