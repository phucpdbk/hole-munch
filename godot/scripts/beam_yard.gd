extends RefCounted

# The beam daily's world map (beam_drop.gd), built instead of a city like the
# cow hunt's farmland (countryside.gd): no buildings, traffic, army or
# landmark. The whole field is ocean, and the continents (the "world" region
# of world_map_data.gd) rise from it as low green slabs with a sandy coast,
# fitted to the saucer's reach. Every regular campaign city has its spot on
# the map at its real longitude and Mercator latitude (cities), where
# beam_drop.gd puts the pins its landmarks are dropped on. Nothing on the map
# can be eaten: the land is drawn with the ground's own material.
const Campaign = preload("res://scripts/campaign.gd")
const WorldMapData = preload("res://scripts/world_map_data.gd")
# Slab, path, verge, grass, foliage, light, roof, roof (as Campaign palettes):
# streets and blocks all take the ocean's colour.
const PALETTE := ["24577f", "3483b3", "3483b3", "3483b3", "4f9f3c", "fff4e0", "ff8fb1", "7fc8ff"]
const OCEAN := Color("3483b3")
const SHALLOW := Color("5fb3d0")
const LAND := Color("9fd27e")
const COAST := Color("eadbb2")
# The field's grid (map_layout.gd), wide like the map.
const COLS := 5
const ROWS := 3
const LAND_TOP := 0.34
const SHORE := 0.35

# Land polygons in world x/z (only those that triangulate).
var land: Array[PackedVector2Array] = []
# {id, city, at (Vector3 on the map's surface)} for each regular campaign city.
var cities: Array = []
var unit := 1.0

func colors() -> Array:
	return PALETTE

# The map fills the saucer's reach; one projected degree is `unit` metres.
func plan(layout) -> void:
	var data: Dictionary = WorldMapData.REGIONS.world
	var box: Array = data.box
	unit = minf(2.0*layout.move_x/(float(box[2]) - float(box[0])), 2.0*layout.move_z/(float(box[3]) - float(box[1])))
	land.clear()
	for ring in data.land:
		var polygon := PackedVector2Array()
		for i in range(0, ring.size(), 2): polygon.append(to_world(Vector2(ring[i], ring[i+1]), box))
		if not Geometry2D.triangulate_polygon(polygon).is_empty(): land.append(polygon)
	cities.clear()
	for region in Campaign.REGIONS:
		var stops: Array = WorldMapData.REGIONS[region.id].stops
		for slot in region.cities.size():
			var p: Array = stops[slot]
			# Oceania's stops run on 0..360 longitudes.
			var at := to_world(Vector2(wrapf(float(p[0]), -180.0, 180.0), float(p[1])), box)
			var city: Array = region.cities[slot]
			cities.append({"id":city[1], "city":Campaign.city_name(city[1], city[0]), "at":Vector3(at.x, height_at(at), at.y)})

# Projected degrees to world x/z: x = east, z = south (toward the camera).
func to_world(point: Vector2, box: Array) -> Vector2:
	var centre := Vector2((float(box[0]) + float(box[2]))/2, (float(box[1]) + float(box[3]))/2)
	return Vector2(point.x - centre.x, centre.y - point.y)*unit

func on_land(at: Vector2) -> bool:
	return land.any(func(polygon): return Geometry2D.is_point_in_polygon(at, polygon))

# The map's surface: the land's top, or sea level (the ground's top).
func height_at(at: Vector2) -> float:
	return LAND_TOP if on_land(at) else 0.16

# Open sea at least `clear` from any coast.
func at_sea(at: Vector2, clear: float) -> bool:
	if on_land(at): return false
	for step in 8:
		if on_land(at + Vector2.RIGHT.rotated(step*TAU/8)*clear): return false
	return true

func ground(_x: float, _z: float) -> Color:
	return OCEAN

# One flat sea over the blocks, so their edges leave no grid lines.
func ground_parts(layout, m) -> Array:
	return [m.piece("box", Vector3(0, 0.165, 0), Vector3(layout.half_x*2 - 2, 0.01, layout.half_z*2 - 2), OCEAN)]

# The continents: shallows round every coast, a sandy rim and a green top.
func build(g, _rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in land:
		for ring in Geometry2D.offset_polygon(polygon, SHORE, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(ring): fill(st, ring, 0.18, SHALLOW)
	for polygon in land:
		fill(st, polygon, LAND_TOP, LAND)
		for ring in Geometry2D.offset_polygon(polygon, -0.12, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(ring): fill(st, ring, LAND_TOP + 0.005, LAND.darkened(0.06))
		sides(st, polygon)
	var map := MeshInstance3D.new()
	map.mesh = st.commit()
	# The ground's shader, so the hole still opens where it crosses land.
	map.material_override = g.ground_material
	map.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.world.add_child(map)

func fill(st: SurfaceTool, polygon: PackedVector2Array, y: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i+1]]
		var c := polygon[indices[i+2]]
		tri(st, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP, color)

# The coast's sandy walls, from the sea floor up to the land's top.
func sides(st: SurfaceTool, polygon: PackedVector2Array) -> void:
	for i in polygon.size():
		var p: Vector2 = polygon[i]
		var q: Vector2 = polygon[(i+1)%polygon.size()]
		var edge := q - p
		if edge.length() < 0.001: continue
		var out := Vector2(edge.y, -edge.x).normalized()
		if Geometry2D.is_point_in_polygon((p + q)/2 + out*0.02, polygon): out = -out
		var normal := Vector3(out.x, 0, out.y)
		var a := Vector3(p.x, 0.1, p.y)
		var b := Vector3(q.x, 0.1, q.y)
		var lift := Vector3(0, LAND_TOP - 0.1, 0)
		tri(st, a, b, b + lift, normal, COAST)
		tri(st, a, b + lift, a + lift, normal, COAST)

# A triangle facing `normal` (Godot's front faces wind clockwise), its vertex
# colours linear like models.bake().
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	var linear := color.srgb_to_linear()
	for v in [a, b, c]:
		st.set_color(linear)
		st.set_normal(normal)
		st.add_vertex(v)

# What the HUD minimap draws instead of streets.
func minimap_land() -> Array:
	return land
