extends Node2D
## Super Jae's IPA Juggle — Game & Watch-style juggling in a brass-and-wood handheld.
## The keg launches foaming IPAs along discrete LCD arcs: keg -> left slot -> center -> right -> delivery tub.
## Stand under each mug as it comes down to bounce it on. Drop 3 or run out of Hop Hydration = ¡LA CRUDA!

enum State { READY, PLAYING, BONUS, OVER }

# --- layout (1280x720 base, centered when the screen is wider) ---
const BODY := Rect2(16, 14, 1248, 692)
const BEZEL := Rect2(196, 36, 888, 618)
const SCREEN := Rect2(220, 60, 840, 570)
## Where the bar name sits. Move this to line up with the blank hanging sign in your background art.
const SIGN_RECT := Rect2(470, 68, 340, 50)
const SLOT_X := [430.0, 640.0, 850.0]       # 25% / 50% / 75% across the LCD screen
const FLOOR_Y := 612.0
const CONTACT_Y := 380.0                     # where a mug meets the borracho's head
const LAUNCH := Vector2(335, 178)
const DELIVER := Vector2(1000, 336)
const PLAYER_SCALE := 0.86
const BTN_RADIUS := 78.0
const BTN_CENTERS := [Vector2(110, 470), Vector2(1170, 470)]
const MUTE_RECT := Rect2(1124, 26, 92, 52)
const OVER_PANEL := Rect2(170, 60, 940, 580)

# --- arcs: keg->slot0, slot0->slot1, slot1->slot2, slot2->tub. Steps per arc and arc height. ---
const ARC_N := [4, 5, 5, 4]
const ARC_H := [60.0, 185.0, 185.0, 110.0]
const CONTACT_TICKS := [3, 8, 13]            # ticks after launch that a mug reaches slot 0/1/2
# burritos fly one beat faster on every arc
const ARC_N_FAST := [3, 4, 4, 3]
const CONTACT_TICKS_FAST := [2, 6, 10]

const STAGES := [
	{"name": "Chula Vista Brewery", "min": 0, "bg": "res://assets/backgrounds/bg_stage1_cvb.png"},
	{"name": "The Archway", "min": 100, "bg": "res://assets/backgrounds/bg_stage2_archway.png"},
	{"name": "Brewjería Taproom", "min": 200, "bg": "res://assets/backgrounds/bg_stage3_brewjeria.png"},
	{"name": "Bar Sin Nombre", "min": 300, "bg": "res://assets/backgrounds/bg_stage4_sinnombre.png"},
	{"name": "Los Panchos Taco Shop", "min": 450, "bg": "res://assets/backgrounds/bg_stage5_lospanchos.png"},
	{"name": "Tacos El Gordo - H St", "min": 600, "bg": "res://assets/backgrounds/bg_stage6_elgordo.png"},
	{"name": "Lolita's Mexican Food", "min": 800, "bg": "res://assets/backgrounds/bg_stage7_lolitas.png"},
]
const BOSS_STAGE := 4          # thrash metal from here on
const BURRITO_STAGE := 5       # California burritos join the juggle
const LOLITAS_STAGE := 6       # max-speed survival
const BURRITO_POINTS := 25

# Hora del Burrito bonus round
const BONUS_EVERY := 300
const BONUS_TIME := 8.0
const BURRITO_BITES := 12
const BONUS_POINTS := 150

const MAX_MISSES := 3
const FEVER_BELOW := 25.0
const BOUNCE_HYDRATION := 9.0
const POSE_TIME := 0.3
const POWERUP_CHANCE := 0.09
const SHART_STREAK := 15
const SPLAT_TIME := 1.6
const SPLAT_CALLOUTS := ["¡SE SALIÓ UN CHIFLIDO!", "¡HUELE A LOS PANCHOS!", "¡CON PREMIO AGUADO!"]
const SPLAT_COLORS := [Color(0.88, 0.70, 0.18), Color(0.40, 0.33, 0.13), Color(0.37, 0.40, 0.15)]
const STREAK_CALLS := {5: "¡Échale!", 10: "¡Fondo! ¡Fondo!", 20: "¡Puro Chula Vista!"}
const STREAK_CYCLE := ["¡Échale!", "¡Fondo! ¡Fondo!", "¡Puro Chula Vista!"]

var state: int = State.READY
var lane := 1
var facing := "right"
var items: Array = []       # {"kind", "arc", "idx", "bounced", "spawn"}
var fx: Array = []          # {"type", "pos", "t"}  crash / soft / salud / powerup
var splats: Array = []      # {"type", "t", "pos", "sd"}
var bubbles: Array = []     # {"text", "t", "pos"}
var notes: Array = []       # {"pos", "t", "vx"}
var arc_pts: Array = []
var arc_pts_fast: Array = []
var next_bonus := BONUS_EVERY
var bonus_t := 0.0
var bites := 0
var last_bite_dir := 0
var bonus_over_t := -1.0     # >= 0 while the "round over" pause runs
var pending_shart := false
var chomp_t := 0.0
var score := 0
var misses := 0
var bounces := 0
var streak := 0
var stage := 0
var hydration := 100.0
var tick_count := 0
var tick_timer := 0.0
var tick_interval := 0.55
var next_spawn_tick := 2
var next_miss_clear := 200
var ready_timer := 1.6
var pose_lock := 0.0
var shake := 0.0
var star_t := 0.0
var note_timer := 0.0
var btn_flash := [0.0, 0.0]
var _restarting := false
var ticker_text := ""
var ticker_t := 99.0
const TICKER_TIME := 3.6

var bg_rect: TextureRect
var playfield: Node2D
var rig: Node2D
var sprite: Sprite2D
var mug_overlay: Node2D
var stars: Node2D
var top_layer: Node2D
var fever_rtl: RichTextLabel
var sign_label: Label
var banner: Label
var flash: ColorRect
var grain: ColorRect
var hydration_bar: ProgressBar
var mute_btn: Button
var ui_layer: CanvasLayer
var overlay: Control
var over_panel: Panel
var over_score: Label
var board: Control
var entry_box: Control
var initials: Array[String] = ["J", "A", "E"]
var letter_labels: Array = []
var hop_tween: Tween
var _box_cache := {}


func _ready() -> void:
	_build_arcs()
	_build_nodes()
	_apply_stage(0, false)
	_show_lane_pose()
	_show_banner("GET READY!")
	get_viewport().size_changed.connect(_recenter)
	_recenter()
	ChiptuneAudio.track_changed.connect(_show_ticker)


## Now-playing badge, shown whenever the soundtrack changes.
func _show_ticker(title: String) -> void:
	if title == "":
		return
	ticker_text = title
	ticker_t = 0.0


func _recenter() -> void:
	position = GameData.center_offset(self)
	ui_layer.offset = position
	grain.position = -position
	grain.size = get_viewport_rect().size


func _build_arcs() -> void:
	arc_pts = _make_arcs(ARC_N)
	arc_pts_fast = _make_arcs(ARC_N_FAST)


func _make_arcs(steps: Array) -> Array:
	var out: Array = []
	var ends := [LAUNCH, Vector2(SLOT_X[0], CONTACT_Y), Vector2(SLOT_X[1], CONTACT_Y), Vector2(SLOT_X[2], CONTACT_Y), DELIVER]
	for a in 4:
		var pts := PackedVector2Array()
		var s: Vector2 = ends[a]
		var e: Vector2 = ends[a + 1]
		var n: int = steps[a]
		var h: float = ARC_H[a]
		for j in range(1, n + 1):
			var u := float(j) / n
			pts.append(s.lerp(e, u) + Vector2(0, -h * 4.0 * u * (1.0 - u)))
		out.append(pts)
	return out


func _arc_n(it: Dictionary) -> int:
	return ARC_N_FAST[it["arc"]] if it["fast"] else ARC_N[it["arc"]]


func _at_contact(it: Dictionary) -> bool:
	return int(it["idx"]) >= _arc_n(it)


func _item_pos(it: Dictionary) -> Vector2:
	var pts: PackedVector2Array = (arc_pts_fast if it["fast"] else arc_pts)[it["arc"]]
	return pts[int(it["idx"]) - 1]


# ================================================================ scene setup

