extends Node
## Headless autopilot: plays the real game scene through every stage and both burrito rounds,
## then forces a game over and saves a leaderboard record. Run:
##   godot --headless --path . res://tests/sim_test.tscn

var game: Node
var frames := 0
var last_stage := -1
var last_state := -1
var over_frames := 0
var bites_seen := 0
var log_lines: Array[String] = []


func _ready() -> void:
	Engine.time_scale = 6.0
	GameData.selected_char = "char2"     # no chug/dizzy art: exercises the mug-overlay + tip-over paths
	game = load("res://scenes/game_and_watch.tscn").instantiate()
	add_child(game)
	ChiptuneAudio.track_changed.connect(func(t: String) -> void: _log("music -> " + t))


func _process(_delta: float) -> void:
	frames += 1
	if game.stage != last_stage:
		last_stage = game.stage
		_log("stage -> %d (%s) at score %d" % [game.stage, game.STAGES[game.stage]["name"], game.score])
	if game.state != last_state:
		last_state = game.state
		_log("state -> %s at score %d, hydration %.0f, misses %d" % [["READY", "PLAYING", "BONUS", "OVER"][game.state], game.score, game.hydration, game.misses])

	match game.state:
		1:  # PLAYING: walk to whichever item lands next
			if game.score >= 880:
				game._game_over()
				return
			var best_lane := -1
			var best_left := 999
			for it in game.items:
				if int(it["arc"]) >= 3 or it["bounced"]:
					continue
				var left: int = game._arc_n(it) - int(it["idx"])
				if left < best_left:
					best_left = left
					best_lane = int(it["arc"])
			if best_lane >= 0 and best_lane != game.lane:
				game._move(1 if best_lane > game.lane else -1)
		2:  # BONUS: alternate taps
			if frames % 3 == 0:
				game._move(-1 if (frames / 3) % 2 == 0 else 1)
			bites_seen = maxi(bites_seen, game.bites)
		3:
			over_frames += 1
			if over_frames == 30:
				var kinds := {}
				_log("game over: score %d, bounces %d, qualifies=%s" % [game.score, game.bounces, GameData.qualifies(game.score)])
			if over_frames == 400:
				if game.entry_box != null:
					game._spin_letter(0, 1)
					game._save_record()
				_log("leaderboard now:")
				for e in GameData.leaderboard:
					_log("   %s  %-10s %4d  %s" % [e["initials"], e["character"], e["score"], e["location"]])
				_log("max bites in a bonus round: %d" % bites_seen)
				_log("frames: %d  -- SIM DONE" % frames)
				get_tree().quit()
	if frames > 200000:
		_log("TIMEOUT")
		get_tree().quit(1)


func _log(s: String) -> void:
	print("[sim] " + s)
