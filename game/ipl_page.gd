extends "res://game/career_page.gd"
## IPL 2026: pick a franchise, then the season hub: next match, points table, fixtures and
## results, and the squad. Built from the career page's pieces.

const MONTHS := ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

var season: Ipl
var _reset_armed := false

func _build() -> void:
	season = Ipl.load_saved()
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_child(_small_button("‹  MENU", func(): get_tree().call_deferred("change_scene_to_file", "res://game/menu.tscn")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label("IPL 2026", "bold", 44, Hud.GOLD))
	_col.add_child(head)
	if season == null:
		_build_pick()
	else:
		_build_season()

static func date_text(d: String) -> String:
	var p := d.split("-")
	return "%d %s" % [int(p[2]), MONTHS[int(p[1])]]

func _team_bar(code: String, h: float = 56.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = IplData.team(code).kit
	r.custom_minimum_size = Vector2(10, h)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

# ---- Pick a team ---------------------------------------------------------------------

func _build_pick() -> void:
	var card := _card()
	var v := card.get_child(0) as VBoxContainer
	v.add_child(_label("PICK YOUR TEAM", "bold", 52, Hud.TEXT))
	v.add_child(_label("Play the 2026 season with a real squad: all 70 league fixtures in order, the points table, and the play-offs. You bat; every other match is played out for you.", "med", 24, Hud.DIM, true))
	for code in IplData.ORDER:
		var t := IplData.team(code)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 92)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var sb := Hud.pill_box(Color(1, 1, 1, 0.07 if not st.contains("pressed") else 0.16), 18)
			sb.border_color = Color(t.kit.r, t.kit.g, t.kit.b, 0.9)
			sb.border_width_left = 10
			b.add_theme_stylebox_override(st, sb)
		var n := _label(str(t.name).to_upper(), "bold", 32, Hud.TEXT)
		n.position = Vector2(30, 8)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(n)
		var s := _label("%s  ·  captain %s  ·  home %s" % [code, t.captain, t.home], "med", 22, Hud.DIM)
		s.position = Vector2(30, 52)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(s)
		var team_code: String = code
		b.pressed.connect(func():
			Ipl.create(team_code).save()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(MATCH_SAVE))
			_build())
		v.add_child(b)
	v.add_child(_label("Squads as of March 2026. Batting orders and ratings are the game's own.", "med", 20, Hud.DIM, true))
	_col.add_child(card)

# ---- The season ----------------------------------------------------------------------

