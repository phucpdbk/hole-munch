extends Node

# Procedural sound effects ported from the 2D game's WebAudio tones, so the app
# still ships without audio files. Each effect is synthesised once at startup.
const RATE := 22050
const VOICES := 6
const POP_SIZES := [5.0, 15.0, 30.0, 60.0]
const TO_2D_UNITS := 25.0

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var last_pop := 0

func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = -4.0
		add_child(player)
		players.append(player)
	for size in POP_SIZES: sounds["pop%d" % size] = render(pop_tones(size))
	sounds.grow = render([{"freq":400, "to":800, "dur":0.15, "type":"square", "vol":0.08}])
	var boss: Array = [{"freq":120, "to":40, "dur":0.8, "type":"saw", "vol":0.2}]
	for i in 4:
		boss.append({"freq":300+i*120, "to":600+i*150, "dur":0.18, "type":"square", "vol":0.12, "delay":i*0.12})
	sounds.boss = render(boss)
	var win: Array = []
	for i in 4: win.append({"freq":[523, 659, 784, 1046][i], "dur":0.2, "type":"triangle", "vol":0.2, "delay":i*0.1})
	sounds.win = render(win)
	var lose: Array = []
	for i in 3:
		var f: float = [400, 320, 250][i]
		lose.append({"freq":f, "to":f*0.8, "dur":0.25, "type":"saw", "vol":0.12, "delay":i*0.15})
	sounds.lose = render(lose)
	sounds.tick = render([{"freq":1000, "dur":0.05, "type":"square", "vol":0.06}])
	sounds.click = render([{"freq":600, "to":900, "dur":0.06, "type":"triangle", "vol":0.15}])

# Bigger objects make deeper pops, as in the 2D game.
func pop_tones(size: float) -> Array:
	var f := maxf(90.0, 900.0 - size * 9.0)
	var tones: Array = [{"freq":f, "to":f*0.4, "dur":0.1 + minf(size, 80.0)/400.0, "type":"triangle", "vol":0.25}]
	if size > 35: tones.append({"freq":90, "to":35, "dur":0.19, "type":"sine", "vol":0.16})
	return tones

func wave(kind: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		"square": return 1.0 if p < 0.5 else -1.0
		"triangle": return 4.0 * absf(p - 0.5) - 1.0
		"saw": return 2.0 * p - 1.0
	return sin(p * TAU)

# Exponential pitch and volume ramps, matching the WebAudio envelopes.
func render(tones: Array) -> AudioStreamWAV:
	var length := 0.0
	for tone in tones: length = maxf(length, tone.get("delay", 0.0) + tone.dur + 0.02)
	var samples := PackedFloat32Array()
	samples.resize(int(length * RATE))
	for tone in tones:
		var start := int(tone.get("delay", 0.0) * RATE)
		var count := int(tone.dur * RATE)
		var from: float = tone.freq
		var to: float = maxf(20.0, tone.get("to", from))
		var phase := 0.0
		for i in count:
			var k := float(i) / count
			phase += from * pow(to / from, k) / RATE
			var gain: float = tone.vol * pow(0.001 / tone.vol, k)
			samples[start + i] += wave(tone.type, phase) * gain
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size(): data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

func play(sound: String, pitch := 1.0) -> void:
	if not sounds.has(sound): return
	var player := players[next_player]
	next_player = (next_player + 1) % VOICES
	player.stream = sounds[sound]
	player.pitch_scale = pitch
	player.play()

func pop(object_radius: float) -> void:
	var now := Time.get_ticks_msec()
	if now - last_pop < 35: return
	last_pop = now
	var size := object_radius * TO_2D_UNITS
	var nearest: float = POP_SIZES[0]
	for candidate in POP_SIZES:
		if absf(candidate - size) < absf(nearest - size): nearest = candidate
	play("pop%d" % nearest, randf_range(0.95, 1.05))
