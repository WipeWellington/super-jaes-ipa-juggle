extends Node
## Autoload "ChiptuneAudio": a tiny NES-style synth. Square lead, triangle bass,
## sine-sweep kick, noise snare/hats, plus procedural SFX. No audio files needed.

## Emitted whenever the song changes (new genre, or the A/B variation swap every 8 bars).
signal track_changed(title: String)

const MIX_RATE := 22050.0
const SAVE_PATH := "user://audio.cfg"
const BARS_PER_VARIATION := 8
const REST := -99

## Song patterns. spb = steps per beat, bar = steps per bar.
const SONGS := {
	"PUNK_A": {"title": "8-Bit Punk: Third Ave Skate Rat", "bpm": 178.0, "spb": 2, "bar": 8},
	"PUNK_B": {"title": "8-Bit Punk: Hardcore H Street", "bpm": 185.0, "spb": 2, "bar": 8},
	"MARIACHI_A": {"title": "8-Bit Mariachi: Fiesta en 3rd Ave", "bpm": 158.0, "spb": 2, "bar": 8},
	"MARIACHI_B": {"title": "8-Bit Mariachi: Fanfarria Brewjería", "bpm": 165.0, "spb": 2, "bar": 6},
	"METAL_A": {"title": "8-Bit Metal: Los Panchos Thrash", "bpm": 200.0, "spb": 4, "bar": 16},
	"METAL_B": {"title": "8-Bit Metal: Twin Burrito Leads", "bpm": 196.0, "spb": 4, "bar": 16},
	"ROCKABILLY_A": {"title": "8-Bit Rockabilly: Chula Vista Shuffle", "bpm": 165.0, "spb": 2, "bar": 8, "swing": true, "bars": 12},
	"ROCKABILLY_B": {"title": "8-Bit Rockabilly: Third Ave Hot Rod", "bpm": 165.0, "spb": 2, "bar": 8, "swing": true, "bars": 12},
}
const GENRES := {
	"ROCKABILLY": ["ROCKABILLY_A", "ROCKABILLY_B"],
	"PUNK": ["PUNK_A", "PUNK_B"],
	"MARIACHI": ["MARIACHI_A", "MARIACHI_B"],
	"METAL": ["METAL_A", "METAL_B"],
}

# PUNK_A: fast E-major skate punk (E4 B4 C#5 A4), PUNK_B: hardcore descent (G4 F4 E4 D4)
const PUNK_A_ROOTS := [64, 71, 73, 69]
const PUNK_A_ARP := [0, 7, 12, 7, 0, 7, 12, 7]
const PUNK_B_ROOTS := [67, 65, 64, 62]
const PUNK_B_PAT := [0, 0, 7, 0, 12, 0, 7, 0]
# MARIACHI_A: trumpets in thirds over a guitarrón oom-pah; MARIACHI_B: 6/8 fanfare
const MARIACHI_PAIRS := [[72, 76], [74, 77], [76, 79], [74, 77]]     # C5+E5, D5+F5, E5+G5, D5+F5
const MARIACHI_MOTIF := [0, REST, 2, 0, REST, 5, 3, REST]
const FANFARE_A := [67, 71, 74, 79, 74, 71]                            # G4 B4 D5 G5 D5 B4
const FANFARE_B := [79, 79, 74, 79, 83, REST]
# METAL_A: E Phrygian dominant chug; METAL_B: twin-lead D minor riff (D4 F4 A4 Bb4 A4)
const THRASH_RIFF_A := [52, 52, 52, 53, 52, 52, 52, 56, 52, 52, 57, 52, 59, 52, 60, 59]
const THRASH_RIFF_B := [52, 52, 52, 53, 52, 52, 52, 56, 52, 52, 57, 52, 56, 57, 53, 52]
const TWIN_A := [62, 65, 69, 70, 69, 65, 62, 65]
const TWIN_B := [69, 70, 72, 74, 72, 70, 69, 65]
const D_MINOR := [57, 58, 60, 62, 64, 65, 67, 69, 70, 72, 74, 76, 77, 79, 81]
# ROCKABILLY: 12-bar blues in A (A=0, D=+5, E=+7), slap-bass walk, swung twangy licks
const BLUES_12 := [0, 0, 0, 0, 5, 5, 0, 0, 7, 5, 0, 7]
const WALK := [45, 49, 52, 54, 55, 54, 52, 49]           # A2 C#3 E3 F#3 G3 F#3 E3 C#3
const LICK := [64, 67, 69, 72, 71, 69]                    # E4 G4 A4 C5 B4 A4
const LICK_STEPS_A := [0, 1, 2, 3, 4, 5]                  # lick on the first 3 beats, then a breath
const LICK_STEPS_B := [2, 3, 4, 5, 6, 7]                  # pickup-style: lick lands later in the bar
const ECHO_SAMPLES := 2200                                # ~100 ms slapback

