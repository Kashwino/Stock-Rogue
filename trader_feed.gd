extends Control
class_name TraderFeed

## A scrolling feed of other traders reacting to the venue's price action, like
## a stock chatroom running alongside the heist. Purely cosmetic, but it sells
## the idea that the underworld market is a place other people are watching.
##
## Connect it to a LiveStock: feed.bind_stock(live_stock). It listens for
## `market_event` and posts a line whenever something notable happens.
##
## Drop on a Control in hud.tscn under the chart, ~260x120.

const MAX_LINES := 4
const LINE_HEIGHT := 20.0
const COOLDOWN := 1.1          # min seconds between posts, so it can't spam

const HANDLES := [
	"BIG_Wh4le", "vaultrat", "no_alibi", "PaperHands_Pete", "ski_mask_liquidity",
	"getawaydriver", "FenceKing", "cold_storage", "Molotov_Margin", "bagholder99",
	"silent_alarm", "TheAccountant", "smash_and_grabber", "night_deposit",
	"crowbar_calls", "LaundroMat", "safecrack_sam", "InsideJob_",
]

## Reaction pools, keyed by event kind.
const LINES := {
	&"kill": [
		"another one down, ticker's climbing",
		"whoever's inside is COOKING",
		"volume spiking, someone's working",
		"load up, this thing has legs",
		"buying every dip on this one",
	],
	&"damage": [
		"oof. that's blood in the water",
		"selling. SELLING.",
		"they got clipped, get out get out",
		"this is why i don't hold overnight",
		"knife catchers assemble i guess",
	],
	&"boss": [
		"THE VAULT IS OPEN. MOON MISSION.",
		"biggest print of the night, holy",
		"whoever did that just made rent forever",
		"i'm all in, don't care about the heat",
	],
	&"grade": [
		"clean exit. textbook.",
		"closing the position, good run",
		"that's how it's done",
	],
	&"drift_up": [
		"steady bid under this",
		"quiet accumulation, i like it",
		"someone knows something",
		"chart looks pretty here ngl",
	],
	&"drift_down": [
		"bleeding out slowly",
		"who keeps dumping",
		"support gone, watch below",
		"down bad. as usual.",
	],
}

## Rarer, louder lines that only fire on big moves.
const HYPE := [
	"LEGENDARY GUN GOES TO THE MOON",
	"MORTGAGED THE SAFEHOUSE FOR THIS",
	"generational wealth or jail. no in between",
	"tell my wife i said hello",
	"THIS IS NOT FINANCIAL ADVICE THIS IS A ROBBERY",
	"i will not be taking questions",
]

var _lines: Array[Label] = []
var _cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _stock = null

func _ready() -> void:
	_rng.randomize()
	custom_minimum_size = Vector2(260, MAX_LINES * LINE_HEIGHT + 8)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Hook up to the heist's LiveStock.
## NOTE: named bind_stock, not bind — `bind` is a built-in Callable method and
## the parser resolves that first, giving "Nonexistent function 'bind'".
func bind_stock(stock) -> void:
	_stock = stock
	if stock and stock.has_signal("market_event"):
		stock.market_event.connect(_on_market_event)
	post(_pick(HANDLES), "chat's live. someone's about to do something stupid.",
		Color(0.55, 0.57, 0.65))
	# Whatever broke on the wire since the last job.
	if not RunState.news.is_empty():
		post("NEWSWIRE", MarketNews.line(RunState.news[0]), Palette.GOLD)

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func _on_market_event(kind: StringName, magnitude: float) -> void:
	if _cooldown > 0.0:
		return
	# Small routine moves shouldn't generate chatter every time.
	if kind == &"hit":
		return
	if (kind == &"drift_up" or kind == &"drift_down") and _rng.randf() > 0.45:
		return
	if kind == &"kill" and _rng.randf() > 0.35:
		return

	var pool: Array = LINES.get(kind, LINES[&"drift_up"])
	var text: String = _pick(pool)
	# Big moves occasionally trigger an unhinged one instead.
	if magnitude > 0.15 and _rng.randf() < 0.5:
		text = _pick(HYPE)

	var colour := Palette.UP
	if kind == &"damage" or kind == &"drift_down":
		colour = Palette.DOWN
	elif kind == &"boss":
		colour = Palette.GOLD

	post(_pick(HANDLES), text, colour)
	_cooldown = COOLDOWN

## Add a line to the feed, scrolling older ones up.
func post(handle: String, text: String, colour: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = "%s: %s" % [handle, text]
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_font_override("font", VisualTheme.font("body"))
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.size = Vector2(size.x - 8, LINE_HEIGHT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	_lines.append(l)

	# Drop the oldest line once the feed is full.
	while _lines.size() > MAX_LINES:
		var old: Label = _lines.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	_relayout()
	var t := create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.2)

func _relayout() -> void:
	for i in _lines.size():
		var l: Label = _lines[i]
		if not is_instance_valid(l):
			continue
		var target_y := 4.0 + i * LINE_HEIGHT
		# Newest line slides in; older ones ease upward.
		if l.position.y == 0.0 and i == _lines.size() - 1:
			l.position = Vector2(6, target_y + 10.0)
		var t := create_tween()
		t.tween_property(l, "position:y", target_y, 0.18)
		l.position.x = 6
		# Older lines fade as they age out.
		var age := float(_lines.size() - 1 - i)
		l.modulate.a = clampf(1.0 - age * 0.16, 0.35, 1.0)

func _pick(pool: Array) -> String:
	return pool[_rng.randi() % pool.size()]
