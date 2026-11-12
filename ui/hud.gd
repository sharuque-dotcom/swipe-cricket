class_name Hud
extends CanvasLayer
## Scoreboard cards, per-ball feedback, the field radar and the swipe trail.
## Built and drawn in code; no scene file.

const NAVY := Color(0.030, 0.060, 0.130)
const NAVY_HI := Color(0.075, 0.135, 0.260)
const GOLD := Color(1.0, 0.79, 0.28)
const BLUE := Color(0.22, 0.55, 1.0)
const RED := Color(0.95, 0.30, 0.32)
const GREEN := Color(0.25, 0.86, 0.46)
const TEXT := Color(0.96, 0.975, 1.0)
const DIM := Color(0.62, 0.70, 0.83)
const MARGIN := 14.0

static var _fonts := {}

static func font(weight: String = "bold") -> Font:
	if not _fonts.has(weight):
		var path: String = {"bold": "res://ui/fonts/BarlowCondensed-Bold.ttf", "semi": "res://ui/fonts/BarlowCondensed-SemiBold.ttf",
			"med": "res://ui/fonts/BarlowCondensed-Medium.ttf"}[weight]
		_fonts[weight] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[weight]

## A rounded glass card: dark navy, hairline border, soft drop shadow.
static func card_box(radius: int = 24, alpha: float = 0.90, border: Color = Color(1, 1, 1, 0.10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(NAVY.r, NAVY.g, NAVY.b, alpha)
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing_size = 1.2
	return sb

static func pill_box(c: Color, radius: int = 999) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing_size = 1.2
	return sb

var _root: Control
var _top: TopBar
var _radar: Radar
var _toast: PanelContainer
var _toast_text: Label
var _band: TextureRect
var _big: Label
var _shot_panel: PanelContainer
var _shot: Label
var _detail: Label
var _hint: Label
var _hint_panel: PanelContainer
var _fps: Label
var _meter: TimingMeter
var _trail: Line2D
var _scrim: ColorRect
var _card: PanelContainer
var _card_col: VBoxContainer
var _prompt: Control
var _big_tween: Tween
var _safe_top := 0.0

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_safe_top = _safe_inset()

	_top = TopBar.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_top = _safe_top
	_top.offset_bottom = _safe_top + 330
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)

	# Delivery read-out and short notices: a pill under the scoreboard.
	_toast = PanelContainer.new()
	var tsb := pill_box(Color(NAVY.r, NAVY.g, NAVY.b, 0.82))
	tsb.border_color = Color(1, 1, 1, 0.14)
	tsb.set_border_width_all(2)
	tsb.content_margin_left = 22
	tsb.content_margin_right = 22
	tsb.content_margin_top = 5
	tsb.content_margin_bottom = 7
	_toast.add_theme_stylebox_override("panel", tsb)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = _safe_top + 184
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)
	_toast_text = _text("", "semi", 26, TEXT)
	_toast.add_child(_toast_text)

	# Big call ("SIX!") on a soft colour band so it reads against the crowd.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_band = TextureRect.new()
	_band.texture = gt
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.anchor_right = 1.0
	_band.anchor_top = 0.335
	_band.anchor_bottom = 0.335
	_band.offset_top = -30
	_band.offset_bottom = 190
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.modulate.a = 0.0
	_root.add_child(_band)
	_big = _text("", "bold", 150, TEXT)
	_big.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.08, 0.9))
	_big.add_theme_constant_override("outline_size", 14)
	_big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_big.add_theme_constant_override("shadow_offset_y", 8)
	_big.add_theme_constant_override("shadow_outline_size", 14)
	_big.anchor_right = 1.0
	_big.anchor_top = 0.335
	_big.anchor_bottom = 0.335
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_big)

	_shot_panel = PanelContainer.new()
	var ssb := card_box(22, 0.78)
	ssb.content_margin_left = 30
	ssb.content_margin_right = 30
	ssb.content_margin_top = 8
	ssb.content_margin_bottom = 12
	_shot_panel.add_theme_stylebox_override("panel", ssb)
	_shot_panel.anchor_left = 0.5
	_shot_panel.anchor_right = 0.5
	_shot_panel.anchor_top = 0.615
	_shot_panel.anchor_bottom = 0.615
	_shot_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shot_panel.visible = false
	_root.add_child(_shot_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", -4)
	_shot_panel.add_child(sv)
	_shot = _text("", "bold", 38, TEXT)
	_shot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(_shot)
	_detail = _text("", "med", 25, DIM)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(_detail)

	_meter = TimingMeter.new()
	_meter.anchor_left = 0.5
	_meter.anchor_right = 0.5
	_meter.anchor_top = 0.705
	_meter.anchor_bottom = 0.705
	_meter.offset_left = -236
	_meter.offset_right = 236
	_meter.offset_bottom = 96
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.visible = false
	_root.add_child(_meter)

	_radar = Radar.new()
	_radar.anchor_top = 1.0
	_radar.anchor_bottom = 1.0
	_radar.offset_left = MARGIN
	_radar.offset_right = MARGIN + 206
	_radar.offset_top = -(MARGIN + 206 + 20)
	_radar.offset_bottom = -(MARGIN + 20)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.visible = false
	_root.add_child(_radar)

	# Swipe hint in a rounded glass panel near the bottom.
	_hint_panel = PanelContainer.new()
	var hsb := card_box(22, 0.78)
	hsb.content_margin_left = 28
	hsb.content_margin_right = 28
	hsb.content_margin_top = 14
	hsb.content_margin_bottom = 18
	_hint_panel.add_theme_stylebox_override("panel", hsb)
	_hint_panel.anchor_left = 0.0
	_hint_panel.anchor_right = 1.0
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left = 24
	_hint_panel.offset_right = -24
	_hint_panel.offset_top = -70
	_hint_panel.offset_bottom = -70
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	_root.add_child(_hint_panel)
	_hint = _text("", "semi", 27, TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_constant_override("line_spacing", 2)
	_hint_panel.add_child(_hint)

	_trail = Line2D.new()
	_trail.width = 14.0
	_trail.default_color = Color(1, 1, 1, 0.75)
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.15))
	curve.add_point(Vector2(1, 1))
	_trail.width_curve = curve
	_root.add_child(_trail)

	_fps = _text("", "med", 20, Color(1, 1, 1, 0.5))
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.position += Vector2(-78, -34)
	_fps.visible = OS.is_debug_build()
	_root.add_child(_fps)

	# Modal card (match intro, result, session summary) over a dimmed pitch.
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.0, 0.02, 0.06, 0.55)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	_root.add_child(_scrim)
	_card = PanelContainer.new()
	var sb := card_box(34, 0.96, Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	sb.shadow_size = 30
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 30
	sb.content_margin_bottom = 36
	_card.add_theme_stylebox_override("panel", sb)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size = Vector2(600, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_card_col = VBoxContainer.new()
	_card_col.add_theme_constant_override("separation", 6)
	_card.add_child(_card_col)
	_root.add_child(_card)

func _safe_inset() -> float:
	# Keep the scoreboard clear of a notch or status bar on phones.
	if not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return 0.0
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return 0.0
	var view_h := float(get_viewport().get_visible_rect().size.y)
	return clampf(float(safe.position.y) * view_h / float(win.y), 0.0, 90.0)

func _text(s: String, weight: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
	if _trail.get_point_count() > 0 and _trail.modulate.a > 0.0 and not _trail.has_meta("live"):
		_trail.modulate.a = maxf(0.0, _trail.modulate.a - delta * 3.0)
	if _prompt != null and _card.visible:
		_prompt.modulate.a = 0.72 + 0.28 * sin(Time.get_ticks_msec() / 260.0)

# ---- Scoreboard ----------------------------------------------------------------------

## Nets: runs, wickets and how far through the session we are.
func set_score(runs: int, wickets: int, ball: int, total: int) -> void:
	_top.match_mode = false
	_top.title = "NETS"
	_top.score = "%d" % runs if wickets == 0 else "%d/%d" % [runs, wickets]
	_top.right_label = "BALL"
	_top.right_big = "%d" % mini(ball, total)
	_top.right_small = "/%d" % total
	_top.line = "%d wicket%s lost" % [wickets, "" if wickets == 1 else "s"] if wickets > 0 else "12-ball session"
	_top.progress = float(mini(ball, total) - 1) / maxf(total, 1)
	_top.queue_redraw()

## Match: everything on the scoreboard comes straight from the match state.
func set_match(m: MatchState) -> void:
	_top.match_mode = true
	_top.title = "BLUE"
	_top.title_b = "RED %d/%d" % [m.red_total, m.red_wickets]
	_top.score = "%d/%d" % [m.runs, m.wickets]
	_top.right_label = "OVERS"
	_top.right_big = m.overs_text()
	_top.right_small = "/%d" % MatchState.OVERS
	_top.line = "TARGET %d" % m.target if m.balls == 0 else ("" if m.finished() else "NEED %d OFF %d" % [m.need(), m.balls_left()])
	_top.line_right = "" if m.finished() or m.balls == 0 else "REQ. RATE %.1f" % m.required_rate()
	_top.progress = clampf(float(m.runs) / maxf(m.target, 1), 0.0, 1.0)
	var s: Dictionary = m.batters[m.striker]
	var n: Dictionary = m.batters[m.non_striker]
	_top.striker = [str(s.name), int(s.runs), int(s.balls)]
	_top.partner = [str(n.name), int(n.runs), int(n.balls)]
	var sk := m.striker_skill()
	_top.role = sk.role
	_top.power = BatterSkill.pips(sk.power)
	_top.timing = BatterSkill.pips(sk.timing)
	var bi := m.bowler_index()
	var b: Dictionary = m.bowling[bi]
	_top.bowler = str(MatchState.BOWLERS[bi][0])
	_top.bowler_style = str({"swing": "SWING", "pace": "PACE", "off": "OFF SPIN", "leg": "LEG SPIN"}.get(m.bowler_style(), ""))
	_top.figures = "%d-%d" % [b.wkts, b.runs]
	_top.figures_overs = "(%s)" % m.overs_text(b.balls)
	_top.over = m.this_over.duplicate()
	_top.queue_redraw()
	_toast.offset_top = _safe_top + 332

func set_delivery(text: String) -> void:
	_toast_text.text = text
	_toast.visible = text != ""

func set_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = text != ""

# ---- Per-ball feedback ---------------------------------------------------------------

func clear_result() -> void:
	_big.text = ""
	_band.modulate.a = 0.0
	_shot_panel.visible = false
	_meter.visible = false

func show_big(text: String, c: Color) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", c)
	_big.pivot_offset = Vector2(_root.size.x * 0.5, 90)
	if _big_tween:
		_big_tween.kill()
	_big.scale = Vector2(0.4, 0.4)
	_band.modulate = Color(c.r * 0.35, c.g * 0.35, c.b * 0.45, 0.0)
	_big_tween = create_tween().set_parallel()
	_big_tween.tween_property(_big, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_big_tween.tween_property(_band, "modulate:a", 0.78, 0.22)

func show_shot(name: String, detail: String) -> void:
	_shot.text = name
	_detail.text = detail
	_detail.visible = detail != ""
	_shot_panel.visible = name != ""
	_shot_panel.reset_size()

## `perfect` and `clean` are the zone edges this swing was judged against.
func show_timing(n: float, label: String, ms: float, perfect: float = Tuning.PERFECT_N, clean: float = Tuning.CLEAN_N) -> void:
	_meter.n = n
	_meter.perfect = perfect
	_meter.clean = clean
	_meter.label = label
	_meter.caption = "%+d ms" % int(round(ms))
	_meter.visible = true
	_meter.queue_redraw()

# ---- Cards ----------------------------------------------------------------------------

## A modal card. Keys, all optional: kicker, title, sub, accent (Color),
## rows ([[label, value, Color?], ...]), notes ([String, ...]), prompt.
func show_card(d: Dictionary) -> void:
	for c in _card_col.get_children():
		_card_col.remove_child(c)
		c.queue_free()
	_prompt = null
	var accent: Color = d.get("accent", GOLD)
	if d.get("kicker", "") != "":
		var k := _text(str(d.kicker), "semi", 24, GOLD)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_col.add_child(k)
	if d.get("title", "") != "":
		var t := _text(str(d.title), "bold", 78, accent)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("line_spacing", -14)
		_card_col.add_child(t)
	if d.get("sub", "") != "":
		var s := _text(str(d.sub), "semi", 32, TEXT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_col.add_child(s)
	var rows: Array = d.get("rows", [])
	if not rows.is_empty():
		_card_col.add_child(_gap(14))
		for r: Array in rows:
			_card_col.add_child(_row(str(r[0]), str(r[1]), r[2] if r.size() > 2 else Color(0, 0, 0, 0)))
	for note in d.get("notes", []):
		var nl := _text(str(note), "med", 27, DIM)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_col.add_child(_gap(6))
		_card_col.add_child(nl)
	if d.get("prompt", "") != "":
		_card_col.add_child(_gap(20))
		var pc := PanelContainer.new()
		var psb := pill_box(GOLD, 22)
		psb.content_margin_top = 10
		psb.content_margin_bottom = 14
		pc.add_theme_stylebox_override("panel", psb)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pl := _text(str(d.prompt).to_upper(), "bold", 34, NAVY)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(pl)
		_card_col.add_child(pc)
		_prompt = pc
	clear_result()
	_scrim.visible = true
	_card.visible = true
	_card.reset_size()
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.16)

func hide_card() -> void:
	_scrim.visible = false
	_card.visible = false

func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

func _row(label: String, value: String, chip: Color) -> Control:
	var pc := PanelContainer.new()
	var sb := pill_box(Color(1, 1, 1, 0.055), 16)
	sb.content_margin_left = 18
	sb.content_margin_right = 20
	sb.content_margin_top = 6
	sb.content_margin_bottom = 9
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	if chip.a > 0.0:
		var dot := ColorRect.new()
		dot.color = chip
		dot.custom_minimum_size = Vector2(8, 30)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
	var l := _text(label, "semi", 29, DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(_text(value, "bold", 32, TEXT))
	return pc

# ---- Radar ----------------------------------------------------------------------------

func radar_field(field: Array) -> void:
	_radar.spots = field
	_radar.track.clear()
	_radar.visible = true
	_radar.queue_redraw()

func radar_ball(p: Vector3) -> void:
	if _radar.track.is_empty() or _radar.track[_radar.track.size() - 1].distance_squared_to(p) > 1.0:
		_radar.track.append(p)
		_radar.queue_redraw()

func radar_clear() -> void:
	_radar.track.clear()
	_radar.queue_redraw()

# ---- Swipe trail ----------------------------------------------------------------------

func trail_begin() -> void:
	_trail.clear_points()
	_trail.modulate.a = 1.0
	_trail.set_meta("live", true)

func trail_points(points: PackedVector2Array) -> void:
	_trail.points = points

func trail_end() -> void:
	_trail.remove_meta("live")


## The scoreboard: a score card, and in a match a batting card and a bowling card under it.
class TopBar:
	extends Control
	var match_mode := false
	var title := ""
	var title_b := ""
	var score := "0"
	var right_label := ""
	var right_big := ""
	var right_small := ""
	var line := ""
	var line_right := ""
	var progress := 0.0
	var striker := ["", 0, 0]
	var partner := ["", 0, 0]
	var role := ""
	var power := 5
	var timing := 5
	var bowler := ""
	var bowler_style := ""
	var figures := ""
	var figures_overs := ""
	var over: Array = []

	func _t(weight: String, s: String, x: float, y: float, sz: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> float:
		var f := Hud.font(weight)
		draw_string(f, Vector2(x, y), s, align, w, sz, c)
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

	func _draw() -> void:
		var w := size.x
		var m := Hud.MARGIN
		# Score card.
		var a := Rect2(m, 12, w - m * 2.0, 164)
		draw_style_box(Hud.card_box(26), a)
		var sheen := StyleBoxFlat.new()
		sheen.bg_color = Color(Hud.NAVY_HI.r, Hud.NAVY_HI.g, Hud.NAVY_HI.b, 0.55)
		sheen.set_corner_radius_all(24)
		sheen.corner_radius_bottom_left = 0
		sheen.corner_radius_bottom_right = 0
		draw_style_box(sheen, Rect2(a.position + Vector2(2, 2), Vector2(a.size.x - 4, 46)))
		var x := a.position.x + 24
		var y := a.position.y
		draw_style_box(Hud.pill_box(Hud.BLUE, 4), Rect2(x, y + 15, 7, 22))
		var tx := x + 18 + _t("bold", title, x + 18, y + 36, 28, Hud.TEXT)
		if title_b != "":
			tx += 12 + _t("med", "v", tx + 12, y + 36, 24, Hud.DIM)
			draw_style_box(Hud.pill_box(Hud.RED, 4), Rect2(tx + 12, y + 15, 7, 22))
			_t("semi", title_b, tx + 30, y + 36, 26, Hud.DIM)
		_t("semi", right_label, x, y + 36, 22, Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT, a.size.x - 48)
		_t("bold", score, x - 2, y + 118, 84, Hud.TEXT)
		var sw := Hud.font("semi").get_string_size(right_small, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		_t("semi", right_small, x, y + 114, 30, Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT, a.size.x - 48)
		_t("bold", right_big, x, y + 114, 60, Hud.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, a.size.x - 48 - sw - 6)
		var score_w := Hud.font("bold").get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
		if match_mode:
			_t("semi", line, x + score_w + 22, y + 92, 27, Hud.GOLD)
			_t("med", line_right, x + score_w + 22, y + 120, 23, Hud.DIM)
		else:
			_t("med", line, x + score_w + 22, y + 112, 25, Hud.DIM)
		var bar := Rect2(x, y + 138, a.size.x - 48, 8)
		draw_style_box(Hud.pill_box(Color(1, 1, 1, 0.12)), bar)
		if progress > 0.0:
			draw_style_box(Hud.pill_box(Hud.GOLD), Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 8.0), 8)))
		if not match_mode:
			return

		# Batting card: striker, their ability, and the non-striker.
		var bw := floorf((w - m * 2.0 - 10.0) * 0.585)
		var b := Rect2(m, a.end.y + 10, bw, 132)
		draw_style_box(Hud.card_box(22), b)
		x = b.position.x + 18
		y = b.position.y
		var inner := b.size.x - 36
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 19), Vector2(x + 13, y + 28), Vector2(x, y + 37)]), Hud.GOLD)
		_t("bold", str(striker[0]).to_upper(), x + 22, y + 38, 30, Hud.TEXT)
		var bl := " (%d)" % striker[2]
		var blw := Hud.font("med").get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_t("med", bl, x, y + 38, 24, Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT, inner)
		_t("bold", str(striker[1]), x, y + 38, 32, Hud.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, inner - blw)
		# Ability strip.
		var strip := Rect2(x - 6, y + 50, inner + 12, 36)
		draw_style_box(Hud.pill_box(Color(1, 1, 1, 0.06), 12), strip)
		_t("semi", role.to_upper(), strip.position.x + 12, strip.position.y + 25, 20, Hud.GOLD)
		var px := strip.end.x - 12
		px = _pips(px, strip.position.y + 12, "TIMING", timing)
		_pips(px - 14, strip.position.y + 12, "POWER", power)
		_t("semi", str(partner[0]).to_upper(), x + 22, y + 116, 25, Hud.DIM)
		_t("med", "%d (%d)" % [partner[1], partner[2]], x, y + 116, 25, Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT, inner)

		# Bowling card: who, what they bowl, figures, and this over ball by ball.
		var c := Rect2(b.end.x + 10, b.position.y, w - m - b.end.x - 10, 132)
		draw_style_box(Hud.card_box(22), c)
		x = c.position.x + 18
		y = c.position.y
		inner = c.size.x - 36
		draw_circle(Vector2(x + 7, y + 28), 7.0, Hud.RED)
		_t("bold", bowler.to_upper(), x + 22, y + 38, 28, Hud.TEXT)
		_t("semi", bowler_style, x, y + 72, 21, Hud.RED.lightened(0.25))
		var fw := Hud.font("med").get_string_size(figures_overs, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
		_t("med", figures_overs, x, y + 72, 23, Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT, inner)
		_t("bold", figures, x, y + 72, 28, Hud.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, inner - fw - 6)
		var step := inner / 6.0
		for i in 6:
			var centre := Vector2(x + step * (i + 0.5), y + 104)
			var r := minf(15.0, step * 0.5 - 2.0)
			if i >= over.size():
				draw_arc(centre, r - 1.0, 0.0, TAU, 28, Color(1, 1, 1, 0.16), 2.0, true)
				continue
			var mark := str(over[i])
			var fill := Color(1, 1, 1, 0.14)
			var ink := Hud.TEXT
			match mark:
				"4":
					fill = Hud.BLUE
				"6":
					fill = Hud.GOLD
					ink = Hud.NAVY
				"W":
					fill = Hud.RED
			draw_circle(centre, r, fill)
			if mark == "·":
				draw_circle(centre, 3.0, Hud.DIM)
			else:
				_t("bold", mark, centre.x - r, centre.y + 8, 23, ink, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)

	## Five pips with a label to their left; returns the x where the label starts.
	func _pips(right: float, y: float, label: String, n: int) -> float:
		var x := right
		for i in range(4, -1, -1):
			x -= 11
			draw_style_box(Hud.pill_box(Hud.GOLD if i < n else Color(1, 1, 1, 0.16), 3), Rect2(x, y, 9, 13))
			x -= 2
		var lw := Hud.font("semi").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_t("semi", label, x - 5 - lw, y + 13, 17, Hud.DIM)
		return x - 5 - lw


## How early or late the bat was, against the zones this batter and this shot allowed.
class TimingMeter:
	extends Control
	var n := 0.0
	var perfect := Tuning.PERFECT_N
	var clean := Tuning.CLEAN_N
	var label := ""
	var caption := ""

	func _draw() -> void:
		var w := size.x
		draw_style_box(Hud.card_box(20, 0.78), Rect2(-18, -12, w + 36, 108))
		var bar_y := 30.0
		var h := 16.0
		var f := Hud.font("semi")
		draw_string(f, Vector2(0, 20), "EARLY", HORIZONTAL_ALIGNMENT_LEFT, w, 19, Hud.DIM)
		draw_string(f, Vector2(0, 20), "LATE", HORIZONTAL_ALIGNMENT_RIGHT, w, 19, Hud.DIM)
		var red := Color(0.90, 0.25, 0.27)
		var amber := Color(0.98, 0.70, 0.18)
		draw_style_box(Hud.pill_box(red), Rect2(0, bar_y, w, h))
		var x0 := (-clean * 0.5 + 0.5) * w
		var x1 := (clean * 0.5 + 0.5) * w
		draw_rect(Rect2(x0, bar_y, x1 - x0, h), amber)
		x0 = (-perfect * 0.5 + 0.5) * w
		x1 = (perfect * 0.5 + 0.5) * w
		draw_rect(Rect2(x0, bar_y, x1 - x0, h), Hud.GREEN)
		var mx := clampf((clampf(n, -1.0, 1.0) * 0.5 + 0.5) * w, 3.0, w - 3.0)
		draw_style_box(Hud.pill_box(Hud.NAVY), Rect2(mx - 7, bar_y - 9, 14, h + 18))
		draw_style_box(Hud.pill_box(Color.WHITE), Rect2(mx - 4, bar_y - 6, 8, h + 12))
		var c := Hud.GREEN if label == "PERFECT" else (amber if not label.begins_with("TOO") else red)
		var fb := Hud.font("bold")
		var lw := fb.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var cw := Hud.font("med").get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var sx := (w - lw - cw - 12.0) * 0.5
		draw_string(fb, Vector2(sx, bar_y + h + 38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)
		draw_string(Hud.font("med"), Vector2(sx + lw + 12.0, bar_y + h + 38), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Hud.TEXT)


## Top-down map of the field: where all eleven of the fielding side are, and where the
## last shot went. The batter is at the bottom looking up the pitch, as on screen.
class Radar:
	extends Control
	var spots: Array = []
	var track: Array[Vector3] = []

	func _map(p: Vector3, c: Vector2, k: float) -> Vector2:
		return c + Vector2(p.x - Pitch.FIELD_CENTRE.x, p.z - Pitch.FIELD_CENTRE.z) * k

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 10.0
		var k := r / Pitch.BOUNDARY_RADIUS
		draw_style_box(Hud.card_box(999, 0.86), Rect2(Vector2.ZERO, size))
		draw_circle(c, r, Color(0.13, 0.42, 0.20, 0.95))
		draw_circle(c, r * 0.70, Color(0.16, 0.48, 0.23, 0.95))
		draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.85), 2.0, true)
		draw_arc(c, 27.4 * k, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 1.5, true)
		var p0 := _map(Vector3(-1.5, 0, Pitch.BOWLER_STUMPS_Z), c, k)
		var p1 := _map(Vector3(1.5, 0, 0), c, k)
		draw_rect(Rect2(p0, p1 - p0).grow(1.0), Color(0.80, 0.70, 0.50))
		if track.size() > 1:
			var pts := PackedVector2Array()
			for p in track:
				var q := _map(p, c, k)
				if q.distance_to(c) > r:
					q = c + (q - c).normalized() * r
				pts.append(q)
			draw_polyline(pts, Color(1, 1, 1, 0.9), 2.5, true)
			draw_circle(pts[pts.size() - 1], 4.0, Color.WHITE)
		for s in spots:
			var q := _map(s.pos, c, k)
			if q.distance_to(c) > r - 3.0:
				q = c + (q - c).normalized() * (r - 3.0)
			draw_circle(q, 5.5, Hud.NAVY)
			draw_circle(q, 4.0, Hud.GOLD if s.kind == Fielding.Kind.KEEPER else Hud.RED)
		draw_circle(_map(Vector3(0, 0, -1.0), c, k), 5.5, Hud.NAVY)
		draw_circle(_map(Vector3(0, 0, -1.0), c, k), 4.0, Hud.BLUE)
