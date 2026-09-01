class_name GameSession
extends RefCounted
## Mutable match state. Presentation (UI, stadium, timers) stays outside.

var rng := RandomNumberGenerator.new()

var inning := 1
var outs := 0
var balls := 0
var strikes := 0
var player_score := 0
var rival_score := 0
var inning_runs: Array = [null, null, null, null, null, null, null, null, null]
var away_inning_runs: Array = [null, null, null, null, null, null, null, null, null]
var home_inning_runs: Array = [null, null, null, null, null, null, null, null, null]
var bases: Array[bool] = [false, false, false]
var selected_pitch := "fastball"
var aim_zone := 4
var active_pitch: Dictionary = {}
var resolving := false
var game_over := false
var game_started := false
var match_ready := false
var character_id := "meow_white"
var team_id := "home"
var half := "top"
var combo := 0
var hits := 0
var perfects := 0
var total_runs := 0

func _init() -> void:
	rng.randomize()


func reset() -> void:
	inning = 1
	outs = 0
	balls = 0
	strikes = 0
	player_score = 0
	rival_score = 0
	inning_runs = [null, null, null, null, null, null, null, null, null]
	away_inning_runs = [null, null, null, null, null, null, null, null, null]
	home_inning_runs = [null, null, null, null, null, null, null, null, null]
	bases = [false, false, false]
	active_pitch.clear()
	resolving = false
	game_over = false
	game_started = false
	match_ready = false
	half = "top"
	combo = 0
	hits = 0
	perfects = 0
	total_runs = 0
	selected_pitch = "fastball"
	aim_zone = 4


func is_live_pitch() -> bool:
	return not active_pitch.is_empty()


func can_choose() -> bool:
	return match_ready and active_pitch.is_empty() and not resolving and not game_over


func configure(next_character: String, next_team: String) -> bool:
	if not GameRules.CHARACTERS.has(next_character) or not GameRules.TEAMS.has(next_team):
		return false
	character_id = next_character
	team_id = next_team
	half = "top"
	match_ready = true
	return true


func player_character() -> Dictionary:
	return GameRules.CHARACTERS[character_id]


func player_team() -> Dictionary:
	return GameRules.TEAMS[team_id]


func rival_team() -> Dictionary:
	var rival_id := "away" if team_id == "home" else "home"
	return GameRules.TEAMS[rival_id]


func player_role() -> String:
	return str(player_character()["role"])


func is_pitcher() -> bool:
	return player_role() == "pitcher"


func is_batter() -> bool:
	return player_role() == "batter"


func is_player_offense() -> bool:
	if half == "top":
		return team_id == "away"
	return team_id == "home"


func is_fielding() -> bool:
	return not is_player_offense()


func half_label() -> String:
	return "上半局" if half == "top" else "下半局"


func batting_side() -> String:
	return "away" if half == "top" else "home"


func away_score() -> int:
	return player_score if team_id == "away" else rival_score


func home_score() -> int:
	return player_score if team_id == "home" else rival_score


func batting_team() -> Dictionary:
	return GameRules.TEAMS[batting_side()]


func choose_cpu_pitch() -> String:
	selected_pitch = GameRules.cpu_pick_pitch(rng)
	return selected_pitch


func auto_pitch_delay() -> float:
	return GameRules.auto_pitch_delay(rng.randf())


func cpu_batter_plan() -> Dictionary:
	if active_pitch.is_empty():
		return {"action": "take", "progress": 0.0}
	return GameRules.cpu_batter_plan(bool(active_pitch["in_zone"]), float(active_pitch["ideal"]), rng)


func select_pitch(name: String) -> bool:
	if not GameRules.PITCHES.has(name):
		return false
	selected_pitch = name
	return true


func select_aim(index: int) -> void:
	aim_zone = clampi(index, 0, 8)


func move_aim(keycode: int) -> void:
	aim_zone = GameRules.move_aim(aim_zone, keycode)


func pitch_definition() -> Dictionary:
	return GameRules.PITCHES[selected_pitch]


