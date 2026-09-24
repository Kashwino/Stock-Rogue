extends Node
class_name VisualTheme
## Autoload "Look". Builds the one UI theme every screen uses — stamped buttons,
## panels, sliders, checkboxes, scrollbars, tooltips and font roles — straight
## into the project theme, so Controls under any CanvasLayer inherit it.
## Colours come from Palette; the constants below are kept as short aliases.

const INK := Palette.BG
const PANEL := Palette.PANEL
const EDGE := Palette.EDGE
const GOLD := Palette.GOLD
const TEAL := Palette.TEAL
const WHITE := Palette.PAPER

const FONT_DIR := "res://assets/fonts/"

static var _fonts: Dictionary = {}

func _ready() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		push_error("Look: no project theme — set gui/theme/custom in project.godot.")
		return
	build_theme(theme)

# ------------------------------------------------------------------ fonts ---
## Font roles: heading (Oswald), body (Barlow), mono (Plex Mono), type (Courier).
static func font(role: String) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var f: Font = null
	match role:
		"heading": f = _variable("Oswald.ttf", 600, ["Oswald", "Bebas Neue", "Impact", "Arial Narrow", "sans-serif"])
		"heading_bold": f = _variable("Oswald.ttf", 700, ["Oswald", "Impact", "sans-serif"])
		"body": f = _file("BarlowSemiCondensed-Medium.ttf", ["Barlow Semi Condensed", "Roboto Condensed", "Arial", "sans-serif"])
		"body_bold": f = _file("BarlowSemiCondensed-Bold.ttf", ["Barlow Semi Condensed", "Arial", "sans-serif"])
		"mono": f = _file("IBMPlexMono-Medium.ttf", ["IBM Plex Mono", "DejaVu Sans Mono", "Courier New", "monospace"])
		"type": f = _file("CourierPrime-Regular.ttf", ["Courier Prime", "Courier New", "monospace"])
		"type_bold": f = _file("CourierPrime-Bold.ttf", ["Courier Prime", "Courier New", "monospace"])
		_: f = ThemeDB.fallback_font
	_fonts[role] = f
	return f

static func _file(file: String, fallback: Array) -> Font:
	var path := FONT_DIR + file
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Font:
			return loaded
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(fallback)
	return sys

static func _variable(file: String, weight: int, fallback: Array) -> Font:
	var base := _file(file, fallback)
	var fv := FontVariation.new()
	fv.base_font = base
	if base is FontFile:
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		fv.variation_opentype = {tag: weight}
	return fv

# ------------------------------------------------------------ styleboxes ----
static func panel(accent: Color = EDGE, padding: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.with_alpha(Palette.PANEL, 0.97)
	box.border_color = accent
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(padding)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	return box

static func box(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 3, margin: float = 10.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b

## Paper card (case files, reports, newspaper).
static func paper(color: Color = Palette.MANILA, padding: int = 18) -> StyleBoxFlat:
	var b := box(color, color.darkened(0.25), 1, 2, padding)
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 10
	b.shadow_offset = Vector2(3, 5)
	return b

## A "stamped" button face: gold edge with a heavier lip at the bottom so it
## reads as raised; hover fills it, pressed dips it.
static func _button_face(state: String, accent: Color, filled: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(3)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 10
	b.content_margin_bottom = 12
	b.border_width_left = 2
	b.border_width_right = 2
	b.border_width_top = 2
	b.border_width_bottom = 5
	match state:
		"normal":
			b.bg_color = accent if filled else Palette.PANEL
			b.border_color = accent.darkened(0.35) if filled else Palette.with_alpha(accent, 0.75)
		"hover":
			b.bg_color = accent.lightened(0.12) if filled else accent
			b.border_color = accent.darkened(0.3)
		"focus":
			b.bg_color = Color.TRANSPARENT
			b.draw_center = false
			b.border_color = Palette.GOLD_PALE
			b.set_border_width_all(2)
		"pressed":
			b.bg_color = accent.darkened(0.3)
			b.border_color = accent.darkened(0.5)
			b.border_width_bottom = 2
			b.content_margin_top = 13
			b.content_margin_bottom = 9
		"disabled":
			b.bg_color = Color("141418")
			b.border_color = Color("2a2a31")
	b.shadow_color = Color(0, 0, 0, 0.3 if state != "pressed" else 0.1)
	b.shadow_size = 4 if state != "pressed" else 1
	b.shadow_offset = Vector2(0, 2)
	return b

# ------------------------------------------------------------ icons --------
func _icon(size: Vector2i, painter: Callable) -> ImageTexture:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	painter.call(img)
	return ImageTexture.create_from_image(img)

func _paint_circle(img: Image, color: Color, ring: Color) -> void:
	var c := Vector2(img.get_width(), img.get_height()) * 0.5 - Vector2(0.5, 0.5)
	var r := img.get_width() * 0.5 - 1.0
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x, y).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, ring if d > r - 2.2 else color)
			elif d <= r + 1.0:
				img.set_pixel(x, y, Palette.with_alpha(ring, r + 1.0 - d))

func _paint_check(img: Image, checked: bool) -> void:
	var w := img.get_width()
	for y in w:
		for x in w:
			var edge := x < 2 or y < 2 or x >= w - 2 or y >= w - 2
			if edge:
				img.set_pixel(x, y, Palette.GOLD if checked else Palette.GOLD_DIM)
			elif checked:
				img.set_pixel(x, y, Palette.with_alpha(Palette.GOLD, 0.16))
	if checked:
		# A stamped X.
		for i in range(5, w - 5):
			for t in [-1, 0, 1]:
				img.set_pixel(clampi(i + t, 0, w - 1), i, Palette.GOLD)
				img.set_pixel(clampi(w - 1 - i + t, 0, w - 1), i, Palette.GOLD)

func _paint_switch(img: Image, on: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r := h * 0.5
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r))
			if d <= r - 0.5:
				img.set_pixel(x, y, Palette.with_alpha(Palette.GOLD, 0.35) if on else Color("26262d"))
	var knob := Vector2(w - r if on else r, r)
	for y in h:
		for x in w:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(knob)
			if d <= r - 3.0:
				img.set_pixel(x, y, Palette.GOLD if on else Palette.MUTED)

