extends Node
## Autoload "GameData": selected character, high scores, input map, shared colors.

const CHAR_ORDER := ["char1", "char2", "char3"]

## Rename the borrachos here.
const CHARACTERS := {
	"char1": {
		"name": "Jae V.", "tagline": "The Hopfather of 3rd Ave", "card_pose": "chug", "initials": "JAE",
		"drink": "Drink: Double Hazy IPA (9.2% ABV)",
		"bio": "Never met a pint he couldn't juggle. Claims he's \"just having one\" at Chula Vista Brewery before ending up at Los Panchos at 2 AM.",
	},
	"char2": {
		"name": "Josh M.", "tagline": "El Misterioso de Broadway", "card_pose": "cheer", "initials": "JSH",
		"drink": "Drink: Cold Brew & Michelada Chaser",
		"bio": "Keeps his shades on inside The Archway so nobody sees his eyes glazing over. Immune to bright neon signs and bad decisions.",
	},
	"char3": {
		"name": "Andres G.", "tagline": "The Mosh Pit Mixologist", "card_pose": "cheer", "initials": "AND",
		"drink": "Drink: Pitcher of Amber Ale",
		"bio": "Powered by 8-bit thrash riffs and carne asada fries. Can headbang at 200 BPM without spilling a single drop.",
	},
}

const HIGHSCORE_PATH := "user://highscores.json"
const LEADERBOARD_SIZE := 5
const DEFAULT_LEADERBOARD := [
	{"initials": "JAE", "character": "Jae V.", "score": 480, "location": "Los Panchos Taco Shop"},
	{"initials": "JSH", "character": "Josh M.", "score": 320, "location": "Bar Sin Nombre"},
	{"initials": "AND", "character": "Andres G.", "score": 210, "location": "Brewjería Taproom"},
]
## Top 5: [{initials, character, score, location}], highest first.
var leaderboard: Array = []

const GAME_TITLE := "SUPER JAE'S IPA JUGGLE"
const SAVE_PATH := "user://pub_and_watch.cfg"

# 1930s cartoon palette
const INK := Color(0.10, 0.08, 0.06)
const CREAM := Color(0.96, 0.91, 0.78)
const AMBER := Color(0.95, 0.62, 0.12)
const FOAM := Color(1.0, 0.97, 0.88)
const BRASS := Color(0.80, 0.62, 0.28)
const BRASS_DARK := Color(0.50, 0.36, 0.14)
const WOOD := Color(0.40, 0.23, 0.11)
const WOOD_DARK := Color(0.26, 0.14, 0.06)
const RED := Color(0.72, 0.16, 0.10)

var selected_char: String = "char1"
var high_scores := {}
const CARTOON_FONT := "res://assets/fonts/cartoon_font.ttf"
const OUTLINE := Color(0.08, 0.05, 0.03)
var title_font: Font          # Luckiest Guy (cartoon display font)
var body_font: SystemFont     # readable serif for small paragraphs
var lcd_font: SystemFont


func _ready() -> void:
	_add_keys("move_left", [KEY_LEFT, KEY_A])
	_add_keys("move_right", [KEY_RIGHT, KEY_D])
	_add_keys("restart", [KEY_SPACE, KEY_ENTER])
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif", "serif"])
	body_font.font_weight = 800
	# Luckiest Guy for all display text; the serif covers any glyph it lacks (e.g. "·")
	if ResourceLoader.exists(CARTOON_FONT):
		title_font = load(CARTOON_FONT) as Font
		var fb: Array[Font] = [body_font]
		title_font.fallbacks = fb
	else:
		title_font = body_font
	lcd_font = SystemFont.new()
	lcd_font.font_names = PackedStringArray(["Courier New", "Consolas", "DejaVu Sans Mono", "monospace"])
	lcd_font.font_weight = 700
	_load()
	_load_leaderboard()


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


const BASE_SIZE := Vector2(1280, 720)


## With aspect "expand" a wide phone gets extra room; this keeps the 1280x720 layout centered in it.
func center_offset(node: CanvasItem) -> Vector2:
	return ((node.get_viewport_rect().size - BASE_SIZE) / 2.0).floor()


func char_name(char_id: String = "") -> String:
	if char_id == "":
		char_id = selected_char
	return CHARACTERS[char_id]["name"]


func sprite_path(pose: String, char_id: String = "") -> String:
	if char_id == "":
		char_id = selected_char
	return "res://assets/sprites/%s_%s.png" % [char_id, pose]


func has_pose(pose: String, char_id: String = "") -> bool:
	return ResourceLoader.exists(sprite_path(pose, char_id))


func sprite(pose: String, char_id: String = "") -> Texture2D:
	var path := sprite_path(pose, char_id)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func high_score(char_id: String = "") -> int:
	if char_id == "":
		char_id = selected_char
	return int(high_scores.get(char_id, 0))


## Returns true if this is a new best for the selected character.
func submit_score(score: int) -> bool:
	if score <= high_score():
		return false
	high_scores[selected_char] = score
	_save()
	return true


# ---------------------------------------------------------------- top-5 leaderboard

func default_initials(char_id: String = "") -> String:
	if char_id == "":
		char_id = selected_char
	return CHARACTERS[char_id]["initials"]


func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	if leaderboard.size() < LEADERBOARD_SIZE:
		return true
	return score > int(leaderboard[LEADERBOARD_SIZE - 1]["score"])


