extends Control
## Guided tutorial overlay. Dims the screen, highlights a target node with a
## spotlight cutout, shows a message + Next/Skip. Data-driven via `steps`.
##
## USAGE:
##   var tut = preload("res://scenes/tutorial_overlay.tscn").instantiate()
##   add_child(tut)                       # add on top of your game UI
##   tut.steps = [
##       { "target": "%PortfolioPanel", "title": "Your Portfolio",
##         "text": "These are the criminal ventures you hold." },
##       { "target": "%BuyButton", "title": "Buy In",
##         "text": "Tap Buy to ante up capital and take a position." },
##       { "target": "", "title": "Good luck",
##         "text": "Watch the market, time your exits, don't get greedy." },
##   ]
##   tut.start()
##
## `target` is a node path resolved against the overlay's PARENT (your game
## scene). Empty target = centered message with no spotlight.
## Set the same nodes to "Access as Unique Name" so % paths work.

signal finished

@onready var dim: ColorRect = %Dim
@onready var spotlight: Control = %Spotlight    # a Panel/NinePatch you position
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton
@onready var box: Control = %MessageBox         # container for title/body/buttons

var steps: Array = []
var _index: int = 0

func _ready() -> void:
	next_button.pressed.connect(_advance)
	skip_button.pressed.connect(_finish)
	hide()

func start() -> void:
	if steps.is_empty():
		_finish()
		return
	_index = 0
	show()
	_show_step()

func _advance() -> void:
	_index += 1
	if _index >= steps.size():
		_finish()
	else:
		_show_step()

func _show_step() -> void:
	var step: Dictionary = steps[_index]
	title_label.text = step.get("title", "")
	body_label.text = step.get("text", "")
	next_button.text = "Done" if _index == steps.size() - 1 else "Next"

	var target_path: String = step.get("target", "")
	if target_path == "":
		spotlight.hide()
		_center_box()
	else:
		var target := get_parent().get_node_or_null(target_path)
		if target and target is Control:
			_spotlight_on(target as Control)
		else:
			push_warning("Tutorial: target not found: " + target_path)
			spotlight.hide()
			_center_box()

func _spotlight_on(target: Control) -> void:
	var rect := target.get_global_rect()
	spotlight.show()
	spotlight.global_position = rect.position - Vector2(8, 8)
	spotlight.size = rect.size + Vector2(16, 16)
	# Place the message box just below the highlighted node (or above if low).
	var below := rect.position.y + rect.size.y + 16
	if below + box.size.y > get_viewport_rect().size.y:
		box.global_position = Vector2(rect.position.x, rect.position.y - box.size.y - 16)
	else:
		box.global_position = Vector2(rect.position.x, below)

func _center_box() -> void:
	var vp := get_viewport_rect().size
	box.global_position = (vp - box.size) * 0.5

func _finish() -> void:
	Meta.mark_tutorial_seen()      # never show again unless progress is reset
	hide()
	finished.emit()
	queue_free()