func _build_nodes() -> void:
	bg_rect = TextureRect.new()
	bg_rect.position = SCREEN.position
	bg_rect.size = SCREEN.size
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)
	var wash := ColorRect.new()          # light cream wash keeps the LCD readable over busy art
	wash.position = SCREEN.position
	wash.size = SCREEN.size
	wash.color = Color(GameData.CREAM, 0.22)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	playfield = Node2D.new()
	add_child(playfield)
	playfield.draw.connect(_draw_playfield)

	rig = Node2D.new()
	rig.position = Vector2(SLOT_X[1], FLOOR_Y)
	add_child(rig)
	sprite = Sprite2D.new()
	sprite.scale = Vector2.ONE * PLAYER_SCALE
	rig.add_child(sprite)
	mug_overlay = Node2D.new()
	mug_overlay.visible = false
	sprite.add_child(mug_overlay)
	mug_overlay.draw.connect(func() -> void: GameData.draw_mug(mug_overlay, Vector2.ZERO, 1.9))
	stars = Node2D.new()
	stars.visible = false
	add_child(stars)
	stars.draw.connect(_draw_stars)
	top_layer = Node2D.new()
	add_child(top_layer)
	top_layer.draw.connect(_draw_top)
	fever_rtl = GameData.make_rtl("[shake rate=18.0 level=6]¡UNA MÁS Y YA!  x2[/shake]", 42, GameData.RED, Rect2(SCREEN.position.x, 124, SCREEN.size.x, 70), 9)
	fever_rtl.visible = false
	add_child(fever_rtl)

	sign_label = _label("", 26, GameData.CREAM, GameData.title_font)
	sign_label.position = SIGN_RECT.position
	sign_label.size = SIGN_RECT.size
	sign_label.add_theme_color_override("font_outline_color", GameData.INK)
	sign_label.add_theme_constant_override("outline_size", 8)
	add_child(sign_label)

	banner = _label("", 54, GameData.RED, GameData.title_font)
	banner.position = Vector2(SCREEN.position.x, 220)
	banner.size = Vector2(SCREEN.size.x, 80)
	banner.add_theme_color_override("font_outline_color", GameData.CREAM)
	banner.add_theme_constant_override("outline_size", 12)
	add_child(banner)

	flash = ColorRect.new()
	flash.position = SCREEN.position
	flash.size = SCREEN.size
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	grain = ColorRect.new()
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/film_grain.gdshader")
	grain.material = mat
	add_child(grain)

	hydration_bar = ProgressBar.new()
	hydration_bar.position = Vector2(1110, 138)
	hydration_bar.size = Vector2(122, 30)
	hydration_bar.max_value = 100.0
	hydration_bar.show_percentage = false
	hydration_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hydration_bar.add_theme_stylebox_override("background", GameData.make_box(GameData.INK, GameData.INK, 3, 6))
	hydration_bar.add_theme_stylebox_override("fill", GameData.make_box(GameData.AMBER, GameData.INK, 3, 6))
	add_child(hydration_bar)

	mute_btn = Button.new()
	mute_btn.position = MUTE_RECT.position
	mute_btn.size = MUTE_RECT.size
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.add_theme_stylebox_override("normal", GameData.make_box(GameData.BRASS, GameData.INK, 4, 12))
	mute_btn.add_theme_stylebox_override("hover", GameData.make_box(GameData.BRASS.lightened(0.15), GameData.INK, 4, 12))
	mute_btn.add_theme_stylebox_override("pressed", GameData.make_box(GameData.BRASS_DARK, GameData.INK, 4, 12))
	mute_btn.pressed.connect(_on_mute)
	mute_btn.draw.connect(_draw_speaker)
	add_child(mute_btn)

	_build_overlay()


func _build_overlay() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	overlay = Control.new()
	overlay.size = GameData.BASE_SIZE
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.position = Vector2(-2000, -2000)
	dim.size = Vector2(5280, 4720)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	over_panel = Panel.new()
	over_panel.position = OVER_PANEL.position
	over_panel.size = OVER_PANEL.size
	var sb := GameData.make_box(GameData.CREAM, GameData.INK, 7, 22)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(8, 10)
	over_panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(over_panel)


## Fills the ¡LA CRUDA! card: score, initials entry (if it's a top-5 run), the Hall of Fame and buttons.
func _fill_game_over_panel(best: bool) -> void:
	var panel := over_panel
	panel.add_child(GameData.make_rtl("[wave amp=10.0 freq=4.0]¡LA CRUDA![/wave]", 54, GameData.RED, Rect2(6, 16, 374, 84), 8))
	over_score = _label("SCORE %04d\n%s\n%s" % [score, "NEW PERSONAL BEST!" if best else "HI %04d" % GameData.high_score(), STAGES[stage]["name"]], 22, GameData.INK, GameData.lcd_font)
	over_score.position = Vector2(0, 92)
	over_score.size = Vector2(380, 92)
	panel.add_child(over_score)

	if GameData.qualifies(score):
		entry_box = Control.new()
		entry_box.position = Vector2(20, 190)
		entry_box.size = Vector2(340, 250)
		panel.add_child(entry_box)
		var head := _label("NEW RECORD! YOUR INITIALS:", 18, GameData.RED, GameData.title_font)
		head.size = Vector2(340, 28)
		entry_box.add_child(head)
		var init := GameData.default_initials()
		initials = [init[0], init[1], init[2]]
		letter_labels = []
		for i in 3:
			var cx := 70.0 + i * 100.0
			var up := _arrow_button(true)
			up.position = Vector2(cx - 34, 32)
			up.pressed.connect(_spin_letter.bind(i, 1))
			entry_box.add_child(up)
			var lbl := _label(initials[i], 46, GameData.INK, GameData.lcd_font)
			lbl.position = Vector2(cx - 34, 84)
			lbl.size = Vector2(68, 56)
			entry_box.add_child(lbl)
			letter_labels.append(lbl)
			var dn := _arrow_button(false)
			dn.position = Vector2(cx - 34, 142)
			dn.pressed.connect(_spin_letter.bind(i, -1))
			entry_box.add_child(dn)
		var save := _menu_button("SAVE RECORD", GameData.RED, GameData.CREAM, Vector2(240, 54))
		save.position = Vector2(50, 196)
		save.pressed.connect(_save_record)
		entry_box.add_child(save)
	else:
		var tap := _label("No record this time...\n¡Échale otra vez!", 22, GameData.RED.darkened(0.2), GameData.title_font)
		tap.position = Vector2(0, 230)
		tap.size = Vector2(380, 80)
		panel.add_child(tap)

	_rebuild_board(-1)

	var again := _menu_button("DRINK AGAIN", GameData.RED, GameData.CREAM, Vector2(220, 62))
	again.position = Vector2(400, 470)
	again.pressed.connect(_restart)
	panel.add_child(again)
	var pal := _menu_button("CHANGE BORRACHO", GameData.BRASS, GameData.INK, Vector2(290, 62))
	pal.add_theme_font_size_override("font_size", 21)
	pal.position = Vector2(632, 470)
	pal.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/char_select.tscn"))
	panel.add_child(pal)
	var hint := _label("(or tap outside this card to drink again)", 16, Color(GameData.INK, 0.6), GameData.title_font)
	hint.position = Vector2(20, 545)
	hint.size = Vector2(OVER_PANEL.size.x - 40, 24)
	panel.add_child(hint)


func _rebuild_board(highlight: int) -> void:
	if board:
		board.queue_free()
	board = GameData.build_leaderboard(highlight)
	board.position = Vector2(392, 24)
	board.size = Vector2(540, 400)
	over_panel.add_child(board)


func _spin_letter(i: int, dir: int) -> void:
	var code := initials[i].unicode_at(0) - 65
	code = posmod(code + dir, 26)
	initials[i] = String.chr(65 + code)
	(letter_labels[i] as Label).text = initials[i]
	ChiptuneAudio.play_step()


func _save_record() -> void:
	if entry_box == null:
		return
	var rank := GameData.insert_record("".join(PackedStringArray(initials)), score, STAGES[stage]["name"])
	ChiptuneAudio.play_powerup()
	entry_box.queue_free()
	entry_box = null
	var saved := _label("RECORD SAVED! #%d" % (rank + 1), 28, GameData.RED, GameData.title_font)
	saved.position = Vector2(0, 250)
	saved.size = Vector2(380, 50)
	over_panel.add_child(saved)
	_rebuild_board(rank)


