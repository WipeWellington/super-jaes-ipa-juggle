extends Control
## Title + "Select Borracho" screen: marquee (PNG or drawn), the & "friends" stamp, three profile cards.

const GAME_SCENE := "res://scenes/game_and_watch.tscn"
const MARQUEE_PNG := "res://assets/backgrounds/title_marquee.png"
const CARD_SIZE := Vector2(300, 416)
const ART_H := 190.0
const CARD_GAP := 40.0
const CARD_Y := 222.0
const FRIENDS_DELAY := 0.85
const FRIENDS_SLAM := 0.35

var _t := 0.0
var _cards: Array[Button] = []
var _picked := false
var _has_marquee_png := false
var _grain: ColorRect
var _trophy: Button
var _board_panel: Panel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = GameData.BASE_SIZE
	# title_marquee.png is a full-screen still (shown on the title screen); here we keep the drawn banner
	_has_marquee_png = false
	if _has_marquee_png:
		var m := TextureRect.new()
		m.texture = load(MARQUEE_PNG)
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m.position = Vector2(200, 6)
		m.size = Vector2(880, 130)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(m)
	_build_header()
	_build_cards()
	_build_hint()
	_build_trophy()
	_build_grain()
	ChiptuneAudio.set_genre("ROCKABILLY")   # keeps playing from the title (or restarts after CHANGE BORRACHO)
	get_viewport().size_changed.connect(_recenter)
	_recenter()
	var idx := GameData.CHAR_ORDER.find(GameData.selected_char)
	if idx >= 0:
		_cards[idx].grab_focus()


func _recenter() -> void:
	position = GameData.center_offset(self)
	_grain.position = -position
	_grain.size = get_viewport_rect().size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	for i in _cards.size():
		var art := _cards[i].get_node("Art") as TextureRect
		art.position.y = 10.0 + sin(_t * 3.0 + i * 1.3) * 4.0


func _draw() -> void:
	draw_rect(Rect2(-position, get_viewport_rect().size), GameData.WOOD_DARK)
	var c := Vector2(640, 780)
	var rays := 28
	for i in rays:
		if i % 2 == 0:
			continue
		var a0 := _t * 0.08 + TAU * i / rays
		var a1 := a0 + TAU / rays
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 2000.0, c + Vector2(cos(a1), sin(a1)) * 2000.0])
		draw_colored_polygon(pts, Color(GameData.AMBER, 0.13))

	var ink := GameData.INK
	var f := GameData.title_font
	if not _has_marquee_png:
		var red := GameData.RED
		_ribbon_tail(Vector2(250, 36), -1, ink, red)
		_ribbon_tail(Vector2(1030, 36), 1, ink, red)
		var band := Rect2(250, 20, 780, 96)
		draw_style_box(GameData.make_box(red, ink, 7, 14), band)
		draw_rect(Rect2(band.position + Vector2(14, 11), Vector2(band.size.x - 28, 4)), Color(1, 1, 1, 0.25))
		# marquee bulbs
		for k in 26:
			var bx := band.position.x + 20.0 + k * (band.size.x - 40.0) / 25.0
			var on := int(_t * 6.0 + k) % 3 != 0
			for by in [band.position.y + 4.0, band.end.y - 4.0]:
				draw_circle(Vector2(bx, by), 5.0, ink)
				draw_circle(Vector2(bx, by), 3.5, Color(1.0, 0.9, 0.5) if on else Color(0.5, 0.35, 0.2))
		draw_string(f, Vector2(band.position.x + 3, 88), GameData.GAME_TITLE, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, 52, ink)
		draw_string(f, Vector2(band.position.x, 85), GameData.GAME_TITLE, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, 52, GameData.CREAM)

	GameData.draw_mug(self, Vector2(372, 190), 0.7)
	GameData.draw_mug(self, Vector2(908, 190), 0.7)


func _ribbon_tail(anchor: Vector2, dir: int, ink: Color, red: Color) -> void:
	var w := 110.0 * dir
	var pts := PackedVector2Array([
		anchor + Vector2(0, -10), anchor + Vector2(w, -10), anchor + Vector2(w * 0.7, 40),
		anchor + Vector2(w, 90), anchor + Vector2(0, 90),
	])
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_colored_polygon(pts, red.darkened(0.3))
	draw_polyline(outline, ink, 6.0)


