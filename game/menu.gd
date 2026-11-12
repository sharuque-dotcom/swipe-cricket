extends Control
## Start screen: resume a saved match, start a new 20-over match, or go to the nets.
## Command line: -- --scene=match or -- --scene=nets skips the menu (used for testing).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--scene="):
			_go(a.trim_prefix("--scene="))
			return
	if "--autoplay" in args:
		_go("nets")
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://world/tex/stadium.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.05, 0.12, 0.70)
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 44
	col.offset_right = -44
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	col.add_child(_label("QUICK-FIRE T20", "semi", 28, Hud.GOLD))
	var title := _label("SWIPE\nCRICKET", "bold", 150, Hud.TEXT)
	title.add_theme_constant_override("line_spacing", -44)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.add_theme_constant_override("shadow_outline_size", 16)
	col.add_child(title)
	var rule := ColorRect.new()
	rule.color = Hud.GOLD
	rule.custom_minimum_size = Vector2(120, 6)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(rule)
	col.add_child(_label("Every ball is real physics. Timing is everything.", "med", 28, Hud.DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 48)
	col.add_child(gap)
	var saved := _saved_summary()
	if saved != "":
		col.add_child(_button("RESUME MATCH", saved, Hud.GREEN, func(): _go("match")))
	col.add_child(_button("NEW MATCH", "Chase Red's total in 20 overs", Hud.BLUE, func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://match.json"))
		_go("match")))
	col.add_child(_button("NETS", "12 balls to find your timing", Hud.GOLD, func(): _go("nets")))

func _label(text: String, weight: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Hud.font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A card button: accent bar, title, one line of description, chevron.
func _button(text: String, sub: String, accent: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 124)
	for s in ["normal", "hover", "pressed", "focus"]:
		var sb := Hud.card_box(28, 0.86, Color(1, 1, 1, 0.14))
		if s == "pressed":
			sb.bg_color = Color(Hud.NAVY_HI.r, Hud.NAVY_HI.g, Hud.NAVY_HI.b, 0.95)
			sb.border_color = accent
		b.add_theme_stylebox_override(s, sb)
	var bar := ColorRect.new()
	bar.color = accent
	bar.position = Vector2(26, 34)
	bar.size = Vector2(8, 56)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bar)
	var t := _label(text, "bold", 46, Hud.TEXT)
	t.position = Vector2(54, 16)
	b.add_child(t)
	var d := _label(sub, "med", 26, Hud.DIM)
	d.position = Vector2(54, 70)
	b.add_child(d)
	var ch := _label("›", "bold", 64, accent)
	ch.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	ch.position += Vector2(-52, -48)
	b.add_child(ch)
	b.pressed.connect(on_press)
	return b

func _saved_summary() -> String:
	if not FileAccess.file_exists("user://match.json"):
		return ""
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://match.json"))
	if not d is Dictionary:
		return ""
	var m := MatchState.from_dict(d)
	if m.finished():
		return ""
	return "BLUE %d/%d  ·  %s ov  ·  need %d" % [m.runs, m.wickets, m.overs_text(), m.need()]

func _go(which: String) -> void:
	get_tree().call_deferred("change_scene_to_file", "res://game/match.tscn" if which == "match" else "res://game/nets.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