func _arrow_button(up: bool) -> Button:
	var b := Button.new()
	b.size = Vector2(68, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", GameData.make_box(GameData.BRASS, GameData.INK, 4, 10))
	b.add_theme_stylebox_override("hover", GameData.make_box(GameData.BRASS.lightened(0.15), GameData.INK, 4, 10))
	b.add_theme_stylebox_override("pressed", GameData.make_box(GameData.BRASS_DARK, GameData.INK, 4, 10))
	b.draw.connect(_draw_arrow.bind(b, up))
	return b


func _draw_arrow(b: Button, up: bool) -> void:
	var c := b.size / 2.0
	var d := -1.0 if up else 1.0
	b.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 12 * d), c + Vector2(-16, -10 * d), c + Vector2(16, -10 * d)]), GameData.INK)


func _menu_button(text: String, bg: Color, fg: Color, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", GameData.title_font)
	b.add_theme_font_size_override("font_size", 24)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_stylebox_override("normal", GameData.make_box(bg, GameData.INK, 5, 16))
	b.add_theme_stylebox_override("hover", GameData.make_box(bg.lightened(0.15), GameData.INK, 5, 16))
	b.add_theme_stylebox_override("pressed", GameData.make_box(bg.darkened(0.2), GameData.INK, 5, 16))
	return b


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameData.tune_outline(l, font_size)
	return l


# ================================================================ loop

func _process(delta: float) -> void:
	for i in 2:
		btn_flash[i] = maxf(0.0, btn_flash[i] - delta)
	star_t += delta
	ticker_t += delta

	if state == State.READY:
		ready_timer -= delta
		if ready_timer <= 0.0:
			state = State.PLAYING
			banner.text = ""
			ChiptuneAudio.set_genre(_genre_for_stage())
			_show_ticker(ChiptuneAudio.current_title())   # punk may already be playing from the title screen
	elif state == State.PLAYING:
		hydration -= minf(7.0 + bounces * 0.05, 16.0) * delta
		if hydration <= 0.0:
			hydration = 0.0
			_game_over()
		tick_timer += delta
		while state == State.PLAYING and tick_timer >= tick_interval:
			tick_timer -= tick_interval
			_tick()
	elif state == State.BONUS:
		_process_bonus(delta)
	chomp_t = maxf(0.0, chomp_t - delta)

	if pose_lock > 0.0:
		pose_lock -= delta
		if pose_lock <= 0.0 and state != State.OVER:
			_show_lane_pose()

	_update_headbang(delta)
	_age(fx, delta, 0.9)
	_age(splats, delta, SPLAT_TIME)
	_age(bubbles, delta, 1.3)
	_age(notes, delta, 1.2)

	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		playfield.position = Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0)) * (shake / 0.25)
	else:
		playfield.position = Vector2.ZERO

	hydration_bar.value = hydration
	fever_rtl.visible = _fever()
	playfield.queue_redraw()
	top_layer.queue_redraw()
	if stars.visible:
		stars.queue_redraw()
	queue_redraw()


func _age(list: Array, delta: float, life: float) -> void:
	for e in list.duplicate():
		e["t"] += delta
		if e["t"] > life:
			list.erase(e)


## Headbanging escalates with the streak: 5+ bobs, 10+ full mosh with flying music notes.
func _update_headbang(delta: float) -> void:
	if state == State.OVER:
		return
	var rot := 0.0
	var bob := 0.0
	if streak >= 10:
		rot = sin(star_t * 16.0) * 0.17
		bob = -absf(sin(star_t * 16.0)) * 12.0
		note_timer -= delta
		if note_timer <= 0.0:
			note_timer = 0.22
			notes.append({"pos": _head_pos() + Vector2(randf_range(-30, 30), 0), "t": 0.0, "vx": randf_range(-50, 50)})
	elif streak >= 5:
		rot = sin(star_t * 10.0) * 0.06
		bob = -absf(sin(star_t * 10.0)) * 5.0
	sprite.rotation = rot
	sprite.position.y = bob


