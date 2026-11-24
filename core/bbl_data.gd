class_name BblData
extends RefCounted
## BBL|16 (2026-27): the eight clubs, their squads, a first-choice XI in batting order, the
## five who bowl, the forty league fixtures and the finals.
##
## Squads, fixtures and venues: the 2026-27 Big Bash League season page on Wikipedia (squads
## as of 13 November 2026; schedule released by Cricket Australia on 13-14 July 2026).
## Batting orders, ratings [power, timing] and bowling styles are this game's own judgement.
## For personal use only: real names, no logos. Bowling styles are IplData.STYLES.

const TITLE := "BBL|16"
const LEAGUE_NAME := "Big Bash League"
## Finals: 1st v 2nd (Qualifier), 3rd v 4th (Knockout), the Qualifier's loser v the
## Knockout's winner (Challenger), then the Final.
const PICK_TEXT := "Play BBL|16 with a real squad: all 40 league fixtures in order from the Chennai opener, the table, the Power Surge, and the finals. You bat; every other match is played out for you."
const SQUAD_NOTE := "Squads as of 13 November 2026. Batting orders and ratings are the game's own."
const STAGES := ["Qualifier", "Knockout", "Challenger", "Final"]
## Big Bash first innings average a little lower than the IPL's.
const PAR := 1.14
const STYLES := IplData.STYLES