func start_pitch() -> Dictionary:
	if game_over:
		return {"ok": false, "restart": true}
	if not match_ready or not active_pitch.is_empty() or resolving:
		return {"ok": false, "restart": false}
	game_started = true
	var definition: Dictionary = pitch_definition()
	var in_zone := rng.randf() > (1.0 - GameRules.IN_ZONE_CHANCE)
	var zone := -1
	if in_zone:
		zone = aim_zone if is_fielding() else rng.randi_range(0, 8)
	active_pitch = definition.duplicate()
	active_pitch["zone"] = zone
	active_pitch["in_zone"] = in_zone
	return {
		"ok": true,
		"restart": false,
		"kind": selected_pitch,
		"duration": float(definition["duration"]),
		"zone": zone,
		"label": str(definition["label"]),
		"speed": int(definition["speed"])
	}


func resolve_take() -> Dictionary:
	if active_pitch.is_empty() or resolving:
		return {"ok": false}
	var in_zone := bool(active_pitch["in_zone"])
	active_pitch.clear()
	if in_zone:
		return _apply_strike("看球好球", 0.90, "CALLED STRIKE", "strike")
	return _apply_ball(0.90, "BALL", "")


func swing(progress: float, swing_aim: int = -1) -> Dictionary:
	if active_pitch.is_empty():
		var toast := ""
		if not game_over and not resolving and is_player_offense():
			toast = "等投手把球投進來再揮棒！"
		return {"ok": false, "toast": toast}
	var pitch := active_pitch.duplicate()
	active_pitch.clear()
	var used_aim := aim_zone if swing_aim < 0 else clampi(swing_aim, 0, 8)
	var timing := GameRules.classify_timing(progress, float(pitch["ideal"]))
	if str(timing["grade"]) == "MISS":
		var miss := _apply_strike("揮棒落空", 0.92, "SWING & MISS", "strike")
		miss["timing"] = timing
		miss["cancel_pitch"] = true
		return miss
	var distance := GameRules.grid_distance(used_aim, int(pitch["zone"])) if bool(pitch["in_zone"]) else 2
	var outcome := GameRules.roll_outcome(str(timing["grade"]), distance, rng)
	if str(timing["grade"]) == "PERFECT" and is_player_offense():
		perfects += 1
	var result := _apply_contact(timing, outcome)
	result["timing"] = timing
	result["outcome"] = outcome
	result["play_hit"] = true
	result["cancel_pitch"] = false
	return result


func switch_half() -> Dictionary:
	_clear_diamond()
	resolving = true
	if half == "top":
		if inning >= GameRules.TOTAL_INNINGS and _home_ahead():
			return _end_game()
		half = "bottom"
		return _half_change("攻守轉換", "下半局開始", "客隊三人出局，換邊。", "第 " + str(inning) + " 局下半開始")
	if inning >= GameRules.TOTAL_INNINGS:
		return _end_game()
	inning += 1
	half = "top"
	return _half_change("INNING " + str(inning), "第 " + str(inning) + " 局上半開始", "攻守再轉換，客隊先攻。", "第 " + str(inning) + " 局開始")


func advance_inning() -> Dictionary:
	return switch_half()


func prepare_next_pitch() -> void:
	resolving = false
	active_pitch.clear()


func _apply_strike(reason: String, delay: float, burst: String, burst_kind: String) -> Dictionary:
	strikes += 1
	combo = 0
	if strikes >= GameRules.STRIKES_FOR_OUT:
		return _apply_out("三振！" + reason, delay + 0.12, burst, burst_kind)
	return _wait_prepare("再來一球，抓住節奏。", delay, burst, burst_kind)


func _apply_ball(delay: float, burst: String, burst_kind: String) -> Dictionary:
	balls += 1
	combo = 0
	if balls >= GameRules.BALLS_FOR_WALK:
		var walked := GameRules.force_walk(bases)
		bases = GameRules.copy_bases(walked["bases"])
		_add_runs(int(walked["runs"]))
		balls = 0
		strikes = 0
		return _wait_prepare("四壞保送，跑者推進。", delay + 0.12, "WALK", burst_kind)
	return _wait_prepare("壞球，耐心等。", delay, burst, burst_kind)


