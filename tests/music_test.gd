extends Node
## Drives the synth directly (headless has no real audio device) to check every song plays,
## swaps A<->B after 8 bars, and stays within [-1, 1] without going silent.

func _ready() -> void:
	ChiptuneAudio.set_process(false)
	ChiptuneAudio.track_changed.connect(func(t: String) -> void: print("[music] -> " + t))
	for g in ["ROCKABILLY", "PUNK", "MARIACHI", "METAL"]:
		ChiptuneAudio.stop_music()
		ChiptuneAudio.set_genre(g)
		var peak := 0.0
		var energy := 0.0
		var n := int(ChiptuneAudio.MIX_RATE * (40.0 if g == "ROCKABILLY" else 26.0))   # long enough for two swaps
		for i in n:
			var s: float = ChiptuneAudio._sample()
			peak = maxf(peak, absf(s))
			energy += s * s
		print("[music] %s: peak %.2f  rms %.3f  now on variation %s" % [g, peak, sqrt(energy / n), "AB"[ChiptuneAudio.variation]])
	print("[music] DONE")
	get_tree().quit()