const TEAMS := {
	"AS": {"name": "Adelaide Strikers", "short": "STRIKERS", "kit": Color(0.0, 0.62, 0.87), "trim": Color(0.04, 0.12, 0.30),
		"home": "Adelaide Oval", "captain": "Matt Short",
		"xi": [["Matt Short", "Opener", 0.88, 0.80], ["Mackenzie Harvey", "Opener", 0.80, 0.78], ["Mark Chapman", "Top order", 0.82, 0.80],
			["Ben Stokes", "All-rounder", 0.88, 0.82], ["Alex Carey", "Wicketkeeper", 0.76, 0.86], ["Jason Sangha", "Middle order", 0.70, 0.80],
			["Thomas Kelly", "All-rounder", 0.80, 0.60], ["Liam Scott", "All-rounder", 0.66, 0.60], ["Henry Thornton", "Bowler", 0.30, 0.25],
			["Haris Rauf", "Bowler", 0.30, 0.20], ["Lloyd Pope", "Bowler", 0.20, 0.20]],
		"attack": [["Haris Rauf", "rf", 0.88], ["Henry Thornton", "rf", 0.80], ["Ben Stokes", "rft", 0.80],
			["Lloyd Pope", "lb", 0.82], ["Matt Short", "ob", 0.72]],
		"squad": ["Matt Short", "Alex Carey", "Mark Chapman*", "Mackenzie Harvey", "Thomas Kelly", "Lloyd Pope", "Haris Rauf*",
			"Jason Sangha", "Liam Scott", "Ben Stokes*", "Tom Straker", "Harjas Singh", "Henry Thornton", "Jerrssis Wadia"]},
	"BH": {"name": "Brisbane Heat", "short": "HEAT", "kit": Color(0.0, 0.70, 0.77), "trim": Color(0.98, 0.84, 0.22),
		"home": "The Gabba", "captain": "",
		"xi": [["Matt Renshaw", "Opener", 0.78, 0.84], ["Max Bryant", "Opener", 0.88, 0.70], ["Usman Khawaja", "Top order", 0.70, 0.92],
			["Tim Robinson", "Top order", 0.84, 0.74], ["Nathan McSweeney", "Middle order", 0.70, 0.84], ["Jimmy Peirson", "Wicketkeeper", 0.74, 0.76],
			["Jack Wildermuth", "All-rounder", 0.78, 0.62], ["Tom Curran", "All-rounder", 0.72, 0.62], ["Michael Neser", "All-rounder", 0.66, 0.60],
			["Xavier Bartlett", "Bowler", 0.45, 0.35], ["Spencer Johnson", "Bowler", 0.30, 0.20]],
		"attack": [["Spencer Johnson", "lf", 0.86], ["Xavier Bartlett", "rms", 0.84], ["Michael Neser", "rms", 0.82],
			["Matthew Kuhnemann", "sla", 0.80], ["Tom Curran", "rm", 0.76]],
		"squad": ["Xavier Bartlett", "Max Bryant", "Tom Curran*", "Lachlan Hearne", "Bevon Jacobs*", "Spencer Johnson",
			"Usman Khawaja", "Matthew Kuhnemann", "Nathan McSweeney", "Michael Neser", "Jimmy Peirson", "Matt Renshaw",
			"Tim Robinson*", "Callum Vidler", "Hugh Weibgen", "Jack Wildermuth"]},
	"HH": {"name": "Hobart Hurricanes", "short": "HURRICANES", "kit": Color(0.41, 0.21, 0.61), "trim": Color(0.98, 0.84, 0.30),
		"home": "Bellerive Oval", "captain": "Nathan Ellis",
		"xi": [["Mitchell Owen", "Opener", 0.96, 0.70], ["Ben McDermott", "Wicketkeeper", 0.86, 0.76], ["Shai Hope", "Top order", 0.74, 0.88],
			["Jake Weatherald", "Top order", 0.82, 0.76], ["Tim David", "Power hitter", 0.98, 0.72], ["Beau Webster", "All-rounder", 0.78, 0.74],
			["Nikhil Chaudhary", "All-rounder", 0.80, 0.62], ["Nathan Ellis", "Bowler", 0.45, 0.40], ["Rishad Hossain", "Bowler", 0.45, 0.35],
			["Riley Meredith", "Bowler", 0.25, 0.20], ["Billy Stanlake", "Bowler", 0.20, 0.15]],
		"attack": [["Riley Meredith", "rf", 0.82], ["Nathan Ellis", "rm", 0.88], ["Billy Stanlake", "rft", 0.80],
			["Rishad Hossain", "lb", 0.82], ["Nikhil Chaudhary", "lb", 0.74]],
		"squad": ["Nathan Ellis", "Marcus Bean", "Iain Carlisle", "Nikhil Chaudhary", "Tim David", "Nick Hobson", "Shai Hope*",
			"Rishad Hossain*", "Ben McDermott", "Riley Meredith", "Mitchell Owen", "Will Prestwidge", "Billy Stanlake", "Tim Ward",
			"Jake Weatherald", "Beau Webster", "Adam Zampa"]},
	"MR": {"name": "Melbourne Renegades", "short": "RENEGADES", "kit": Color(0.86, 0.08, 0.12), "trim": Color(0.08, 0.08, 0.10),
		"home": "MCG", "captain": "Will Sutherland",
		"xi": [["Jake Fraser-McGurk", "Opener", 0.97, 0.62], ["Josh Brown", "Opener", 0.92, 0.64], ["Jonny Bairstow", "Wicketkeeper", 0.90, 0.80],
			["Caleb Jewell", "Top order", 0.76, 0.76], ["Oliver Peake", "Middle order", 0.76, 0.80], ["Will Sutherland", "All-rounder", 0.82, 0.68],
			["Michael Bracewell", "All-rounder", 0.78, 0.72], ["Tom Rogers", "Bowler", 0.40, 0.30], ["Callum Stow", "Bowler", 0.30, 0.30],
			["Brendan Doggett", "Bowler", 0.25, 0.20], ["Mustafizur Rahman", "Bowler", 0.20, 0.15]],
		"attack": [["Mustafizur Rahman", "lfm", 0.86], ["Brendan Doggett", "rf", 0.78], ["Will Sutherland", "rm", 0.80],
			["Tom Rogers", "rms", 0.78], ["Callum Stow", "lb", 0.76]],
		"squad": ["Will Sutherland", "Michael Archer", "Jonny Bairstow*", "Michael Bracewell*", "Josh Brown", "Harry Dixon",
			"Brendan Doggett", "Sam Elliott", "Jake Fraser-McGurk", "Caleb Jewell", "Ben Manenti", "Oliver Peake", "Tom Rogers",
			"Mustafizur Rahman*", "Callum Stow"]},
	"MS": {"name": "Melbourne Stars", "short": "STARS", "kit": Color(0.0, 0.69, 0.25), "trim": Color(0.08, 0.10, 0.10),
		"home": "MCG", "captain": "Marcus Stoinis",
		"xi": [["Finn Allen", "Opener", 0.96, 0.70], ["Sam Harper", "Wicketkeeper", 0.80, 0.74], ["Campbell Kellaway", "Top order", 0.72, 0.76],
			["Marcus Stoinis", "All-rounder", 0.92, 0.78], ["Glenn Maxwell", "Power hitter", 0.95, 0.78], ["Hilton Cartwright", "Middle order", 0.76, 0.76],
			["Jamie Overton", "All-rounder", 0.86, 0.58], ["Craig Overton", "All-rounder", 0.60, 0.55], ["Todd Murphy", "Bowler", 0.30, 0.30],
			["Peter Siddle", "Bowler", 0.25, 0.20], ["Mitchell Swepson", "Bowler", 0.20, 0.20]],
		"attack": [["Jamie Overton", "rf", 0.84], ["Craig Overton", "rft", 0.80], ["Peter Siddle", "rm", 0.76],
			["Todd Murphy", "ob", 0.80], ["Mitchell Swepson", "lb", 0.78]],
		"squad": ["Marcus Stoinis", "Finn Allen*", "Austin Anlezark", "Hilton Cartwright", "Sam Harper", "Liam Hatcher",
			"Campbell Kellaway", "Glenn Maxwell", "Todd Murphy", "Craig Overton*", "Jamie Overton*", "Tom Rogers", "Peter Siddle",
			"Mitchell Swepson"]},
	"PS": {"name": "Perth Scorchers", "short": "SCORCHERS", "kit": Color(1.0, 0.50, 0.0), "trim": Color(0.10, 0.08, 0.08),
		"home": "Perth Stadium", "captain": "Ashton Turner",
		"xi": [["Mitchell Marsh", "Opener", 0.94, 0.80], ["Zak Crawley", "Opener", 0.84, 0.80], ["Cooper Connolly", "Top order", 0.86, 0.76],
			["Ashton Turner", "Finisher", 0.88, 0.78], ["Aaron Hardie", "All-rounder", 0.82, 0.72], ["Joel Curtis", "Wicketkeeper", 0.70, 0.72],
			["Ashton Agar", "All-rounder", 0.66, 0.66], ["Jhye Richardson", "Bowler", 0.35, 0.30], ["Joel Paris", "Bowler", 0.30, 0.25],
			["Mahli Beardman", "Bowler", 0.30, 0.25], ["Lance Morris", "Bowler", 0.20, 0.15]],
		"attack": [["Jhye Richardson", "rf", 0.88], ["Lance Morris", "rf", 0.82], ["Joel Paris", "lfm", 0.82],
			["Ashton Agar", "sla", 0.78], ["Cooper Connolly", "sla", 0.72]],
		"squad": ["Ashton Turner", "Ashton Agar", "Mahli Beardman", "Cooper Connolly", "Brody Couch", "Zak Crawley*", "Joel Curtis",
			"Aneurin Donald*", "Albert Esterhuysen", "Aaron Hardie", "Calvin Harrison*", "Will Malajczuk", "Mitchell Marsh",
			"Lance Morris", "Joel Paris", "Jhye Richardson"]},
	"SS": {"name": "Sydney Sixers", "short": "SIXERS", "kit": Color(1.0, 0.0, 0.56), "trim": Color(0.08, 0.08, 0.16),
		"home": "SCG", "captain": "",
		"xi": [["Josh Philippe", "Wicketkeeper", 0.84, 0.80], ["Tim Seifert", "Opener", 0.86, 0.76], ["Steve Smith", "Top order", 0.82, 0.94],
			["Jordan Silk", "Middle order", 0.74, 0.82], ["Lachlan Shaw", "Middle order", 0.80, 0.70], ["Jack Edwards", "All-rounder", 0.86, 0.66],
			["Hayden Kerr", "All-rounder", 0.72, 0.62], ["Sean Abbott", "All-rounder", 0.74, 0.55], ["Ben Dwarshuis", "Bowler", 0.62, 0.50],
			["Chris Jordan", "Bowler", 0.50, 0.40], ["Jafer Chohan", "Bowler", 0.25, 0.20]],
		"attack": [["Ben Dwarshuis", "lfm", 0.84], ["Sean Abbott", "rf", 0.82], ["Chris Jordan", "rf", 0.80],
			["Jafer Chohan", "lb", 0.78], ["Jack Edwards", "rm", 0.72]],
		"squad": ["Sean Abbott", "Jafer Chohan*", "Joel Davies", "Oliver Davies", "Ben Dwarshuis", "Jack Edwards", "Chris Jordan*",
			"Hayden Kerr", "Riley Kingsell", "Fergus O'Neill", "Josh Philippe", "Corey Rocchiccioli", "Jake Scott", "Tim Seifert*",
			"Lachlan Shaw", "Jordan Silk", "Steve Smith"]},
	"ST": {"name": "Sydney Thunder", "short": "THUNDER", "kit": Color(0.59, 0.84, 0.0), "trim": Color(0.14, 0.14, 0.17),
		"home": "Sydney Showground", "captain": "",
		"xi": [["David Warner", "Opener", 0.90, 0.84], ["Sam Konstas", "Opener", 0.82, 0.74], ["Cameron Bancroft", "Top order", 0.70, 0.82],
			["Sam Billings", "Wicketkeeper", 0.80, 0.80], ["Nic Maddinson", "Middle order", 0.80, 0.72], ["Matthew Gilkes", "Middle order", 0.74, 0.74],
			["Daniel Sams", "All-rounder", 0.86, 0.60], ["Chris Green", "All-rounder", 0.66, 0.64], ["Tanveer Sangha", "Bowler", 0.25, 0.25],
			["Lockie Ferguson", "Bowler", 0.30, 0.20], ["Trent Boult", "Bowler", 0.30, 0.20]],
		"attack": [["Lockie Ferguson", "rf", 0.88], ["Trent Boult", "lfm", 0.90], ["Daniel Sams", "lf", 0.80],
			["Tanveer Sangha", "lb", 0.82], ["Chris Green", "ob", 0.78]],
		"squad": ["Cameron Bancroft", "Sam Billings*", "Trent Boult*", "Lockie Ferguson*", "Matthew Gilkes", "Chris Green",
			"Ryan Hadley", "Harry Hoekstra", "Sam Konstas", "Aidan O'Connor", "Nic Maddinson", "Will Salzmann", "Daniel Sams",
			"Tanveer Sangha", "David Warner"]},
}