func _head_pos() -> Vector2:
	var h := 200.0
	if sprite.texture:
		h = sprite.texture.get_height() * PLAYER_SCALE
	return rig.position + Vector2(0, -h - 10.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event.is_action_pressed("move_left"):
		_move(-1)
	elif event.is_action_pressed("move_right"):
		_move(1)
	elif event.is_action_pressed("restart") and state == State.OVER and overlay.visible:
		if entry_box != null:
			_save_record()          # Enter/Space saves the initials first
		else:
			_restart()


## Tap the left or right half of the screen to move; after game over any tap restarts.
func _on_tap(screen_pos: Vector2) -> void:
	var local := screen_pos - position
	if state == State.OVER:
		if overlay.visible and not OVER_PANEL.has_point(local):
			_restart()
		return
	if MUTE_RECT.grow(8.0).has_point(local):
		return
	_move(-1 if screen_pos.x < get_viewport_rect().size.x / 2.0 else 1)


func _move(dir: int) -> void:
	btn_flash[0 if dir < 0 else 1] = 0.12
	if state == State.OVER:
		return
	if state == State.BONUS:
		_bite(dir)
		return
	facing = "left" if dir < 0 else "right"
	var new_lane := clampi(lane + dir, 0, 2)
	if new_lane != lane:
		lane = new_lane
		rig.position.x = SLOT_X[lane]
		ChiptuneAudio.play_step()
		if hop_tween:
			hop_tween.kill()
		hop_tween = create_tween()
		rig.position.y = FLOOR_Y - 16.0
		hop_tween.tween_property(rig, "position:y", FLOOR_Y, 0.1)
	if pose_lock <= 0.0:
		_show_lane_pose()
	if state == State.PLAYING:
		for it in items:
			if int(it["arc"]) == lane and _at_contact(it) and not it["bounced"]:
				_bounce(it)
				break


# ================================================================ juggling

func _tick() -> void:
	tick_count += 1
	for it in items.duplicate():
		if state != State.PLAYING:
			return                       # a bounce just kicked off the burrito bonus round
		if _at_contact(it):
			if it["bounced"]:
				it["arc"] += 1
				it["idx"] = 1
				it["bounced"] = false
			else:
				items.erase(it)
				_drop(it)
				if state != State.PLAYING:
					return
				continue
		else:
			it["idx"] += 1
		if _at_contact(it):
			if int(it["arc"]) == 3:
				items.erase(it)
				_deliver(it)
			elif int(it["arc"]) == lane:
				_bounce(it)
	if tick_count >= next_spawn_tick:
		_try_spawn()


func _try_spawn() -> void:
	var kind := "mug"
	var roll := randf()
	if bounces > 6 and roll < POWERUP_CHANCE:
		kind = "taco" if randf() < 0.5 else "michelada"
	elif stage >= BURRITO_STAGE and roll < POWERUP_CHANCE + (0.38 if stage >= LOLITAS_STAGE else 0.28):
		kind = "burrito"
	var fast := kind == "burrito"
	if not _schedule_ok(tick_count, fast):
		next_spawn_tick = tick_count + 1
		return
	items.append({"kind": kind, "arc": 0, "idx": 1, "bounced": false, "spawn": tick_count, "fast": fast})
	var lo := 4 if bounces < 12 else (3 if bounces < 35 else 2)
	var hi := maxi(lo + 1, 7 - int(bounces / 12.0))
	next_spawn_tick = tick_count + randi_range(lo, hi)


## A new launch must never make two mugs land on the same beat, and give a spare beat to cross the whole bar.
func _schedule_ok(t: int, fast: bool) -> bool:
	var mine: Array = CONTACT_TICKS_FAST if fast else CONTACT_TICKS
	for it in items:
		var s: int = it["spawn"]
		var theirs: Array = CONTACT_TICKS_FAST if it["fast"] else CONTACT_TICKS
		for k in 3:
			var t1: int = s + int(theirs[k])
			if t1 < tick_count:
				continue
			for k2 in 3:
				var t2: int = t + int(mine[k2])
				var gap := absi(t1 - t2)
				if gap == 0:
					return false
				if absi(k - k2) == 2 and gap < 2:
					return false
	return true


func _bounce(it: Dictionary) -> void:
	if it["kind"] == "taco" or it["kind"] == "michelada":
		items.erase(it)
		_powerup(it["kind"])
		return
	it["bounced"] = true
	bounces += 1
	streak += 1
	var pts := BURRITO_POINTS if it["kind"] == "burrito" else 10
	score += pts * 2 if _fever() else pts
	hydration = minf(100.0, hydration + BOUNCE_HYDRATION)
	if score >= next_miss_clear:
		next_miss_clear += 200
		misses = maxi(0, misses - 1)          # classic G&W bonus: clear a miss
	tick_interval = 0.22 if stage >= LOLITAS_STAGE else maxf(0.22, 0.55 - bounces * 0.005)
	ChiptuneAudio.set_intensity((0.55 - tick_interval) / 0.33)
	ChiptuneAudio.play_gulp()
	_play_chug()
	if streak % SHART_STREAK == 0:
		_shart()
	else:
		_streak_call()
	_after_score()


func _powerup(kind: String) -> void:
	ChiptuneAudio.play_powerup()
	if kind == "taco":
		score += 50
		misses = maxi(0, misses - 1)
		bubbles.append({"text": "¡TACOS AL PASTOR! +50", "t": 0.0, "pos": _head_pos()})
	else:
		score += 30
		hydration = 100.0
		bubbles.append({"text": "¡MICHELADA! FULL HYDRATION", "t": 0.0, "pos": _head_pos()})
	fx.append({"type": "powerup", "pos": _head_pos() + Vector2(0, 20), "t": 0.0})
	_play_chug()
	_after_score()


func _after_score() -> void:
	_check_stage()
	if state == State.PLAYING and score >= next_bonus:
		while next_bonus <= score:
			next_bonus += BONUS_EVERY
		_start_bonus()


# ================================================================ ¡HORA DEL BURRITO! bonus round

func _start_bonus() -> void:
	state = State.BONUS
	bonus_t = BONUS_TIME
	bites = 0
	last_bite_dir = 0
	bonus_over_t = -1.0
	lane = 0                      # step up to the counter, burrito's bitten end at your mouth
	facing = "right"
	rig.position.x = SLOT_X[0]
	_show_lane_pose()
	_show_banner("¡HORA DEL BURRITO!", 1.4)
	ChiptuneAudio.play_powerup()
	ChiptuneAudio.set_genre("MARIACHI")


func _process_bonus(delta: float) -> void:
	if bonus_over_t >= 0.0:
		bonus_over_t -= delta
		if bonus_over_t < 0.0:
			_end_bonus()
		return
	bonus_t -= delta
	if bonus_t <= 0.0:
		bonus_t = 0.0
		bonus_over_t = 1.2
		_show_banner("¡SE ACABÓ EL TIEMPO!", 1.0)
		ChiptuneAudio.play_crash()


## Alternate left/right taps to chomp. Same side twice in a row doesn't count.
func _bite(dir: int) -> void:
	if bonus_over_t >= 0.0 or dir == last_bite_dir:
		return
	last_bite_dir = dir
	bites += 1
	chomp_t = 0.12
	ChiptuneAudio.play_crunch()
	_play_chug()
	fx.append({"type": "crumbs", "pos": _burrito_bite_point(), "t": 0.0})
	if bites >= BURRITO_BITES:
		hydration = 100.0
		score += BONUS_POINTS
		pending_shart = true
		bonus_over_t = 1.4
		bubbles.append({"text": "¡BURRITO TERMINADO! +%d" % BONUS_POINTS, "t": 0.0, "pos": _head_pos()})
		ChiptuneAudio.play_stage_up()


func _end_bonus() -> void:
	state = State.PLAYING
	tick_timer = 0.0
	_check_stage()
	ChiptuneAudio.set_genre(_genre_for_stage())
	if pending_shart:
		pending_shart = false
		_shart("¡DEMASIADO FRIJOL!")


const GIANT_BITE_END := Vector2(515, 446)    # bitten end of the giant burrito, at the borracho's mouth
const GIANT_H := 92.0


func _burrito_len() -> float:
	return 40.0 + 340.0 * float(BURRITO_BITES - bites) / BURRITO_BITES


func _burrito_bite_point() -> Vector2:
	return GIANT_BITE_END


func _drop(it: Dictionary) -> void:
	var at := Vector2(SLOT_X[int(it["arc"])], FLOOR_Y)
	if it["kind"] != "mug":
		fx.append({"type": "soft", "pos": at, "t": 0.0})
		return
	misses += 1
	streak = 0
	hydration = maxf(0.0, hydration - 10.0)
	fx.append({"type": "crash", "pos": at, "t": 0.0})
	shake = 0.25
	ChiptuneAudio.play_crash()
	if misses >= MAX_MISSES:
		_game_over()


func _deliver(_it: Dictionary) -> void:
	fx.append({"type": "salud", "pos": DELIVER, "t": 0.0})


func _fever() -> bool:
	return state == State.PLAYING and hydration < FEVER_BELOW


func _streak_call() -> void:
	var text := ""
	if STREAK_CALLS.has(streak):
		text = STREAK_CALLS[streak]
	elif streak > 20 and streak % 10 == 0:
		text = STREAK_CYCLE[(streak / 10) % STREAK_CYCLE.size()]
	if text != "":
		bubbles.append({"text": text, "t": 0.0, "pos": _head_pos()})


## Every 15 bounces in a row: a random toot, a matching splat, an embarrassed red face.
func _shart(callout: String = "") -> void:
	var type := ChiptuneAudio.play_shart()
	var behind := -80.0 if facing == "right" else 80.0
	var x := clampf(SLOT_X[lane] + behind, SCREEN.position.x + 90.0, SCREEN.end.x - 90.0)
	var pos := Vector2(x, FLOOR_Y - 30.0)
	splats.append({"type": type, "t": 0.0, "pos": pos, "sd": randf() * TAU})
	bubbles.append({"text": callout if callout != "" else SPLAT_CALLOUTS[type], "t": 0.0, "pos": pos + Vector2(0, -120)})
	sprite.self_modulate = Color(1.0, 0.5, 0.45)
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color.WHITE, 1.4).set_delay(0.3)


# ================================================================ stages

func _check_stage() -> void:
	var s := 0
	for i in STAGES.size():
		if score >= int(STAGES[i]["min"]):
			s = i
	if s != stage:
		_apply_stage(s, true)


func _apply_stage(s: int, announce: bool) -> void:
	stage = s
	if not announce:
		_swap_location(s)
		return
	# Retro camera flash: pop to white, swap the location while the screen is blown out, then fade.
	var boss: bool = s == BOSS_STAGE
	var tw := create_tween()
	flash.color = Color(1.0, 0.98, 0.9, 0.0)
	tw.tween_property(flash, "color:a", 1.0, 0.05)
	tw.tween_callback(_swap_location.bind(s))
	tw.tween_interval(0.07)
	if boss:
		tw.tween_property(flash, "color", Color(GameData.AMBER, 0.85), 0.08)
		tw.tween_property(flash, "color", Color(1.0, 0.98, 0.9, 1.0), 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	ChiptuneAudio.play_stage_up()
	if state == State.PLAYING:
		ChiptuneAudio.set_genre(_genre_for_stage())
	if boss:
		_show_banner("LAST CALL: LOS PANCHOS!", 1.8)
	else:
		_show_banner("STAGE %d!" % (s + 1), 1.2)


## Soundtrack by location: punk for stages 1-2, mariachi for 3-4, metal from Los Panchos on.
func _genre_for_stage() -> String:
	if stage >= BOSS_STAGE:
		return "METAL"
	if stage >= 2:
		return "MARIACHI"
	return "PUNK"


## Where each background's blank hanging sign sits on the LCD screen (art scaled to cover the screen).
const BG_SIGNS := {
	"res://assets/backgrounds/bg_stage1_cvb.png": Rect2(484, 118, 316, 52),
}
var _current_bg := ""


## Loads the stage's background (if the image exists yet; otherwise the previous art stays)
## and writes the bar name onto the hanging sign.
func _swap_location(s: int) -> void:
	var st: Dictionary = STAGES[s]
	sign_label.text = st["name"]
	if ResourceLoader.exists(st["bg"]):
		bg_rect.texture = load(st["bg"])
		_current_bg = st["bg"]
	var r: Rect2 = BG_SIGNS.get(_current_bg, SIGN_RECT)
	sign_label.position = r.position
	sign_label.size = r.size


func _show_banner(text: String, secs: float = 0.0) -> void:
	banner.text = text
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if secs > 0.0:
		tw.tween_interval(secs)
		tw.tween_callback(_clear_banner.bind(text))


func _clear_banner(text: String) -> void:
	if banner.text == text:
		banner.text = ""


func _on_mute() -> void:
	ChiptuneAudio.toggle_mute()
	mute_btn.queue_redraw()


func _game_over() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	pose_lock = 0.0
	streak = 0
	sprite.position.y = 0.0
	sprite.rotation = 0.0
	ChiptuneAudio.stop_music()
	ChiptuneAudio.play_game_over()
	var best := GameData.submit_score(score)
	_fill_game_over_panel(best)
	banner.text = ""
	if GameData.has_pose("dizzy"):
		_show_pose("dizzy")
	else:
		# no knocked-out art for this borracho: tip the idle pose over and add orbiting stars
		_show_pose("idle")
		var dir := 1.0 if lane == 0 else -1.0
		var tex := sprite.texture
		var lift := tex.get_width() * PLAYER_SCALE * 0.25
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "rotation", dir * PI / 2.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position:y", -lift, 0.35)
		var head := Vector2(0, -tex.get_height() * 0.85 * PLAYER_SCALE).rotated(dir * PI / 2.0)
		stars.position = Vector2(rig.position.x, FLOOR_Y - lift) + head + Vector2(0, -30)
		stars.visible = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void: overlay.visible = true)


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().reload_current_scene()


