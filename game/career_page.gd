extends Control
## The career page: make your player, then see your ratings, your next match, your season,
## your career numbers, how well you time it, and your recent innings.

const MATCH_SAVE := "user://match.json"

var career: Career
var _col: VBoxContainer
var _name_edit: LineEdit
var _role := "Opener"
var _delete_armed := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://world/tex/stadium.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.10, 0.86)
	add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 16)
	margin.add_child(_col)
	career = Career.load_saved()
	_build()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_screenshot()

func _build() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_child(_small_button("‹  MENU", func(): get_tree().call_deferred("change_scene_to_file", "res://game/menu.tscn")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label("CAREER", "bold", 44, Hud.GOLD))
	_col.add_child(head)
	if career == null:
		_build_create()
	else:
		_build_hub()

# ---- Making a player -----------------------------------------------------------------

func _build_create() -> void:
	var card := _card()
	var v := card.get_child(0) as VBoxContainer
	v.add_child(_label("START YOUR CAREER", "bold", 52, Hud.TEXT))
	v.add_child(_label("Begin in club cricket. Win your seasons, or score the runs, and move up: state, franchise, international.", "med", 26, Hud.DIM, true))
	v.add_child(_label("YOUR NAME", "semi", 22, Hud.GOLD))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name on your shirt"
	_name_edit.max_length = 18
	_name_edit.custom_minimum_size = Vector2(0, 76)
	_name_edit.add_theme_font_override("font", Hud.font("bold"))
	_name_edit.add_theme_font_size_override("font_size", 36)
	var sb := Hud.pill_box(Color(1, 1, 1, 0.08), 16)
	sb.content_margin_left = 20
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(2)
	_name_edit.add_theme_stylebox_override("normal", sb)
	_name_edit.add_theme_stylebox_override("focus", sb)
	v.add_child(_name_edit)
	v.add_child(_label("YOUR ROLE", "semi", 22, Hud.GOLD))
	var blurbs := {"Opener": "No. 1  ·  face the new ball, set it up", "Top order": "No. 3  ·  build the innings, time it",
		"Middle order": "No. 4  ·  rotate it, then cut loose", "Finisher": "No. 6  ·  big hitting at the death"}
	var group := ButtonGroup.new()
	for r: String in Career.ROLE_ORDER:
		var st: Array = Career.ROLES[r].start
		var b := _choice_button(r.to_upper(), "%s  ·  power %d  timing %d" % [blurbs[r], Career.rating(st[0]), Career.rating(st[1])], group, r == _role)
		var role := r
		b.toggled.connect(func(on: bool):
			if on:
				_role = role)
		v.add_child(b)
	v.add_child(_big_button("START CAREER", Hud.GOLD, func():
		career = Career.create(_name_edit.text, _role)
		career.save()
		_build()))
	_col.add_child(card)

# ---- The hub -------------------------------------------------------------------------

func _build_hub() -> void:
	var c := career
	var tier := c.tier_info()
	# You.
	var you := _card()
	var v := you.get_child(0) as VBoxContainer
	var top := HBoxContainer.new()
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -6)
	names.add_child(_label(c.name.to_upper(), "bold", 60, Hud.TEXT))
	names.add_child(_label("%s  ·  %s  ·  SEASON %d" % [c.role.to_upper(), tier.name, c.season], "semi", 24, Hud.GOLD))
	names.add_child(_label(c.team_name() if c.team_name() != "" else "IPL auction", "med", 24, Hud.DIM))
	top.add_child(names)
	top.add_child(_ovr(c.overall()))
	v.add_child(top)
	if c.points > 0:
		var pts := PanelContainer.new()
		var psb := Hud.pill_box(Color(Hud.GOLD.r, Hud.GOLD.g, Hud.GOLD.b, 0.18), 14)
		psb.content_margin_left = 16
		psb.content_margin_top = 6
		psb.content_margin_bottom = 8
		pts.add_theme_stylebox_override("panel", psb)
		pts.add_child(_label("%d SKILL POINT%s TO SPEND  ·  tap + to add" % [c.points, "" if c.points == 1 else "S"], "bold", 26, Hud.GOLD))
		v.add_child(pts)
	var colours := {"power": Hud.GOLD, "timing": Hud.GREEN, "placement": Hud.BLUE, "footwork": Color(0.75, 0.55, 1.0)}
	for area: String in Career.AREAS:
		v.add_child(_ability(area, colours[area]))
	v.add_child(_label("Points come from runs, fifties and hundreds, strike rate, timing it in the green, and winning. Getting out cheaply costs a point or two from whatever got you out.", "med", 21, Hud.DIM, true))
	_col.add_child(you)

	if c.tier >= Career.IPL_TIER and c.ipl_team == "":
		_build_auction()
		return

	# Next match.
	var nxt := _card(Hud.BLUE)
	v = nxt.get_child(0) as VBoxContainer
	var opts := c.match_opts(false)
	var resuming := _career_match_saved()
	if opts.is_empty():
		_col.add_child(nxt)
		v.add_child(_label("Waiting for the next season", "bold", 36, Hud.TEXT))
		return
	if opts.has("ipl"):
		var ip: Dictionary = opts.ipl
		var stage := ("MATCH %d OF %d" % [int(opts.career.match), int(opts.career.of)]) if str(ip.stage) == "League" else str(ip.stage).to_upper()
		v.add_child(_label("IPL  ·  %s  ·  %s  ·  %s" % [stage, IplPage.date_text(str(ip.date)), str(ip.ground).to_upper()], "semi", 22, Hud.GOLD))
		v.add_child(_label("v %s" % IplData.team(opts.red_name).name, "bold", 42, Hud.TEXT))
	else:
		v.add_child(_label("NEXT MATCH  ·  %d OF %d" % [c.match_no + 1, c.matches_in_season()], "semi", 22, Hud.GOLD))
		v.add_child(_label("v %s" % opts.red_name, "bold", 50, Hud.TEXT))
	v.add_child(_row("Pitch", str(Conditions.info(str(opts.pitch)).name).capitalize()))
	v.add_child(_row("Played", "Under lights" if opts.night else "In the day"))
	var atk := []
	for n in opts.attack:
		atk.append(str(n).split(" ")[1])
	v.add_child(_row("Their attack", ", ".join(atk)))
	v.add_child(_row("You bat", "No. %d  for %s" % [c.position() + 1, opts.blue_name]))
	v.add_child(_big_button("CONTINUE MATCH" if resuming else "PLAY", Hud.GOLD, func():
		if not resuming:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(MATCH_SAVE))
		Career.active = true
		Ipl.active = false
		get_tree().call_deferred("change_scene_to_file", "res://game/match.tscn")))
	_col.add_child(nxt)

	# This season. In the IPL, the league table.
	if c.in_ipl():
		var s := c.ipl()
		var tab := _card()
		v = tab.get_child(0) as VBoxContainer
		v.add_child(_label("IPL SEASON %d  ·  POINTS TABLE" % c.season, "semi", 22, Hud.GOLD))
		var tv := PointsTable.new()
		tv.rows = s.table()
		tv.me = c.ipl_team
		tv.custom_minimum_size = Vector2(0, 34 + 46 * tv.rows.size())
		v.add_child(tv)
		_col.add_child(tab)
	var sea := _card()
	v = sea.get_child(0) as VBoxContainer
	v.add_child(_label("SEASON %d  ·  %s" % [c.season, tier.name], "semi", 22, Hud.GOLD))
	var outs := maxi(c.season_outs, 1)
	v.add_child(_tiles([["PLAYED", str(c.match_no)], ["WON", str(c.season_wins)], ["RUNS", str(c.season_runs)],
		["AVERAGE", "%.1f" % (float(c.season_runs) / outs) if c.season_runs > 0 else "–"]], 4))
	if c.tier == Career.IPL_TIER - 1:
		v.add_child(_label("Win %d of %d or average %d and the IPL franchises come calling." % [
			int(ceilf(c.matches_in_season() * Career.PROMOTE_WINS)), c.matches_in_season(), int(Career.PROMOTE_AVERAGE)], "med", 22, Hud.DIM, true))
	elif c.tier < Career.IPL_TIER:
		v.add_child(_label("Move up to %s: win %d of %d, or average %d." % [Career.TIERS[c.tier + 1].name,
			int(ceilf(c.matches_in_season() * Career.PROMOTE_WINS)), c.matches_in_season(), int(Career.PROMOTE_AVERAGE)], "med", 22, Hud.DIM, true))
	else:
		v.add_child(_label("Playing for %s in the IPL." % c.team_name().capitalize(), "med", 22, Hud.DIM))
	_col.add_child(sea)

	# Career numbers.
	var st := c.stats
	var num := _card()
	v = num.get_child(0) as VBoxContainer
	v.add_child(_label("CAREER", "semi", 22, Hud.GOLD))
	var inns := int(st.innings)
	v.add_child(_tiles([["MATCHES", str(st.matches)], ["INNINGS", str(inns)], ["RUNS", str(st.runs)],
		["HIGHEST", "%d%s" % [st.hs, "*" if st.hs_not_out else ""] if inns > 0 else "–"],
		["AVERAGE", "%.1f" % c.average() if inns > 0 else "–"], ["STRIKE RATE", "%.0f" % c.strike_rate() if int(st.balls) > 0 else "–"],
		["50s", str(st.fifties)], ["100s", str(st.hundreds)], ["4s", str(st.fours)], ["6s", str(st.sixes)],
		["NOT OUTS", str(st.not_outs)], ["WINS", str(st.wins)]], 3))
	_col.add_child(num)

	# Timing.
	var tt := c.timing_totals
	var total := int(tt.perfect) + int(tt.early) + int(tt.late) + int(tt.miss)
	var tim := _card()
	v = tim.get_child(0) as VBoxContainer
	v.add_child(_label("YOUR TIMING", "semi", 22, Hud.GOLD))
	if total == 0:
		v.add_child(_label("Play a match to see how well you time it.", "med", 24, Hud.DIM))
	else:
		v.add_child(_label("%d%% of your swings in the green" % int(round(100.0 * tt.perfect / total)), "bold", 36, Hud.TEXT))
		var bar := TimingSplit.new()
		bar.parts = [[float(tt.perfect) / total, Hud.GREEN, "PERFECT"], [float(tt.early) / total, Color(0.98, 0.70, 0.18), "EARLY"],
			[float(tt.late) / total, Color(1.0, 0.55, 0.25), "LATE"], [float(tt.miss) / total, Hud.RED, "MISSED"]]
		bar.custom_minimum_size = Vector2(0, 84)
		v.add_child(bar)
	_col.add_child(tim)

	# Recent innings.
	if not c.recent.is_empty():
		var rec := _card()
		v = rec.get_child(0) as VBoxContainer
		v.add_child(_label("RECENT INNINGS", "semi", 22, Hud.GOLD))
		for r: Dictionary in c.recent.slice(0, 8):
			var score := "DNB" if not r.get("batted", true) else "%d%s (%d)" % [r.runs, "" if str(r.out) != "" else "*", r.balls]
			var how := "did not bat" if not r.get("batted", true) else (str(r.out) if str(r.out) != "" else "not out")
			v.add_child(_innings_row(score, "v %s  ·  %s" % [r.opp, how], bool(r.won)))
		_col.add_child(rec)
	if not c.history.is_empty():
		var his := _card()
		v = his.get_child(0) as VBoxContainer
		v.add_child(_label("SEASONS", "semi", 22, Hud.GOLD))
		for line in c.history.slice(0, 6):
			v.add_child(_label(str(line), "med", 24, Hud.TEXT, true))
		_col.add_child(his)
	var del := _small_button("Start a new career", Callable())
	del.pressed.connect(func():
		if not _delete_armed:
			_delete_armed = true
			del.text = "Tap again to delete %s's career" % c.name
			return
		Career.delete_saved()
		career = null
		_build())
	del.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(del)