const ORDER := ["AS", "BH", "HH", "MR", "MS", "PS", "SS", "ST"]

## How each ground plays.
const GROUNDS := {"Chennai": "dusty", "The Gabba": "good", "Manuka Oval": "flat", "Bellerive Oval": "green", "MCG": "good",
	"Sydney Showground": "dusty", "Perth Stadium": "green", "Junction Oval": "flat", "SCG": "dusty", "Adelaide Oval": "flat",
	"York Park": "green"}

## League stage: [match, date, home, away, ground].
const FIXTURES := [
	[1, "2026-12-12", "MR", "PS", "Chennai"], [2, "2026-12-15", "BH", "SS", "The Gabba"],
	[3, "2026-12-16", "ST", "AS", "Manuka Oval"], [4, "2026-12-17", "HH", "BH", "Bellerive Oval"],
	[5, "2026-12-18", "MS", "AS", "MCG"], [6, "2026-12-19", "ST", "SS", "Sydney Showground"],
	[7, "2026-12-20", "PS", "HH", "Perth Stadium"], [8, "2026-12-21", "MS", "BH", "Junction Oval"],
	[9, "2026-12-22", "SS", "MR", "SCG"], [10, "2026-12-23", "AS", "ST", "Adelaide Oval"],
	[11, "2026-12-24", "MR", "HH", "Junction Oval"], [12, "2026-12-26", "SS", "BH", "SCG"],
	[13, "2026-12-26", "PS", "MS", "Perth Stadium"], [14, "2026-12-27", "ST", "MR", "Sydney Showground"],
	[15, "2026-12-28", "BH", "AS", "The Gabba"], [16, "2026-12-29", "HH", "MS", "Bellerive Oval"],
	[17, "2026-12-30", "PS", "ST", "Perth Stadium"], [18, "2026-12-31", "AS", "MS", "Adelaide Oval"],
	[19, "2027-01-01", "MR", "SS", "MCG"], [20, "2027-01-01", "BH", "HH", "The Gabba"],
	[21, "2027-01-02", "ST", "PS", "Sydney Showground"], [22, "2027-01-03", "SS", "AS", "Manuka Oval"],
	[23, "2027-01-04", "MS", "MR", "MCG"], [24, "2027-01-04", "PS", "BH", "Perth Stadium"],
	[25, "2027-01-05", "HH", "ST", "Bellerive Oval"], [26, "2027-01-06", "AS", "MR", "Adelaide Oval"],
	[27, "2027-01-07", "MS", "SS", "MCG"], [28, "2027-01-08", "BH", "PS", "The Gabba"],
	[29, "2027-01-09", "HH", "AS", "York Park"], [30, "2027-01-10", "SS", "PS", "SCG"],
	[31, "2027-01-10", "MR", "BH", "Junction Oval"], [32, "2027-01-11", "ST", "MS", "Manuka Oval"],
	[33, "2027-01-12", "AS", "HH", "Adelaide Oval"], [34, "2027-01-13", "PS", "MR", "Perth Stadium"],
	[35, "2027-01-14", "MS", "HH", "MCG"], [36, "2027-01-15", "SS", "ST", "SCG"],
	[37, "2027-01-16", "AS", "PS", "Adelaide Oval"], [38, "2027-01-16", "MR", "MS", "MCG"],
	[39, "2027-01-17", "HH", "SS", "Bellerive Oval"], [40, "2027-01-17", "BH", "ST", "The Gabba"],
]
## Matches played in the day (the rest are night games).
const DAY := [17, 19, 30, 37, 39]