func _build_cards() -> void:
	var total := CARD_SIZE.x * 3 + CARD_GAP * 2
	var x0 := (1280.0 - total) / 2.0
	for i in GameData.CHAR_ORDER.size():
		var id: String = GameData.CHAR_ORDER[i]
		var info: Dictionary = GameData.CHARACTERS[id]
		var card := Button.new()
		card.position = Vector2(x0 + i * (CARD_SIZE.x + CARD_GAP), CARD_Y)
		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE / 2.0
		card.focus_mode = Control.FOCUS_ALL
		var normal := GameData.make_box(GameData.CREAM, GameData.INK, 6, 22)
		normal.shadow_color = Color(0, 0, 0, 0.45)
		normal.shadow_size = 6
		normal.shadow_offset = Vector2(6, 9)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = GameData.CREAM.lerp(GameData.AMBER, 0.25)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = GameData.AMBER
		var focus := normal.duplicate() as StyleBoxFlat
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = GameData.BRASS
		focus.shadow_size = 0
		focus.set_expand_margin_all(6)
		card.add_theme_stylebox_override("normal", normal)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", pressed)
		card.add_theme_stylebox_override("focus", focus)
		add_child(card)

		var art := TextureRect.new()
		art.name = "Art"
		art.texture = GameData.sprite(info["card_pose"], id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2(14, 10)
		art.size = Vector2(CARD_SIZE.x - 28, ART_H)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)

		var y := ART_H + 10.0
		var name_label := _label(info["name"], 32, GameData.RED, GameData.title_font)
		name_label.position = Vector2(0, y - 2)
		name_label.size = Vector2(CARD_SIZE.x, 38)
		name_label.pivot_offset = name_label.size / 2.0
		name_label.rotation = deg_to_rad([-2.0, 1.5, 2.0][i % 3])    # playful tilt
		GameData.tune_outline(name_label, 32, 7)                   # chunky black outline
		card.add_child(name_label)

		var tag := _wrapped(info["tagline"], 16, GameData.RED.darkened(0.15), Rect2(10, y + 32, CARD_SIZE.x - 20, 22))
		card.add_child(tag)

		var drink := _wrapped(info["drink"], 14, GameData.BRASS_DARK.darkened(0.2), Rect2(10, y + 54, CARD_SIZE.x - 20, 20), GameData.body_font)
		card.add_child(drink)

		var bio := _wrapped(info["bio"], 13, GameData.INK.lightened(0.15), Rect2(16, y + 78, CARD_SIZE.x - 32, 92), GameData.body_font)
		bio.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		card.add_child(bio)

		var hi := _label("HI %04d" % GameData.high_score(id), 18, GameData.INK, GameData.lcd_font)
		hi.position = Vector2(0, CARD_SIZE.y - 28)
		hi.size = Vector2(CARD_SIZE.x, 24)
		card.add_child(hi)

		card.pressed.connect(_on_pick.bind(id, card))
		card.mouse_entered.connect(_wiggle.bind(card))
		card.focus_entered.connect(_wiggle.bind(card))
		_cards.append(card)


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


