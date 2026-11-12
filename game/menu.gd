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
	shade.color = Color(0.02, 0.05, 0.12, 0.62)
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 56
	col.offset_right = -56
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	var title := Label.new()
	title.text = "SWIPE\nCRICKET"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_constant_override("line_spacing", -18)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 14)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "BLUE v RED"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 60)
	col.add_child(gap)
	var saved := _saved_summary()
	if saved != "":
		col.add_child(_button("RESUME MATCH\n" + saved, Color(0.15, 0.55, 0.25), func(): _go("match")))
	col.add_child(_button("NEW 20-OVER MATCH", Color(0.10, 0.32, 0.78), func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://match.json"))
		_go("match")))
	col.add_child(_button("NETS", Color(0.22, 0.25, 0.33), func(): _go("nets")))

func _button(text: String, c: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 116 if "\n" in text else 96)
	b.add_theme_font_size_override("font_size", 34)
	for s in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c.lightened(0.12) if s == "pressed" else c
		sb.set_corner_radius_all(26)
		sb.border_color = Color(1, 1, 1, 0.25)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 10
		b.add_theme_stylebox_override(s, sb)
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