# ================================================================ poses

func _show_lane_pose() -> void:
	if lane == 1 and GameData.has_pose("idle"):
		_show_pose("idle")
	else:
		_show_pose("run_" + facing)


func _show_pose(pose: String) -> void:
	var tex := GameData.sprite(pose)
	if tex == null:
		tex = GameData.sprite("run_right")
	if tex == null:
		return
	sprite.texture = tex
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	mug_overlay.visible = false


func _play_chug() -> void:
	pose_lock = POSE_TIME
	if GameData.has_pose("chug"):
		_show_pose("chug")
	else:
		_show_pose("cheer")
		var tex := sprite.texture
		if tex:
			# raised fist is up and to the left in the cheer art
			mug_overlay.position = Vector2(-tex.get_width() * 0.30, -tex.get_height() * 0.86)
			mug_overlay.visible = true
	var tw := create_tween()
	sprite.scale = Vector2(1.18, 0.86) * PLAYER_SCALE
	tw.tween_property(sprite, "scale", Vector2.ONE * PLAYER_SCALE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ================================================================ drawing: console

func _box(key: String, bg: Color, border: Color, bw: int, r: int) -> StyleBoxFlat:
	if not _box_cache.has(key):
		_box_cache[key] = GameData.make_box(bg, border, bw, r)
	return _box_cache[key]


func _draw() -> void:
	var ink := GameData.INK
	var brass := GameData.BRASS
	draw_style_box(_box("body", GameData.WOOD, brass, 10, 64), BODY)
	for i in 12:
		var y := 44.0 + i * 56.0
		var pts := PackedVector2Array()
		for k in 31:
			var x := 40.0 + k * 40.0
			pts.append(Vector2(x, y + sin(x * 0.012 + i * 1.7) * 7.0))
		draw_polyline(pts, Color(GameData.WOOD_DARK, 0.55), 2.0)
	draw_style_box(_box("bezel", brass, GameData.BRASS_DARK, 6, 34), BEZEL)
	draw_style_box(_box("rim", ink, ink, 0, 20), SCREEN.grow(12))
	if bg_rect.texture == null:
		_draw_fallback_bar()
	var rivets := [BEZEL.position + Vector2(14, 14), Vector2(BEZEL.end.x - 14, BEZEL.position.y + 14),
			Vector2(BEZEL.position.x + 14, BEZEL.end.y - 14), BEZEL.end - Vector2(14, 14)]
	for rv in rivets:
		draw_circle(rv, 6.0, GameData.BRASS_DARK)
		draw_circle(rv - Vector2(1.5, 1.5), 3.0, brass.lightened(0.3))
	draw_string(GameData.title_font, Vector2(BEZEL.position.x, 690), GameData.GAME_TITLE, HORIZONTAL_ALIGNMENT_CENTER, BEZEL.size.x, 32, brass)

	# left plate: score / hi / stage
	var lf := GameData.lcd_font
	draw_style_box(_box("plate", brass, ink, 4, 14), Rect2(34, 70, 150, 222))
	draw_string(GameData.title_font, Vector2(34, 98), "SCORE", HORIZONTAL_ALIGNMENT_CENTER, 150, 20, ink)
	draw_style_box(_box("lcd", GameData.CREAM, ink, 3, 6), Rect2(46, 106, 126, 50))
	draw_string(lf, Vector2(46, 143), "%04d" % score, HORIZONTAL_ALIGNMENT_CENTER, 126, 36, ink)
	draw_string(GameData.title_font, Vector2(34, 184), "HI", HORIZONTAL_ALIGNMENT_CENTER, 150, 18, ink)
	draw_style_box(_box("lcd", GameData.CREAM, ink, 3, 6), Rect2(46, 192, 126, 40))
	draw_string(lf, Vector2(46, 222), "%04d" % maxi(score, GameData.high_score()), HORIZONTAL_ALIGNMENT_CENTER, 126, 28, ink)
	draw_string(GameData.title_font, Vector2(34, 270), "STAGE %d" % (stage + 1), HORIZONTAL_ALIGNMENT_CENTER, 150, 22, GameData.RED.darkened(0.2))

	# right plate: hydration meter (ProgressBar node sits on top) + dropped mugs
	draw_style_box(_box("plate", brass, ink, 4, 14), Rect2(1096, 92, 150, 186))
	draw_string(GameData.title_font, Vector2(1096, 114), "HOP", HORIZONTAL_ALIGNMENT_CENTER, 150, 17, ink)
	draw_string(GameData.title_font, Vector2(1096, 132), "HYDRATION", HORIZONTAL_ALIGNMENT_CENTER, 150, 17, ink)
	draw_string(GameData.title_font, Vector2(1096, 202), "DROPS", HORIZONTAL_ALIGNMENT_CENTER, 150, 20, ink)
	for i in MAX_MISSES:
		var mp := Vector2(1128 + i * 43, 244)
		if i < misses:
			GameData.draw_mug(self, mp, 0.6)
			draw_line(mp + Vector2(-16, -18), mp + Vector2(16, 14), GameData.RED, 5.0)
			draw_line(mp + Vector2(16, -18), mp + Vector2(-16, 14), GameData.RED, 5.0)
		else:
			GameData.draw_mug(self, mp, 0.6, true)

	# big brass buttons (decorative: the whole left/right half of the screen is the touch zone)
	for i in 2:
		var c: Vector2 = BTN_CENTERS[i]
		var pressed: bool = btn_flash[i] > 0.0
		var off := Vector2(0, 5) if pressed else Vector2.ZERO
		draw_circle(c + Vector2(0, 9), BTN_RADIUS + 8.0, Color(0, 0, 0, 0.35))
		draw_circle(c, BTN_RADIUS + 8.0, GameData.BRASS_DARK)
		draw_circle(c, BTN_RADIUS + 3.0, brass)
		draw_circle(c + off, BTN_RADIUS - 6.0, ink)
		draw_circle(c + off, BTN_RADIUS - 11.0, GameData.RED.lightened(0.2) if pressed else GameData.RED)
		draw_arc(c + off, BTN_RADIUS - 22.0, PI * 1.1, PI * 1.55, 10, Color(1, 1, 1, 0.35), 6.0)
		var d := -1.0 if i == 0 else 1.0
		var tri := PackedVector2Array([c + off + Vector2(32 * d, 0), c + off + Vector2(-20 * d, -30), c + off + Vector2(-20 * d, 30)])
		draw_colored_polygon(tri, GameData.CREAM)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), ink, 4.0)
		draw_string(GameData.title_font, c + Vector2(-80, BTN_RADIUS + 44), "LEFT" if i == 0 else "RIGHT", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, brass)