## One ability: bar, rating, what it does, and a + button when there are points to spend.
func _ability(area: String, c: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	var h := _rating_bar(area.to_upper(), career.value(area), c)
	if career.points > 0:
		var plus := Button.new()
		var can := career.can_spend(area)
		plus.text = "+" if career.cost(area) == 1 else "+  (%d)" % career.cost(area)
		plus.disabled = not can
		plus.custom_minimum_size = Vector2(70 if career.cost(area) == 1 else 104, 52)
		plus.add_theme_font_override("font", Hud.font("bold"))
		plus.add_theme_font_size_override("font_size", 30)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var sb := Hud.pill_box(Hud.GOLD if can and st != "disabled" else Color(1, 1, 1, 0.08), 14)
			plus.add_theme_stylebox_override(st, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			plus.add_theme_color_override(k, Hud.NAVY)
		plus.add_theme_color_override("font_disabled_color", Hud.DIM)
		plus.pressed.connect(func():
			if career.spend(area):
				career.save()
				_build())
		h.add_child(plus)
	v.add_child(h)
	v.add_child(_label(str(Career.AREA_INFO[area]), "med", 19, Hud.DIM))
	return v

## Promoted from state cricket: three franchises want you.
func _build_auction() -> void:
	var card := _card(Hud.GOLD)
	var v := card.get_child(0) as VBoxContainer
	v.add_child(_label("IPL AUCTION", "semi", 24, Hud.GOLD))
	v.add_child(_label("Three franchises want you", "bold", 46, Hud.TEXT))
	v.add_child(_label("Pick one. You'll bat at No. %d in their XI and play the whole IPL season with them: their real squad, the real fixtures, the points table and the play-offs." % (career.position() + 1), "med", 23, Hud.DIM, true))
	for code: String in career.auction:
		var t := IplData.team(code)
		var xi: Array = t.xi
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 100)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var sb := Hud.pill_box(Color(1, 1, 1, 0.07 if not st.contains("pressed") else 0.16), 18)
			sb.border_color = Color(t.kit.r, t.kit.g, t.kit.b, 0.95)
			sb.border_width_left = 12
			b.add_theme_stylebox_override(st, sb)
		var n := _label(str(t.name).to_upper(), "bold", 34, Hud.TEXT)
		n.position = Vector2(32, 8)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(n)
		var sub := _label("Captain %s  ·  home %s  ·  their No. %d now: %s" % [t.captain, t.home, career.position() + 1, xi[career.position()][0]], "med", 21, Hud.DIM)
		sub.position = Vector2(32, 56)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sub)
		var code2 := code
		b.pressed.connect(func():
			career.join(code2)
			career.save()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(MATCH_SAVE))
			_build())
		v.add_child(b)
	_col.add_child(card)

