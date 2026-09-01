class_name GameRules
extends Object
## Pure baseball rules shared by the Godot session.
## Keep tables in sync with game-rules.js.

const TOTAL_INNINGS := 3
const BALLS_FOR_WALK := 4
const STRIKES_FOR_OUT := 3
const OUTS_PER_INNING := 3
const IN_ZONE_CHANCE := 0.82
const AUTO_PITCH_MIN := 3.0
const AUTO_PITCH_MAX := 15.0

const CHARACTER_ORDER := ["meow_white", "meow_boo", "meow_mi"]
const TEAM_ORDER := ["home", "away"]

const CHARACTERS := {
	"meow_white": {
		"id": "meow_white",
		"name": "喵白白",
		"role": "pitcher",
		"role_label": "投手",
		"number": "#1",
		"blurb": "主場王牌，球速快、節奏穩。",
		"art": "pitcher-v2.png"
	},
	"meow_boo": {
		"id": "meow_boo",
		"name": "喵布布",
		"role": "batter",
		"role_label": "打者",
		"number": "#B",
		"blurb": "揮棒果斷，擅長抓準甜蜜點。",
		"art": "batter-v2.png"
	},
	"meow_mi": {
		"id": "meow_mi",
		"name": "咪嚕",
		"role": "batter",
		"role_label": "打者",
		"number": "#7",
		"blurb": "外野砲，安打後推進特別積極。",
		"art": "runner-v1.png"
	}
}

const TEAMS := {
	"home": {
		"id": "home",
		"name": "喵白白隊",
		"short": "HOME CAT  ·  喵白白",
		"art": "home-crest-v1.png"
	},
	"away": {
		"id": "away",
		"name": "喵布布隊",
		"short": "AWAY CAT  ·  喵布布",
		"art": "away-crest-v1.png"
	}
}

const PITCHES := {
	"fastball": {"label": "快速球", "speed": 145, "duration": 1.06, "ideal": 0.86},
	"curveball": {"label": "曲球", "speed": 118, "duration": 1.40, "ideal": 0.91},
	"slider": {"label": "滑球", "speed": 126, "duration": 1.22, "ideal": 0.88},
	"changeup": {"label": "變速球", "speed": 108, "duration": 1.52, "ideal": 0.82}
}

const PITCH_ORDER := ["fastball", "curveball", "slider", "changeup"]

const COACH_NOTES := [
	"Perfect 的視窗很短，先盯著球進入好球帶。",
	"瞄準格只影響接觸點；先猜球，再用時機補救。",
	"兩好球後別急著追壞球，讓投手自己送一個保送。",
	"連續安打會疊 COMBO，下一球的飛行距離也會更漂亮。"
]

const OUTCOME_LABELS := {
	"homerun": "全壘打！",
	"triple": "三壘安打",
	"double": "二壘安打",
	"single": "一壘安打",
	"foul": "界外球",
	"out": "守備接殺"
}

const OUTCOME_TABLES := {
	"PERFECT": [["homerun", 0.16], ["triple", 0.08], ["double", 0.28], ["single", 0.43], ["foul", 0.02], ["out", 0.03]],
	"GOOD": [["homerun", 0.07], ["triple", 0.06], ["double", 0.24], ["single", 0.43], ["foul", 0.08], ["out", 0.12]],
	"EARLY": [["homerun", 0.015], ["triple", 0.025], ["double", 0.12], ["single", 0.31], ["foul", 0.28], ["out", 0.25]],
	"LATE": [["homerun", 0.012], ["triple", 0.02], ["double", 0.14], ["single", 0.30], ["foul", 0.29], ["out", 0.238]]
}

static func classify_timing(progress: float, ideal: float) -> Dictionary:
	var delta := progress - ideal
	var distance := absf(delta)
	if distance <= 0.035:
		return {"grade": "PERFECT", "label": "PERFECT!"}
	if distance <= 0.09:
		return {"grade": "GOOD", "label": "GOOD!"}
	if distance <= 0.19:
		return {"grade": "EARLY" if delta < 0.0 else "LATE", "label": "EARLY" if delta < 0.0 else "LATE"}
	return {"grade": "MISS", "label": "MISS"}


static func zone_row(zone: int) -> int:
	return int(zone / 3)


static func grid_distance(a: int, b: int) -> int:
	if b < 0:
		return 2
	return absi(zone_row(a) - zone_row(b)) + absi((a % 3) - (b % 3))


static func move_aim(aim: int, keycode: int) -> int:
	var row := zone_row(aim)
	var col := aim % 3
	match keycode:
		KEY_UP:
			row = maxi(0, row - 1)
		KEY_DOWN:
			row = mini(2, row + 1)
		KEY_LEFT:
			col = maxi(0, col - 1)
		KEY_RIGHT:
			col = mini(2, col + 1)
	return clampi(row * 3 + col, 0, 8)


