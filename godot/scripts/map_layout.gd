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
	return absf(x) == blocks_x.back() or absf(z) == blocks_z.back()