## Inserts a run, saves, and returns its rank index (0 = first), or -1 if it didn't make the cut.
func insert_record(initials: String, score: int, location: String) -> int:
	var entry := {"initials": initials.to_upper().left(3), "character": char_name(), "score": score, "location": location}
	var rank := leaderboard.size()
	for i in leaderboard.size():
		if score > int(leaderboard[i]["score"]):
			rank = i
			break
	if rank >= LEADERBOARD_SIZE:
		return -1
	leaderboard.insert(rank, entry)
	while leaderboard.size() > LEADERBOARD_SIZE:
		leaderboard.pop_back()
	_save_leaderboard()
	return rank


func _load_leaderboard() -> void:
	leaderboard = []
	if FileAccess.file_exists(HIGHSCORE_PATH):
		var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Array:
				for e in data:
					if e is Dictionary and e.has("initials") and e.has("score"):
						leaderboard.append({
							"initials": str(e["initials"]).left(3),
							"character": str(e.get("character", "?")),
							"score": int(e["score"]),
							"location": str(e.get("location", "")),
						})
	if leaderboard.is_empty():
		leaderboard = DEFAULT_LEADERBOARD.duplicate(true)
		_save_leaderboard()
	leaderboard.sort_custom(func(a, b) -> bool: return int(a["score"]) > int(b["score"]))


func _save_leaderboard() -> void:
	var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(leaderboard, "  "))


## Builds the retro "TOP BORRACHOS" table. highlight = rank index to flash (or -1).
func build_leaderboard(highlight: int = -1) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = "~ TOP BORRACHOS ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", RED)
	tune_outline(title, 30, 6)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	var head := ["#", "INI", "BORRACHO", "SCORE", "LOCATION"]
	for h in head:
		grid.add_child(_cell(h, 15, BRASS_DARK, title_font))
	for i in LEADERBOARD_SIZE:
		var col := RED if i == highlight else INK
		if i < leaderboard.size():
			var e: Dictionary = leaderboard[i]
			grid.add_child(_cell(str(i + 1), 20, col, lcd_font))
			grid.add_child(_cell(e["initials"], 20, col, lcd_font))
			grid.add_child(_cell(e["character"], 17, col, body_font))
			grid.add_child(_cell("%04d" % int(e["score"]), 20, col, lcd_font))
			grid.add_child(_cell(e["location"], 15, col, body_font))
		else:
			for c in [str(i + 1), "---", "-", "----", "-"]:
				grid.add_child(_cell(c, 18, Color(INK, 0.4), lcd_font))
	return box


func _cell(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tune_outline(l, font_size, 0)
	return l


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for id in CHAR_ORDER:
		high_scores[id] = cfg.get_value("high_scores", id, 0)
	selected_char = cfg.get_value("player", "last_char", "char1")


func _save() -> void:
	var cfg := ConfigFile.new()
	for id in high_scores:
		cfg.set_value("high_scores", id, high_scores[id])
	cfg.set_value("player", "last_char", selected_char)
	cfg.save(SAVE_PATH)


## Cartoon beer mug, used by the game and the menu. ghost = faint LCD "unlit segment".
func draw_mug(ci: CanvasItem, pos: Vector2, s: float, ghost: bool = false) -> void:
	var foam_pts := [Vector2(-11, -17), Vector2(0, -21), Vector2(11, -17)]
	var body := Rect2(pos + Vector2(-15, -16) * s, Vector2(30, 36) * s)
	if ghost:
		var g := Color(0, 0, 0, 0.06)
		ci.draw_rect(body, g)
		ci.draw_arc(pos + Vector2(15, 2) * s, 9 * s, -PI * 0.5, PI * 0.5, 12, g, 5 * s)
		for f in foam_pts:
			ci.draw_circle(pos + f * s, 8 * s, g)
		return
	ci.draw_arc(pos + Vector2(15, 2) * s, 10 * s, -PI * 0.5, PI * 0.5, 16, INK, 8 * s)
	ci.draw_arc(pos + Vector2(15, 2) * s, 10 * s, -PI * 0.5, PI * 0.5, 16, FOAM, 3 * s)
	ci.draw_rect(body.grow(3 * s), INK)
	ci.draw_rect(body, AMBER)
	ci.draw_rect(Rect2(body.position + Vector2(5, 7) * s, Vector2(4, 22) * s), Color(1, 1, 0.9, 0.7))
	ci.draw_rect(Rect2(body.position + Vector2(20, 9) * s, Vector2(3, 18) * s), AMBER.darkened(0.25))
	for f in foam_pts:
		ci.draw_circle(pos + f * s, 10 * s, INK)
	for f in foam_pts:
		ci.draw_circle(pos + f * s, 7.5 * s, FOAM)


## The theme gives every label a thick outline + drop shadow. That's great on big titles but turns
## small text into blobs, so small labels get them switched off.
func tune_outline(c: Control, font_size: int, outline: int = -1) -> void:
	if outline < 0:
		outline = 0 if font_size < 26 else 8
	c.add_theme_constant_override("outline_size", outline)
	c.add_theme_color_override("font_outline_color", OUTLINE)
	if outline == 0:
		c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))


## Wobbly/shaky BBCode title, e.g. make_rtl("[wave amp=9.0 freq=3.5]HI[/wave]", 60, CREAM, rect).
func make_rtl(bbcode: String, font_size: int, color: Color, rect: Rect2, outline: int = 8) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = "[center]" + bbcode + "[/center]"
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.clip_contents = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", title_font)
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_color_override("font_outline_color", OUTLINE)
	r.add_theme_constant_override("outline_size", outline)
	r.position = rect.position
	r.size = rect.size
	return r


func make_box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb
