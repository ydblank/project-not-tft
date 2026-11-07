extends SceneTree

## Draws the burning-ground flame sprite sheet (pixel art, generated, not hand drawn) used by the
## Mage's Inferno skill (assets/effects/burning_ground.gd). Same palette as the fireball sheets
## (tools/make_fireball_sprites.py). Run from the project root:
##
##     <godot> --headless --path . --script res://tools/make_ground_fire_sprites.gd
##
## Writes assets/art/1 Characters/Other/Ground_Fire.png: FRAMES frames of W x H, one small flame
## licking upward (bottom-centre is the flame's foot), looping. Deterministic (seeded).

const OUT_PATH := "res://assets/art/1 Characters/Other/Ground_Fire.png"
const FRAMES := 8
const W := 16
const H := 20
const SEED := 4242

## Heat ramp, coolest (edge) to hottest (core); the fireball's palette.
const PALETTE: Array[Color] = [
	Color8(122, 24, 22),
	Color8(190, 40, 24),
	Color8(232, 92, 26),
	Color8(252, 158, 38),
	Color8(255, 214, 82),
	Color8(255, 244, 178),
]
## Heat needed for each palette step (below the first: transparent).
const STEPS: Array[float] = [0.08, 0.22, 0.38, 0.55, 0.72, 0.88]


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var sheet := Image.create(W * FRAMES, H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for f in FRAMES:
		var phase := TAU * f / FRAMES
		# The body flickers taller and shorter; a tongue breaks off its tip and rises away.
		var body := 0.62 + 0.16 * sin(phase) + 0.06 * sin(phase * 3.0)
		var rise := float(f) / FRAMES
		var tongue_up := body + rise * (1.0 - body) * 0.95
		var tongue_r := lerpf(2.4, 0.9, rise)
		for y in H:
			var up := float(H - 1 - y) / float(H - 1) # 0 at the foot of the sprite, 1 at its top
			var u := up / body # 0..1 over the flame body
			# Width shrinks toward the tip; the flame sways more the higher it goes.
			var half := 5.2 * pow(maxf(1.0 - u, 0.0), 0.8) + 0.3
			var sway := sin(up * 4.2 - phase) * 2.0 * up + sin(up * 9.0 - phase * 2.0) * 0.5 * up
			for x in W:
				var dx := absf(x + 0.5 - (W * 0.5 + sway))
				var heat := 1.0 - dx / half
				heat *= 1.0 - pow(clampf(u, 0.0, 1.0), 1.8) * 0.9 # cooler toward the tip
				if u > 1.0:
					heat = -1.0
				heat += (rng.randf() - 0.5) * 0.18 # flicker
				# A licking tongue that rises and breaks off over the loop.
				var tongue := 1.0 - Vector2(x + 0.5 - W * 0.5 - sway * 1.2, (up - tongue_up) * (H - 1)).length() / tongue_r
				heat = maxf(heat, tongue * lerpf(0.7, 0.3, rise))
				var step := -1
				for i in STEPS.size():
					if heat >= STEPS[i]:
						step = i
				if step >= 0:
					sheet.set_pixel(f * W + x, y, PALETTE[step])
	var err := sheet.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("wrote ", OUT_PATH, " (", FRAMES, " frames of ", W, "x", H, ") err=", err)
	quit()