func _build_season() -> void:
	var s := season
	var me := IplData.team(s.team)
	var rows := s.table()
	var pos := s.position()
	var mine: Dictionary = rows[pos - 1]

	# Your team.
	var top := _card(Color(me.kit.r, me.kit.g, me.kit.b, 0.9))
	var v := top.get_child(0) as VBoxContainer
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(_team_bar(s.team, 70))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(_label(str(me.name).to_upper(), "bold", 44, Hud.TEXT))
	names.add_child(_label("Captain %s  ·  %s" % [me.captain, me.home], "med", 24, Hud.DIM))
	h.add_child(names)
	v.add_child(h)
	v.add_child(_tiles([["PLAYED", str(mine.p)], ["WON", str(mine.w)], ["POINTS", str(mine.pts)], ["POSITION", _ord(pos)]], 4))
	_col.add_child(top)

	# Next match, or the end of the season.
	var nxt := _card(Hud.BLUE)
	v = nxt.get_child(0) as VBoxContainer
	var f := s.peek_mine()
	if s.season_over():
		v.add_child(_label("SEASON OVER", "semi", 22, Hud.GOLD))
		v.add_child(_label("%s ARE CHAMPIONS" % s.champion, "bold", 46, Hud.TEXT))
		v.add_child(_label(str(s.results["Final"].text), "med", 24, Hud.DIM))
		v.add_child(_big_button("NEW SEASON", Hud.GOLD, func():
			Ipl.delete_saved()
			_build()))
	elif f.is_empty():
		var out := s.league_done()
		v.add_child(_label("YOUR SEASON IS OVER" if out else "WAITING FOR THE PLAY-OFFS", "semi", 22, Hud.GOLD))
		v.add_child(_label("%s finished %s" % [s.team, _ord(pos)] if out else "Play out the remaining matches", "bold", 40, Hud.TEXT))
		v.add_child(_big_button("SIMULATE THE REST", Hud.GOLD, func():
			season.sim_to_end()
			season.save()
			_build()))
	else:
		var opp := s.opponent(f)
		var resuming := _ipl_match_saved()
		var stage := ("MATCH %d" % int(f.n)) if str(f.stage) == "League" else str(f.stage).to_upper()
		v.add_child(_label("NEXT  ·  %s  ·  %s  ·  %s" % [stage, date_text(str(f.date)), str(f.ground).to_upper()], "semi", 22, Hud.GOLD))
		var vs := HBoxContainer.new()
		vs.add_theme_constant_override("separation", 14)
		vs.add_child(_team_bar(opp, 52))
		vs.add_child(_label("v %s" % IplData.team(opp).name, "bold", 40, Hud.TEXT))
		v.add_child(vs)
		v.add_child(_row("Pitch", str(Conditions.info(str(IplData.GROUNDS.get(str(f.ground), "good"))).name).capitalize()))
		v.add_child(_row("Played", "Afternoon" if Ipl.is_day(f) else "Under lights"))
		var atk := []
		for n in IplData.attack_names(opp):
			atk.append(str(n).split(" ")[-1])
		v.add_child(_row("Their attack", ", ".join(atk)))
		v.add_child(_label("You chase. Matches before this one are played out when you start.", "med", 21, Hud.DIM, true))
		v.add_child(_big_button("CONTINUE MATCH" if resuming else "PLAY", Hud.GOLD, func():
			if not resuming:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(MATCH_SAVE))
			Ipl.active = true
			Career.active = false
			get_tree().call_deferred("change_scene_to_file", "res://game/match.tscn")))
	_col.add_child(nxt)

	# Points table.
	var tab := _card()
	v = tab.get_child(0) as VBoxContainer
	v.add_child(_label("POINTS TABLE", "semi", 22, Hud.GOLD))
	var tv := TableView.new()
	tv.rows = rows
	tv.me = s.team
	tv.custom_minimum_size = Vector2(0, 34 + 46 * rows.size())
	v.add_child(tv)
	if not s.playoffs.is_empty():
		for p: Dictionary in s.playoffs:
			var r: Dictionary = s.results.get(str(p.stage), {})
			v.add_child(_row(str(p.stage), ("%s v %s" % [p.home, p.away]) if r.is_empty() else str(r.text)))
	_col.add_child(tab)

	# Your fixtures.
	var fx := _card()
	v = fx.get_child(0) as VBoxContainer
	v.add_child(_label("%s FIXTURES" % s.team, "semi", 22, Hud.GOLD))
	for g: Dictionary in s.fixtures():
		if not s.mine(g):
			continue
		var r: Dictionary = s.results.get(str(g.key), {})
		var opp2 := s.opponent(g)
		var label := ("M%d" % int(g.n)) if str(g.stage) == "League" else str(g.stage)
		var line := "%s  ·  %s  ·  v %s  ·  %s" % [label, date_text(str(g.date)), opp2, g.ground]
		if r.is_empty():
			v.add_child(_fixture_row(line, "", Color(0, 0, 0, 0)))
		else:
			var won := str(r.winner) == s.team
			var score := "%s %d/%d, %s %d/%d" % [r.first, r.first_runs, r.first_wkts, r.chase, r.chase_runs, r.chase_wkts]
			v.add_child(_fixture_row(line, ("WON  " if won else "LOST  ") + score, Hud.GREEN if won else Hud.RED))
	_col.add_child(fx)

	# Around the league.
	var others := []
	for g: Dictionary in s.fixtures():
		var r: Dictionary = s.results.get(str(g.key), {})
		if not r.is_empty() and not s.mine(g):
			others.append("M%d  %s" % [int(g.n), r.text] if str(g.stage) == "League" else "%s  %s" % [g.stage, r.text])
	if not others.is_empty():
		var lg := _card()
		v = lg.get_child(0) as VBoxContainer
		v.add_child(_label("AROUND THE LEAGUE", "semi", 22, Hud.GOLD))
		for line in others.slice(maxi(0, others.size() - 6)):
			v.add_child(_label(str(line), "med", 24, Hud.TEXT, true))
		_col.add_child(lg)

	# Squad.
	var sq := _card()
	v = sq.get_child(0) as VBoxContainer
	v.add_child(_label("PLAYING XI", "semi", 22, Hud.GOLD))
	var i := 1
	for p: Array in me.xi:
		v.add_child(_row("%d.  %s" % [i, p[0]], "%s  ·  P %d  T %d" % [p[1], Career.rating(float(p[2])), Career.rating(float(p[3]))]))
		i += 1
	v.add_child(_label("BOWLING", "semi", 22, Hud.GOLD))
	for a: Array in me.attack:
		v.add_child(_row(str(a[0]), str(IplData.STYLES[str(a[1])].label).capitalize()))
	var xi := IplData.xi_names(s.team)
	var bench := []
	for n: String in me.squad:
		if not xi.has(n.trim_suffix("*")):
			bench.append(n.trim_suffix("*") + (" (overseas)" if n.ends_with("*") else ""))
	v.add_child(_label("SQUAD", "semi", 22, Hud.GOLD))
	v.add_child(_label(", ".join(bench), "med", 22, Hud.DIM, true))
	_col.add_child(sq)

	var del := _small_button("Start a new season", Callable())
	del.pressed.connect(func():
		if not _reset_armed:
			_reset_armed = true
			del.text = "Tap again to end this season"
			return
		Ipl.delete_saved()
		_build())
	del.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(del)

