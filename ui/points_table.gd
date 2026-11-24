class_name PointsTable
extends Control
## The points table, drawn: position, team, played, won, lost, net run rate, points.
var rows: Array = []
var me := ""
var league: GDScript = IplData   # IplData or BblData, for the team colours

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
		var t: Dictionary = league.team(str(r.code))
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
