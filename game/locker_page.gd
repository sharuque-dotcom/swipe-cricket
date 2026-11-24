extends "res://game/career_page.gd"
## The locker: what you've earned, what's still to earn, and what you're wearing.

const SLOTS := [["bat", "BAT STICKER"], ["helmet", "HELMET"], ["celebration", "CELEBRATION"]]

func _build() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_child(_small_button("‹  MENU", func(): get_tree().call_deferred("change_scene_to_file", "res://game/menu.tscn")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label("LOCKER", "bold", 44, Hud.GOLD))
	_col.add_child(head)

	var items := Locker.items()
	for slot: Array in SLOTS:
		var card := _card()
		var v := card.get_child(0) as VBoxContainer
		v.add_child(_label(str(slot[1]), "semi", 22, Hud.GOLD))
		var on := Locker.equipped(str(slot[0]))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		var options: Array = [["", "Standard"]] + (items[str(slot[0])] as Array)
		for it: Array in options:
			var b := Button.new()
			b.text = str(it[1]).to_upper()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 58)
			b.add_theme_font_override("font", Hud.font("bold"))
			b.add_theme_font_size_override("font_size", 22)
			var sel := str(it[0]) == on
			for st in ["normal", "hover", "pressed", "focus"]:
				var sb := Hud.pill_box(Hud.GOLD if sel else Color(1, 1, 1, 0.08), 14)
				sb.content_margin_left = 18
				sb.content_margin_right = 18
				b.add_theme_stylebox_override(st, sb)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(k, Hud.NAVY if sel else Hud.TEXT)
			var s_id := str(slot[0])
			var i_id := str(it[0])
			b.pressed.connect(func():
				Locker.equip(s_id, i_id)
				_build())
			row.add_child(b)
		v.add_child(row)
		_col.add_child(card)

	var ach := _card()
	var av := ach.get_child(0) as VBoxContainer
	var got := 0
	for id in Locker.ACHIEVEMENTS:
		if Locker.unlocked(id):
			got += 1
	av.add_child(_label("ACHIEVEMENTS  ·  %d OF %d" % [got, Locker.ACHIEVEMENTS.size()], "semi", 22, Hud.GOLD))
	for id in Locker.ACHIEVEMENTS:
		var a: Array = Locker.ACHIEVEMENTS[id]
		var done := Locker.unlocked(id)
		var line := HBoxContainer.new()
		var tick := _label("✓" if done else "·", "bold", 30, Hud.GREEN if done else Hud.DIM)
		tick.custom_minimum_size = Vector2(36, 0)
		line.add_child(tick)
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(_label(str(a[0]).to_upper(), "bold", 26, Hud.TEXT if done else Hud.DIM))
		txt.add_child(_label("%s  ·  unlocks %s" % [a[1], a[4]], "med", 20, Hud.DIM, true))
		line.add_child(txt)
		av.add_child(line)
	_col.add_child(ach)
