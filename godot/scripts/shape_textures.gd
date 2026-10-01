extends RefCounted

# Small white alpha masks for particle billboards and shop icons (hearts, stars,
# coins, flakes...). Drawn once from implicit shapes with 2×2 supersampling, so
# no image files or emoji fonts are needed (web builds have no emoji font).
const SIZE := 48
const KINDS := ["circle", "ring", "square", "heart", "star", "coin", "flake", "flame"]
static var cache := {}

static func texture(kind: String) -> ImageTexture:
	if not cache.has(kind): cache[kind] = ImageTexture.create_from_image(render(kind))
	return cache[kind]

static func render(kind: String) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var value := 0.0
			var alpha := 0.0
			for sy in 2:
				for sx in 2:
					# Shape space: -1..1 with y pointing up.
					var p := Vector2((x + 0.25 + sx*0.5)/SIZE*2.0 - 1.0, 1.0 - (y + 0.25 + sy*0.5)/SIZE*2.0)
					var shade := sample(kind, p)
					if shade > 0.0:
						alpha += 0.25
						value += shade*0.25
			var level := value/maxf(alpha, 0.001)
			image.set_pixel(x, y, Color(level, level, level, alpha))
	return image

# Brightness (0 = outside) of one sample; a few shapes shade their edge darker.
static func sample(kind: String, p: Vector2) -> float:
	var r := p.length()
	match kind:
		"circle": return 1.0 if r < 0.9 else 0.0
		"ring": return 1.0 if absf(r - 0.72) < 0.14 else 0.0
		"square": return 1.0 if maxf(absf(p.x), absf(p.y)) < 0.78 else 0.0
		"heart":
			var q := p*1.3 + Vector2(0, 0.15)
			var a := q.x*q.x + q.y*q.y - 1.0
			return 1.0 if a*a*a - q.x*q.x*q.y*q.y*q.y <= 0.0 else 0.0
		"star":
			var spoke := TAU/5.0
			var f := absf(fposmod(atan2(p.x, p.y) + spoke*0.5, spoke) - spoke*0.5)/(spoke*0.5)
			return 1.0 if r < lerpf(0.95, 0.42, f) else 0.0
		"coin":
			if r >= 0.9: return 0.0
			return 0.72 if r > 0.7 or (absf(p.x) < 0.1 and absf(p.y) < 0.45) else 1.0
		"flake":
			if r > 0.92: return 0.0
			for i in 3:
				if absf(p.cross(Vector2.from_angle(PI*i/3.0))) < 0.09: return 1.0
			return 1.0 if r < 0.2 else 0.0
		"flame":
			var drop := 0.55
			if p.distance_to(Vector2(0, -0.3)) < drop: return 1.0
			return 1.0 if p.y > -0.3 and p.y < 0.95 and absf(p.x) < drop*(0.95 - p.y)/1.25 else 0.0
	return 0.0
