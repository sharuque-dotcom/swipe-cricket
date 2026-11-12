class_name Hud
extends CanvasLayer
## Scoreboard, per-ball feedback and the swipe trail. Built in code; no scene file.

var _root: Control
var _score: Label
var _balls: Label
var _mode: Label
var _delivery: Label
var _big: Label
var _shot: Label
var _detail: Label
var _hint: Label
var _hint_panel: PanelContainer
var _fps: Label
var _meter: TimingMeter
var _trail: Line2D
var _panel: PanelContainer
var _panel_text: Label
var _big_tween: Tween

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top bar: deep navy fading slightly lighter, with a thin glowing accent line underneath.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.07, 0.17, 0.94))
	grad.set_color(1, Color(0.07, 0.16, 0.32, 0.86))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	var bar := TextureRect.new()
	bar.texture = gt
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 118
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var accent := ColorRect.new()
	accent.color = Color(0.38, 0.72, 1.0, 0.85)
	accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent.offset_top = 118
	accent.offset_bottom = 122
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(accent)
	_mode = _label(26, Color(0.62, 0.78, 1.0), Control.PRESET_TOP_LEFT, Vector2(28, 22))
	_mode.text = "NETS"
	_score = _label(58, Color.WHITE, Control.PRESET_TOP_LEFT, Vector2(28, 44))
	_balls = _label(30, Color(1.0, 0.86, 0.35), Control.PRESET_TOP_RIGHT, Vector2(-28, 22))
	_balls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_delivery = _label(30, Color.WHITE, Control.PRESET_TOP_RIGHT, Vector2(-28, 64))
	_delivery.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_delivery.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_big = _center_label(120, Color.WHITE, 0.27)
	_shot = _center_label(40, Color.WHITE, 0.375)
	_detail = _center_label(28, Color(0.85, 0.92, 1.0), 0.415)
	# Swipe hint in a rounded glass panel near the bottom.
	_hint_panel = PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.05, 0.10, 0.18, 0.72)
	hsb.set_corner_radius_all(22)
	hsb.border_color = Color(1, 1, 1, 0.18)
	hsb.set_border_width_all(2)
	hsb.content_margin_left = 28
	hsb.content_margin_right = 28
	hsb.content_margin_top = 18
	hsb.content_margin_bottom = 20
	hsb.shadow_color = Color(0, 0, 0, 0.35)
	hsb.shadow_size = 12
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
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 23)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hint.add_theme_constant_override("line_spacing", 6)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(_hint)

	_meter = TimingMeter.new()
	_meter.anchor_left = 0.5
	_meter.anchor_right = 0.5
	_meter.anchor_top = 0.47
	_meter.anchor_bottom = 0.47
	_meter.offset_left = -230
	_meter.offset_right = 230
	_meter.offset_bottom = 64
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.visible = false
	_root.add_child(_meter)

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

	_fps = _label(20, Color(1, 1, 1, 0.55), Control.PRESET_BOTTOM_LEFT, Vector2(16, -36))
	_fps.visible = OS.is_debug_build()

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.07, 0.14, 0.92)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(40)
	sb.border_color = Color(1.0, 0.86, 0.35)
	sb.set_border_width_all(3)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel_text = Label.new()
	_panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_text.add_theme_font_size_override("font_size", 38)
	_panel_text.add_theme_constant_override("line_spacing", 14)
	_panel.add_child(_panel_text)
	_root.add_child(_panel)