func _paint_arrow(img: Image) -> void:
	var w := img.get_width()
	for y in range(6, 12):
		var half := 11 - y
		for x in range(w / 2 - half, w / 2 + half + 1):
			img.set_pixel(x, y, Palette.GOLD)

# ------------------------------------------------------------- theme -------
func build_theme(theme: Theme) -> void:
	var body := font("body")
	theme.default_font = body
	theme.default_font_size = 22

	# Labels.
	theme.set_color("font_color", "Label", Palette.PAPER)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_font("font", "Label", body)

	# Buttons: stamped.
	for kind in ["Button", "OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			theme.set_stylebox(state, kind, _button_face(state, Palette.GOLD, false))
		theme.set_font("font", kind, font("body_bold"))
		theme.set_font_size("font_size", kind, 22)
		theme.set_color("font_color", kind, Palette.PAPER)
		theme.set_color("font_hover_color", kind, Palette.INK)
		theme.set_color("font_hover_pressed_color", kind, Palette.INK)
		theme.set_color("font_pressed_color", kind, Palette.PAPER)
		theme.set_color("font_focus_color", kind, Palette.GOLD_PALE)
		theme.set_color("font_disabled_color", kind, Palette.MUTED)
		theme.set_color("icon_hover_color", kind, Palette.INK)
		theme.set_constant("h_separation", kind, 10)
	theme.set_icon("arrow", "OptionButton", _icon(Vector2i(22, 18), _paint_arrow))

	# Button variations.
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "PrimaryButton", _button_face(state, Palette.GOLD, true))
	theme.set_color("font_color", "PrimaryButton", Palette.INK)
	theme.set_color("font_focus_color", "PrimaryButton", Palette.INK)
	theme.set_color("font_pressed_color", "PrimaryButton", Palette.INK)
	theme.set_type_variation("DangerButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "DangerButton", _button_face(state, Palette.DANGER, false))
	theme.set_type_variation("GhostButton", "Button")
	var ghost := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 2, 8)
	for state in ["normal", "disabled", "focus"]:
		theme.set_stylebox(state, "GhostButton", ghost)
	theme.set_stylebox("hover", "GhostButton", box(Palette.with_alpha(Palette.GOLD, 0.12), Palette.GOLD_DIM, 1, 2, 8))
	theme.set_stylebox("pressed", "GhostButton", box(Palette.with_alpha(Palette.GOLD, 0.2), Palette.GOLD, 1, 2, 8))
	theme.set_color("font_color", "GhostButton", Palette.GOLD)
	theme.set_color("font_hover_color", "GhostButton", Palette.GOLD_PALE)

	# Toggles.
	for kind in ["CheckButton", "CheckBox"]:
		var flat := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 2, 6)
		for state in ["normal", "pressed", "disabled", "hover_pressed"]:
			theme.set_stylebox(state, kind, flat)
		theme.set_stylebox("hover", kind, box(Palette.with_alpha(Palette.GOLD, 0.08), Color.TRANSPARENT, 0, 2, 6))
		theme.set_stylebox("focus", kind, box(Color.TRANSPARENT, Palette.GOLD_DIM, 1, 2, 6))
		theme.set_font("font", kind, body)
		theme.set_color("font_color", kind, Palette.PAPER)
		theme.set_color("font_hover_color", kind, Palette.GOLD_PALE)
		theme.set_color("font_pressed_color", kind, Palette.PAPER)
		theme.set_color("font_hover_pressed_color", kind, Palette.GOLD_PALE)
		theme.set_color("font_focus_color", kind, Palette.PAPER)
	var sw_on := _icon(Vector2i(52, 28), _paint_switch.bind(true))
	var sw_off := _icon(Vector2i(52, 28), _paint_switch.bind(false))
	theme.set_icon("checked", "CheckButton", sw_on)
	theme.set_icon("unchecked", "CheckButton", sw_off)
	theme.set_icon("checked_disabled", "CheckButton", sw_on)
	theme.set_icon("unchecked_disabled", "CheckButton", sw_off)
	theme.set_icon("checked", "CheckBox", _icon(Vector2i(26, 26), _paint_check.bind(true)))
	theme.set_icon("unchecked", "CheckBox", _icon(Vector2i(26, 26), _paint_check.bind(false)))

	# Sliders.
	var track := box(Color("26262d"), Color("33333c"), 1, 3, 4)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", track)
	var fill := box(Palette.GOLD_DIM, Color.TRANSPARENT, 0, 3, 4)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.GOLD, Color.TRANSPARENT, 0, 3, 4))
	theme.set_icon("grabber", "HSlider", _icon(Vector2i(26, 26), _paint_circle.bind(Palette.GOLD, Palette.GOLD_PALE)))
	theme.set_icon("grabber_highlight", "HSlider", _icon(Vector2i(28, 28), _paint_circle.bind(Palette.GOLD_PALE, Color.WHITE)))

	# Panels.
	theme.set_stylebox("panel", "PanelContainer", panel(Palette.GOLD_DIM, 18))
	theme.set_stylebox("panel", "Panel", panel(Palette.EDGE, 0))
	theme.set_type_variation("PaperPanel", "PanelContainer")
	theme.set_stylebox("panel", "PaperPanel", paper())
	theme.set_type_variation("FlatPanel", "PanelContainer")
	theme.set_stylebox("panel", "FlatPanel", box(Palette.with_alpha(Palette.BG, 0.82), Palette.with_alpha(Palette.GOLD_DIM, 0.6), 1, 2, 10))

	# Scrollbars.
	for kind in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", kind, box(Color("15151a"), Color.TRANSPARENT, 0, 4, 3))
		theme.set_stylebox("grabber", kind, box(Palette.GOLD_DIM, Color.TRANSPARENT, 0, 4, 3))
		theme.set_stylebox("grabber_highlight", kind, box(Palette.GOLD, Color.TRANSPARENT, 0, 4, 3))
		theme.set_stylebox("grabber_pressed", kind, box(Palette.GOLD_PALE, Color.TRANSPARENT, 0, 4, 3))

	# Tooltips and popups.
	theme.set_stylebox("panel", "TooltipPanel", box(Palette.INK, Palette.GOLD, 1, 2, 10))
	theme.set_color("font_color", "TooltipLabel", Palette.PAPER)
	theme.set_font("font", "TooltipLabel", body)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	theme.set_stylebox("panel", "PopupMenu", box(Palette.PANEL, Palette.GOLD_DIM, 1, 2, 8))
	theme.set_stylebox("hover", "PopupMenu", box(Palette.GOLD, Color.TRANSPARENT, 0, 2, 6))
	theme.set_color("font_color", "PopupMenu", Palette.PAPER)
	theme.set_color("font_hover_color", "PopupMenu", Palette.INK)
	theme.set_font_size("font_size", "PopupMenu", 22)
	theme.set_stylebox("separator", "HSeparator", box(Palette.GOLD_DIM, Color.TRANSPARENT, 0, 0, 1))
	theme.set_constant("separation", "HSeparator", 10)

	# Font role variations for Labels.
	_label_variation(theme, "HeadingLabel", font("heading"), 34, Palette.GOLD)
	_label_variation(theme, "TitleLabel", font("heading_bold"), 64, Palette.PAPER)
	_label_variation(theme, "MonoLabel", font("mono"), 18, Palette.PAPER)
	_label_variation(theme, "TypeLabel", font("type"), 20, Palette.INK)
	_label_variation(theme, "DimLabel", body, 18, Palette.PAPER_DIM)
	_label_variation(theme, "KickerLabel", font("heading"), 18, Palette.GOLD_DIM)

static func _label_variation(theme: Theme, name: String, f: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, f)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)

# ------------------------------------------------------------ helpers ------
## Build a Label in one call. `role` is a theme variation (HeadingLabel...).
static func label(text: String, role: String = "", size: int = 0, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if role != "":
		l.theme_type_variation = role
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