## Procedural 1930s taproom used until real background art is dropped in.
func _draw_fallback_bar() -> void:
	var ink := GameData.INK
	draw_style_box(_box("screen", GameData.CREAM, ink, 0, 12), SCREEN)
	# striped wallpaper
	for i in 21:
		var x := SCREEN.position.x + 20.0 + i * 40.0
		draw_rect(Rect2(x, SCREEN.position.y, 14, 420), Color(GameData.AMBER, 0.10))
	# back shelf with bottles and a smiling barrel
	var shelf_y := 300.0
	draw_rect(Rect2(SCREEN.position.x + 10, shelf_y, SCREEN.size.x - 20, 12), GameData.WOOD)
	draw_rect(Rect2(SCREEN.position.x + 10, shelf_y, SCREEN.size.x - 20, 12), ink, false, 3.0)
	for i in 14:
		var bx := 300.0 + i * 50.0
		if bx > 560.0 and bx < 720.0:
			continue
		var hgt := 30.0 + float((i * 7) % 3) * 8.0
		var col: Color = [Color(0.35, 0.45, 0.25), GameData.AMBER.darkened(0.3), GameData.RED.darkened(0.2)][i % 3]
		draw_rect(Rect2(bx - 8, shelf_y - hgt, 16, hgt), col)
		draw_rect(Rect2(bx - 4, shelf_y - hgt - 12, 8, 12), col)
		draw_rect(Rect2(bx - 8, shelf_y - hgt, 16, hgt), ink, false, 2.0)
	var bc := Vector2(640, 262)
	draw_circle(bc, 36.0, ink)
	draw_circle(bc, 32.0, GameData.WOOD.lightened(0.15))
	draw_arc(bc + Vector2(0, 4), 16.0, 0.3, PI - 0.3, 10, ink, 4.0)
	draw_circle(bc + Vector2(-11, -8), 4.0, ink)
	draw_circle(bc + Vector2(11, -8), 4.0, ink)
	# wooden bar counter behind the borracho
	var top := 470.0
	draw_rect(Rect2(SCREEN.position.x, top, SCREEN.size.x, 20), GameData.WOOD.lightened(0.15))
	draw_rect(Rect2(SCREEN.position.x, top, SCREEN.size.x, 20), ink, false, 4.0)
	draw_rect(Rect2(SCREEN.position.x, top + 20, SCREEN.size.x, FLOOR_Y - top - 12), GameData.WOOD)
	for i in 10:
		var px := SCREEN.position.x + 14.0 + i * 82.0
		draw_rect(Rect2(px, top + 34, 64, FLOOR_Y - top - 60), GameData.WOOD_DARK.lightened(0.1))
		draw_rect(Rect2(px, top + 34, 64, FLOOR_Y - top - 60), ink, false, 3.0)
	draw_line(Vector2(SCREEN.position.x, FLOOR_Y - 18), Vector2(SCREEN.end.x, FLOOR_Y - 18), GameData.BRASS, 5.0)
	draw_rect(Rect2(SCREEN.position.x, FLOOR_Y + 8, SCREEN.size.x, SCREEN.end.y - FLOOR_Y - 8), GameData.WOOD_DARK)


# ================================================================ drawing: LCD playfield

func _draw_playfield() -> void:
	var p := playfield
	var ink := GameData.INK
	p.draw_line(Vector2(SCREEN.position.x + 12, FLOOR_Y + 8), Vector2(SCREEN.end.x - 12, FLOOR_Y + 8), Color(ink, 0.6), 3.0)
	# hanging sign plank (only when there's no background art with its own sign)
	if bg_rect.texture == null:
		p.draw_line(SIGN_RECT.position + Vector2(40, -8), SIGN_RECT.position + Vector2(40, 4), ink, 3.0)
		p.draw_line(Vector2(SIGN_RECT.end.x - 40, SIGN_RECT.position.y - 8), Vector2(SIGN_RECT.end.x - 40, SIGN_RECT.position.y + 4), ink, 3.0)
		p.draw_style_box(_box("sign", GameData.WOOD, ink, 4, 8), SIGN_RECT)
	_draw_keg(p, Vector2(272, 150))
	_draw_tub(p, DELIVER + Vector2(0, 52))
	# LCD ghost segments for every arc step, then the live items
	for a in 4:
		var pts: PackedVector2Array = arc_pts[a]
		for q in pts:
			GameData.draw_mug(p, q, 1.0, true)
	if state == State.BONUS:
		if bites < BURRITO_BITES:
			var wobble := sin(chomp_t * 60.0) * 4.0 if chomp_t > 0.0 else 0.0
			var length := _burrito_len()
			_draw_burrito(p, GIANT_BITE_END + Vector2(length / 2.0 + wobble, 0), length, GIANT_H, 0.0, bites > 0)
		for e in fx:
			_draw_fx(p, e)
		return
	for it in items:
		var pos := _item_pos(it)
		if it["bounced"]:
			pos.y -= 14.0
		elif int(it["idx"]) == ARC_N[it["arc"]]:
			pos.x += sin(star_t * 40.0) * 2.0      # teetering, about to drop!
		var spin := float(it["idx"]) * 0.55 + float(it["arc"]) * 1.3
		match it["kind"]:
			"taco":
				_draw_glow(p, pos)
				_draw_taco(p, pos, spin * 0.3)
			"michelada":
				_draw_glow(p, pos)
				_draw_michelada(p, pos)
			"burrito":
				_draw_burrito(p, pos, 66.0, 30.0, sin(spin) * 0.7, true)
			_:
				p.draw_set_transform(pos, sin(spin) * 0.5, Vector2.ONE)
				GameData.draw_mug(p, Vector2.ZERO, 1.0)
				p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in fx:
		_draw_fx(p, e)
	for sp in splats:
		_draw_splat(p, sp)


func _draw_keg(ci: CanvasItem, c: Vector2) -> void:
	var ink := GameData.INK
	ci.draw_style_box(_box("keg", GameData.WOOD.lightened(0.1), ink, 4, 20), Rect2(c - Vector2(38, 46), Vector2(76, 92)))
	for y in [-24.0, 24.0]:
		ci.draw_rect(Rect2(c + Vector2(-38, y - 4), Vector2(76, 8)), ink)
		ci.draw_rect(Rect2(c + Vector2(-36, y - 2), Vector2(72, 4)), GameData.BRASS)
	ci.draw_circle(c + Vector2(-10, -4), 4.0, ink)
	ci.draw_circle(c + Vector2(10, -4), 4.0, ink)
	ci.draw_arc(c + Vector2(0, 4), 12.0, 0.3, PI - 0.3, 8, ink, 3.0)
	var sp := c + Vector2(38, 18)
	ci.draw_rect(Rect2(sp + Vector2(0, -7), Vector2(26, 14)), ink)
	ci.draw_rect(Rect2(sp + Vector2(0, -4), Vector2(26, 8)), GameData.BRASS)
	ci.draw_rect(Rect2(sp + Vector2(6, -30), Vector2(8, 24)), ink)
	ci.draw_circle(sp + Vector2(10, -32), 7.0, GameData.RED)


func _draw_tub(ci: CanvasItem, c: Vector2) -> void:
	var ink := GameData.INK
	var pts := PackedVector2Array([c + Vector2(-46, -30), c + Vector2(46, -30), c + Vector2(36, 30), c + Vector2(-36, 30)])
	ci.draw_colored_polygon(pts, GameData.WOOD.lightened(0.1))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ink, 4.0)
	ci.draw_line(c + Vector2(-43, -12), c + Vector2(43, -12), GameData.BRASS, 5.0)
	ci.draw_line(c + Vector2(-39, 14), c + Vector2(39, 14), GameData.BRASS, 5.0)
	ci.draw_string(GameData.title_font, c + Vector2(-46, 52), "SALUD", HORIZONTAL_ALIGNMENT_CENTER, 92, 18, ink)