var muted := false
var genre := ""                 # "", "PUNK", "MARIACHI" or "METAL"
var variation := 0              # 0 = A, 1 = B
var bpm_scale := 1.0
var _bar := 0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _buf := PackedVector2Array()
var _step := 0
var _step_left := 0.0

# music voices
var _lead_f := 0.0
var _lead_ph := 0.0
var _lead_duty := 0.5
var _lead_env := 0.0
var _lead_dec := 0.0
var _vib := 0.0              # trumpet vibrato depth (mariachi)
var _vib_ph := 0.0
var _harm_f := 0.0           # second square: trumpet harmony / twin lead
var _harm_ph := 0.0
var _harm_duty := 0.25
var _harm_env := 0.0
var _harm_dec := 0.0
var _bass_bend := 0.0        # upright-bass slap: pitch starts high and snaps down
var _echo := PackedFloat32Array()
var _echo_i := 0
var _echo_mix := 0.0
var _bass_f := 0.0
var _bass_ph := 0.0
var _bass_env := 0.0
var _bass_dec := 0.0
var _kick_f := 0.0
var _kick_ph := 0.0
var _kick_env := 0.0
var _noise_env := 0.0
var _noise_dec := 0.0
var _noise_vol := 0.0

# sfx voices
var _sfx: Array = []          # queue of [start_hz, end_hz, seconds, duty]
var _sfx_t := 0.0
var _sfx_ph := 0.0
var _crunch_env := 0.0
var _crunch_dec := 0.0
var _crunch_val := 0.0
var _crunch_hold := 0
var _crunch_hold_len := 5

# shart voice (see play_shart)
var _sh_type := -1
var _sh_t := 0.0
var _sh_dur := 0.0
var _sh_ph := 0.0
var _sh_low := 0.0       # state-variable bandpass filter state
var _sh_band := 0.0
var _sh_click_env := 0.0
var _sh_click_ph := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_echo.resize(ECHO_SAMPLES)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.12
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	# Godot 4.3 web defaults to "sample" playback, which can't play a generator (= silence on phones).
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		muted = cfg.get_value("audio", "muted", false)
	AudioServer.set_bus_mute(0, muted)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	_buf.resize(n)
	for i in n:
		var s := _sample()
		_buf[i] = Vector2(s, s)
	_playback.push_buffer(_buf)


# ---------------------------------------------------------------- public API

## "PUNK", "MARIACHI" or "METAL". Starts at Variation A; no-op if that genre is already playing.
func set_genre(genre_name: String) -> void:
	if genre_name == genre or not GENRES.has(genre_name):
		return
	genre = genre_name
	variation = 0
	_bar = 0
	_step = 0
	_step_left = 0.0
	track_changed.emit(current_title())


func stop_music() -> void:
	genre = ""


func current_song() -> String:
	return GENRES[genre][variation] if genre != "" else ""


func current_title() -> String:
	return SONGS[current_song()]["title"] if genre != "" else ""


