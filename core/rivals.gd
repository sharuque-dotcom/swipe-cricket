class_name Rivals
extends RefCounted
## Bowlers remember you. Every ball you face is kept against the bowler's name, across
## matches: balls, runs, and how they got you out. A bowler who keeps getting you comes back
## with the same plan, and the card says so when he comes on.

const PATH := "user://rivals.json"

static var _data := {}
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			_data = d

static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data))

## A ball faced from `bowler`: runs off the bat, and how out ("" if not).
static func record(bowler: String, runs: int, how_out: String) -> void:
	_load()
	var r: Dictionary = _data.get(bowler, {"balls": 0, "runs": 0, "outs": 0, "hows": []})
	r.balls = int(r.balls) + 1
	r.runs = int(r.runs) + runs
	if how_out != "" and not how_out.begins_with("run out"):
		r.outs = int(r.outs) + 1
		var hows: Array = r.hows
		hows.append(_kind(how_out))
		r.hows = hows.slice(maxi(hows.size() - 6, 0))
	_data[bowler] = r
	_save()

static func get_record(bowler: String) -> Dictionary:
	_load()
	return _data.get(bowler, {})

## How a dismissal reads as a weakness: "stumps" (bowled, lbw), "edge" (keeper, slips),
## "deep" (caught in the deep), "stumped", or "caught".
static func _kind(how: String) -> String:
	if how.begins_with("b ") or how.begins_with("lbw"):
		return "stumps"
	if how.begins_with("st "):
		return "stumped"
	if how.contains("keeper") or how.contains("slip"):
		return "edge"
	if how.contains("deep") or how.contains("long") or how.contains("third man") or how.contains("fine leg"):
		return "deep"
	return "caught"

static func _most(hows: Array) -> String:
	var count := {}
	var best := ""
	for h in hows:
		count[h] = int(count.get(h, 0)) + 1
		if best == "" or int(count[h]) > int(count[best]):
			best = str(h)
	return best

## The bowler's plan against you, if he has one: "straight" at the stumps, "wide" for the
## edge, "short" to tempt the hook into the deep. "" if he hasn't worked you out.
static func plan(bowler: String) -> String:
	var r := get_record(bowler)
	if int(r.get("outs", 0)) < 2:
		return ""
	return {"stumps": "straight", "edge": "wide", "deep": "short"}.get(_most(r.get("hows", [])), "")

## One line for the bowler's card, or "" if there's no history worth telling.
static func line(bowler: String) -> String:
	var r := get_record(bowler)
	var balls := int(r.get("balls", 0))
	var outs := int(r.get("outs", 0))
	if balls < 6 and outs == 0:
		return ""
	var runs := int(r.get("runs", 0))
	var head := "%d off %d" % [runs, balls]
	if outs >= 2:
		var how: String = {"stumps": "attacks your stumps", "edge": "goes for the edge", "deep": "tempts you into the deep",
			"stumped": "lures you out", "caught": "has your number"}.get(_most(r.get("hows", [])), "has your number")
		return "RIVAL  ·  has had you out %d times  ·  %s  ·  %s" % [outs, head, how]
	if outs == 1:
		return "Has had you out once  ·  %s" % head
	if float(runs) / balls >= 1.6:
		return "You've had the better of him  ·  %s" % head
	return "You've faced him before  ·  %s" % head