static func bases_advanced(key: String) -> int:
	match key:
		"homerun":
			return 4
		"triple":
			return 3
		"double":
			return 2
		"single":
			return 1
		_:
			return 0


static func advance_runners(bases: Array, distance: int, home_run: bool) -> Dictionary:
	var current: Array = bases.duplicate()
	var runs := 0
	if home_run or distance >= 4:
		runs = 1
		for occupied in current:
			if occupied:
				runs += 1
		return {"bases": [false, false, false], "runs": runs}
	var next: Array = [false, false, false]
	for index in range(2, -1, -1):
		if not current[index]:
			continue
		var destination := int(index) + distance
		if destination >= 3:
			runs += 1
		else:
			next[destination] = true
	var batter_destination := distance - 1
	if batter_destination >= 3:
		runs += 1
	else:
		next[batter_destination] = true
	return {"bases": next, "runs": runs}


static func force_walk(bases: Array) -> Dictionary:
	var next: Array = bases.duplicate()
	var runs := 0
	if bool(next[0]) and bool(next[1]) and bool(next[2]):
		runs = 1
	if bool(next[0]) and bool(next[1]):
		next[2] = true
	elif bool(next[0]):
		next[1] = true
	next[0] = true
	return {"bases": next, "runs": runs}


static func opponent_runs(roll: float) -> int:
	if roll >= 0.82:
		return 2
	if roll >= 0.35:
		return 1
	return 0


static func auto_pitch_delay(roll: float) -> float:
	return AUTO_PITCH_MIN + clampf(roll, 0.0, 1.0) * (AUTO_PITCH_MAX - AUTO_PITCH_MIN)


static func cpu_pick_pitch(rng: RandomNumberGenerator) -> String:
	return PITCH_ORDER[rng.randi_range(0, PITCH_ORDER.size() - 1)]


static func cpu_batter_plan(in_zone: bool, ideal: float, rng: RandomNumberGenerator) -> Dictionary:
	var swing_chance := 0.88 if in_zone else 0.22
	if rng.randf() > swing_chance:
		return {"action": "take", "progress": 0.0}
	var progress := clampf(ideal + rng.randf_range(-0.12, 0.12), 0.52, 0.97)
	if rng.randf() < 0.08:
		progress = 0.40
	return {"action": "swing", "progress": progress}


static func cpu_swing_aim(pitch_zone: int, rng: RandomNumberGenerator) -> int:
	if pitch_zone < 0:
		return rng.randi_range(0, 8)
	if rng.randf() < 0.5:
		return pitch_zone
	return clampi(pitch_zone + rng.randi_range(-2, 2), 0, 8)


static func art_path(filename: String) -> String:
	return "res://assets/generated/" + filename


static func roll_outcome(grade: String, aim_distance: int, rng: RandomNumberGenerator) -> Dictionary:
	var source: Array = OUTCOME_TABLES.get(grade, OUTCOME_TABLES["GOOD"])
	var weights: Array = []
	for item in source:
		weights.append([item[0], item[1]])
	var nudge := minf(0.18, float(aim_distance) * 0.055)
	for item in weights:
		if item[0] == "out":
			item[1] += nudge
		elif item[0] == "homerun":
			item[1] = maxf(0.005, float(item[1]) - nudge * 0.5)
		elif item[0] == "single" or item[0] == "double":
			item[1] = maxf(0.01, float(item[1]) - nudge * 0.18)
	var total := 0.0
	for item in weights:
		total += float(item[1])
	var roll := rng.randf() * total
	var selected := "out"
	for item in weights:
		roll -= float(item[1])
		if roll <= 0.0:
			selected = str(item[0])
			break
	var flight := _flight_for(selected, rng)
	return {
		"key": selected,
		"label": OUTCOME_LABELS[selected],
		"flight_x": flight.x,
		"flight_y": flight.y
	}


static func _flight_for(key: String, rng: RandomNumberGenerator) -> Vector2:
	match key:
		"homerun":
			return Vector2(0.88, 0.08)
		"triple":
			return Vector2(0.82, 0.18)
		"double":
			return Vector2(0.76, 0.27)
		"single":
			return Vector2(0.68, 0.36)
		"foul":
			return Vector2(0.24 + rng.randf() * 0.22, 0.17 + rng.randf() * 0.11)
		_:
			return Vector2(0.54 + rng.randf() * 0.20, 0.21 + rng.randf() * 0.26)


static func copy_bases(source: Array) -> Array[bool]:
	var next: Array[bool] = [false, false, false]
	for index in range(mini(3, source.size())):
		next[index] = bool(source[index])
	return next