## 0..1 — nudges the tempo up as the game speeds up.
func set_intensity(f: float) -> void:
	bpm_scale = 1.0 + 0.15 * clampf(f, 0.0, 1.0)


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.save(SAVE_PATH)
	return muted


func play_step() -> void:
	_sfx = [[260.0, 140.0, 0.05, 0.5]]
	_sfx_t = 0.0


func play_gulp() -> void:
	_sfx = []
	for m in [60, 64, 67, 72, 76]:
		var hz := _hz(m)
		_sfx.append([hz, hz * 1.06, 0.045, 0.25])
	_sfx_t = 0.0


func play_powerup() -> void:
	_sfx = []
	for m in [72, 76, 79, 84, 79, 84, 88]:
		_sfx.append([_hz(m), _hz(m), 0.06, 0.5])
	_sfx[_sfx.size() - 1][2] = 0.22
	_sfx_t = 0.0


func play_crash() -> void:
	_sfx = [[520.0, 55.0, 0.45, 0.5]]
	_sfx_t = 0.0
	_hit(0.5, 1.0, 5)


## Loud crunchy chomp for the burrito bonus round.
func play_crunch() -> void:
	_hit(0.09, 1.0, 3)
	_sfx = [[150.0 + randf() * 40.0, 70.0, 0.06, 0.5]]
	_sfx_t = 0.0


## Stage-up chime: a bright "ding-ding... DING!" with a fading bell tail.
func play_stage_up() -> void:
	_sfx = [
		[_hz(84), _hz(84), 0.07, 0.125], [_hz(91), _hz(91), 0.07, 0.125],
		[_hz(88), _hz(88), 0.07, 0.125], [_hz(96), _hz(96), 0.32, 0.125, true],
	]
	_sfx_t = 0.0


## Ba-dum-tss: two snare hits, then a fizzy square-wave cymbal.
func play_rimshot() -> void:
	_hit(0.07, 0.75)
	get_tree().create_timer(0.11).timeout.connect(_hit.bind(0.07, 0.75))
	get_tree().create_timer(0.24).timeout.connect(_rim_cymbal)


func _rim_cymbal() -> void:
	_sfx = [[3400.0, 2500.0, 0.45, 0.5, true]]
	_sfx_t = 0.0
	_hit(0.6, 0.45)


func _hit(sec: float, vol: float, hold: int = 1) -> void:
	_crunch_env = vol
	_crunch_dec = _decay(sec)
	_crunch_hold_len = hold
	_crunch_hold = 0


## Random 8-bit toot. Returns the profile so the visuals can match:
## 0 = High Squeaker, 1 = Warm & Gross Rumble, 2 = Watery Splatter.
func play_shart() -> int:
	_sh_type = randi() % 3
	_sh_t = 0.0
	_sh_ph = 0.0
	_sh_low = 0.0
	_sh_band = 0.0
	_sh_click_env = 0.0
	_sh_dur = [0.35, 0.65, 0.55][_sh_type]
	return _sh_type


