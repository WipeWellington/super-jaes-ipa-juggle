extends Control
## Opening still: full-screen title art (or a drawn 1930s marquee), the & "friends" stamp, and TAP TO START.

const NEXT_SCENE := "res://scenes/char_select.tscn"
const MARQUEE_PNG := "res://assets/backgrounds/title_marquee.png"
const FRIENDS_DELAY := 0.85
const FRIENDS_SLAM := 0.35

var _t := 0.0
var _has_png := false
var _started := false
var _art: TextureRect
var _grain: ColorRect
var _flash: ColorRect
var _prompt: RichTextLabel
var _pals: Array[TextureRect] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = GameData.BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # let taps reach _input instead of being eaten by the GUI
	_has_png = ResourceLoader.exists(MARQUEE_PNG)
	if _has_png:
		_art = TextureRect.new()
		_art.texture = load(MARQUEE_PNG)
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)
	else:
		# all three borrachos: Josh and Andres dancing on the left, Jae chugging on the right
		_add_pal("char2", "cheer", Vector2(90, 360), -6.0)
		_add_pal("char3", "cheer", Vector2(270, 372), 4.0)
		_add_pal("char1", "chug", Vector2(990, 360), 5.0)
		# drunkenly swaying title lettering on the drawn marquee
		add_child(GameData.make_rtl("[wave amp=9.0 freq=3.5]SUPER JAE'S[/wave]", 76, GameData.CREAM, Rect2(170, 84, 940, 100), 10))
		add_child(GameData.make_rtl("[wave amp=9.0 freq=3.5]IPA JUGGLE[/wave]", 88, GameData.AMBER.lightened(0.25), Rect2(170, 168, 940, 120), 11))
	_build_stamp()
	_build_prompt()
	_grain = ColorRect.new()
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/film_grain.gdshader")
	_grain.material = mat
	add_child(_grain)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.98, 0.9, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	get_viewport().size_changed.connect(_recenter)
	_recenter()


func _recenter() -> void:
	position = GameData.center_offset(self)
	var vp := get_viewport_rect().size
	for full in [_grain, _flash, _art]:
		if full:
			full.position = -position
			full.size = vp


func _add_pal(id: String, pose: String, pos: Vector2, tilt: float) -> void:
	var r := TextureRect.new()
	r.texture = GameData.sprite(pose, id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.position = pos
	r.size = Vector2(160, 240)
	r.pivot_offset = Vector2(80, 240)
	r.rotation = deg_to_rad(tilt)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.name = "Pal_" + id
	r.set_meta("base_y", pos.y)
	r.set_meta("phase", get_child_count() * 1.6)
	add_child(r)
	_pals.append(r)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	for pal in _pals:
		pal.position.y = float(pal.get_meta("base_y")) + sin(_t * 3.2 + float(pal.get_meta("phase"))) * 8.0


func _draw() -> void:
	if _has_png:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(-position, vp), GameData.WOOD_DARK)
	var c := Vector2(640, 300)
	var rays := 32
	for i in rays:
		if i % 2 == 0:
			continue
		var a0 := _t * 0.1 + TAU * i / rays
		var a1 := a0 + TAU / rays
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 2200.0, c + Vector2(cos(a1), sin(a1)) * 2200.0]), Color(GameData.AMBER, 0.14))

	# big marquee with chasing bulbs
	var ink := GameData.INK
	var band := Rect2(170, 70, 940, 220)
	draw_style_box(GameData.make_box(GameData.RED, ink, 9, 26), band.grow(10))
	draw_style_box(GameData.make_box(GameData.RED.darkened(0.15), GameData.BRASS, 6, 20), band)
	var bulbs := 34
	for k in bulbs:
		var u := float(k) / bulbs
		var p := _perimeter_point(band.grow(-4), u)
		var on := int(_t * 8.0 + k) % 3 != 0
		draw_circle(p, 7.0, ink)
		draw_circle(p, 5.0, Color(1.0, 0.92, 0.55) if on else Color(0.45, 0.3, 0.18))
	GameData.draw_mug(self, Vector2(250, 182), 1.6)
	GameData.draw_mug(self, Vector2(1030, 182), 1.6)


func _perimeter_point(r: Rect2, u: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := u * per
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


## The last-minute rubber stamp: & "friends" slams down under the title.
func _build_stamp() -> void:
	var stamp := Label.new()
	stamp.text = "& \"friends\""
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_theme_font_override("font", GameData.title_font)
	stamp.add_theme_font_size_override("font_size", 44)
	stamp.add_theme_color_override("font_color", GameData.RED)
	stamp.add_theme_color_override("font_outline_color", GameData.INK)
	stamp.add_theme_constant_override("outline_size", 4)
	var sb := GameData.make_box(GameData.CREAM, GameData.RED, 6, 12)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(5, 6)
	stamp.add_theme_stylebox_override("normal", sb)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.size = Vector2(320, 70)
	# with the painted title art, tuck it under the hop at the bottom of the IPA JUGGLE banner
	stamp.position = Vector2(660 - 160, 392) if _has_png else Vector2(640 - 160, 300)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = deg_to_rad(-6.0)   # crooked last-minute rubber stamp
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(2.5, 2.5)
	add_child(stamp)
	var tw := create_tween()
	tw.tween_interval(FRIENDS_DELAY)
	tw.tween_property(stamp, "scale", Vector2.ONE, FRIENDS_SLAM).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(stamp, "modulate:a", 1.0, FRIENDS_SLAM * 0.4)
	tw.parallel().tween_callback(ChiptuneAudio.play_rimshot).set_delay(0.1)   # the moment it lands


func _build_prompt() -> void:
	_prompt = GameData.make_rtl("[wave amp=9.0 freq=3.5]TAP TO START[/wave]", 56, GameData.CREAM, Rect2(340, 588, 600, 90), 12)
	_prompt.pivot_offset = _prompt.size / 2.0
	add_child(_prompt)
	var tw := create_tween().set_loops()
	tw.tween_property(_prompt, "scale", Vector2(1.07, 1.07), 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_prompt, "modulate:a", 1.0, 0.55)
	tw.tween_property(_prompt, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_prompt, "modulate:a", 0.45, 0.55)


func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed) \
			or event.is_action_pressed("restart"):
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	ChiptuneAudio.set_genre("ROCKABILLY")   # this tap also unlocks audio on mobile browsers
	ChiptuneAudio.play_stage_up()
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 1.0, 0.12)
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))
