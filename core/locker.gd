class_name Locker
extends RefCounted
## Things you earn by playing well, and wear: bat stickers, helmet colours and celebrations.
## Each achievement unlocks one item; equipped items are saved in the settings file.

## id: [title, how to earn it, slot, item id, item name]
const ACHIEVEMENTS := {
	"fifty": ["First fifty", "Make 50 in an innings", "bat", "gold", "Gold bat sticker"],
	"hundred": ["Three figures", "Make a hundred", "helmet", "gold", "Gold helmet"],
	"five_sixes": ["Clearing the rope", "Hit five sixes in an innings", "bat", "flame", "Flame bat sticker"],
	"big_chase": ["Ice in the veins", "Win a chase that needed 12 an over in the last five", "celebration", "roar", "The roar"],
	"daily3": ["Habit", "A three-day Chase of the Day streak", "helmet", "black", "Black helmet"],
	"surge30": ["Surge", "Score 30 in a Power Surge", "bat", "neon", "Neon bat sticker"],
	"rival_six": ["Payback", "Hit a rival for six", "celebration", "point", "Point to the sky"],
	"champions": ["Champions", "Win an IPL or BBL title", "helmet", "silver", "Silver helmet"],
}
const DEFAULTS := {"bat": "", "helmet": "", "celebration": ""}
const BAT_COLOURS := {"gold": Color(1.0, 0.78, 0.2), "flame": Color(1.0, 0.42, 0.1), "neon": Color(0.2, 1.0, 0.6)}
const HELMET_COLOURS := {"gold": Color(0.85, 0.65, 0.15), "black": Color(0.06, 0.06, 0.08), "silver": Color(0.72, 0.74, 0.78)}

static func _cf() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	return cf

static func unlocked(id: String) -> bool:
	return bool(_cf().get_value("locker", id, false))

## Unlocks an achievement. Returns true the first time (so the game can announce it).
static func unlock(id: String) -> bool:
	if not ACHIEVEMENTS.has(id) or unlocked(id):
		return false
	var cf := _cf()
	cf.set_value("locker", id, true)
	# The first thing you earn in a slot goes straight on.
	var slot := str(ACHIEVEMENTS[id][2])
	if str(cf.get_value("equipped", slot, "")) == "":
		cf.set_value("equipped", slot, str(ACHIEVEMENTS[id][3]))
	cf.save(Settings.PATH)
	return true

static func equipped(slot: String) -> String:
	return str(_cf().get_value("equipped", slot, ""))

static func equip(slot: String, item: String) -> void:
	var cf := _cf()
	cf.set_value("equipped", slot, item)
	cf.save(Settings.PATH)

## Everything unlocked so far, by slot: {slot: [[item, name], ...]}.
static func items() -> Dictionary:
	var out := {"bat": [], "helmet": [], "celebration": []}
	for id in ACHIEVEMENTS:
		if unlocked(id):
			var a: Array = ACHIEVEMENTS[id]
			out[str(a[2])].append([str(a[3]), str(a[4])])
	return out

static func bat_colour() -> Color:
	return BAT_COLOURS.get(equipped("bat"), Color(0, 0, 0, 0))

static func helmet_colour() -> Color:
	return HELMET_COLOURS.get(equipped("helmet"), Color(0, 0, 0, 0))

## After a finished match: which achievements it earned (newly).
static func check_match(m: MatchState) -> Array:
	var got := []
	for b in m.batters:
		if int(b.runs) >= 50 and unlock("fifty"):
			got.append("fifty")
		if int(b.runs) >= 100 and unlock("hundred"):
			got.append("hundred")
		if int(b.sixes) >= 5 and unlock("five_sixes"):
			got.append("five_sixes")
	if m.won() and m.hard_chase and unlock("big_chase"):
		got.append("big_chase")
	if m.surge_runs >= 30 and unlock("surge30"):
		got.append("surge30")
	return got

static func title(id: String) -> String:
	return str(ACHIEVEMENTS[id][0])

static func reward(id: String) -> String:
	return str(ACHIEVEMENTS[id][4])
