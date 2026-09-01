extends SceneTree
## Headless checks for the extracted Godot rule layer.

func _init() -> void:
	var failed := 0
	failed += _expect("perfect timing", str(GameRules.classify_timing(0.86, 0.86)["grade"]) == "PERFECT")
	failed += _expect("early timing", str(GameRules.classify_timing(0.76, 0.86)["grade"]) == "EARLY")
	failed += _expect("grid uses integer rows", GameRules.grid_distance(2, 3) == 3)
	failed += _expect("aim left from 5 lands on 4", GameRules.move_aim(5, KEY_LEFT) == 4)
	var walked := GameRules.force_walk([true, true, true])
	failed += _expect("walk scores one with loaded bases", int(walked["runs"]) == 1)
	failed += _expect("walk keeps the diamond occupied", bool(walked["bases"][0]) and bool(walked["bases"][1]) and bool(walked["bases"][2]))
	var fake_home := GameRules.advance_runners([true, true, false], 1, true)
	failed += _expect("home-run flag is not used for walks", int(fake_home["runs"]) == 3)
	failed += _expect("auto pitch min delay is 3 seconds", is_equal_approx(GameRules.auto_pitch_delay(0.0), 3.0))
	failed += _expect("auto pitch max delay is 15 seconds", is_equal_approx(GameRules.auto_pitch_delay(1.0), 15.0))
	failed += _expect("meow white is a pitcher", str(GameRules.CHARACTERS["meow_white"]["role"]) == "pitcher")
	failed += _expect("meow boo is a batter", str(GameRules.CHARACTERS["meow_boo"]["role"]) == "batter")
	var session := GameSession.new()
	session.rng.seed = 1
	session.configure("meow_boo", "away")
	session.bases = [true, true, true]
	session.balls = 3
	session.active_pitch = {"in_zone": false, "ideal": 0.86, "label": "快速球", "speed": 145}
	var take: Dictionary = session.resolve_take()
	failed += _expect("session walk does not clear the bases", session.bases[0] and session.bases[1] and session.bases[2])
	failed += _expect("session walk can score the forced runner", session.player_score == 1)
	failed += _expect("away batting writes the top-half line", int(session.away_inning_runs[0]) == 1)
	failed += _expect("home line stays empty during the top", session.home_inning_runs[0] == null)
	failed += _expect("session walk followup prepares the next pitch", str(take.get("followup", "")) == "prepare")
	var pitcher := GameSession.new()
	pitcher.rng.seed = 2
	pitcher.configure("meow_white", "home")
	pitcher.bases = [true, true, true]
	pitcher.balls = 3
	pitcher.active_pitch = {"in_zone": false, "ideal": 0.86, "label": "快速球", "speed": 145}
	pitcher.resolve_take()
	failed += _expect("pitcher walk scores the rival instead", pitcher.rival_score == 1 and pitcher.player_score == 0)
	failed += _expect("home pitching in the top still scores the away line", int(pitcher.away_inning_runs[0]) == 1)
	failed += _expect("pitcher match uses the selected team", str(pitcher.player_team()["name"]) == "喵白白隊")
	var unready := GameSession.new()
	var blocked: Dictionary = unready.start_pitch()
	failed += _expect("pitch is blocked before lineup is chosen", not bool(blocked.get("ok", false)))
	var batter := GameSession.new()
	batter.rng.seed = 3
	batter.configure("meow_boo", "away")
	failed += _expect("batter can choose after setup", batter.can_choose() and batter.is_batter())
	var delay := batter.auto_pitch_delay()
	failed += _expect("batter auto pitch waits at least 3 seconds", delay >= 3.0)
	failed += _expect("batter auto pitch waits at most 15 seconds", delay <= 15.0)
	batter.choose_cpu_pitch()
	var cpu_started: Dictionary = batter.start_pitch()
	failed += _expect("cpu pitcher can start a pitch for the batter", bool(cpu_started.get("ok", false)))
	batter.active_pitch = {"in_zone": true, "zone": 4, "ideal": 0.86, "label": "快速球", "speed": 145}
	var contact: Dictionary = batter.swing(0.86, 4)
	failed += _expect("batter contact is an offensive result", bool(contact.get("ok", false)))
	var defense := GameSession.new()
	defense.rng.seed = 4
	defense.configure("meow_white", "home")
	defense.aim_zone = 7
	var thrown: Dictionary = defense.start_pitch()
	failed += _expect("pitcher throws to the aimed zone when in play", not bool(thrown.get("ok", false)) or int(thrown.get("zone", -2)) == -1 or int(thrown.get("zone", -2)) == 7)
	defense.active_pitch = {"in_zone": true, "zone": 4, "ideal": 0.86, "label": "快速球", "speed": 145}
	var cpu_hit: Dictionary = defense.swing(0.86, 4)
	failed += _expect("cpu batter contact scores the rival", bool(cpu_hit.get("ok", false)) and defense.player_score == 0)
	failed += _expect("home starts on defense in the top", defense.is_fielding() and not defense.is_player_offense())
	var switched: Dictionary = defense.switch_half()
	failed += _expect("three outs switch to the bottom half", defense.half == "bottom" and defense.inning == 1)
	failed += _expect("home bats after the switch", defense.is_player_offense())
	failed += _expect("switch is not game over in inning one", not bool(switched.get("game_over", false)))
	defense.switch_half()
	failed += _expect("bottom of first advances to top of second", defense.inning == 2 and defense.half == "top" and defense.is_fielding())
	var closer := GameSession.new()
	closer.configure("meow_white", "home")
	closer.inning = 3
	closer.half = "top"
	closer.player_score = 2
	closer.rival_score = 0
	var skipped: Dictionary = closer.switch_half()
	failed += _expect("leading home team skips the last bottom half", bool(skipped.get("game_over", true)) and closer.game_over)
	if failed > 0:
		push_error("%d rule checks failed" % failed)
		quit(1)
	else:
		print("game_rules tests passed")
		quit(0)


func _expect(name: String, ok: bool) -> int:
	if ok:
		print("ok  ", name)
		return 0
	push_error("fail  " + name)
	print("fail  ", name)
	return 1