## Word-wrapped card text. autowrap must be on before sizing, or the label grows to fit one long line.
func _wrapped(text: String, font_size: int, color: Color, r: Rect2, font: Font = null) -> Label:
	var l := _label(text, font_size, color, font if font else GameData.title_font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.position = r.position
	l.size = r.size
	return l


func _build_header() -> void:
	var h := _label("SELECT BORRACHO:", 36, GameData.CREAM, GameData.title_font)
	h.position = Vector2(390, 164)
	h.size = Vector2(500, 50)
	h.pivot_offset = h.size / 2.0
	h.rotation = deg_to_rad(-2.0)
	GameData.tune_outline(h, 36, 9)
	add_child(h)


func _build_hint() -> void:
	var hint := _label("Tap a borracho to start  •  tap left / right to move  •  bounce every IPA!", 22, GameData.CREAM, GameData.title_font)
	hint.position = Vector2(0, 652)
	hint.size = Vector2(1280, 40)
	add_child(hint)


## The last-minute rubber stamp: & "friends" slams down under the marquee.
func _build_friends_stamp() -> void:
	var stamp := _label("& \"friends\"", 34, GameData.RED, GameData.title_font)
	var sb := GameData.make_box(GameData.CREAM, GameData.RED, 5, 10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(4, 5)
	stamp.add_theme_stylebox_override("normal", sb)
	stamp.add_theme_color_override("font_outline_color", GameData.INK)
	stamp.add_theme_constant_override("outline_size", 3)
	stamp.size = Vector2(250, 52)
	stamp.position = Vector2(640 - 125, 116)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = deg_to_rad(-4.0)
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(2.5, 2.5)
	add_child(stamp)

	var tw := create_tween()
	tw.tween_interval(FRIENDS_DELAY)
	tw.tween_property(stamp, "scale", Vector2.ONE, FRIENDS_SLAM).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(stamp, "modulate:a", 1.0, FRIENDS_SLAM * 0.4)
	# elastic ease-out first hits full size ~0.1s in: that's the "slam"
	tw.parallel().tween_callback(ChiptuneAudio.play_rimshot).set_delay(0.1)


## "TOP BORRACHOS" trophy toggle in the top-left corner + the Hall of Fame panel it opens.
func _build_trophy() -> void:
	_trophy = Button.new()
	_trophy.position = Vector2(14, 10)
	_trophy.size = Vector2(124, 96)
	_trophy.focus_mode = Control.FOCUS_NONE
	_trophy.toggle_mode = true
	_trophy.add_theme_stylebox_override("normal", GameData.make_box(GameData.BRASS, GameData.INK, 4, 14))
	_trophy.add_theme_stylebox_override("hover", GameData.make_box(GameData.BRASS.lightened(0.15), GameData.INK, 4, 14))
	_trophy.add_theme_stylebox_override("pressed", GameData.make_box(GameData.AMBER, GameData.INK, 4, 14))
	_trophy.add_theme_stylebox_override("hover_pressed", GameData.make_box(GameData.AMBER, GameData.INK, 4, 14))
	_trophy.draw.connect(_draw_trophy)
	_trophy.toggled.connect(_on_trophy)
	add_child(_trophy)

	_board_panel = Panel.new()
	_board_panel.position = Vector2(290, 150)
	_board_panel.size = Vector2(700, 420)
	_board_panel.visible = false
	var sb := GameData.make_box(GameData.CREAM, GameData.INK, 7, 22)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(8, 10)
	_board_panel.add_theme_stylebox_override("panel", sb)
	_board_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_trophy.button_pressed = false
	)
	add_child(_board_panel)


func _on_trophy(on: bool) -> void:
	for c in _board_panel.get_children():
		c.queue_free()
	if on:
		var b := GameData.build_leaderboard()
		b.position = Vector2(40, 30)
		b.size = Vector2(620, 320)
		_board_panel.add_child(b)
		var hint := _label("tap to close", 16, Color(GameData.INK, 0.6), GameData.title_font)
		hint.position = Vector2(0, 372)
		hint.size = Vector2(700, 30)
		_board_panel.add_child(hint)
		ChiptuneAudio.play_step()
	_board_panel.visible = on


func _draw_trophy() -> void:
	var ink := GameData.INK
	var c := Vector2(62, 34)
	var gold := Color(1.0, 0.82, 0.25)
	_trophy.draw_arc(c + Vector2(-20, -4), 10.0, PI * 0.5, PI * 1.5, 10, ink, 5.0)
	_trophy.draw_arc(c + Vector2(20, -4), 10.0, -PI * 0.5, PI * 0.5, 10, ink, 5.0)
	var cup := PackedVector2Array([c + Vector2(-20, -18), c + Vector2(20, -18), c + Vector2(12, 8), c + Vector2(-12, 8)])
	_trophy.draw_colored_polygon(cup, gold)
	_trophy.draw_polyline(PackedVector2Array([cup[0], cup[1], cup[2], cup[3], cup[0]]), ink, 3.0)
	_trophy.draw_rect(Rect2(c + Vector2(-4, 8), Vector2(8, 8)), ink)
	_trophy.draw_rect(Rect2(c + Vector2(-14, 16), Vector2(28, 7)), ink)
	var f := GameData.title_font
	_trophy.draw_string(f, Vector2(0, 74), "TOP", HORIZONTAL_ALIGNMENT_CENTER, 124, 17, ink)
	_trophy.draw_string(f, Vector2(0, 90), "BORRACHOS", HORIZONTAL_ALIGNMENT_CENTER, 124, 15, ink)


func _build_grain() -> void:
	_grain = ColorRect.new()
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/film_grain.gdshader")
	_grain.material = mat
	add_child(_grain)


func _wiggle(card: Button) -> void:
	if _picked:
		return
	var tw := create_tween()
	tw.tween_property(card, "rotation", deg_to_rad(-3.0), 0.08)
	tw.tween_property(card, "rotation", deg_to_rad(3.0), 0.12)
	tw.tween_property(card, "rotation", 0.0, 0.08)


func _on_pick(id: String, card: Button) -> void:
	if _picked:
		return
	_picked = true
	GameData.selected_char = id
	ChiptuneAudio.play_gulp()   # this first tap also unlocks audio on mobile browsers
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(1.12, 0.9), 0.08)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
