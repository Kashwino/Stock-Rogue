extends Node
## Autoload "RunSave". Snapshot of the CURRENT run so the player can quit and
## resume. Deleted on death (no save-scumming — the roguelike contract).
##
## THREE GAME FILES: everything is slot-based. Set `slot` (0..2) before
## saving/loading — the case-file screen does this when a file is chosen.

const SLOT_COUNT := 3

## The active game file. All save/load/delete calls go to this slot.
var slot: int = 0

func _slot_path(i: int) -> String:
	return "user://run_slot_%d.save" % i

## Write a run snapshot to the active slot.
func save_run(state: Dictionary) -> void:
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("RunSave: could not open slot %d for writing" % slot)
		return
	f.store_string(JSON.stringify(state))
	f.close()

## Returns the active slot's run Dictionary, or {} if none exists.
func load_run() -> Dictionary:
	return peek(slot)

## Read ANY slot without switching to it — the case-file screen uses this to
## show each file's progress (stage reached, gold on hand).
func peek(i: int) -> Dictionary:
	var path := _slot_path(i)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunSave: slot %d corrupt, discarding" % i)
		delete_slot(i)
		return {}
	return parsed

func has_run() -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func slot_has_run(i: int) -> bool:
	return FileAccess.file_exists(_slot_path(i))

## Call on death or when starting a fresh run. Removes the active slot's file.
func delete_run() -> void:
	delete_slot(slot)

func delete_slot(i: int) -> void:
	var path := _slot_path(i)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