func _shart_sample() -> float:
	var k := _sh_t / _sh_dur
	var t := _sh_t
	var out := 0.0
	match _sh_type:
		0:  # High Squeaker: square sweep 280 -> 520 Hz, 45 Hz vibrato, sharp pinch-off
			var f := lerpf(280.0, 520.0, k) * (1.0 + 0.06 * sin(TAU * 45.0 * t))
			_sh_ph = fmod(_sh_ph + f / MIX_RATE, 1.0)
			var sq := 1.0 if _sh_ph < 0.3 else -1.0
			out = sq * 0.24 * (1.0 - pow(k, 6.0))
		1:  # Warm & Gross Rumble: saw/square blend 85 -> 35 Hz, floppy 16 Hz AM
			var f := lerpf(85.0, 35.0, k)
			_sh_ph = fmod(_sh_ph + f / MIX_RATE, 1.0)
			var saw := 2.0 * _sh_ph - 1.0
			var sq := 1.0 if _sh_ph < 0.5 else -1.0
			var am := 0.55 + 0.45 * sin(TAU * 16.0 * t)
			out = (0.6 * saw + 0.4 * sq) * am * 0.42 * (1.0 - k * k)
			out += (randf() * 2.0 - 1.0) * 0.03 * (1.0 - k)
		2:  # Watery Splatter: bubbly 115 -> 55 Hz flutter + 65% bandpassed noise + droplet clicks
			var f := lerpf(115.0, 55.0, k)
			_sh_ph = fmod(_sh_ph + f / MIX_RATE, 1.0)
			var bubble := (1.0 if _sh_ph < 0.4 else -1.0) * (0.5 + 0.5 * sin(TAU * 23.0 * t))
			var fc := 700.0 + 500.0 * sin(TAU * 9.0 * t)
			var f1 := 2.0 * sin(PI * fc / MIX_RATE)
			var hp := (randf() * 2.0 - 1.0) - _sh_low - 0.5 * _sh_band
			_sh_band += f1 * hp
			_sh_low += f1 * _sh_band
			out = (0.35 * bubble + 0.65 * _sh_band * 1.6) * 0.34 * (1.0 - k)
			if randf() < 22.0 / MIX_RATE:
				_sh_click_env = 1.0
			if _sh_click_env > 0.01:
				_sh_click_ph = fmod(_sh_click_ph + 1900.0 / MIX_RATE, 1.0)
				out += sin(_sh_click_ph * TAU) * _sh_click_env * 0.18
				_sh_click_env *= 0.996
	_sh_t += 1.0 / MIX_RATE
	if _sh_t >= _sh_dur:
		_sh_type = -1
	return out


func play_game_over() -> void:
	play_crash()
	for m in [67, 63, 60, 55]:
		_sfx.append([_hz(m), _hz(m) * 0.97, 0.16, 0.5])
	_sfx[_sfx.size() - 1][2] = 0.5


# ---------------------------------------------------------------- synthesis

func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Per-sample multiplier that fades an envelope to ~0 in `sec` seconds.
func _decay(sec: float) -> float:
	return pow(0.001, 1.0 / maxf(sec * MIX_RATE, 1.0))


func _samples_per_step() -> float:
	var song: Dictionary = SONGS[current_song()]
	var base := MIX_RATE * 60.0 / (float(song["bpm"]) * bpm_scale) / float(song["spb"])
	if song.get("swing", false):
		# swung eighths: long-short (2/3 + 1/3 of the beat). _step already points at the next step here.
		return base * (1.34 if (_step - 1) % 2 == 0 else 0.66)
	return base


func _lead(midi: int, duty: float, sec: float, vol: float = 1.0) -> void:
	_lead_f = _hz(midi)
	_lead_duty = duty
	_lead_env = vol
	_lead_dec = _decay(sec)


func _harm(midi: int, duty: float, sec: float, vol: float = 1.0) -> void:
	_harm_f = _hz(midi)
	_harm_duty = duty
	_harm_env = vol
	_harm_dec = _decay(sec)


## Diatonic third above in D minor (for the twin-lead harmony).
func _d_minor_third(n: int) -> int:
	var i := D_MINOR.find(n)
	return D_MINOR[i + 2] if i >= 0 and i + 2 < D_MINOR.size() else n + 3


func _bass(midi: int, sec: float) -> void:
	_bass_f = _hz(midi)
	_bass_env = 1.0
	_bass_dec = _decay(sec)
	_bass_bend = 0.0


func _kick() -> void:
	_kick_f = 160.0
	_kick_env = 1.0


func _noise(sec: float, vol: float) -> void:
	_noise_env = 1.0
	_noise_dec = _decay(sec)
	_noise_vol = vol