func _draw_glow(ci: CanvasItem, pos: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(star_t * 10.0)
	ci.draw_circle(pos, 34.0 + pulse * 6.0, Color(1.0, 0.85, 0.3, 0.25 + 0.2 * pulse))


func _draw_taco(ci: CanvasItem, pos: Vector2, rot: float) -> void:
	var ink := GameData.INK
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0 + rot
		pts.append(pos + Vector2(cos(a) * 26.0, sin(a) * 22.0 + 8.0))
	ci.draw_colored_polygon(pts, Color(0.96, 0.80, 0.40))
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	ci.draw_polyline(loop, ink, 4.0)
	# al pastor, pineapple, cilantro peeking out along the rim
	var fill := [Color(0.80, 0.22, 0.10), Color(0.98, 0.85, 0.20), Color(0.25, 0.60, 0.20), Color(0.80, 0.22, 0.10), Color(0.25, 0.60, 0.20)]
	for k in 5:
		var a := PI * 1.15 + PI * 0.7 * k / 4.0 + rot
		ci.draw_circle(pos + Vector2(cos(a) * 20.0, sin(a) * 16.0 + 6.0), 6.0, fill[k])


func _draw_michelada(ci: CanvasItem, pos: Vector2) -> void:
	var ink := GameData.INK
	var glass := PackedVector2Array([pos + Vector2(-17, -22), pos + Vector2(17, -22), pos + Vector2(12, 22), pos + Vector2(-12, 22)])
	ci.draw_colored_polygon(glass, Color(0.75, 0.22, 0.10))
	ci.draw_polyline(PackedVector2Array([glass[0], glass[1], glass[2], glass[3], glass[0]]), ink, 4.0)
	ci.draw_rect(Rect2(pos + Vector2(-9, -16), Vector2(4, 30)), Color(1, 0.8, 0.7, 0.5))
	for k in 7:
		ci.draw_circle(pos + Vector2(-16 + k * 5.3, -23), 2.6, Color(1, 1, 1))
	ci.draw_line(pos + Vector2(6, -22), pos + Vector2(14, -42), ink, 4.0)
	ci.draw_circle(pos + Vector2(19, -22), 8.0, ink)
	ci.draw_circle(pos + Vector2(19, -22), 6.0, Color(0.55, 0.80, 0.20))


func _draw_fx(ci: CanvasItem, e: Dictionary) -> void:
	var t: float = e["t"]
	var at: Vector2 = e["pos"]
	var a := 1.0 - t / 0.9
	match e["type"]:
		"crash":
			ci.draw_set_transform(at, 0.0, Vector2(1.0, 0.28))
			ci.draw_circle(Vector2.ZERO, 30.0 + t * 40.0, Color(GameData.AMBER, 0.8 * a))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in 5:
				var ang := -PI * (0.15 + 0.7 * k / 4.0)
				var shard := at + Vector2(cos(ang), sin(ang)) * (12.0 + t * 90.0) + Vector2(0, t * t * 120.0)
				ci.draw_colored_polygon(PackedVector2Array([shard, shard + Vector2(9, 4), shard + Vector2(2, 11)]), Color(GameData.AMBER.darkened(0.2), a))
			ci.draw_string(GameData.title_font, at + Vector2(-110, -70 - t * 30.0), "¡No manches!", HORIZONTAL_ALIGNMENT_CENTER, 220, 28, Color(GameData.RED, a))
		"soft":
			ci.draw_string(GameData.title_font, at + Vector2(-80, -40 - t * 30.0), "¡Ay, se cayó!", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(GameData.INK, a))
		"salud":
			for k in 6:
				var ang := TAU * k / 6.0 + t * 3.0
				ci.draw_circle(at + Vector2(cos(ang), sin(ang)) * (10.0 + t * 50.0), 4.0, Color(1.0, 0.9, 0.4, a))
		"powerup":
			ci.draw_arc(at, 20.0 + t * 120.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, a), 6.0)
		"crumbs":
			var cols := [Color(0.45, 0.25, 0.12), Color(0.45, 0.70, 0.25), Color(0.98, 0.82, 0.30), Color(0.96, 0.85, 0.6)]
			for k in 8:
				var ang := -PI * (0.1 + 0.8 * k / 7.0)
				var sp := 90.0 + 40.0 * float(k % 3)
				var d := at + Vector2(cos(ang) * sp * t, sin(ang) * sp * t + 300.0 * t * t)
				var c: Color = cols[k % 4]
				c.a = a
				ci.draw_circle(d, 6.0, Color(GameData.INK, a))
				ci.draw_circle(d, 4.5, c)


## 1930s foil-wrapped California burrito: crinkled silver foil, twisted end, and a peek of
## carne asada, guacamole and fries at the bitten end. c = center.
func _draw_burrito(ci: CanvasItem, c: Vector2, length: float, h: float, rot: float, bitten: bool) -> void:
	var ink := GameData.INK
	var foil := Color(0.80, 0.82, 0.85)
	var half := length / 2.0
	ci.draw_set_transform(c, rot, Vector2.ONE)
	var twist := PackedVector2Array([
		Vector2(half - 6, -h * 0.26), Vector2(half + h * 0.42, -h * 0.44), Vector2(half + h * 0.26, 0),
		Vector2(half + h * 0.42, h * 0.44), Vector2(half - 6, h * 0.26),
	])
	_ink_poly(ci, twist, foil.darkened(0.12), 3.0)
	var body := GameData.make_box(foil, ink, 4 if h > 50.0 else 3, int(h / 2.0))
	ci.draw_style_box(body, Rect2(-half, -h / 2.0, length, h))
	# crinkles
	var x := -half + h * 0.35
	while x < half - 10.0:
		var z := PackedVector2Array([
			Vector2(x, -h * 0.40), Vector2(x + 4, -h * 0.18), Vector2(x - 3, 0),
			Vector2(x + 4, h * 0.18), Vector2(x, h * 0.40),
		])
		ci.draw_polyline(z, foil.darkened(0.3), 2.0)
		x += maxf(12.0, h * 0.24)
	ci.draw_line(Vector2(-half + h * 0.3, -h * 0.28), Vector2(half - 10, -h * 0.28), Color(1, 1, 1, 0.7), maxf(2.0, h * 0.05))
	if bitten:
		var e := Vector2(-half + h * 0.12, 0)
		# fries poking out
		for k in 3:
			var fy := (-0.22 + 0.22 * k) * h
			var fl := h * (0.22 + 0.08 * k)
			var fr := Rect2(e + Vector2(-fl, fy - h * 0.045), Vector2(fl, h * 0.09))
			ci.draw_rect(fr.grow(1.5), ink)
			ci.draw_rect(fr, Color(0.98, 0.82, 0.30))
		_ink_poly(ci, _ellipse(e, h * 0.20, h * 0.47), Color(0.96, 0.86, 0.60), 3.0)    # tortilla
		_ink_poly(ci, _ellipse(e, h * 0.14, h * 0.37), Color(0.45, 0.25, 0.12), 2.0)    # carne asada
		ci.draw_circle(e + Vector2(0, -h * 0.14), h * 0.10, Color(0.45, 0.70, 0.25))     # guac
		ci.draw_circle(e + Vector2(-h * 0.03, h * 0.12), h * 0.08, Color(0.45, 0.70, 0.25))
		ci.draw_circle(e + Vector2(h * 0.04, h * 0.02), h * 0.06, Color(0.60, 0.35, 0.18))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 18:
		var a := TAU * k / 18.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Irregular cartoon blob outline.
func _blob(center: Vector2, r: float, sx: float, sd: float, lumps: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 22:
		var ang := TAU * i / 22.0
		var rr := r * (1.0 + 0.22 * sin(ang * lumps + sd) + 0.1 * sin(ang * 3.0 + sd * 2.0))
		pts.append(center + Vector2(cos(ang) * rr * sx, sin(ang) * rr))
	return pts


func _ink_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_colored_polygon(pts, col)
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(GameData.INK, col.a), w)


