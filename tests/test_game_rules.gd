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
	var session := GameSession.new()
	session.rng.seed = 1
	session.bases = [true, true, true]
	session.balls = 3
	session.active_pitch = {"in_zone": false, "ideal": 0.86, "label": "快速球", "speed": 145}
	var take: Dictionary = session.resolve_take()
	failed += _expect("session walk does not clear the bases", session.bases[0] and session.bases[1] and session.bases[2])
	failed += _expect("session walk can score the forced runner", session.player_score == 1)
	failed += _expect("session walk followup prepares the next pitch", str(take.get("followup", "")) == "prepare")
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
