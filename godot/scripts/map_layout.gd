extends RefCounted

# Per-level city grid. Blocks are 18 units apart with roads between them; the
# boss plaza is always the centre block, so both counts must be odd.
const BLOCK_STEP := 18.0
const BLOCK_SIZE := 14.8

var cols := 3
var rows := 3
var blocks_x: Array[float] = []
var blocks_z: Array[float] = []
var streets_x: Array[float] = []
var streets_z: Array[float] = []
# Inner streets carry traffic and meet at signalled crossings.
var crossings_x: Array[float] = []
var crossings_z: Array[float] = []
var half_x := 28.0
var half_z := 28.0
var move_x := 26.0
var move_z := 26.0

static func make(cols_value: int, rows_value: int) -> RefCounted:
	var layout = load("res://scripts/map_layout.gd").new()
	layout.cols = cols_value
	layout.rows = rows_value
	layout.blocks_x = axis_blocks(cols_value)
	layout.blocks_z = axis_blocks(rows_value)
	layout.streets_x = axis_streets(cols_value)
	layout.streets_z = axis_streets(rows_value)
	layout.crossings_x.assign(layout.streets_x.slice(1, layout.streets_x.size()-1))
	layout.crossings_z.assign(layout.streets_z.slice(1, layout.streets_z.size()-1))
	layout.half_x = cols_value*BLOCK_STEP/2.0 + 1.0
	layout.half_z = rows_value*BLOCK_STEP/2.0 + 1.0
	layout.move_x = layout.half_x - 2.0
	layout.move_z = layout.half_z - 2.0
	return layout

# Unequal city blocks, with the central plaza/spawn streets kept at ±9.
# Traffic and defence share these exact road coordinates.
func vary_districts(seed_value: int) -> void:
	streets_x = district_streets(cols,seed_value)
	streets_z = district_streets(rows,seed_value+3)
	blocks_x.clear()
	blocks_z.clear()
	for i in cols: blocks_x.append((streets_x[i]+streets_x[i+1])*0.5)
	for i in rows: blocks_z.append((streets_z[i]+streets_z[i+1])*0.5)
	crossings_x.assign(streets_x.slice(1,streets_x.size()-1))
	crossings_z.assign(streets_z.slice(1,streets_z.size()-1))
	half_x = maxf(absf(streets_x[0]),streets_x[-1])+1.0
	half_z = maxf(absf(streets_z[0]),streets_z[-1])+1.0
	move_x = half_x-2
	move_z = half_z-2

static func district_streets(count: int, seed_value: int) -> Array[float]:
	var result: Array[float] = [-9.0,9.0]
	for i in count/2:
		result.push_front(result[0]-[20.0,26.0,32.0][(seed_value+i)%3])
		result.append(result[-1]+[20.0,26.0,32.0][(seed_value+i+1)%3])
	return result

func block_size(x: float, z: float) -> Vector2:
	var ix := blocks_x.find(x)
	var iz := blocks_z.find(z)
	return Vector2(streets_x[ix+1]-streets_x[ix]-3.2,streets_z[iz+1]-streets_z[iz]-3.2)

static func axis_blocks(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in count: result.append((i - (count-1)/2.0) * BLOCK_STEP)
	return result

static func axis_streets(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in count+1: result.append((i - count/2.0) * BLOCK_STEP)
	return result

func block_count() -> int:
	return cols*rows

func is_edge_block(x: float, z: float) -> bool:
	return x == blocks_x[0] or x == blocks_x[-1] or z == blocks_z[0] or z == blocks_z[-1]