func _draw_splat(ci: CanvasItem, sp: Dictionary) -> void:
	var type: int = sp["type"]
	var t: float = sp["t"]
	var pos: Vector2 = sp["pos"]
	var sd: float = sp["sd"]
	var a := clampf((SPLAT_TIME - t) / 0.4, 0.0, 1.0)
	var pop := 1.0 + 0.25 * sin(minf(1.0, t / 0.12) * PI) if t < 0.12 else 1.0
	var col: Color = SPLAT_COLORS[type]
	col.a = a
	var ink := Color(GameData.INK, a)
	match type:
		0:  # Squeaker: small, tight mustard puff
			for k in 5:
				var ang := sd + TAU * k / 5.0
				ci.draw_circle(pos + Vector2(cos(ang) * 16.0, sin(ang) * 10.0 - 6.0) * pop, 17.0 * pop, ink)
			for k in 5:
				var ang := sd + TAU * k / 5.0
				ci.draw_circle(pos + Vector2(cos(ang) * 16.0, sin(ang) * 10.0 - 6.0) * pop, 13.0 * pop, col)
			ci.draw_circle(pos + Vector2(-6, -12) * pop, 4.0, Color(1, 1, 0.85, 0.7 * a))
		1:  # Warm & Gross: thick steaming olive-brown splatter with wavy stink lines
			_ink_poly(ci, _blob(pos + Vector2(0, 10), 34.0 * pop, 1.5, sd, 5.0), col, 5.0)
			_ink_poly(ci, _blob(pos + Vector2(-10, 0), 16.0 * pop, 1.3, sd + 1.0, 4.0), col.lightened(0.15), 3.0)
			for k in 3:
				var base := pos + Vector2(-34.0 + k * 34.0, -20.0)
				var rise := fmod(t * 50.0 + k * 18.0, 60.0)
				var line := PackedVector2Array()
				for j in 9:
					line.append(base + Vector2(sin(j * 1.1 + t * 7.0 + k) * 7.0, -rise - j * 9.0))
				ci.draw_polyline(line, Color(0.42, 0.50, 0.18, a * 0.85), 4.0)
		2:  # Watery: wide drippy green-brown splatter with flying droplets
			_ink_poly(ci, _blob(pos + Vector2(0, 14), 30.0 * pop, 2.3, sd, 7.0), col, 4.0)
			for k in 4:
				var dx := -50.0 + k * 33.0 + sin(sd + k) * 6.0
				var drip := minf(t * 45.0, 28.0) * (0.6 + 0.4 * absf(sin(sd * 3.0 + k)))
				var top := pos + Vector2(dx, 24.0)
				ci.draw_rect(Rect2(top + Vector2(-4, 0), Vector2(8, drip)), col)
				ci.draw_circle(top + Vector2(0, drip), 6.0, ink)
				ci.draw_circle(top + Vector2(0, drip), 4.5, col)
			for k in 9:
				var ang := -PI * (0.08 + 0.84 * k / 8.0)
				var spd := 150.0 + 60.0 * absf(sin(sd * 5.0 + k))
				var d := pos + Vector2(cos(ang) * spd * t, sin(ang) * spd * t + 260.0 * t * t)
				if d.y < FLOOR_Y + 4.0:
					ci.draw_circle(d, 6.0, ink)
					ci.draw_circle(d, 4.5, col)


# ================================================================ drawing: top layer (above the borracho)

func _draw_top() -> void:
	var ci := top_layer
	# music notes while moshing
	for n in notes:
		var t: float = n["t"]
		var a := 1.0 - t / 1.2
		var np: Vector2 = n["pos"] + Vector2(float(n["vx"]) * t, -90.0 * t)
		var col := Color(GameData.INK, a)
		ci.draw_circle(np, 7.0, col)
		ci.draw_line(np + Vector2(6, 0), np + Vector2(6, -24), col, 3.0)
		ci.draw_line(np + Vector2(6, -24), np + Vector2(16, -16), col, 3.0)
	if state == State.BONUS:
		_draw_bonus_hud(ci)
	for b in bubbles:
		_draw_callout(ci, b["pos"], b["text"], b["t"])
	if ticker_t < TICKER_TIME:
		_draw_ticker(ci)


func _draw_ticker(ci: CanvasItem) -> void:
	var a := clampf(minf(ticker_t / 0.2, (TICKER_TIME - ticker_t) / 0.5), 0.0, 1.0)
	var drop := (1.0 - minf(1.0, ticker_t / 0.25)) * -18.0
	var r := Rect2(816, 68 + drop, 238, 52)
	var parts := ticker_text.split(": ", true, 1)
	var genre_line := parts[0]
	var song_line := parts[1] if parts.size() > 1 else ""
	var ink := Color(GameData.INK, a)
	var sb := _box("ticker", GameData.CREAM, GameData.INK, 3, 10)
	if a >= 0.99:
		ci.draw_style_box(sb, r)
	else:
		ci.draw_rect(r, Color(GameData.CREAM, a))
		ci.draw_rect(r, ink, false, 3.0)
	# little 1930s eighth note
	var n := r.position + Vector2(20, 36)
	ci.draw_circle(n, 7.0, Color(GameData.RED, a))
	ci.draw_line(n + Vector2(6, 0), n + Vector2(6, -24), ink, 3.0)
	ci.draw_line(n + Vector2(6, -24), n + Vector2(15, -16), ink, 3.0)
	var f := GameData.title_font
	ci.draw_string(f, r.position + Vector2(40, 22), genre_line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 46, 15, Color(GameData.RED, a))
	ci.draw_string(GameData.body_font, r.position + Vector2(40, 42), song_line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 46, 14, ink)


func _draw_bonus_hud(ci: CanvasItem) -> void:
	var f := GameData.title_font
	var seg := Vector2(26, 20)
	var x0 := 640.0 - (BURRITO_BITES * 30.0) / 2.0
	var y := 140.0
	ci.draw_style_box(_box("bonus_plate", Color(GameData.CREAM, 0.92), GameData.INK, 4, 12), Rect2(x0 - 110, y - 14, BURRITO_BITES * 30.0 + 230, 50))
	ci.draw_string(f, Vector2(x0 - 100, y + 18), "BURRITO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GameData.INK)
	for i in BURRITO_BITES:
		var r := Rect2(Vector2(x0 + i * 30.0, y), seg)
		if i >= bites:
			ci.draw_rect(r.grow(2.0), GameData.INK)
			ci.draw_rect(r, GameData.RED)
		else:
			ci.draw_rect(r, Color(0, 0, 0, 0.12))
	ci.draw_string(GameData.lcd_font, Vector2(x0 + BURRITO_BITES * 30.0 + 8, y + 22), "%.1f" % bonus_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, GameData.RED if bonus_t < 3.0 else GameData.INK)
	if banner.text == "" and bonus_over_t < 0.0:
		var pulse := 0.7 + 0.3 * sin(star_t * 12.0)
		ci.draw_string(f, Vector2(SCREEN.position.x, 240), "TAP LEFT · RIGHT · LEFT · RIGHT!", HORIZONTAL_ALIGNMENT_CENTER, SCREEN.size.x, 30, Color(GameData.RED, pulse))


## 1930s comic speech bubble that pops in above its anchor.
func _draw_callout(ci: CanvasItem, anchor: Vector2, text: String, t: float) -> void:
	if t > 1.15:
		return
	var f := GameData.title_font
	var fs := 24
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	var h := 50.0
	var s := minf(1.0, t / 0.15)
	var x := clampf(anchor.x - w / 2.0, SCREEN.position.x + 8.0, SCREEN.end.x - w - 8.0)
	var rect := Rect2(x, anchor.y - 70.0 - (1.0 - s) * 20.0, w, h)
	var tx := clampf(anchor.x, rect.position.x + 20, rect.end.x - 40)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(tx, rect.end.y - 4), Vector2(tx + 22, rect.end.y - 4), anchor + Vector2(4, -6)]), GameData.INK)
	ci.draw_style_box(_box("bubble", GameData.CREAM, GameData.INK, 4, 16), rect)
	ci.draw_string(f, Vector2(rect.position.x, rect.position.y + 34.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, GameData.RED)


func _draw_stars() -> void:
	stars.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	stars.draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 32, Color(GameData.INK, 0.6), 3.0)
	stars.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		var ang := star_t * 3.0 + TAU * i / 3.0
		var c := Vector2(cos(ang) * 60.0, sin(ang) * 21.0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := 14.0 if k % 2 == 0 else 6.0
			var a := -PI / 2.0 + PI * k / 5.0 + star_t * 2.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		stars.draw_colored_polygon(pts, GameData.INK)


func _draw_speaker() -> void:
	var c := mute_btn.size / 2.0 + Vector2(-10, 0)
	var ink := GameData.INK
	mute_btn.draw_rect(Rect2(c + Vector2(-14, -7), Vector2(9, 14)), ink)
	mute_btn.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7), c + Vector2(6, -16), c + Vector2(6, 16), c + Vector2(-6, 7)]), ink)
	if ChiptuneAudio.muted:
		mute_btn.draw_line(c + Vector2(14, -9), c + Vector2(30, 9), GameData.RED, 4.0)
		mute_btn.draw_line(c + Vector2(30, -9), c + Vector2(14, 9), GameData.RED, 4.0)
	else:
		mute_btn.draw_arc(c + Vector2(6, 0), 10.0, -0.9, 0.9, 8, ink, 3.0)
		mute_btn.draw_arc(c + Vector2(6, 0), 19.0, -0.9, 0.9, 10, ink, 3.0)
