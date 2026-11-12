extends Node
## Renders screenshots of key moments into the folder given by --shots=<dir> (windowed run, not headless).

var out_dir := "user://shots"
var step := 0
var t := 0.0
var game: Node
var sel: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out_dir)
	sel = load("res://scenes/title_screen.tscn").instantiate()
	add_child(sel)
	step = -1


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("[shot] " + name)


func _process(delta: float) -> void:
	t += delta
	match step:
		-1:
			if t > 1.8:
				_shot("0_opening")
				sel.queue_free()
				sel = load("res://scenes/char_select.tscn").instantiate()
				add_child(sel)
				step = 0; t = 0.0
		0:
			if t > 1.6:
				_shot("1_title")
				sel._trophy.button_pressed = true
				step = 1; t = 0.0
		1:
			if t > 0.3:
				_shot("2_leaderboard")
				sel.queue_free()
				GameData.selected_char = "char1"
				game = load("res://scenes/game_and_watch.tscn").instantiate()
				add_child(game)
				step = 2; t = 0.0
		2:
			_autopilot()
			if t > 2.2 and t - delta <= 2.2:
				_shot("2b_now_playing")
			if t > 9.0:
				_shot("3_juggling")
				game.streak = 12
				game.hydration = 18.0
				step = 3; t = 0.0
		3:
			_autopilot()
			if t > 1.0:
				_shot("4_mosh_fever")
				game.score = 290
				step = 4; t = 0.0
		4:
			_autopilot()
			if game.state == 2 and game.bites >= 5:
				_shot("5_burrito_bonus")
				step = 5; t = 0.0
			elif game.state == 2 and game.bonus_t < 6.0 and int(t * 10) % 2 == 0:
				game._move(-1 if game.last_bite_dir == 1 else 1)
		5:
			if game.state == 2:
				game._move(-1 if game.last_bite_dir == 1 else 1)
			else:
				_autopilot()
			if t > 4.0:
				_shot("6_after_bonus")
				game.score = 610
				game._check_stage()
				step = 6; t = 0.0
		6:
			_autopilot()
			if t > 4.0:
				_shot("7_el_gordo")
				game._game_over()
				step = 7; t = 0.0
		7:
			if t > 1.6:
				_shot("8_la_cruda")
				get_tree().quit()


func _autopilot() -> void:
	if game.state != 1:
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