func _on_step() -> void:
	var song := current_song()
	var bar_len: int = SONGS[song]["bar"]
	# every 8 bars, flip between Variation A and B so the loop never gets stale
	if _step > 0 and _step % bar_len == 0:
		_bar += 1
		if _bar >= int(SONGS[song].get("bars", BARS_PER_VARIATION)):
			_bar = 0
			_step = 0
			variation = 1 - variation
			song = current_song()
			bar_len = SONGS[song]["bar"]
			track_changed.emit(current_title())
	var s := _step % bar_len
	var b := _step / bar_len
	_vib = 0.0
	_echo_mix = 0.0
	match song:
		"ROCKABILLY_A", "ROCKABILLY_B":
			var chord: int = BLUES_12[b % 12]
			_echo_mix = 0.38                                     # slapback on the twang
			# slap upright bass: walking line, each note starts sharp and snaps down
			_bass(int(WALK[s]) + chord, 0.16)
			_bass_bend = 0.9
			var steps: Array = LICK_STEPS_A if song == "ROCKABILLY_A" else LICK_STEPS_B
			var li := steps.find(s)
			if li >= 0 and (b % 2 == 0 or song == "ROCKABILLY_B"):
				_lead(int(LICK[li]) + chord, 0.25, 0.07)       # staccato twang
			elif song == "ROCKABILLY_A" and s == 6 and b % 2 == 1:
				_lead(69 + chord, 0.25, 0.12)                   # answer note on the off bars
			# train beat: accents on 2 & 4, ghost chugs in between
			if s == 2 or s == 6:
				_noise(0.11, 0.30)
			else:
				_noise(0.03, 0.08)
			if s == 0 or s == 4:
				_kick()
		"PUNK_A":
			var root: int = PUNK_A_ROOTS[b % 4]
			_lead(root + PUNK_A_ARP[s], 0.25, 0.13)
			_bass(root - 24, 0.12)
			if s == 0 or s == 4 or s == 5:
				_kick()
			_backbeat(s == 2 or s == 6)
		"PUNK_B":
			var root: int = PUNK_B_ROOTS[b % 4]
			_lead(root + PUNK_B_PAT[s], 0.5, 0.07, 0.9)
			_harm(root + PUNK_B_PAT[s] + 7, 0.5, 0.07, 0.5)      # power-chord fifth
			_bass(root - 24, 0.08)
			if s == 0 or s == 3 or s == 4:
				_kick()
			_backbeat(s == 2 or s == 6)
		"MARIACHI_A":
			var pair: Array = MARIACHI_PAIRS[b % 4]
			var off: int = MARIACHI_MOTIF[s]
			_vib = 0.012
			if off != REST:
				_lead(int(pair[1]) + off, 0.25, 0.22)
				_harm(int(pair[0]) + off, 0.25, 0.22, 0.8)     # trumpets in thirds
			if s == 0:
				_bass(48, 0.2)                                  # guitarrón: C3...
				_kick()
			elif s == 4:
				_bass(43, 0.2)                                  # ...G2
			if s % 2 == 1:
				_noise(0.05, 0.16)                              # off-beat strums
		"MARIACHI_B":
			var phrase: Array = FANFARE_A if b % 2 == 0 else FANFARE_B
			var note: int = phrase[s]
			_vib = 0.014
			if note != REST:
				_lead(note, 0.25, 0.2)
				if s == 0 or s == 3:
					_harm(note - 4, 0.25, 0.2, 0.8)
			if s == 0:
				_bass(43, 0.22)
				_kick()
			elif s == 3:
				_bass(50, 0.2)
			else:
				_noise(0.04, 0.14)
		"METAL_A":
			var riff: Array = THRASH_RIFF_A if b % 2 == 0 else THRASH_RIFF_B
			var note: int = riff[s]
			if note == 52:
				_lead(note, 0.25, 0.045, 0.85)                  # palm-muted chug
				_bass(40, 0.06)
			else:
				_lead(note + 12, 0.125, 0.12)                   # accent note
				_bass(note - 12, 0.1)
			_metal_drums(s)
		"METAL_B":
			var line: Array = TWIN_A if b % 2 == 0 else TWIN_B
			if s % 2 == 0:
				var note: int = line[s / 2]
				_lead(note, 0.25, 0.24)
				_harm(_d_minor_third(note), 0.25, 0.24, 0.85)  # twin-lead harmony
			_bass(38, 0.05)                                     # D2 chug
			_metal_drums(s)
	_step += 1


