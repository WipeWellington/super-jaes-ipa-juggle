# Super Jae's IPA Juggle (Godot 4.3)

A Game & Watch-style juggling game with 1930s rubber-hose characters, inside a brass-and-wood handheld frame.

## Play
- Godot 4.3 is bundled in `tools/godot/`. Run the game:
  `tools\godot\Godot_v4.3-stable_win64.exe --path .`
  Open the editor with `tools\godot\Godot_v4.3-stable_win64.exe --path . --editor`
- Controls: tap the left/right half of the screen, or press Left/Right (A/D). Space/Enter restarts after a game over.

## Flow
Title (tap to start) → Select Borracho (Jae V., Josh M., Andres G.; trophy button = Top Borrachos) → juggling → ¡LA CRUDA! (enter initials if you made the top 5).

## Rules
- The keg launches IPAs along arcs: left slot → center → right → the SALUD tub. Stand under each mug as it lands to bounce it on.
- Each bounce = +10 points (+20 during **¡UNA MÁS Y YA!** fever, when Hop Hydration is under 25%) and refills hydration. 3 drops or running dry = game over. Every 200 points clears one drop.
- Power-ups: **Tacos al Pastor** (+50 points, clears a drop) and **Michelada** (+30 points, full hydration).
- Streaks: at 5+ bounces you headbang, at 10+ it's a full mosh with music notes. Every 15 bounces in a row you shart (3 random sounds, matching splats and Spanish callouts).
- Stages: Chula Vista Brewery (0) → The Archway (100) → Brewjería Taproom (200) → Bar Sin Nombre (300) → Los Panchos Taco Shop (450) → Tacos El Gordo - H St (600, foil burritos fly 1 beat faster, +25 each) → Lolita's Mexican Food (800, max speed).
- **¡HORA DEL BURRITO!** every 300 points: alternate left/right taps to eat 12 bites in 8 seconds, for full hydration and +150. Finishing triggers ¡DEMASIADO FRIJOL!
- Music: punk for stages 1–2, mariachi for 3–4 and the burrito rounds, metal from Los Panchos on. Each genre swaps between two songs every 8 bars.

## Art you can drop in (`assets/backgrounds/`)
`title_marquee.png` (title screen) and `bg_stage1_cvb.png`, `bg_stage2_archway.png`, `bg_stage3_brewjeria.png`, `bg_stage4_sinnombre.png`, `bg_stage5_lospanchos.png`, `bg_stage6_elgordo.png`, `bg_stage7_lolitas.png`. Anything missing falls back to drawn art. Open the editor once after adding images so they get imported.

## Files
| Path | What |
|---|---|
| `scripts/game_data.gd` | Autoload: borrachos, top-5 leaderboard (`user://highscores.json`), input map, shared drawing |
| `scripts/chiptune_audio.gd` | Autoload: real-time 8-bit synth, with 6 songs over 3 genres plus all SFX |
| `scripts/title_screen.gd` | Opening still, the & "friends" stamp, TAP TO START |
| `scripts/char_select.gd` | Select Borracho and the Top Borrachos panel |
| `scripts/game_and_watch.gd` | The game |
| `tools/slice_sprites.ps1` | Re-slices `raw_art/*.png` into `assets/sprites/` (240px) |
| `tests/` | `sim_test.tscn` (autopilot playthrough), `music_test.tscn` (synth check), `shots.tscn` (screenshots) |

## Phone export
- **Web:** Project → Export → Web (install export templates when prompted), then upload the zip to itch.io as HTML5. The project already uses the Compatibility renderer, which web export requires.
- **Android:** Project → Export → Android (needs the Android SDK and a debug keystore).