func _fixture_row(line: String, result: String, c: Color) -> Control:
	var p := PanelContainer.new()
	var sb := Hud.pill_box(Color(1, 1, 1, 0.05), 14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	p.add_child(col)
	col.add_child(_label(line, "semi", 24, Hud.TEXT))
	if result != "":
		col.add_child(_label(result, "bold", 22, c))
	else:
		col.add_child(_label("to play", "med", 20, Hud.DIM))
	return p

func _ipl_match_saved() -> bool:
	if not FileAccess.file_exists(MATCH_SAVE):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATCH_SAVE))
	if not d is Dictionary or (d.get("ipl", {}) as Dictionary).is_empty():
		return false
	return not MatchState.from_dict(d).finished()

static func _ord(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


## The points table, drawn: position, team, played, won, lost, net run rate, points.
class TableView:
	extends Control
	var rows: Array = []
	var me := ""

	func _draw() -> void:
		var w := size.x
		var f := Hud.font("semi")
		var cols := [["P", w - 300], ["W", w - 245], ["L", w - 190], ["NRR", w - 110], ["PTS", w - 30]]
		draw_rect(Rect2(0, 0, w, 30), Color(1, 1, 1, 0.06))
		draw_string(f, Vector2(10, 22), "TEAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Hud.DIM)
		for c: Array in cols:
			draw_string(f, Vector2(float(c[1]) - 30, 22), str(c[0]), HORIZONTAL_ALIGNMENT_RIGHT, 60, 18, Hud.DIM)
		var y := 34.0
		for i in rows.size():
			var r: Dictionary = rows[i]
			if str(r.code) == me:
				draw_style_box(Hud.pill_box(Color(Hud.GOLD.r, Hud.GOLD.g, Hud.GOLD.b, 0.16), 10), Rect2(0, y, w, 44))
			var t := IplData.team(str(r.code))
			draw_string(Hud.font("bold"), Vector2(10, y + 31), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Hud.DIM)
			draw_rect(Rect2(44, y + 10, 8, 26), t.kit)
			draw_string(Hud.font("bold"), Vector2(62, y + 31), str(r.code), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Hud.TEXT)
			var vals := [str(r.p), str(r.w), str(r.l), "%+.3f" % float(r.nrr), str(r.pts)]
			for j in cols.size():
				draw_string(Hud.font("bold" if j == 4 else "semi"), Vector2(float(cols[j][1]) - 40, y + 31), vals[j],
					HORIZONTAL_ALIGNMENT_RIGHT, 70, 26 if j == 4 else 22, Hud.GOLD if j == 4 else Hud.TEXT)
			if i == 3:
				draw_line(Vector2(0, y + 45), Vector2(w, y + 45), Color(Hud.GOLD.r, Hud.GOLD.g, Hud.GOLD.b, 0.6), 2.0)
			y += 46.0