func _backbeat(snare: bool) -> void:
	if snare:
		_noise(0.14, 0.32)
	else:
		_noise(0.03, 0.10)


func _metal_drums(s16: int) -> void:
	if s16 == 4 or s16 == 12:
		_noise(0.15, 0.34)
	else:
		_kick()                                                 # double-kick
		if s16 % 2 == 0:
			_noise(0.02, 0.08)


func _sample() -> float:
	if genre != "":
		_step_left -= 1.0
		if _step_left <= 0.0:
			_on_step()
			_step_left += _samples_per_step()

	var out := 0.0
	var vib := 1.0
	if _vib > 0.0:
		_vib_ph = fmod(_vib_ph + 5.5 / MIX_RATE, 1.0)
		vib = 1.0 + _vib * sin(_vib_ph * TAU)
	var lead := 0.0
	if _lead_env > 0.001:
		_lead_ph = fmod(_lead_ph + _lead_f * vib / MIX_RATE, 1.0)
		lead = (1.0 if _lead_ph < _lead_duty else -1.0) * _lead_env * 0.13
		_lead_env *= _lead_dec
	# slapback echo on the lead (rockabilly); the delay line always runs so it tails off cleanly
	var echoed := _echo[_echo_i]
	_echo[_echo_i] = lead
	_echo_i = (_echo_i + 1) % ECHO_SAMPLES
	out += lead + echoed * _echo_mix
	if _bass_bend > 0.001:
		_bass_bend *= 0.9965
	if _harm_env > 0.001:
		_harm_ph = fmod(_harm_ph + _harm_f * vib / MIX_RATE, 1.0)
		out += (1.0 if _harm_ph < _harm_duty else -1.0) * _harm_env * 0.09
		_harm_env *= _harm_dec
	if _bass_env > 0.001:
		_bass_ph = fmod(_bass_ph + _bass_f * (1.0 + _bass_bend) / MIX_RATE, 1.0)
		out += (4.0 * absf(_bass_ph - 0.5) - 1.0) * _bass_env * 0.30
		_bass_env *= _bass_dec
	if _kick_env > 0.001:
		_kick_f = maxf(45.0, _kick_f * 0.9993)
		_kick_ph = fmod(_kick_ph + _kick_f / MIX_RATE, 1.0)
		out += sin(_kick_ph * TAU) * _kick_env * 0.42
		_kick_env *= 0.9990
	if _noise_env > 0.001:
		out += (randf() * 2.0 - 1.0) * _noise_env * _noise_vol
		_noise_env *= _noise_dec

	if not _sfx.is_empty():
		var seg: Array = _sfx[0]
		var dur: float = seg[2]
		var f := lerpf(seg[0], seg[1], minf(_sfx_t / dur, 1.0))
		_sfx_ph = fmod(_sfx_ph + f / MIX_RATE, 1.0)
		var duty: float = seg[3]
		var amp := 0.17
		if seg.size() > 4 and seg[4]:
			amp *= 1.0 - minf(_sfx_t / dur, 1.0)     # fade-out (cymbal)
		out += (1.0 if _sfx_ph < duty else -1.0) * amp
		_sfx_t += 1.0 / MIX_RATE
		if _sfx_t >= dur:
			_sfx.pop_front()
			_sfx_t = 0.0
	if _crunch_env > 0.001:
		_crunch_hold -= 1
		if _crunch_hold <= 0:
			_crunch_val = randf() * 2.0 - 1.0
			_crunch_hold = _crunch_hold_len   # longer hold = crunchier, lower noise
		out += _crunch_val * _crunch_env * 0.4
		_crunch_env *= _crunch_dec
	if _sh_type >= 0:
		out += _shart_sample()

	return clampf(out, -1.0, 1.0)
