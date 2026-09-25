extends RefCounted
class_name Log
## Gated debug logging. Flip DEBUG to true to see tagged traces in the output;
## release builds stay silent. Warnings and errors always go through
## push_warning / push_error directly, never through here.

const DEBUG := false

static func info(tag: String, message: String) -> void:
	if DEBUG:
		print("[%s] %s" % [tag, message])

static func is_enabled() -> bool:
	return DEBUG