func _label(size: int, c: Color, preset: int, offset: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	l.set_anchors_preset(preset)
	l.position += offset
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func _center_label(size: int, c: Color, anchor_y: float) -> Label:
	var l := _label(size, c, Control.PRESET_TOP_LEFT, Vector2.ZERO)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_left = 20
	l.offset_right = -20
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _process(_delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
	if _trail.get_point_count() > 0 and _trail.modulate.a > 0.0 and not _trail.has_meta("live"):
		_trail.modulate.a = maxf(0.0, _trail.modulate.a - _delta * 3.0)

func set_score(runs: int, wickets: int, ball: int, total: int) -> void:
	_score.text = "%d" % runs if wickets == 0 else "%d / %d" % [runs, wickets]
	_balls.text = "BALL %d OF %d" % [mini(ball, total), total]

## Match scoreboard: team title, "45/2", overs, and four lines under the bar.
var _match_rows: Array[Label] = []

func set_match_score(title: String, score: String, overs: String) -> void:
	_mode.text = title
	_score.text = score
	_balls.text = overs

func set_match_info(batters: String, bowler: String, need: String, over: String) -> void:
	if _match_rows.is_empty():
		var strip := ColorRect.new()
		strip.color = Color(0.02, 0.05, 0.12, 0.55)
		strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
		strip.offset_top = 122
		strip.offset_bottom = 236
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(strip)
		_root.move_child(strip, 2)
		var a := _label(21, Color(0.92, 0.95, 1.0), Control.PRESET_TOP_LEFT, Vector2(24, 132))
		var b := _label(21, Color(1.0, 0.72, 0.72), Control.PRESET_TOP_RIGHT, Vector2(-24, 132))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var c := _center_label(27, Color(1.0, 0.86, 0.35), 0.0)
		c.offset_top = 164
		var d := _center_label(23, Color(1, 1, 1, 0.85), 0.0)
		d.offset_top = 200
		_match_rows = [a, b, c, d]
	_match_rows[0].text = batters
	_match_rows[1].text = bowler
	_match_rows[2].text = need
	_match_rows[3].text = over

func set_delivery(text: String) -> void:
	_delivery.text = text

func set_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = text != ""

func clear_result() -> void:
	_big.text = ""
	_shot.text = ""
	_detail.text = ""
	_meter.visible = false

func show_big(text: String, c: Color) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", c)
	_big.pivot_offset = _big.size * 0.5
	if _big_tween:
		_big_tween.kill()
	_big.scale = Vector2(0.4, 0.4)
	_big_tween = create_tween()
	_big_tween.tween_property(_big, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_shot(name: String, detail: String) -> void:
	_shot.text = name
	_detail.text = detail

func show_timing(n: float, label: String, ms: float) -> void:
	_meter.n = n
	_meter.caption = "%s  %+d ms" % [label, int(round(ms))] if label != "PERFECT" else "PERFECT  %+d ms" % int(round(ms))
	_meter.visible = true
	_meter.queue_redraw()

func show_panel(text: String) -> void:
	_panel_text.text = text
	_panel.visible = text != ""

func trail_begin() -> void:
	_trail.clear_points()
	_trail.modulate.a = 1.0
	_trail.set_meta("live", true)

func trail_points(points: PackedVector2Array) -> void:
	_trail.points = points

func trail_end() -> void:
	_trail.remove_meta("live")


class TimingMeter:
	extends Control
	var n := 0.0
	var caption := ""

	func _draw() -> void:
		var w := size.x
		var h := 22.0
		var zones := [
			[-1.0, -Tuning.CLEAN_N, Color(0.85, 0.2, 0.2)],
			[-Tuning.CLEAN_N, -Tuning.PERFECT_N, Color(0.95, 0.7, 0.15)],
			[-Tuning.PERFECT_N, Tuning.PERFECT_N, Color(0.2, 0.85, 0.35)],
			[Tuning.PERFECT_N, Tuning.CLEAN_N, Color(0.95, 0.7, 0.15)],
			[Tuning.CLEAN_N, 1.0, Color(0.85, 0.2, 0.2)]]
		draw_rect(Rect2(-4, -4, w + 8, h + 8), Color(0, 0, 0, 0.6))
		for z: Array in zones:
			var x0: float = (z[0] * 0.5 + 0.5) * w
			var x1: float = (z[1] * 0.5 + 0.5) * w
			draw_rect(Rect2(x0, 0, x1 - x0, h), z[2])
		var mx := (clampf(n, -1.15, 1.15) / 1.15 * 0.5 * 1.15 + 0.5) * w
		mx = clampf(mx, -6.0, w + 6.0)
		draw_rect(Rect2(mx - 5, -10, 10, h + 20), Color.WHITE)
		draw_rect(Rect2(mx - 2, -7, 4, h + 14), Color(0.05, 0.05, 0.1))
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(0, h + 40), caption, HORIZONTAL_ALIGNMENT_CENTER, w, 26, 6, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0, h + 40), caption, HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color.WHITE)
		draw_string(font, Vector2(0, -14), "EARLY", HORIZONTAL_ALIGNMENT_LEFT, w, 18, Color(1, 1, 1, 0.7))
		draw_string(font, Vector2(0, -14), "LATE", HORIZONTAL_ALIGNMENT_RIGHT, w, 18, Color(1, 1, 1, 0.7))
