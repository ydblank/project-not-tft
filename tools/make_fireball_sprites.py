#!/usr/bin/env python3
"""Draws the Staff's fireball sprite sheets (pixel art, generated, not hand drawn).

Run from the project root (needs Pillow: `pip install pillow`):

    python3 tools/make_fireball_sprites.py

Writes three sheets next to the other character art:

    Fireball_Flight.png     4 frames of 32x16, a comet that flies to the right (+X)
    Fireball_Impact.png     6 frames of 24x24, the small burst of a quick shot
    Fireball_Explosion.png  6 frames of 64x64, the area blast of a held shot

Change the palette, sizes or seeds below and run it again; Godot reimports the
PNGs on its own. The output is deterministic (seeded), so the same script gives
the same sheets. To hand-polish, open the PNGs in any pixel editor (Aseprite,
Piskel, Pixelorama): the game only cares about the frame size and count.
"""

import math
import random
from pathlib import Path

from PIL import Image

OUT_DIR = Path("assets/art/1 Characters/Other")

# Heat ramp, coolest (edge) to hottest (core).
PALETTE = [
	(122, 24, 22),   # 0 ember
	(190, 40, 24),   # 1 red
	(232, 92, 26),   # 2 orange
	(252, 158, 38),  # 3 amber
	(255, 214, 82),  # 4 yellow
	(255, 244, 178), # 5 white-hot core
]

FLIGHT_FRAMES = 4
FLIGHT_W, FLIGHT_H = 32, 16
HEAD_X, HEAD_R = 24.0, 5.0   # head centre column and radius
TAIL_LEN = 23.0

BURST_FRAMES = 6
# (frame size, start radius, radius growth, starting ring thickness, spark scale, seed)
IMPACT = (24, 3.5, 6.5, 8.0, 1.0, 2000)
EXPLOSION = (64, 8.0, 20.0, 18.0, 2.6, 3000)   # the blast reaches a radius of 28 px


def ramp(heat: float) -> tuple:
	"""Heat 0..1 to a palette colour."""
	i = int(max(0.0, min(0.999, heat)) * len(PALETTE))
	return PALETTE[i] + (255,)


def flight_frame(index: int) -> Image.Image:
	rng = random.Random(1000 + index)
	img = Image.new("RGBA", (FLIGHT_W, FLIGHT_H), (0, 0, 0, 0))
	cy = (FLIGHT_H - 1) / 2.0
	# The head wobbles a little between frames so the fireball seems to burn.
	wobble = [0.0, 0.4, 0.0, -0.4][index % 4]
	for x in range(FLIGHT_W):
		for y in range(FLIGHT_H):
			dx = x - HEAD_X
			dy = y - cy + wobble * 0.3
			d = math.hypot(dx, dy)
			noise = rng.random()
			if d <= HEAD_R + (noise - 0.5) * 1.1:
				# Round head: hot in the middle, cooler toward the rim.
				heat = 1.0 - (d / (HEAD_R + 0.6)) * 0.85 + (noise - 0.5) * 0.2
				img.putpixel((x, y), ramp(heat))
			elif dx < 0:
				# Flame tail: narrows and cools away from the head, ragged edges.
				t = -dx / TAIL_LEN
				if t > 1.0:
					continue
				half = HEAD_R * 0.95 * (1.0 - t) ** 0.85
				edge = abs(dy)
				if edge > half + (noise - 0.5) * 2.2:
					continue
				if noise < t ** 1.6 * 0.75:
					continue # thin out toward the end
				heat = 0.85 - t * 0.75 - (edge / (half + 1.0)) * 0.35 + (noise - 0.5) * 0.3
				img.putpixel((x, y), ramp(heat))
	# A few loose embers behind the tail.
	for _ in range(5):
		ex = rng.randrange(0, int(HEAD_X - HEAD_R - 6))
		ey = rng.randrange(2, FLIGHT_H - 2)
		if img.getpixel((ex, ey))[3] == 0:
			img.putpixel((ex, ey), ramp(rng.uniform(0.0, 0.4)))
	return img


def burst_frame(index: int, spec: tuple) -> Image.Image:
	size, r0, r_span, thick0, spark_scale, seed = spec
	rng = random.Random(seed + index)
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	c = (size - 1) / 2.0
	progress = index / (BURST_FRAMES - 1)
	radius = r0 + progress * r_span
	thickness = max(1.6 * spark_scale, thick0 * (1.0 - progress) ** 0.8)   # a filled ball that thins into a ring
	for x in range(size):
		for y in range(size):
			d = math.hypot(x - c, y - c)
			noise = rng.random()
			rim = radius + (noise - 0.5) * 2.4 * spark_scale ** 0.5
			if d > rim:
				continue
			inner = rim - thickness
			if d < inner:
				continue
			if noise < progress * 0.45:
				continue # breaks apart as it fades
			heat = 1.0 - progress * 0.55 - (d / (radius + 1.0)) * 0.35 + (noise - 0.5) * 0.25
			img.putpixel((x, y), ramp(heat))
	# Sparks thrown outward in the later frames.
	for _ in range(int((3 + index * 2) * spark_scale)):
		ang = rng.uniform(0.0, math.tau)
		dist = radius + rng.uniform(0.5, (2.0 + progress) * spark_scale)
		sx = int(round(c + math.cos(ang) * dist))
		sy = int(round(c + math.sin(ang) * dist))
		if 0 <= sx < size and 0 <= sy < size:
			img.putpixel((sx, sy), ramp(rng.uniform(0.35, 0.9) - progress * 0.3))
	return img


def sheet(frames: list) -> Image.Image:
	w, h = frames[0].size
	out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
	for i, frame in enumerate(frames):
		out.paste(frame, (i * w, 0))
	return out


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	sheet([flight_frame(i) for i in range(FLIGHT_FRAMES)]).save(OUT_DIR / "Fireball_Flight.png")
	sheet([burst_frame(i, IMPACT) for i in range(BURST_FRAMES)]).save(OUT_DIR / "Fireball_Impact.png")
	sheet([burst_frame(i, EXPLOSION) for i in range(BURST_FRAMES)]).save(OUT_DIR / "Fireball_Explosion.png")
	print("wrote Fireball_Flight.png, Fireball_Impact.png and Fireball_Explosion.png in", OUT_DIR)


if __name__ == "__main__":
	main()