func _apply_contact(timing: Dictionary, outcome: Dictionary) -> Dictionary:
	var key := str(outcome["key"])
	if key == "foul":
		combo = 0
		if strikes < 2:
			strikes += 1
		var foul_message := "界外球，兩好球後不再追加。" if strikes >= 2 else "界外球，再來。"
		return _wait_prepare(foul_message, 0.98, str(timing["label"]), "")
	if key == "out":
		return _apply_out(str(timing["label"]) + " · 守備接殺", 1.02, str(timing["label"]), "")
	if is_player_offense():
		hits += 1
		combo += 1
	else:
		combo = 0
	var distance := GameRules.bases_advanced(key)
	var moved := GameRules.advance_runners(bases, distance, key == "homerun")
	bases = GameRules.copy_bases(moved["bases"])
	var runs := int(moved["runs"])
	_add_runs(runs)
	balls = 0
	strikes = 0
	var combo_text := " · COMBO ×" + str(combo) if combo > 1 else ""
	var run_text := " · " + str(runs) + " 分進帳" if runs > 0 else ""
	return _wait_prepare(str(outcome["label"]) + run_text, 1.25 if key == "homerun" else 1.02, str(outcome["label"]) + combo_text, "perfect" if key == "homerun" else "")


func _apply_out(reason: String, delay: float, burst: String, burst_kind: String) -> Dictionary:
	outs += 1
	balls = 0
	strikes = 0
	combo = 0
	if outs >= GameRules.OUTS_PER_INNING:
		resolving = true
		active_pitch.clear()
		return {
			"ok": true,
			"followup": "switch_half",
			"delay": delay + 0.22,
			"burst": burst,
			"burst_kind": burst_kind,
			"prepare_message": reason
		}
	return _wait_prepare(reason, delay, burst, burst_kind)


func _wait_prepare(message: String, delay: float, burst: String, burst_kind: String) -> Dictionary:
	resolving = true
	active_pitch.clear()
	return {
		"ok": true,
		"followup": "prepare",
		"delay": delay,
		"burst": burst,
		"burst_kind": burst_kind,
		"prepare_message": message
	}


func _add_runs(runs: int) -> void:
	if runs <= 0:
		return
	if is_player_offense():
		player_score += runs
		total_runs += runs
	else:
		rival_score += runs
	_add_half_runs(runs)


func _add_half_runs(runs: int) -> void:
	if runs <= 0:
		return
	var line: Array = away_inning_runs if half == "top" else home_inning_runs
	var idx := inning - 1
	line[idx] = int(line[idx] if line[idx] != null else 0) + runs
	if is_player_offense():
		inning_runs[idx] = int(inning_runs[idx] if inning_runs[idx] != null else 0) + runs


func _clear_diamond() -> void:
	bases = [false, false, false]
	outs = 0
	balls = 0
	strikes = 0
	combo = 0
	active_pitch.clear()
	_mark_half_complete()


func _mark_half_complete() -> void:
	var line: Array = away_inning_runs if half == "top" else home_inning_runs
	var idx := inning - 1
	if line[idx] == null:
		line[idx] = 0
	if is_player_offense() and inning_runs[idx] == null:
		inning_runs[idx] = 0


func _home_ahead() -> bool:
	var home_score := player_score if team_id == "home" else rival_score
	var away_score := rival_score if team_id == "home" else player_score
	return home_score > away_score


func _end_game() -> Dictionary:
	game_over = true
	resolving = false
	active_pitch.clear()
	_mark_half_complete()
	return {
		"ok": true,
		"followup": "none",
		"game_over": true,
		"won": player_score >= rival_score,
		"delay": 0.0
	}


func _half_change(kicker: String, title: String, sub: String, prepare_message: String) -> Dictionary:
	var offense := is_player_offense()
	return {
		"ok": true,
		"followup": "prepare",
		"game_over": false,
		"won": false,
		"switched": true,
		"delay": 1.05,
		"prepare_message": prepare_message,
		"message_kicker": kicker,
		"message_title": title,
		"message_sub": sub + (" 換我們打擊。" if offense else " 換我們守備投球。")
	}