## Finals venues were still to be confirmed: they go to the higher-placed side's ground.
const PLAYOFFS := [["Qualifier", "2027-01-19", ""], ["Knockout", "2027-01-20", ""],
	["Challenger", "2027-01-23", ""], ["Final", "2027-01-26", ""]]

static func day_game(f: Dictionary) -> bool:
	return str(f.stage) == "League" and int(f.n) in DAY

static func register_bowlers() -> void:
	for code in TEAMS:
		for a: Array in TEAMS[code].attack:
			var p: Dictionary = STYLES[str(a[1])].duplicate(true)
			var q := float(a[2])
			p.pace = [float(p.pace[0]) * (0.95 + 0.05 * q), float(p.pace[1]) * (0.95 + 0.05 * q)]
			if p.has("swing"):
				p.swing = float(p.swing) * (0.8 + 0.3 * q)
			BowlerProfile.EXTRA[str(a[0])] = p

static func team(code: String) -> Dictionary:
	return TEAMS[code]

static func xi_names(code: String) -> Array:
	var out := []
	for p: Array in TEAMS[code].xi:
		out.append(str(p[0]))
	return out

static func attack_names(code: String) -> Array:
	var out := []
	for a: Array in TEAMS[code].attack:
		out.append(str(a[0]))
	return out

static func batting_strength(code: String) -> float:
	var s := 0.0
	var xi: Array = TEAMS[code].xi
	for i in 7:
		s += (float(xi[i][2]) + float(xi[i][3])) * 0.5
	return s / 7.0

static func bowling_strength(code: String) -> float:
	var s := 0.0
	for a: Array in TEAMS[code].attack:
		s += float(a[2])
	return s / 5.0