func _career_match_saved() -> bool:
	if not FileAccess.file_exists(MATCH_SAVE):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATCH_SAVE))
	if not d is Dictionary or (d.get("career", {}) as Dictionary).is_empty():
		return false
	return not MatchState.from_dict(d).finished()

# ---- Pieces ----------------------------------------------------------------------------

func _card(accent: Color = Color(1, 1, 1, 0.12)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Hud.card_box(28, 0.9, accent)
	for side in ["left", "right"]:
		sb.set("content_margin_" + side, 26)
	sb.content_margin_top = 22
	sb.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return p

func _label(text: String, weight: String, size: int, c: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Hud.font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _row(k: String, val: String) -> Control:
	var h := HBoxContainer.new()
	var a := _label(k, "semi", 26, Hud.DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_label(val, "bold", 28, Hud.TEXT))
	return h

func _innings_row(score: String, sub: String, won: bool) -> Control:
	var p := PanelContainer.new()
	var sb := Hud.pill_box(Color(1, 1, 1, 0.05), 14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var s := _label(score, "bold", 32, Hud.TEXT)
	s.custom_minimum_size = Vector2(130, 0)
	h.add_child(s)
	var d := _label(sub, "med", 22, Hud.DIM)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(d)
	h.add_child(_label("WON" if won else "LOST", "bold", 22, Hud.GREEN if won else Hud.RED))
	return p

func _tiles(items: Array, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for it: Array in items:
		var p := PanelContainer.new()
		var sb := Hud.pill_box(Color(1, 1, 1, 0.06), 16)
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		var big := _label(str(it[1]), "bold", 40, Hud.TEXT)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		var small := _label(str(it[0]), "semi", 18, Hud.DIM)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(small)
		p.add_child(v)
		g.add_child(p)
	return g

func _rating_bar(title: String, value: float, c: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var t := _label(title, "semi", 24, Hud.DIM)
	t.custom_minimum_size = Vector2(100, 0)
	h.add_child(t)
	var bar := Bar.new()
	bar.value = value
	bar.color = c
	bar.custom_minimum_size = Vector2(0, 26)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	var n := _label(str(Career.rating(value)), "bold", 34, Hud.TEXT)
	n.custom_minimum_size = Vector2(52, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h

func _ovr(v: int) -> Control:
	var p := PanelContainer.new()
	var sb := Hud.pill_box(Hud.GOLD, 22)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 4
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -10)
	var n := _label(str(v), "bold", 64, Hud.NAVY)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var l := _label("OVERALL", "bold", 18, Hud.NAVY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	p.add_child(col)
	return p

func _big_button(text: String, c: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 92)
	b.add_theme_font_override("font", Hud.font("bold"))
	b.add_theme_font_size_override("font_size", 40)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := Hud.pill_box(c.lightened(0.12) if st.contains("pressed") else c, 24)
		b.add_theme_stylebox_override(st, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Hud.NAVY)
	b.pressed.connect(on_press)
	return b

func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", Hud.font("semi"))
	b.add_theme_font_size_override("font_size", 28)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Hud.DIM)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b

func _choice_button(title: String, sub: String, group: ButtonGroup, on: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	b.custom_minimum_size = Vector2(0, 96)
	for st in ["normal", "hover", "focus"]:
		var sb := Hud.pill_box(Color(1, 1, 1, 0.06), 20)
		sb.border_color = Color(1, 1, 1, 0.18)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(st, sb)
	for st in ["pressed", "hover_pressed"]:
		var sb := Hud.pill_box(Color(Hud.BLUE.r, Hud.BLUE.g, Hud.BLUE.b, 0.35), 20)
		sb.border_color = Hud.BLUE
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override(st, sb)
	var t := _label(title, "bold", 34, Hud.TEXT)
	t.position = Vector2(24, 8)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	var s := _label(sub, "med", 22, Hud.DIM)
	s.position = Vector2(24, 54)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(s)
	return b

## Saves a screenshot after layout settles (testing: --shot=PATH).
func _screenshot() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(a.trim_prefix("--shot="))
			get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().call_deferred("change_scene_to_file", "res://game/menu.tscn")


class Bar:
	extends Control
	var value := 0.5
	var color := Color.WHITE

	func _draw() -> void:
		draw_style_box(Hud.pill_box(Color(1, 1, 1, 0.12)), Rect2(Vector2.ZERO, size))
		if value > 0.0:
			draw_style_box(Hud.pill_box(color), Rect2(Vector2.ZERO, Vector2(maxf(size.x * clampf(value, 0.0, 1.0), size.y), size.y)))


## A bar split into parts, each with its share and a label under it.
class TimingSplit:
	extends Control
	var parts: Array = []

	func _draw() -> void:
		var x := 0.0
		var w := size.x
		var h := 30.0
		draw_style_box(Hud.pill_box(Color(1, 1, 1, 0.1), 12), Rect2(0, 0, w, h))
		for p: Array in parts:
			var pw := w * float(p[0])
			if pw <= 0.5:
				continue
			draw_rect(Rect2(x, 0, pw, h), p[1])
			if pw > 60.0:
				var f := Hud.font("semi")
				draw_string(f, Vector2(x, h + 30), "%s %d%%" % [p[2], int(round(float(p[0]) * 100.0))], HORIZONTAL_ALIGNMENT_LEFT, pw, 18, p[1])
			x += pw
