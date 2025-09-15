extends Control
class_name StaticBackgroundDrawer

var areas: Array[Area] = []
var map_generator: MapGenerator = null
var map: Global.Map = null
var simple_mode: bool = false

const TREE_MIN_RADIUS: float					= 1.5
const TREE_MAX_RADIUS: float					= 2.0
const TREE_MIN_SIDES: int						= 6		# Reduced for performance
const TREE_MAX_SIDES: int						= 8		# Reduced for performance
const TREE_CANOPY_BASE: Color					= Color(0.13, 0.32, 0.13, 1.0)  # will vary a bit
const TREE_SHADOW_DARKEN: float					= 0.125
const TREE_DENSITY: float						= 0.1	# ↑ denser
const MAX_TREES_PER_AREA: int = 10000					# Prevent excessive trees
const MAX_TREE_ATTEMPTS: int = 10000					# Limit total attempts per area
const TREE_SHADOW_OFFSET: Vector2				= Vector2(6, 6)
const TREE_TRUNK_OFFSET: Vector2					= Vector2(0, TREE_MIN_RADIUS)
const TREE_TRUNK_FRAC: float					= 0.2		# trunk size = frac · TREE_MIN_RADIUS
const TREE_TRUNK_COLOR: Color					= Color(0.29, 0.17, 0.09, 1.0)
const LIGHT_DARK: float				= 0.5	# darkest a facet may get (× base colour)
const LIGHT_BRIGHT: float			= 1.00	# brightest (× base colour)
const FACET_JITTER_DEG: float			= 12.0	# ± rotation for the “normal”

# Mountains
const MTN_BRIGHT_MIN: float			= 0.0		# brightest
const MTN_BRIGHT_MAX: float			= 1.0		# darkest
const MTN_JITTER_DEG: float			= 48.0		# ± random yaw on the fake normal
const MTN_SHADOW_OFFSET: Vector2	= Vector2(24, 24)	# tweak to taste
const MTN_SHADOW_DARKEN: float		= 0.325				# 0 = black, 1 = no darken
const PROFILE_MTN: bool				= true

const MTN_TEX_PADDING_PX: int = 0
const MTN_TEX_SUBPIXEL_OFFSET: float = 0.5

# Mountain ridges configuration
const RIDGE_LEVELS: int = 2
const RIDGE_LEVEL_WIDTH_FACTOR: float = 2.0
const RIDGE_NORMAL_STRENGTH: float = 0.5
const RIDGE_DISTANCE_STRENGTH: float = 0.05
const RIDGE_EPS: float = 0.0001
const RIDGE_TRACE_STEP_PX: float = 16.0
const RIDGE_CURVE_MAX_DEG: float = 48.0
const RIDGE_MAIN_NOISE_DEG: float = 32.0
const RIDGE_MAIN_NOISE_FREQ: float = 1.0 / 180.0
const RIDGE_MAIN_MAX_STEPS: int = 16
const RIDGE_SECOND_NOISE_DEG: float = 16.0
const RIDGE_SECOND_NOISE_FREQ: float = 1.0 / 140.0
const RIDGE_SECOND_MAX_STEPS: int = 16
const RIDGE_SECOND_BIAS: float = 0.35
const RIDGE_MAIN_DISTANCE_BIAS: float = 2.0
const RIDGE_MAIN_NORMAL_DOMINANCE: float = 0.5


# ─── River-bed rocks ───────────────────────────────────────────────
#const WATER_BASE: Color = Color(0.18, 0.24, 0.27, 1.0) # muted blue-grey
#const WATER_BASE: Color = Color(0.1688, 0.225, 0.2531, 1.0) # muted blue-grey
const WATER_BASE: Color = Color(0.1575, 0.21, 0.2363, 1.0)

const ROCK_MIN_RADIUS: float				= 2.0	# pixels
const ROCK_MAX_RADIUS: float				= 2.0
const ROCK_MIN_SIDES: int					= 5
const ROCK_MAX_SIDES: int					= 7
const ROCK_BASE_COLOR: Color				= Color(0.21, 0.19, 0.17, 1.0)
const ROCK_SHADOW_DARKEN: float				= 0.5
const ROCK_SHADOW_OFFSET: Vector2			= Vector2(2.0, 2.0)	# much smaller than trees
# ─── Rock band look ────────────────────────────────────────────────────────────
const ROCK_ELONG_SCALE: float			= 1.75	# stretch along river tangent
const ROCK_SPACING: float				= ROCK_MAX_RADIUS * 1.1	# centre-to-centre
# ─── Rock shading ─────────────────────────────────────────────────────────
const ROCK_LIGHT_DARK: float			= 0.25	# darkest a facet may get (× base)
const ROCK_LIGHT_BRIGHT: float			= 0.875	# brightest
const ROCK_FACET_JITTER_DEG: float		= 18.0	# ± random yaw on the fake normal

const ROAD_W: float				= 5.0
const ROAD_BASE: Color			= Color(60.0/255.0, 55.0/255.0, 45.0/255.0, 0.75)
const ROAD_EDGE: Color			= Color(95.0/255.0, 90.0/255.0, 75.0/255.0, 0.75)
const BRIDGE_W: float			= ROAD_W * 1.1
const BRIDGE_COL: Color			= Color(0.55, 0.42, 0.28, 1.0)
var ROAD_LIT = ROAD_BASE.lightened(0.15)
var ROAD_SHADE = ROAD_BASE.darkened(0.15)
var ROAD_BACKGROUND = ROAD_BASE.darkened(0.75)
const ROAD_STRIPE_LEN: float = ROAD_W*2.25		# equal-length shade/lit stripes


var _river_rocks: Array[Dictionary] = []	# each = { "poly": PackedVector2Array, "shadow": PackedVector2Array }

var _rng: RandomNumberGenerator               = RandomNumberGenerator.new()

var _area_trees: Dictionary						= {}	# area_id → Array[Dictionary]

# MultiMesh for trees - trunks, shadows, canopies (separate passes)
var _tree_trunk_multimesh: MultiMesh
var _tree_shadow_multimesh: MultiMesh
var _tree_canopy_multimesh: MultiMesh
var _tree_trunk_instances: Array[Dictionary] = []  # {transform, color} for trunks
var _tree_shadow_instances: Array[Dictionary] = []  # {vertices, color}
var _tree_canopy_instances: Array[Dictionary] = []  # {vertices, color}

# MultiMesh for mountains
var _mountain_textures: Dictionary = {}  # poly_id -> {"texture": ImageTexture, "aabb": Rect2}

# ─── Plains texture (procedural mottled parchment) ─────────────────────────────
const PLAINS_TEX_SIZE: int = 2048
const PLAINS_TEX_INTENSITY: float = 0.2		# 0=noise off, 1=full
const PLAINS_TEX_CONTRAST: float = 0.0
const PLAINS_NOISE_FREQ_1: float = 1.0 / 320.0	# large blotches
const PLAINS_NOISE_FREQ_2: float = 1.0 / 160.0	# mid tones
const PLAINS_NOISE_FREQ_3: float = 1.0 / 6.0	# detail

var _plains_texture: ImageTexture = null
var _forest_texture: ImageTexture = null
var _world_aabb: Rect2 = Rect2()

var before_rivers: bool = false

func setup(p_areas: Array[Area], p_map_generator: MapGenerator, p_map: Global.Map) -> void:
	areas = p_areas
	map_generator = p_map_generator
	map = p_map
	
	if before_rivers:
		if not simple_mode:
			_prepare_plains_texture()
			_prepare_forest_texture()
	else:
		if not simple_mode:
			_setup_multimeshes()
			_prepare_trees()
			_prepare_mountains()
			texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_prepare_rocks()
	queue_redraw()

func set_simple(p_simple: bool) -> void:
	simple_mode = p_simple
	queue_redraw()

func _setup_multimeshes() -> void:
	# Tree trunk MultiMesh (separate instances)
	_tree_trunk_multimesh = MultiMesh.new()
	_tree_trunk_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_tree_trunk_multimesh.use_colors = true
	_tree_trunk_multimesh.mesh = _create_quad_mesh()
	_tree_trunk_multimesh.instance_count = 0
	
	# (removed) old combined multimesh is no longer used

	# Tree shadow MultiMesh (global shadows first)
	_tree_shadow_multimesh = MultiMesh.new()
	_tree_shadow_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_tree_shadow_multimesh.use_colors = true
	_tree_shadow_multimesh.instance_count = 1

	# Tree canopy MultiMesh (global canopies after shadows)
	_tree_canopy_multimesh = MultiMesh.new()
	_tree_canopy_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_tree_canopy_multimesh.use_colors = true
	_tree_canopy_multimesh.instance_count = 1
	

func _create_quad_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Unit quad centered at origin
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0),  # Triangle 1
		Vector3(-0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)   # Triangle 2
	])
	
	var colors: PackedColorArray = PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE,
		Color.WHITE, Color.WHITE, Color.WHITE
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh
func _draw_textured_area(
	polygon: PackedVector2Array,
	texture: Texture2D,
	base_color: Color,
	edge_color: Color
) -> void:
	if texture == null:
		return
	var centroid: Vector2 = GeometryUtils.calculate_centroid(polygon)
	var tri_pts: PackedVector2Array = PackedVector2Array()
	var tri_uvs: PackedVector2Array = PackedVector2Array()
	for i: int in range(polygon.size()):
		var cur: Vector2 = polygon[i]
		var next: Vector2 = polygon[(i + 1) % polygon.size()]
		tri_pts.append(centroid)
		tri_pts.append(cur)
		tri_pts.append(next)
		var uv_c: Vector2 = Vector2(
			(centroid.x - _world_aabb.position.x) / max(_world_aabb.size.x, 1.0),
			(centroid.y - _world_aabb.position.y) / max(_world_aabb.size.y, 1.0)
		)
		var uv_1: Vector2 = Vector2(
			(cur.x - _world_aabb.position.x) / max(_world_aabb.size.x, 1.0),
			(cur.y - _world_aabb.position.y) / max(_world_aabb.size.y, 1.0)
		)
		var uv_2: Vector2 = Vector2(
			(next.x - _world_aabb.position.x) / max(_world_aabb.size.x, 1.0),
			(next.y - _world_aabb.position.y) / max(_world_aabb.size.y, 1.0)
		)
		tri_uvs.append(uv_c)
		tri_uvs.append(uv_1)
		tri_uvs.append(uv_2)
	for j: int in range(0, tri_pts.size(), 3):
		if j + 2 >= tri_pts.size():
			break
		var tri: PackedVector2Array = PackedVector2Array([
			tri_pts[j], tri_pts[j + 1], tri_pts[j + 2]
		])
		var cols: PackedColorArray = PackedColorArray([
			base_color, edge_color, edge_color
		])
		var uvs: PackedVector2Array = PackedVector2Array([
			tri_uvs[j], tri_uvs[j + 1], tri_uvs[j + 2]
		])
		draw_polygon(tri, cols, uvs, texture)
	if tri_pts.size() < 3:
		draw_colored_polygon(polygon, base_color.lerp(edge_color, 0.5))


func _create_tree_combined_mesh() -> ArrayMesh:
	# Legacy function kept for compatibility; now returns an empty mesh
	return ArrayMesh.new()

func _create_mesh_from_instances(instances: Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()

	for instance: Dictionary in instances:
		var poly: PackedVector2Array = instance["vertices"]
		var col: Color = instance["color"]
		if poly.size() == 3:
			vertices.append(Vector3(poly[0].x, poly[0].y, 0))
			vertices.append(Vector3(poly[1].x, poly[1].y, 0))
			vertices.append(Vector3(poly[2].x, poly[2].y, 0))
			colors.append(col)
			colors.append(col)
			colors.append(col)
		else:
			if poly.size() > 3:
				var idxs: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
				for i_t: int in range(0, idxs.size(), 3):
					var a: Vector2 = poly[idxs[i_t]]
					var b: Vector2 = poly[idxs[i_t + 1]]
					var c: Vector2 = poly[idxs[i_t + 2]]
					vertices.append(Vector3(a.x, a.y, 0))
					vertices.append(Vector3(b.x, b.y, 0))
					vertices.append(Vector3(c.x, c.y, 0))
					colors.append(col)
					colors.append(col)
					colors.append(col)

	if vertices.size() > 0:
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh

# Expose generated tree shadow polygons (body + bands) for other drawers
func get_tree_shadow_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for inst: Dictionary in _tree_shadow_instances:
		if inst.has("vertices"):
			out.append(inst["vertices"] as PackedVector2Array)
	return out

# ─────────────────────────── Plains texture preparation ─────────────────────────
func _compute_world_aabb() -> void:
	var has_any: bool = false
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for original_area: Area in map.original_walkable_areas:
		for v: Vector2 in original_area.polygon:
			if has_any == false:
				has_any = true
			min_x = min(min_x, v.x)
			min_y = min(min_y, v.y)
			max_x = max(max_x, v.x)
			max_y = max(max_y, v.y)
	for obstacle in areas:
		if obstacle.owner_id == -3:
			for v2: Vector2 in obstacle.polygon:
				if has_any == false:
					has_any = true
				min_x = min(min_x, v2.x)
				min_y = min(min_y, v2.y)
				max_x = max(max_x, v2.x)
				max_y = max(max_y, v2.y)
	if has_any == true:
		_world_aabb = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	else:
		_world_aabb = Rect2(Vector2.ZERO, Vector2(1.0, 1.0))

# Shared noise image generator for textured areas (plains/forest)
func _generate_noise_image(seed1: int, seed2: int, seed3: int) -> Image:
	var img: Image = Image.create(PLAINS_TEX_SIZE, PLAINS_TEX_SIZE, false, Image.FORMAT_RGBA8)
	var noise1: FastNoiseLite = FastNoiseLite.new()
	noise1.seed = seed1
	noise1.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise1.frequency = PLAINS_NOISE_FREQ_1
	noise1.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise1.fractal_octaves = 4
	var noise2: FastNoiseLite = FastNoiseLite.new()
	noise2.seed = seed2
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise2.frequency = PLAINS_NOISE_FREQ_2
	noise2.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise2.fractal_octaves = 3
	var noise3: FastNoiseLite = FastNoiseLite.new()
	noise3.seed = seed3
	noise3.noise_type = FastNoiseLite.TYPE_VALUE
	noise3.frequency = PLAINS_NOISE_FREQ_3
	var warp_freq: float = 1.0 / 1600.0
	var warp_amp: float = 0.0
	for y: int in range(PLAINS_TEX_SIZE):
		for x: int in range(PLAINS_TEX_SIZE):
			var fx: float = float(x)
			var fy: float = float(y)
			var wx: float = fx + noise3.get_noise_2d(fx * warp_freq, fy * warp_freq) * warp_amp
			var wy: float = fy + noise2.get_noise_2d(fx * warp_freq * 1.13, fy * warp_freq * 0.91) * warp_amp
			var n1: float = noise1.get_noise_2d(wx, wy)
			var n2: float = noise2.get_noise_2d(wx * 1.87, wy * 1.63)
			var n3: float = noise3.get_noise_2d(wx * 2.11, wy * 2.39)
			var v: float = 0.5 + 0.5 * n1 + 0.45 * n2 + 0.3 * n3
			if v < 0.0:
				v = 0.0
			else:
				v = v
			var centered: float = v - 0.5
			v = 0.5 + centered * (1.0 + PLAINS_TEX_CONTRAST)
			var mul: float = 1.0 + (v - 0.5) * 2.0 * PLAINS_TEX_INTENSITY
			if mul < 0.0:
				mul = 0.0
			else:
				mul = mul
			if mul > 1.5:
				mul = 1.5
			else:
				mul = mul
			img.set_pixel(x, y, Color(mul, mul, mul, 1.0))
	return img

func _generate_plains_image() -> Image:
	var img: Image = _generate_noise_image(1337, 7331, 9119)
	return img

func _generate_forest_image() -> Image:
	var img: Image = _generate_noise_image(2468, 8642, 7777)
	return img

 

func _prepare_plains_texture() -> void:
	_compute_world_aabb()
	var image: Image = _generate_plains_image()
	image.generate_mipmaps()
	_plains_texture = ImageTexture.create_from_image(image)

func _prepare_forest_texture() -> void:
	_compute_world_aabb()
	var image: Image = _generate_forest_image()
	image.generate_mipmaps()
	_forest_texture = ImageTexture.create_from_image(image)

 
	
func _draw_mountain_shadows() -> void:
	var col: Color = Global.get_color_for_terrain("mountains") * MTN_SHADOW_DARKEN
	col.a = MTN_SHADOW_DARKEN					# tweak opacity as you like
	
	for original_area: Area in map.original_walkable_areas:
		if map.terrain_map[original_area.polygon_id] != "mountains":
			continue
		
		var mountain_polygon: PackedVector2Array = original_area.polygon
		mountain_polygon = _clip_river_polygons(mountain_polygon, original_area)
		
		var shadow_poly: PackedVector2Array = GeometryUtils.translate_polygon(
			mountain_polygon,
			MTN_SHADOW_OFFSET
		)
		# 1) ground shadow (clip out the mountain polygon so rivers and plains outside get shadow only)
		var ground_poly: PackedVector2Array = GeometryUtils.find_largest_polygon(
			Geometry2D.clip_polygons(
				shadow_poly,
				mountain_polygon
			)
		)
		# 1b) fill the swept band between original and translated polygons
		var band_quads: Array[PackedVector2Array] = StaticBackgroundDrawer.build_between_band_quads(
			mountain_polygon,
			shadow_poly
		)
		for q: PackedVector2Array in band_quads:
			if not Geometry2D.is_polygon_clockwise(q): continue
			for clipped_q: PackedVector2Array in Geometry2D.clip_polygons(
				q,
				mountain_polygon
			):
				if Geometry2D.is_polygon_clockwise(clipped_q): continue
				draw_colored_polygon(clipped_q, col)
		

# Draw the portion of each mountain's shadow that lies ON the mountain itself
func _draw_mountain_self_shadows() -> void:
	var col: Color = Global.get_color_for_terrain("mountains") * MTN_SHADOW_DARKEN
	col.a = MTN_SHADOW_DARKEN
	for original_area: Area in map.original_walkable_areas:
		if map.terrain_map[original_area.polygon_id] == "mountains":
			var mountain_polygon: PackedVector2Array = original_area.polygon
			mountain_polygon = _clip_river_polygons(mountain_polygon, original_area)
			draw_colored_polygon(mountain_polygon, col)

func _draw_mountain_black_bases() -> void:
	var black: Color = Color.BLACK
	for original_area: Area in map.original_walkable_areas:
		if map.terrain_map[original_area.polygon_id] == "mountains":
			draw_colored_polygon(original_area.polygon, black)

# ──────────────────────────── Helpers ─────────────────────────────────────
func _composite_over_color(src: Color, dst: Color) -> Color:
	var a: float = src.a
	if a < 0.0:
		a = 0.0
	else:
		if a > 1.0:
			a = 1.0
	var out_r: float = src.r * a + dst.r * (1.0 - a)
	var out_g: float = src.g * a + dst.g * (1.0 - a)
	var out_b: float = src.b * a + dst.b * (1.0 - a)
	return Color(out_r, out_g, out_b, 1.0)

static func build_between_band_quads(poly_a: PackedVector2Array, poly_b: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if poly_a.size() < 2:
		return out
	# Connect corresponding edges with quads; handle size mismatch by wrapping
	for i: int in range(poly_a.size()):
		var a0: Vector2 = poly_a[i]
		var a1: Vector2 = poly_a[(i + 1) % poly_a.size()]
		var b0: Vector2 = poly_b[i % poly_b.size()]
		var b1: Vector2 = poly_b[(i + 1) % poly_b.size()]
		# Split quad into two triangles; we can return as a quad polygon and rely on triangulation by draw
		out.append(PackedVector2Array([a0, a1, b1, b0]))
	return out
func _generate_canopy_polygon(centre: Vector2) -> PackedVector2Array:
	var sides: int = _rng.randi_range(TREE_MIN_SIDES, TREE_MAX_SIDES)
	var radius_min: float = TREE_MIN_RADIUS
	var radius_max: float = TREE_MAX_RADIUS
	
	var verts: PackedVector2Array = PackedVector2Array()
	for i: int in range(sides):
		var base_angle: float = 2.0 * PI * float(i) / float(sides)
		var jitter: float = _rng.randf_range(-PI / float(sides), PI / float(sides))
		var angle: float = base_angle + jitter
		var r: float = _rng.randf_range(radius_min, radius_max)
		var v: Vector2 = centre + Vector2(cos(angle), sin(angle)) * r
		verts.append(v)
	return verts

func _get_river_polygons(original_area: Area, extra_offset: float = 0.0) -> Array[PackedVector2Array]:
	var river_polygons: Array[PackedVector2Array]
	for adjacent_original_area: Area in map.adjacent_original_walkable_area[original_area]:
		if not map.original_walkable_area_river_neighbors.has(adjacent_original_area):
			continue
		if original_area in map.original_walkable_area_river_neighbors[adjacent_original_area]:
			var shared_border: PackedVector2Array = map.original_walkable_area_shared_borders[original_area][adjacent_original_area][0]
			var river_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
				Geometry2D.offset_polyline(
					shared_border,
					MapGenerator.BANK_OFFSET+extra_offset,
					Geometry2D.JOIN_ROUND,
					Geometry2D.END_ROUND,
				)
			)
			river_polygons.append(river_polygon)
	return river_polygons

func _clip_river_polygons(
	polygon: PackedVector2Array,
	original_area: Area,
	extra_offset: float = 0.0,
) -> PackedVector2Array:
	for river_polygon: PackedVector2Array in _get_river_polygons(original_area,extra_offset):
		polygon = GeometryUtils.find_largest_polygon(
			Geometry2D.clip_polygons(
				polygon, river_polygon
			)
		)
	return polygon
		
func _prepare_trees() -> void:
	_area_trees.clear()
	_tree_trunk_instances.clear()
	_tree_canopy_instances.clear()
	_tree_shadow_instances.clear()
	_rng.randomize()
	
	var start_time = Time.get_unix_time_from_system()
	print("Starting tree generation...")

	for original_area: Area in map.original_walkable_areas:

		var tree_canopy_base: Color = TREE_CANOPY_BASE
		tree_canopy_base.s *= 0.55
		tree_canopy_base.v *= 1.0
		var base_hsv: Vector3 = Vector3(tree_canopy_base.h, tree_canopy_base.s, tree_canopy_base.v)
		var base_hue: float = clamp(base_hsv.x + _rng.randf_range(-0.04, 0.04), 0.0, 1.0)
		var base_val: float = base_hsv.z#clamp(base_hsv.z + _rng.randf_range(-0.07, 0.07), 0.0, 1.0)
		tree_canopy_base = Color.from_hsv(base_hue, base_hsv.y, base_val, TREE_CANOPY_BASE.a)
		
		var pid: int = original_area.polygon_id
		if map.terrain_map[pid] != "forest":
			continue
		
		var polygon: PackedVector2Array = original_area.polygon
		polygon = GeometryUtils.find_largest_polygon(
			Geometry2D.offset_polygon(
				polygon, -max(TREE_MAX_RADIUS, DrawComponent.AREA_OUTLINE_THICKNESS/2.0), Geometry2D.JOIN_ROUND
			)
		)
		polygon = _clip_river_polygons(polygon, original_area, TREE_MAX_RADIUS)
			
		if polygon.size() < 3:
			continue
		
		var poly_area: float = GeometryUtils.calculate_polygon_area(polygon)
		var tree_count: int = min(int(ceil(poly_area * TREE_DENSITY)), MAX_TREES_PER_AREA)
		
		# Debug info to track performance
		if tree_count > 100:
			print("Forest area ", pid, ": ", int(poly_area), " px² → ", tree_count, " trees")
		
		var trees: Array = []
		var area_canopy_facets: Array[Dictionary] = []
		var aabb: Rect2 = GeometryUtils.calculate_bounding_box(polygon)
		
		var tries: int = 0
		var tries_limit: int = min(tree_count * 40, MAX_TREE_ATTEMPTS)
		
		# Pre-calculate polygon bounds for efficiency
		var poly_min_x: float = INF
		var poly_max_x: float = -INF
		var poly_min_y: float = INF
		var poly_max_y: float = -INF
		for pt in polygon:
			poly_min_x = min(poly_min_x, pt.x)
			poly_max_x = max(poly_max_x, pt.x)
			poly_min_y = min(poly_min_y, pt.y)
			poly_max_y = max(poly_max_y, pt.y)
		
		while trees.size() < tree_count and tries < tries_limit:
			tries += 1
			
			var centre: Vector2 = Vector2(
				_rng.randf_range(poly_min_x, poly_max_x),
				_rng.randf_range(poly_min_y, poly_max_y)
			)

			# Fast polygon check (this is the expensive operation)
			if not Geometry2D.is_point_in_polygon(centre, polygon):
				continue
				
				
			# ─ canopy polygon ─────────────────────────────────────────────
			var canopy: PackedVector2Array = _generate_canopy_polygon(centre)

			#var intersect: Array[PackedVector2Array] =  Geometry2D.intersect_polygons(
				#canopy,
				#polygon,
			#)
			#if not intersect.size()==1 or intersect[0] != canopy:
				#continue
			
			# shadow is just translated
			var shadow: PackedVector2Array = GeometryUtils.translate_polygon(canopy, TREE_SHADOW_OFFSET)
			# tiny trunk
			var trunk_r: float = TREE_MIN_RADIUS * TREE_TRUNK_FRAC
			var trunk: PackedVector2Array = PackedVector2Array([
				centre + Vector2(0, -trunk_r) + TREE_TRUNK_OFFSET,
				centre + Vector2(trunk_r/2.0, 0) + TREE_TRUNK_OFFSET,
				centre + Vector2(0, trunk_r) + TREE_TRUNK_OFFSET,
				centre + Vector2(-trunk_r/2.0, 0) + TREE_TRUNK_OFFSET,
			])
			
			# base colour harmonised
			var hsv: Vector3 = Vector3(tree_canopy_base.h, tree_canopy_base.s, tree_canopy_base.v)
			var hue: float = clamp(hsv.x + _rng.randf_range(-0.01, 0.01), 0.0, 1.0)
			#var val: float = hsv.z
			var val: float = clamp(hsv.z + _rng.randf_range(-0.1, 0.0), 0.0, 1.0)
			var base_col: Color = Color.from_hsv(hue, hsv.y, val, tree_canopy_base.a)
			
			# ─ compute low-poly facets with base-proximity darken ─────────────
			var facets: Array = []			# Array[Dictionary]
			var max_edge_dist: float = 0.0
			for i: int in range(canopy.size()):
				var v1: Vector2 = canopy[i]
				var v2: Vector2 = canopy[(i + 1) % canopy.size()]
				var tri: PackedVector2Array = PackedVector2Array([centre, v1, v2])
				
				# fake normal = bisector + jitter
				var mid: Vector2 = (v1 + v2) * 0.5
				var n: Vector2 = (mid - centre).normalized()
				var yaw: float = deg_to_rad(_rng.randf_range(-FACET_JITTER_DEG, FACET_JITTER_DEG))
				var n_rot: Vector2 = Vector2(
					n.x * cos(yaw) - n.y * sin(yaw),
					n.x * sin(yaw) + n.y * cos(yaw)
				)
				
				var dot: float = clamp(n_rot.dot(Global.LIGHT_DIR), -1.0, 1.0)
				var f: float = LIGHT_DARK + (LIGHT_BRIGHT - LIGHT_DARK) * (dot + 1.0) * 0.5
				# distance to nearest canopy edge for base proximity
				var min_d: float = INF
				var e_i: int = 0
				while e_i < canopy.size():
					var ea: Vector2 = canopy[e_i]
					var eb: Vector2 = canopy[(e_i + 1) % canopy.size()]
					var cp: Vector2 = Geometry2D.get_closest_point_to_segment(mid, ea, eb)
					var ed: float = mid.distance_to(cp)
					if ed < min_d:
						min_d = ed
					e_i += 1
				if min_d > max_edge_dist:
					max_edge_dist = min_d
				facets.append({ "poly": tri, "mid": mid, "light_f": f, "edge_dist": min_d })
			
			trees.append({
				"centre": centre,
				"canopy": canopy,
				"shadow": shadow,
				"trunk": trunk,
				"facets": facets
			})
			
			# Collect trunk instance (separate MultiMesh)
			var trunk_size: Vector2 = Vector2(trunk_r * 2.0, trunk_r * 2.0)
			var trunk_transform: Transform2D = Transform2D()
			trunk_transform = trunk_transform.scaled(trunk_size)
			trunk_transform.origin = centre + TREE_TRUNK_OFFSET
			_tree_trunk_instances.append({
				"transform": trunk_transform,
				"color": TREE_TRUNK_COLOR
			})
			
			# Collect combined shadow+canopy (in correct order: shadows first, then canopy)
			
			# 1. Shadow body (translated canopy) + swept band quads (no clipping), triangulated later in mesh builder
			var shadow_color: Color = Color.BLACK
			shadow_color.a = TREE_SHADOW_DARKEN
			#shadow_color.a = 1.0
			_tree_shadow_instances.append({
				"vertices": shadow,
				"color": shadow_color
			})
			var band_quads: Array[PackedVector2Array] = StaticBackgroundDrawer.build_between_band_quads(
				canopy,
				shadow
			)
			for q: PackedVector2Array in band_quads:
				_tree_shadow_instances.append({
					"vertices": q,
					"color": shadow_color
				})
			
			# 2. Canopy facets (collect now; area-edge darkening applied after all trees in area)
			for facet: Dictionary in facets:
				var facet_poly: PackedVector2Array = facet["poly"]
				if facet_poly.size() >= 3:
					area_canopy_facets.append({
						"poly": facet_poly,
						"mid": facet["mid"],
						"light_f": facet["light_f"],
						"base_col": base_col
					})
		
		_area_trees[pid] = trees

		# After collecting all canopies for this area, compute area-edge proximity
		var area_max_edge_dist: float = 0.0
		for facet_rec in area_canopy_facets:
			var mid: Vector2 = facet_rec["mid"]
			var min_d: float = INF
			var e_k: int = 0
			while e_k < polygon.size():
				var pa: Vector2 = polygon[e_k]
				var pb: Vector2 = polygon[(e_k + 1) % polygon.size()]
				var cp2: Vector2 = Geometry2D.get_closest_point_to_segment(mid, pa, pb)
				var ed: float = mid.distance_to(cp2)
				if ed < min_d:
					min_d = ed
				e_k += 1
			facet_rec["edge_dist"] = min_d
			if min_d > area_max_edge_dist:
				area_max_edge_dist = min_d
		
		# Append canopy facets with area-edge darken applied
		for facet_rec2 in area_canopy_facets:
			var facet_poly2: PackedVector2Array = facet_rec2["poly"]
			var light_f2: float = facet_rec2["light_f"]
			var base_col2: Color = facet_rec2["base_col"]
			var edge_dist2: float = facet_rec2["edge_dist"]
			var t_norm2: float = 0.0
			if area_max_edge_dist > 0.0:
				t_norm2 = edge_dist2 / area_max_edge_dist
			else:
				t_norm2 = 0.0
			var eased2: float = pow(t_norm2, 1/2.0)
			var base_factor2: float = 0.75 + 0.25 * eased2
			var col2: Color = base_col2 * light_f2
			col2 = col2 * base_factor2
			col2.a = 1.0
			_tree_canopy_instances.append({
				"vertices": facet_poly2,
				"color": col2
			})
		
		# Debug: Report generation stats
		if tree_count > 100:
			print("  → Generated ", trees.size(), "/", tree_count, " trees in ", tries, " attempts")
	
	# Set up trunk MultiMesh instances
	_tree_trunk_multimesh.instance_count = _tree_trunk_instances.size()
	for i: int in range(_tree_trunk_instances.size()):
		var instance: Dictionary = _tree_trunk_instances[i]
		_tree_trunk_multimesh.set_instance_transform_2d(i, instance["transform"])
		_tree_trunk_multimesh.set_instance_color(i, instance["color"])
	
	# Create separate shadow and canopy meshes
	_tree_shadow_multimesh.mesh = _create_mesh_from_instances(_tree_shadow_instances)
	_tree_shadow_multimesh.set_instance_transform_2d(0, Transform2D.IDENTITY)
	_tree_shadow_multimesh.set_instance_color(0, Color.WHITE)
	_tree_canopy_multimesh.mesh = _create_mesh_from_instances(_tree_canopy_instances)
	_tree_canopy_multimesh.set_instance_transform_2d(0, Transform2D.IDENTITY)
	_tree_canopy_multimesh.set_instance_color(0, Color.WHITE)


func _prepare_mountains() -> void:
	_mountain_textures.clear()
	
	# Deterministic seed per run not required for textures; avoid randomize here
	
	for original_area: Area in map.original_walkable_areas:
		var poly_id: int = original_area.polygon_id
		if map.terrain_map[poly_id] != "mountains":
			continue
		var mountain_polygon: PackedVector2Array = original_area.polygon
		mountain_polygon = _clip_river_polygons(mountain_polygon, original_area)
		var tex_entry: Dictionary = _build_mountain_texture_entry(poly_id, mountain_polygon)
		if tex_entry.is_empty() == false:
			_mountain_textures[poly_id] = tex_entry

# ─────────────────────────── Mountain texture helpers ───────────────────────────
func _build_mountain_texture_entry(poly_id: int, polygon: PackedVector2Array) -> Dictionary:
	var result: Dictionary = {}
	if polygon.size() < 3:
		return result
	var t_total0: int = 0
	if PROFILE_MTN:
		t_total0 = Time.get_ticks_msec()
	var aabb_world: Rect2 = GeometryUtils.calculate_bounding_box(polygon)
	var pad: int = MTN_TEX_PADDING_PX
	var padded_pos: Vector2 = Vector2(aabb_world.position.x - float(pad), aabb_world.position.y - float(pad))
	var padded_size: Vector2 = Vector2(aabb_world.size.x + float(pad * 2), aabb_world.size.y + float(pad * 2))
	var aabb_padded: Rect2 = Rect2(padded_pos, padded_size)
	var tex_w: int = int(ceil(max(1.0, aabb_padded.size.x)))
	var tex_h: int = int(ceil(max(1.0, aabb_padded.size.y)))
	var img: Image = Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	var centroid: Vector2 = GeometryUtils.calculate_centroid(polygon)
	var t_ridge0: int = 0
	var t_ridge_ms: int = 0
	if PROFILE_MTN:
		t_ridge0 = Time.get_ticks_msec()
	var ridges: Array[Dictionary] = _build_ridges_for_polygon(polygon)
	if PROFILE_MTN:
		t_ridge_ms = Time.get_ticks_msec() - t_ridge0
	var base: Color = Global.get_color_for_terrain("mountains")
	var base_hsv: Vector3 = Vector3(base.h, base.s, base.v)
	var base_col: Color = Color.from_hsv(base_hsv.x, base_hsv.y, base_hsv.z, base.a)
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(tex_w * tex_h)
	var max_edge_dist: float = 0.0
	var tested_pixels: int = 0
	var inside_pixels: int = 0
	var edge_tests: int = 0
	var t_pass1_0: int = 0
	var t_pass1_ms: int = 0
	var t_pp_ms: int = 0
	var t_edge_ms: int = 0
	# Pass 1: compute edge distances and max
	var y1: int = 0
	while y1 < tex_h:
		var x1: int = 0
		while x1 < tex_w:
			if PROFILE_MTN:
				if y1 == 0 and x1 == 0:
					t_pass1_0 = Time.get_ticks_msec()
			var world_p: Vector2 = Vector2(aabb_padded.position.x + float(x1) + MTN_TEX_SUBPIXEL_OFFSET, aabb_padded.position.y + float(y1) + MTN_TEX_SUBPIXEL_OFFSET)
			var t_pp0: int = 0
			if PROFILE_MTN:
				t_pp0 = Time.get_ticks_msec()
			var inside: bool = Geometry2D.is_point_in_polygon(world_p, polygon)
			if PROFILE_MTN:
				t_pp_ms += Time.get_ticks_msec() - t_pp0
			var idx: int = y1 * tex_w + x1
			if inside:
				var t_e0: int = 0
				if PROFILE_MTN:
					t_e0 = Time.get_ticks_msec()
				var d: float = _nearest_edge_distance(world_p, polygon)
				if PROFILE_MTN:
					t_edge_ms += Time.get_ticks_msec() - t_e0
				edge_tests += 1
				distances[idx] = d
				if d > max_edge_dist:
					max_edge_dist = d
				inside_pixels += 1
			else:
				distances[idx] = -1.0
			tested_pixels += 1
			x1 += 1
		y1 += 1
	if PROFILE_MTN:
		t_pass1_ms = Time.get_ticks_msec() - t_pass1_0
	# Pass 2: shade pixels
	var y2: int = 0
	var t_pass2_0: int = 0
	var t_pass2_ms: int = 0
	var t_ridge_lookup_ms: int = 0
	if PROFILE_MTN:
		t_pass2_0 = Time.get_ticks_msec()
	while y2 < tex_h:
		var x2: int = 0
		while x2 < tex_w:
			var idx2: int = y2 * tex_w + x2
			var d2: float = distances[idx2]
			if d2 >= 0.0:
				var world_p2: Vector2 = Vector2(aabb_padded.position.x + float(x2) + MTN_TEX_SUBPIXEL_OFFSET, aabb_padded.position.y + float(y2) + MTN_TEX_SUBPIXEL_OFFSET)
				var t_r0: int = 0
				if PROFILE_MTN:
					t_r0 = Time.get_ticks_msec()
				var col: Color = _compute_mountain_pixel_color(world_p2, centroid, base_col, ridges, d2, max_edge_dist)
				if PROFILE_MTN:
					t_ridge_lookup_ms += Time.get_ticks_msec() - t_r0
				img.set_pixel(x2, y2, col)
			else:
				img.set_pixel(x2, y2, Color(0.0, 0.0, 0.0, 0.0))
			x2 += 1
		y2 += 1
	if PROFILE_MTN:
		t_pass2_ms = Time.get_ticks_msec() - t_pass2_0
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	result["texture"] = tex
	result["aabb"] = aabb_padded
	if PROFILE_MTN:
		var t_total_ms: int = Time.get_ticks_msec() - t_total0
		print("[MTN/TEX] poly_id=", poly_id,
			" tex=", tex_w, "x", tex_h,
			" tested=", tested_pixels,
			" inside=", inside_pixels,
			" ridge_ms=", t_ridge_ms,
			" pass1_ms=", t_pass1_ms, " (pp_ms=", t_pp_ms, ", edge_ms=", t_edge_ms, ", edge_tests=", edge_tests, ")",
			" pass2_ms=", t_pass2_ms, " (ridge_ms=", t_ridge_lookup_ms, ")",
			" total_ms=", t_total_ms)
	return result

func _compute_mountain_pixel_color(p: Vector2, centroid: Vector2, base_col: Color, ridges: Array[Dictionary], edge_dist: float, max_edge_dist: float) -> Color:
	var dir_vec: Vector2 = (p - centroid)
	var n: Vector2
	if dir_vec.length() == 0.0:
		n = Vector2(0.0, -1.0)
	else:
		n = dir_vec.normalized()
	var yaw: float = deg_to_rad(_rng.randf_range(-MTN_JITTER_DEG, MTN_JITTER_DEG))
	var n_rot: Vector2 = Vector2(
		n.x * cos(yaw) - n.y * sin(yaw),
		n.x * sin(yaw) + n.y * cos(yaw)
	)
	var d_l: float = n_rot.dot(-Global.LIGHT_DIR)
	if d_l < -1.0:
		d_l = -1.0
	else:
		if d_l > 1.0:
			d_l = 1.0
	var f_light: float = MTN_BRIGHT_MIN + (MTN_BRIGHT_MAX - MTN_BRIGHT_MIN) * (d_l + 1.0) * 0.5
	var ridge_pair: Dictionary = _ridge_multipliers_at(p, ridges)
	var ridge_dist_mul: float = float(ridge_pair["distance"])
	var ridge_norm_mul: float = float(ridge_pair["normal"])
	var t_norm: float = 0.0
	if max_edge_dist > 0.0:
		t_norm = edge_dist / max_edge_dist
	else:
		t_norm = 0.0
	var eased: float = pow(t_norm, 1.0 / 2.0)
	eased = min(eased, 0.75)
	var col: Color = base_col * (0.75 * ridge_norm_mul + 0.75 * f_light)
	col = _composite_over_color(col, Global.background_color)
	var prox_mul: float = 0.5 + eased * 0.5# + min(0.75, 3.0 * pow(eased, 2.0) * pow(1.0 - ridge_dist_mul, 2.0))
	if prox_mul > 1.0:
		prox_mul = 1.0
	else:
		prox_mul = prox_mul
	col = col * prox_mul
	col.a = 1.0
	return col

func _draw_textured_polygon_with_aabb(polygon: PackedVector2Array, texture: Texture2D, aabb: Rect2) -> void:
	if texture == null:
		return
	var centroid: Vector2 = GeometryUtils.calculate_centroid(polygon)
	var tri_pts: PackedVector2Array = PackedVector2Array()
	var tri_uvs: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i < polygon.size():
		var cur: Vector2 = polygon[i]
		var next: Vector2 = polygon[(i + 1) % polygon.size()]
		tri_pts.append(centroid)
		tri_pts.append(cur)
		tri_pts.append(next)
		var uv_c: Vector2 = Vector2(
			(centroid.x - aabb.position.x) / max(aabb.size.x, 1.0),
			(centroid.y - aabb.position.y) / max(aabb.size.y, 1.0)
		)
		var uv_1: Vector2 = Vector2(
			(cur.x - aabb.position.x) / max(aabb.size.x, 1.0),
			(cur.y - aabb.position.y) / max(aabb.size.y, 1.0)
		)
		var uv_2: Vector2 = Vector2(
			(next.x - aabb.position.x) / max(aabb.size.x, 1.0),
			(next.y - aabb.position.y) / max(aabb.size.y, 1.0)
		)
		tri_uvs.append(uv_c)
		tri_uvs.append(uv_1)
		tri_uvs.append(uv_2)
		i += 1
	var j: int = 0
	while j < tri_pts.size():
		if j + 2 >= tri_pts.size():
			break
		var tri: PackedVector2Array = PackedVector2Array([
			tri_pts[j], tri_pts[j + 1], tri_pts[j + 2]
		])
		var cols: PackedColorArray = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 1.0)
		])
		var uvs: PackedVector2Array = PackedVector2Array([
			tri_uvs[j], tri_uvs[j + 1], tri_uvs[j + 2]
		])
		draw_polygon(tri, cols, uvs, texture)
		j += 3


# ═══════════════  Drawing helpers  ═════════════════════════════════════════
func _edge_key(a: Vector2, b: Vector2) -> String:
	return "%f,%f|%f,%f" % [a.x, a.y, b.x, b.y] \
		if (a.x < b.x or (a.x == b.x and a.y < b.y)) \
		else "%f,%f|%f,%f" % [b.x, b.y, a.x, a.y]

func _stroke_river(poly_not_extended: PackedVector2Array, col: Color, width: float) -> void:
	var poly: PackedVector2Array = poly_not_extended.duplicate()
	
	# Simple endpoint extension (no obstacle handling needed for drawing)
	if poly.size() >= 2:
		var push: float = MapGenerator.BANK_OFFSET
		
		# Extend start point if on world edge
		if Global.is_point_on_world_edge(poly[0]):
			var dir_start: Vector2 = (poly[0] - poly[1]).normalized()
			poly[0] += dir_start * push
		
		# Extend end point if on world edge
		var last: int = poly.size() - 1
		if Global.is_point_on_world_edge(poly[last]):
			var dir_end: Vector2 = (poly[last] - poly[last - 1]).normalized()
			poly[last] += dir_end * push
	
	for i: int in range(poly.size() - 1):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[i + 1]

		# larger push-out if the vertex touches the world border
		var ext_a: float = width * 0.25
		var ext_b: float = width * 0.25

		var a2: Vector2 = a + (a - b).normalized() * ext_a
		var b2: Vector2 = b + (b - a).normalized() * ext_b

		draw_line(a2, b2, col, width, true)

func _water_ripples(
		poly: PackedVector2Array,
		ripples_per_px: float,
		max_offset: float,
		col: Color,
		width: float
) -> void:
	var accumulated: float = 0.0
	for i in range(poly.size() - 1):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[i + 1]
		var seg: Vector2 = b - a
		var seg_len: float = seg.length()
		if seg_len < 1.0:
			continue
		var dir: Vector2 = seg / seg_len
		var perp: Vector2 = Vector2(-dir.y, dir.x)

		var step: float = 1.0 / ripples_per_px			# draw roughly every N px
		var t: float = 0.0
		while t < seg_len:
			var centre: Vector2 = a + dir * t
			var offset: float   = randf_range(-max_offset, max_offset)
			var p: Vector2      = centre + perp * offset
			# short dash perpendicular to flow
			draw_line(p - dir * width * 0.125,
					  p + dir * width * 0.125,
					  col, width * 0.05, true)
			t += step


func _draw_rivers() -> void:
	if map == null:
		return

	# style constants --------------------------------------------------
	#const WATER_W     := 2*MapGenerator.BANK_OFFSET			# main water body
	#const WATER_INNER := 1.5*MapGenerator.BANK_OFFSET			# lighter core
	#const WATER_CORE  := MapGenerator.BANK_OFFSET			# darker centre
	#const WATER_INNER_CORE  := 0.5*MapGenerator.BANK_OFFSET			# darker centre
	#
	#var WATER_LIGHT := WATER_BASE.lightened(0.0)
	#var WATER_DARK  := WATER_BASE.darkened(0.0625)
	#var WATER_DARKEST  := WATER_BASE.darkened(0.125)
	#
	## ripple parameters
	#const RIPPLES_PER_PX := 1.0 / 28.0			 # ~1 ripple every 28 px along
	#const RIPPLE_OFFSET  := WATER_W * 0.40
#
	## render passes ----------------------------------------------------
	#for river: PackedVector2Array in map.rivers:
		#if river.size() < 2:
			#continue
#
	#for river: PackedVector2Array in map.rivers:
		#if river.size() < 2:
			#continue
		#_stroke_river(river, WATER_LIGHT, WATER_INNER)
	#
#
	#for river: PackedVector2Array in map.rivers:
		#if river.size() < 2:
			#continue
		#_stroke_river(river, WATER_DARK,  WATER_CORE)
#
	#for river: PackedVector2Array in map.rivers:
		#if river.size() < 2:
			#continue
		#_stroke_river(river, WATER_DARKEST,  WATER_INNER_CORE)
		#
	#for river: PackedVector2Array in map.rivers:
		#if river.size() < 2:
			#continue
		## 5) subtle ripples
		#var color: Color = WATER_LIGHT
		##color.a = 0.4
		#_water_ripples(river, RIPPLES_PER_PX, RIPPLE_OFFSET, color, WATER_W)
	
	_draw_rocks()

static func generate_rock_polygon(centre: Vector2, tangent: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var sides: int = rng.randi_range(ROCK_MIN_SIDES, ROCK_MAX_SIDES)
	var perp: Vector2 = Vector2(-tangent.y, tangent.x)
	var out: PackedVector2Array = PackedVector2Array()
	
	for k: int in range(sides):
		var ang: float = TAU * float(k) / float(sides) + rng.randf_range(-0.2, 0.2)
		var r: float = rng.randf_range(ROCK_MIN_RADIUS, ROCK_MAX_RADIUS)
		var raw: Vector2 = Vector2(cos(ang), sin(ang)) * r
		# decompose then stretch along flow
		var x_t: float = raw.dot(tangent)
		var y_p: float = raw.dot(perp)
		var v: Vector2 = tangent * x_t * ROCK_ELONG_SCALE + perp * y_p
		out.append(centre + v)
	return out

static func generate_rock_facets(outline: PackedVector2Array, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var centroid: Vector2 = Vector2.ZERO
	for v: Vector2 in outline:
		centroid += v
	centroid /= float(outline.size())
	
	var facets: Array[Dictionary] = []
	for i_f: int in range(outline.size()):
		var v1: Vector2 = outline[i_f]
		var v2: Vector2 = outline[(i_f + 1) % outline.size()]
		var tri: PackedVector2Array = PackedVector2Array([centroid, v1, v2])
		
		var mid: Vector2 = (v1 + v2) * 0.5
		var n: Vector2 = (mid - centroid).normalized()
		if n == Vector2.ZERO:
			n = Vector2(0.0, -1.0)
		var yaw: float = deg_to_rad(
			rng.randf_range(-ROCK_FACET_JITTER_DEG, ROCK_FACET_JITTER_DEG)
		)
		var n_rot: Vector2 = Vector2(
			n.x * cos(yaw) - n.y * sin(yaw),
			n.x * sin(yaw) + n.y * cos(yaw)
		)
		
		var dot_l: float = clamp(n_rot.dot(-Global.LIGHT_DIR), -1.0, 1.0)
		var f: float = ROCK_LIGHT_DARK + (ROCK_LIGHT_BRIGHT - ROCK_LIGHT_DARK) * (dot_l + 1.0) * 0.5
		var color: Color = ROCK_BASE_COLOR * f 
		color.v += rng.randf_range(-0.1, 0.1)
		facets.append({"poly": tri, "col": color})
	
	return facets

func _prepare_rocks() -> void:
	_river_rocks.clear()
	_rng.randomize()
	
	# Build simplified T‑junction data: impacted gaps and hitting extensions/suppressions
	var t_data: Dictionary = _compute_t_junction_data(map)
	var bank_gaps: Dictionary = {}
	var bank_extensions: Dictionary = {}
	if t_data.has("gaps"):
		bank_gaps = t_data["gaps"]
	else:
		bank_gaps = {}
	if t_data.has("extensions"):
		bank_extensions = t_data["extensions"]
	else:
		bank_extensions = {}
	
	for river_index: int in range(map.rivers.size()):
		if river_index >= map.river_banks.size():
			continue
			
		var banks: Dictionary = map.river_banks[river_index]
		var bank_left: PackedVector2Array = banks["left"]
		var bank_right: PackedVector2Array = banks["right"]

		# Iterate banks with side labels so we can apply side-specific gaps
		var banks_list: Array = []
		banks_list.append(bank_left)
		banks_list.append(bank_right)
		var sides: Array[String] = ["left", "right"]
		
		for bi: int in range(banks_list.size()):
			var bank: PackedVector2Array = banks_list[bi]
			var side_name: String = sides[bi]
			# total length of this bank polyline
			var total: float = 0.0
			for i: int in range(bank.size() - 1):
				total += bank[i].distance_to(bank[i + 1])
			
			var steps: int = int(ceil(total / ROCK_SPACING))
			if steps <= 0:
				continue
			var spacing: float = total / float(steps)
			
			var acc: float = 0.0
			var seg_idx: int = 0
			var seg_len: float = bank[0].distance_to(bank[1])
			
			for s: int in range(steps):
				# absolute param position along this bank
				var s_pos: float = float(s) * spacing
				# skip if within any confluence gap for this bank
				if _s_in_any_gap(bank_gaps, river_index, side_name, s_pos):
					continue
				# advance along bank to reach s_pos
				while acc + seg_len < s_pos and seg_idx < bank.size() - 2:
					acc += seg_len
					seg_idx += 1
					seg_len = bank[seg_idx].distance_to(bank[seg_idx + 1])
				
				if seg_len <= 0.0:
					continue
				var t: float = (s_pos - acc) / seg_len
				var a: Vector2 = bank[seg_idx]
				var b: Vector2 = bank[seg_idx + 1]
				var pos: Vector2 = a.lerp(b, t)
				var tangent: Vector2 = (b - a).normalized()
				if b == a:
					continue
				# build facets
				var outline: PackedVector2Array = generate_rock_polygon(pos, tangent, _rng)
				var centroid: Vector2 = Vector2.ZERO
				for v: Vector2 in outline:
					centroid += v
				centroid /= float(outline.size())
				
				var facets: Array[Dictionary] = generate_rock_facets(outline, _rng)
				
				var shadow_poly: PackedVector2Array = GeometryUtils.translate_polygon(
					outline, ROCK_SHADOW_OFFSET
				)
				
				_river_rocks.append({
					"shadow": shadow_poly,
					"facets": facets
				})

			# Handle extensions for this bank (add rocks along extended range if any)
			var key_ext: String = str(river_index) + "|" + side_name
			if bank_extensions.has(key_ext):
				var ext_ranges: Array = bank_extensions[key_ext]
				for rng in ext_ranges:
					var s_a: float = rng["start"]
					var s_b: float = rng["end"]
					var ext_len: float = abs(s_b - s_a)
					if ext_len <= 0.0:
						continue
					var ext_steps: int = int(ceil(ext_len / ROCK_SPACING))
					if ext_steps <= 0:
						continue
					for ei: int in range(ext_steps + 1):
						var alpha: float = float(ei) / float(ext_steps)
						var s_cur: float = s_a + (s_b - s_a) * alpha
						# Skip if extension point falls into a suppression gap as well
						if _s_in_any_gap(bank_gaps, river_index, side_name, s_cur):
							continue
						var pos_ext: Vector2 = _point_at_extended_s_on_bank(bank, s_cur)
						var seg_dir: Vector2
						if bank.size() >= 2:
							seg_dir = (bank[bank.size() - 1] - bank[bank.size() - 2]).normalized()
						else:
							seg_dir = Vector2(1.0, 0.0)
						var outline_e: PackedVector2Array = generate_rock_polygon(pos_ext, seg_dir, _rng)
						var centroid_e: Vector2 = Vector2.ZERO
						for vv: Vector2 in outline_e:
							centroid_e += vv
						centroid_e /= float(outline_e.size())
						var facets_e: Array[Dictionary] = generate_rock_facets(outline_e, _rng)
						var shadow_e: PackedVector2Array = GeometryUtils.translate_polygon(
							outline_e, ROCK_SHADOW_OFFSET
						)
						_river_rocks.append({
							"shadow": shadow_e,
							"facets": facets_e
						})


func _draw_rocks() -> void:
	for rock: Dictionary in _river_rocks:
		# subtle translucent shadow
		var sh_col: Color = ROCK_BASE_COLOR * ROCK_SHADOW_DARKEN
		sh_col.a = 0.2
		draw_polygon(rock["shadow"] as PackedVector2Array, PackedColorArray([sh_col]))
	
	for rock: Dictionary in _river_rocks:
		# each facet with its own shade
		var facets: Array = rock["facets"]
		for face in facets:
			draw_polygon(face["poly"] as PackedVector2Array, PackedColorArray([face["col"]]))

# ──────────────────────────── Ridge helpers ─────────────────────────────────────
func _build_ridges_for_polygon(polygon: PackedVector2Array) -> Array[Dictionary]:
	var ridges: Array[Dictionary] = []
	if polygon.size() < 3:
		return ridges
	# Find two farthest vertices
	var i_a: int = 0
	var i_b: int = 0
	var max_d2: float = -INF
	for i: int in range(polygon.size()):
		for j: int in range(i + 1, polygon.size()):
			var d2: float = polygon[i].distance_squared_to(polygon[j])
			if d2 > max_d2:
				max_d2 = d2
				i_a = i
				i_b = j
			else:
				max_d2 = max_d2
	var centroid: Vector2 = GeometryUtils.calculate_centroid(polygon)
	# Main ridge: two noisy polylines centroid -> farthest vertices
	var main_poly_1: PackedVector2Array = _trace_noisy_path(
		centroid, polygon[i_a], polygon,
		RIDGE_TRACE_STEP_PX, RIDGE_CURVE_MAX_DEG,
		RIDGE_MAIN_NOISE_DEG, RIDGE_MAIN_NOISE_FREQ
	)
	var main_poly_2: PackedVector2Array = _trace_noisy_path(
		centroid, polygon[i_b], polygon,
		RIDGE_TRACE_STEP_PX, RIDGE_CURVE_MAX_DEG,
		RIDGE_MAIN_NOISE_DEG, RIDGE_MAIN_NOISE_FREQ
	)
	var main_len_1: int = 0
	var main_len_2: int = 0
	if main_poly_1.size() >= 2:
		main_len_1 = main_poly_1.size() - 1
	else:
		main_len_1 = 0
	if main_poly_2.size() >= 2:
		main_len_2 = main_poly_2.size() - 1
	else:
		main_len_2 = 0
	for k: int in range(main_poly_1.size() - 1):
		var rec_m1: Dictionary = {}
		rec_m1["a"] = main_poly_1[k]
		rec_m1["b"] = main_poly_1[k + 1]
		rec_m1["level"] = 1
		ridges.append(rec_m1)
	for k2: int in range(main_poly_2.size() - 1):
		var rec_m2: Dictionary = {}
		rec_m2["a"] = main_poly_2[k2]
		rec_m2["b"] = main_poly_2[k2 + 1]
		rec_m2["level"] = 1
		ridges.append(rec_m2)
	if RIDGE_LEVELS <= 1:
		return ridges
	# Secondary ridges: random walk from remaining vertices until they hit any ridge (main or earlier secondaries)
	var secondary_total_segments: int = 0
	var secondary_count: int = 0
	for vi: int in range(polygon.size()):
		if vi == i_a or vi == i_b:
			continue
		var vtx: Vector2 = polygon[vi]
		var all_blockers: Array[PackedVector2Array] = []
		all_blockers.append(main_poly_1)
		all_blockers.append(main_poly_2)
		# append previously added secondary polylines from this loop (built from ridges list)
		var existing_sec: Array[PackedVector2Array] = _reconstruct_secondary_polylines(ridges)
		for pl in existing_sec:
			all_blockers.append(pl)
		# starting direction is bisector between centroid and closest point on main branches
		var c1: Vector2 = _closest_point_on_polyline(vtx, main_poly_1)
		var c2: Vector2 = _closest_point_on_polyline(vtx, main_poly_2)
		var d1: float = vtx.distance_squared_to(c1)
		var d2: float = vtx.distance_squared_to(c2)
		var closest: Vector2 = c1 if d1 <= d2 else c2
		var dir_c: Vector2 = (centroid - vtx).normalized()
		var dir_m: Vector2 = (closest - vtx).normalized()
		var start_dir: Vector2 = dir_c + dir_m
		if start_dir.length() <= 0.0:
			start_dir = dir_m
		else:
			start_dir = start_dir.normalized()
		var sec_poly: PackedVector2Array = _trace_random_walk_until_hit(
			vtx, polygon, centroid,
			RIDGE_TRACE_STEP_PX * 0.9, RIDGE_CURVE_MAX_DEG,
			RIDGE_SECOND_NOISE_DEG, RIDGE_SECOND_NOISE_FREQ,
			all_blockers,
			start_dir
		)
		var use_poly: PackedVector2Array = sec_poly
		var sec_len: int = 0
		if use_poly.size() >= 2:
			sec_len = use_poly.size() - 1
		else:
			sec_len = 0
		secondary_total_segments += sec_len
		secondary_count += 1
		for s: int in range(use_poly.size() - 1):
			var rec_s: Dictionary = {}
			rec_s["a"] = use_poly[s]
			rec_s["b"] = use_poly[s + 1]
			rec_s["level"] = 2
			ridges.append(rec_s)
	if PROFILE_MTN:
		print("[MTN] main_len1=", main_len_1, " main_len2=", main_len_2, " secondary_total=", secondary_total_segments, " secondary_count=", secondary_count)
	return ridges

func _trace_noisy_path(
		start_pt: Vector2,
		end_pt: Vector2,
		polygon: PackedVector2Array,
		step_px: float,
		max_turn_deg: float,
		noise_deg: float,
		noise_freq: float,
		stop_on_polyline: PackedVector2Array = PackedVector2Array()
	) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var dir: Vector2 = (end_pt - start_pt)
	if dir.length() <= 0.0:
		out.append(start_pt)
		out.append(start_pt)
		return out
	dir = dir.normalized()
	var pos: Vector2 = start_pt
	out.append(pos)
	var max_turn_rad: float = deg_to_rad(max_turn_deg)
	var t: float = 0.0
	var steps: int = 0
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(floor(start_pt.x + start_pt.y))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_freq
	while steps < RIDGE_MAIN_MAX_STEPS:
		steps += 1
		# direction to goal
		var to_goal: Vector2 = (end_pt - pos)
		if to_goal.length() <= step_px:
			out.append(end_pt)
			break
		to_goal = to_goal.normalized()
		# curvature noise
		var n: float = noise.get_noise_2d(pos.x, pos.y)
		var ang_noise: float = deg_to_rad(noise_deg) * n
		# blend direction and clamp turn
		var desired: Vector2 = to_goal
		var cur_ang: float = atan2(dir.y, dir.x)
		var des_ang: float = atan2(desired.y, desired.x) + ang_noise
		var delta: float = wrapf(des_ang - cur_ang, -PI, PI)
		if delta < -max_turn_rad:
			delta = -max_turn_rad
		else:
			if delta > max_turn_rad:
				delta = max_turn_rad
		var new_ang: float = cur_ang + delta
		dir = Vector2(cos(new_ang), sin(new_ang))
		var next_pos: Vector2 = pos + dir * step_px
		# keep inside polygon
		if Geometry2D.is_point_in_polygon(next_pos, polygon) == false:
			break
			## project slightly towards inside by blending with centroid
			#var centroid: Vector2 = GeometryUtils.calculate_centroid(polygon)
			#var pull: Vector2 = (centroid - pos).normalized()
			#next_pos = pos + pull * step_px
			#if Geometry2D.is_point_in_polygon(next_pos, polygon) == false:
				#break
		# stop if we hit the stop polyline
		if stop_on_polyline.size() >= 2:
			for i: int in range(stop_on_polyline.size() - 1):
				var ip_any: Variant = Geometry2D.segment_intersects_segment(pos, next_pos, stop_on_polyline[i], stop_on_polyline[i + 1])
				if ip_any is Vector2:
					out.append(ip_any)
					return out
		pos = next_pos
		out.append(pos)
		# early stop if very close to end
		if pos.distance_to(end_pt) <= step_px:
			out.append(end_pt)
			break
	return out

func _closest_point_on_polyline(p: Vector2, poly: PackedVector2Array) -> Vector2:
	var best: Vector2 = poly[0]
	var best_d2: float = INF
	for i: int in range(poly.size() - 1):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[i + 1]
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var d2: float = q.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best = q
		else:
			best_d2 = best_d2
	return best


func _nearest_edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best: float = INF
	var e: int = 0
	while e < poly.size():
		var a: Vector2 = poly[e]
		var b: Vector2 = poly[(e + 1) % poly.size()]
		var proj: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var d: float = p.distance_to(proj)
		if d < best:
			best = d
		else:
			best = best
		e += 1
	return best
	
func _ridge_multipliers_at(p: Vector2, segments: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	result["distance"] = 1.0
	result["normal"] = 1.0
	result["level"] = 0
	if segments.size() <= 0:
		return result
	var best_idx: int = -1
	var best_d_eff: float = INF
	var best_proj: Vector2 = Vector2.ZERO
	var main_best: float = INF
	var main_proj: Vector2 = Vector2.ZERO
	var main_a: Vector2 = Vector2.ZERO
	var main_b: Vector2 = Vector2.ZERO
	var i: int = 0
	while i < segments.size():
		var seg: Dictionary = segments[i]
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var lvl: int = seg["level"]
		var proj: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var d: float = p.distance_to(proj)
		var d_eff: float = d
		if lvl > 1:
			d_eff = d * RIDGE_MAIN_DISTANCE_BIAS
		else:
			d_eff = d_eff
		if d_eff < best_d_eff:
			best_d_eff = d_eff
			best_idx = i
			best_proj = proj
		else:
			best_d_eff = best_d_eff
		if lvl == 1:
			var q: Vector2 = proj
			var dmain: float = p.distance_to(q)
			if dmain < main_best:
				main_best = dmain
				main_proj = q
				main_a = a
				main_b = b
		else:
			main_best = main_best
		i += 1
	assert(best_idx >= 0)
	var chosen: Dictionary = segments[best_idx]
	var a2: Vector2 = chosen["a"]
	var b2: Vector2 = chosen["b"]
	var level: int = chosen["level"]
	var seg_vec: Vector2 = b2 - a2
	if seg_vec.length() <= 0.0:
		return result
	var t_n: Vector2 = seg_vec.normalized()
	var n_vec: Vector2 = Vector2(-t_n.y, t_n.x)
	var yaw: float = deg_to_rad(_rng.randf_range(-MTN_JITTER_DEG, MTN_JITTER_DEG))
	n_vec = Vector2(
		n_vec.x * cos(yaw) - n_vec.y * sin(yaw),
		n_vec.x * sin(yaw) + n_vec.y * cos(yaw)
	)
	var rel: Vector2 = p - best_proj
	var side_dot: float = rel.dot(n_vec)
	var side: float = 0.0
	if side_dot >= 0.0:
		side = 1.0
	else:
		side = -1.0
	var light: float = n_vec.dot(-Global.LIGHT_DIR)
	if light < -1.0:
		light = -1.0
	else:
		if light > 1.0:
			light = 1.0
	result["distance"] = _ridge_factor_distance_from(best_d_eff, level)
	var normal_chosen: float = _ridge_factor_normal_from(light, side)
	var normal_main: float = normal_chosen
	if main_a != main_b:
		var m_vec: Vector2 = (main_b - main_a)
		if m_vec.length() > 0.0:
			var m_n: Vector2 = m_vec.normalized()
			var m_perp: Vector2 = Vector2(-m_n.y, m_n.x)
			var yaw2: float = deg_to_rad(_rng.randf_range(-MTN_JITTER_DEG, MTN_JITTER_DEG))
			var m_light_n: Vector2 = Vector2(
				m_perp.x * cos(yaw2) - m_perp.y * sin(yaw2),
				m_perp.x * sin(yaw2) + m_perp.y * cos(yaw2)
			)
			var rel2: Vector2 = p - main_proj
			var side2: float
			if rel2.dot(m_perp) >= 0.0:
				side2 = 1.0
			else:
				side2 = -1.0
			var light2: float = m_light_n.dot(-Global.LIGHT_DIR)
			if light2 < -1.0:
				light2 = -1.0
			else:
				if light2 > 1.0:
					light2 = 1.0
			normal_main = _ridge_factor_normal_from(light2, side2)
	var dom_w: float = 0.0
	if level > 1:
		dom_w = RIDGE_MAIN_NORMAL_DOMINANCE
		if main_best < INF and best_d_eff > 0.0:
			var ratio: float = clamp(main_best / pow(best_d_eff, 2.0), 0.0, 1.0)
			dom_w = clamp(dom_w * (1.0 - ratio), 0.0, 1.0)
	var normal_blend: float = normal_chosen * (1.0 - dom_w) + normal_main * dom_w
	result["normal"] = normal_blend
	result["level"] = level
	return result

func _reconstruct_secondary_polylines(ridges: Array[Dictionary]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var cur: PackedVector2Array = PackedVector2Array()
	var last_b: Vector2 = Vector2.ZERO
	var has_last: bool = false
	for rec in ridges:
		if int(rec.get("level", 0)) != 2:
			continue
		var a: Vector2 = rec["a"]
		var b: Vector2 = rec["b"]
		if has_last and a == last_b:
			cur.append(b)
			last_b = b
		else:
			if cur.size() >= 2:
				out.append(cur)
			cur = PackedVector2Array()
			cur.append(a)
			cur.append(b)
			last_b = b
			has_last = true
	if cur.size() >= 2:
		out.append(cur)
	return out

func _trace_random_walk_until_hit(
		start_pt: Vector2,
		polygon: PackedVector2Array,
		centroid: Vector2,
		step_px: float,
		max_turn_deg: float,
		noise_deg: float,
		noise_freq: float,
		blockers: Array[PackedVector2Array],
		initial_dir: Vector2
	) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var dir: Vector2 = initial_dir
	var pos: Vector2 = start_pt
	out.append(pos)
	var max_turn_rad: float = deg_to_rad(max_turn_deg)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(floor(start_pt.x * 13.0 + start_pt.y * 7.0))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_freq
	var steps: int = 0
	while steps < RIDGE_SECOND_MAX_STEPS:
		steps += 1
		# bias toward centroid a bit to reduce escape to corners
		var n: float = noise.get_noise_2d(pos.x, pos.y)
		var cur_ang: float = atan2(dir.y, dir.x)
		var des_ang: float = atan2(initial_dir.y, initial_dir.x)
		var bias_ang: float = lerp_angle(cur_ang, des_ang, RIDGE_SECOND_BIAS)
		var ang_noise: float = deg_to_rad(noise_deg) * n
		var target_ang: float = bias_ang + ang_noise
		var delta: float = wrapf(target_ang - cur_ang, -PI, PI)
		if delta < -max_turn_rad:
			delta = -max_turn_rad
		else:
			if delta > max_turn_rad:
				delta = max_turn_rad
		dir = Vector2(cos(cur_ang + delta), sin(cur_ang + delta))
		var next_pos: Vector2 = pos + dir * step_px
		if Geometry2D.is_point_in_polygon(next_pos, polygon) == false:
			break
		# check intersections to blockers
		for pl in blockers:
			for i: int in range(pl.size() - 1):
				var ip_any: Variant = Geometry2D.segment_intersects_segment(pos, next_pos, pl[i], pl[i + 1])
				if ip_any is Vector2:
					out.append(ip_any)
					return out
		pos = next_pos
		out.append(pos)
	return out

func _ridge_factor_distance_from(best_d: float, level: int) -> float:
	var width_px: float = 1.0 / (float(level) * RIDGE_LEVEL_WIDTH_FACTOR)
	if width_px <= 0.0:
		width_px = RIDGE_EPS
	var atten: float = (best_d / width_px)
	if atten < 0.0:
		atten = 0.0
	else:
		atten = atten
	var factor_distance: float = pow(RIDGE_DISTANCE_STRENGTH * atten, 1/4.0)
	return clamp(factor_distance, 0.0, 1.0)

func _ridge_factor_normal_from(light: float, side: float) -> float:
	var factor_normal: float = RIDGE_NORMAL_STRENGTH * ((side * light) + 1.0) * 0.5
	return clamp(factor_normal, 0.0, 1.0)


# ---------- river confluence gap helpers ----------
func _add_gap_range(
		bank_gaps: Dictionary,
		river_index: int,
		side_name: String,
		start_s: float,
		end_s: float
	) -> void:
	var key: String = str(river_index) + "|" + side_name
	var arr: Array = []
	if bank_gaps.has(key):
		arr = bank_gaps[key]
	else:
		arr = []
	var entry: Dictionary = {}
	entry["start"] = start_s
	entry["end"] = end_s
	arr.append(entry)
	bank_gaps[key] = arr

func _s_in_any_gap(
		bank_gaps: Dictionary,
		river_index: int,
		side_name: String,
		s_pos: float
	) -> bool:
	var key: String = str(river_index) + "|" + side_name
	if bank_gaps.has(key):
		var ranges: Array = bank_gaps[key]
		for r in ranges:
			var start_s: float = r["start"]
			var end_s: float = r["end"]
			if s_pos >= start_s and s_pos <= end_s:
				return true
	else:
		pass
	return false

func _bank_total_length(bank: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(bank.size() - 1):
		var d: float = bank[i].distance_to(bank[i + 1])
		total += d
	return total

func _find_s_on_bank(bank: PackedVector2Array, p: Vector2) -> float:
	var best_s: float = 0.0
	var best_d2: float = INF
	var acc: float = 0.0
	for i: int in range(bank.size() - 1):
		var a: Vector2 = bank[i]
		var b: Vector2 = bank[i + 1]
		var ab: Vector2 = b - a
		var seg_len: float = ab.length()
		if seg_len <= 0.0:
			continue
		var t: float = ((p - a).dot(ab)) / (seg_len * seg_len)
		if t < 0.0:
			t = 0.0
		else:
			if t > 1.0:
				t = 1.0
		var proj: Vector2 = a.lerp(b, t)
		var d2: float = proj.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best_s = acc + seg_len * t
		acc += seg_len
	return best_s

func _point_at_s_on_bank(bank: PackedVector2Array, s_pos: float) -> Vector2:
	var acc: float = 0.0
	for i: int in range(bank.size() - 1):
		var a: Vector2 = bank[i]
		var b: Vector2 = bank[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len <= 0.0:
			continue
		if acc + seg_len >= s_pos:
			var t: float = (s_pos - acc) / seg_len
			return a.lerp(b, t)
		acc += seg_len
	return bank[bank.size() - 1]


# ---------- simplified T-junction helpers ----------
func _nearest_endpoint_and_adjacent(bank: PackedVector2Array, p0: Vector2) -> Dictionary:
	var out: Dictionary = {}
	if bank.size() < 2:
		out["endpoint_idx"] = 0
		out["adjacent_idx"] = 0
		out["endpoint_is_end"] = true
		out["endpoint"] = bank[0]
		out["adjacent"] = bank[0]
		return out
	var d_start: float = bank[0].distance_to(p0)
	var d_end: float = bank[bank.size() - 1].distance_to(p0)
	if d_end <= d_start:
		out["endpoint_idx"] = bank.size() - 1
		out["adjacent_idx"] = bank.size() - 2
		out["endpoint_is_end"] = true
		out["endpoint"] = bank[bank.size() - 1]
		out["adjacent"] = bank[bank.size() - 2]
	else:
		out["endpoint_idx"] = 0
		out["adjacent_idx"] = 1
		out["endpoint_is_end"] = false
		out["endpoint"] = bank[0]
		out["adjacent"] = bank[1]
	return out

func _build_terminal_line_for_bank(bank: PackedVector2Array, p0: Vector2, extend_len: float) -> Dictionary:
	var res: Dictionary = {}
	var info: Dictionary = _nearest_endpoint_and_adjacent(bank, p0)
	var endpoint: Vector2 = info["endpoint"]
	var adjacent: Vector2 = info["adjacent"]
	var dir_vec: Vector2 = (endpoint - adjacent)
	if dir_vec.length() <= 0.0:
		res["p1"] = endpoint
		res["p2"] = endpoint
		res["endpoint"] = endpoint
		res["adjacent"] = adjacent
		res["endpoint_is_end"] = info["endpoint_is_end"]
		return res
	var dir_n: Vector2 = dir_vec.normalized()
	var p1: Vector2 = endpoint - dir_n * extend_len
	var p2: Vector2 = endpoint + dir_n * extend_len
	res["p1"] = p1
	res["p2"] = p2
	res["endpoint"] = endpoint
	res["adjacent"] = adjacent
	res["endpoint_is_end"] = info["endpoint_is_end"]
	return res

func _intersections_with_polyline(p1: Vector2, p2: Vector2, bank: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bank.size() < 2:
		return out
	for i: int in range(bank.size() - 1):
		var q1: Vector2 = bank[i]
		var q2: Vector2 = bank[i + 1]
		var ip_any: Variant = Geometry2D.segment_intersects_segment(p1, p2, q1, q2)
		if ip_any is Vector2:
			var rec: Dictionary = {}
			rec["point"] = ip_any
			rec["seg_i"] = i
			out.append(rec)
	return out

func _compute_t_junction_data(p_map: Global.Map) -> Dictionary:
	var result: Dictionary = {}
	var bank_gaps: Dictionary = {}
	var bank_extensions: Dictionary = {}
	if p_map == null:
		result["gaps"] = bank_gaps
		result["extensions"] = bank_extensions
		return result
	var extend_len: float = MapGenerator.BANK_OFFSET * 4.0
	for entry in p_map.river_end_confluences:
		var impacted_index: int = entry["impacted_river_index"]
		var hitting_index: int = entry["hitting_river_index"]
		var p0: Vector2 = entry["point"]
		if impacted_index < 0 or impacted_index >= p_map.river_banks.size():
			continue
		if hitting_index < 0 or hitting_index >= p_map.river_banks.size():
			continue
		var impacted_banks: Dictionary = p_map.river_banks[impacted_index]
		var hitting_banks: Dictionary = p_map.river_banks[hitting_index]
		if impacted_banks.is_empty() or hitting_banks.is_empty():
			continue
		if impacted_banks.has("left") and impacted_banks.has("right") and hitting_banks.has("left") and hitting_banks.has("right"):
			var hit_left: PackedVector2Array = hitting_banks["left"]
			var hit_right: PackedVector2Array = hitting_banks["right"]
			var line_left: Dictionary = _build_terminal_line_for_bank(hit_left, p0, extend_len)
			var line_right: Dictionary = _build_terminal_line_for_bank(hit_right, p0, extend_len)
			var impacted_left: PackedVector2Array = impacted_banks["left"]
			var impacted_right: PackedVector2Array = impacted_banks["right"]
			# test both impacted sides; pick the side producing two intersections closest to p0
			var best_side: String = ""
			var best_i_a: Vector2 = Vector2.ZERO
			var best_i_b: Vector2 = Vector2.ZERO
			var best_score: float = INF
			for side_i: int in range(2):
				var side_name: String
				var impacted_bank: PackedVector2Array
				if side_i == 0:
					side_name = "left"
					impacted_bank = impacted_left
				else:
					side_name = "right"
					impacted_bank = impacted_right
				var ints_l: Array[Dictionary] = _intersections_with_polyline(line_left["p1"], line_left["p2"], impacted_bank)
				var ints_r: Array[Dictionary] = _intersections_with_polyline(line_right["p1"], line_right["p2"], impacted_bank)
				if ints_l.size() <= 0 or ints_r.size() <= 0:
					continue
				# pick closest to p0 for each
				var i_l: Vector2 = Vector2.ZERO
				var i_r: Vector2 = Vector2.ZERO
				var min_dl: float = INF
				var min_dr: float = INF
				for rec_l in ints_l:
					var pt_l: Vector2 = rec_l["point"]
					var dl: float = pt_l.distance_to(p0)
					if dl < min_dl:
						min_dl = dl
						i_l = pt_l
					else:
						min_dl = min_dl
				for rec_r in ints_r:
					var pt_r: Vector2 = rec_r["point"]
					var dr: float = pt_r.distance_to(p0)
					if dr < min_dr:
						min_dr = dr
						i_r = pt_r
					else:
						min_dr = min_dr
				var score: float = max(min_dl, min_dr)
				if score < best_score:
					best_score = score
					best_side = side_name
					best_i_a = i_l
					best_i_b = i_r
				else:
					best_score = best_score
			# if no valid side, skip
			if best_side == "":
				continue
			# Add impacted gap between intersections (order independent)
			var impacted_bank_sel: PackedVector2Array
			if best_side == "left":
				impacted_bank_sel = impacted_left
			else:
				impacted_bank_sel = impacted_right
			var s_a: float = _find_s_on_bank(impacted_bank_sel, best_i_a)
			var s_b: float = _find_s_on_bank(impacted_bank_sel, best_i_b)
			var g_start: float = min(s_a, s_b)
			var g_end: float = max(s_a, s_b)
			var key_imp: String = str(impacted_index) + "|" + best_side
			var arr_g: Array = []
			if bank_gaps.has(key_imp):
				arr_g = bank_gaps[key_imp]
			else:
				arr_g = []
			var entry_g: Dictionary = {}
			entry_g["start"] = g_start
			entry_g["end"] = g_end
			arr_g.append(entry_g)
			bank_gaps[key_imp] = arr_g
			# For each hitting side, decide suppression or extension
			for side_hit_i: int in range(2):
				var side_hit: String
				var hit_bank: PackedVector2Array
				var line_info: Dictionary
				var i_pt: Vector2
				if side_hit_i == 0:
					side_hit = "left"
					hit_bank = hit_left
					line_info = line_left
					i_pt = best_i_a
				else:
					side_hit = "right"
					hit_bank = hit_right
					line_info = line_right
					i_pt = best_i_b
				# compute if intersection lies within terminal segment
				var endpoint: Vector2 = line_info["endpoint"]
				var adjacent: Vector2 = line_info["adjacent"]
				var seg_vec: Vector2 = endpoint - adjacent
				var seg_len2: float = seg_vec.length_squared()
				var inside: bool = false
				if seg_len2 > 0.0:
					var t_proj: float = ((i_pt - adjacent).dot(seg_vec)) / seg_len2
					if t_proj >= 0.0:
						if t_proj <= 1.0:
							inside = true
						else:
							inside = false
					else:
						inside = false
				else:
					inside = false
				var key_hit: String = str(hitting_index) + "|" + side_hit
				var total_len_hit: float = _bank_total_length(hit_bank)
				if inside:
					# suppress rocks from intersection towards endpoint
					var s_int: float = _find_s_on_bank(hit_bank, i_pt)
					var s_end: float
					var info_end: Dictionary = _nearest_endpoint_and_adjacent(hit_bank, p0)
					var is_end: bool = info_end["endpoint_is_end"]
					if is_end:
						s_end = total_len_hit
					else:
						s_end = 0.0
					var gs: float = min(s_int, s_end)
					var ge: float = max(s_int, s_end)
					var arr_h_gap: Array = []
					if bank_gaps.has(key_hit):
						arr_h_gap = bank_gaps[key_hit]
					else:
						arr_h_gap = []
					var rec_gap: Dictionary = {}
					rec_gap["start"] = gs
					rec_gap["end"] = ge
					arr_h_gap.append(rec_gap)
					bank_gaps[key_hit] = arr_h_gap
				else:
					# extend rocks from endpoint to the intersection beyond
					var dist_ext: float = i_pt.distance_to(endpoint)
					var s_a_ext: float
					var s_b_ext: float
					var info_end2: Dictionary = _nearest_endpoint_and_adjacent(hit_bank, p0)
					var is_end2: bool = info_end2["endpoint_is_end"]
					if is_end2:
						s_a_ext = total_len_hit
						s_b_ext = total_len_hit + dist_ext
					else:
						s_a_ext = -dist_ext
						s_b_ext = 0.0
					var arr_ext: Array = []
					if bank_extensions.has(key_hit):
						arr_ext = bank_extensions[key_hit]
					else:
						arr_ext = []
					var rec_ext: Dictionary = {}
					rec_ext["start"] = s_a_ext
					rec_ext["end"] = s_b_ext
					arr_ext.append(rec_ext)
					bank_extensions[key_hit] = arr_ext
		else:
			pass
	result["gaps"] = bank_gaps
	result["extensions"] = bank_extensions
	return result

func _point_at_extended_s_on_bank(bank: PackedVector2Array, s_pos: float) -> Vector2:
	var total: float = _bank_total_length(bank)
	if s_pos >= 0.0:
		if s_pos <= total:
			return _point_at_s_on_bank(bank, s_pos)
		else:
			# beyond end
			if bank.size() < 2:
				return bank[bank.size() - 1]
			var last: int = bank.size() - 1
			var v: Vector2 = bank[last] - bank[last - 1]
			var over: float = s_pos - total
			if v.length() > 0.0:
				return bank[last] + v.normalized() * over
			else:
				return bank[last]
	else:
		# before start
		if bank.size() < 2:
			return bank[0]
		var v2: Vector2 = bank[1] - bank[0]
		if v2.length() > 0.0:
			return bank[0] + v2.normalized() * s_pos
		else:
			return bank[0]

# ---------- helper: striped line drawer (place above _stroke_road_segment) ----------
func _draw_striped_line(
		p1: Vector2, p2: Vector2,
		col1: Color, col2: Color,
		width: float, stripe_len: float,
		antialiased: bool = true
	) -> void:
	draw_line(p1, p2, ROAD_BACKGROUND, width+2, antialiased)
		
	var total_len: float = p1.distance_to(p2)
	if total_len <= 0.0:
		return
	var dir: Vector2 = (p2 - p1).normalized()
	var drawn: float = 0.0
	var start: Vector2 = p1
	var use_first: bool = true
	while drawn < total_len:
		var seg_len: float = min(stripe_len, total_len - drawn)
		var end: Vector2 = start + dir * seg_len
		var col: Color
		if use_first:
			col = col1
		else:
			col = col2
		draw_line(start, end, col, width, antialiased)
		use_first = not use_first
		drawn += seg_len
		start = end

# ---------- replace body of _stroke_road_segment (keep its signature) ----------
func _stroke_road_segment(a: Vector2, b: Vector2) -> void:
	var width: float = ROAD_W
	_draw_striped_line(
		a, b,
		ROAD_SHADE, ROAD_LIT,
		width, ROAD_STRIPE_LEN,
		true
	)



func _draw_roads() -> void:
	if map == null:
		return

	for road: PackedVector2Array in map.roads:
		if road.size() < 2:
			continue

		# simple bridges where road-segment crosses any river-segment
		for i: int in range(road.size() - 1):
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			_stroke_road_segment(a, b)

	for road: PackedVector2Array in map.roads:
		if road.size() < 2:
			continue

		# simple bridges where road-segment crosses any river-segment
		for i: int in range(road.size() - 1):
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			# AFTER  ─────────────────────────────────────────────────────────────
			var bridge_pos: Vector2 = Vector2.ZERO
			var found: bool = false
			for river: PackedVector2Array in map.rivers:
				if found:
					break
				for j: int in range(river.size() - 1):
					var ip_any: Variant = Geometry2D.segment_intersects_segment(a, b, river[j], river[j + 1])
					if ip_any is Vector2:
						bridge_pos = ip_any
						found = true
						break

			if found:
				var dir: Vector2 = (b - a).normalized()
				
				# decide which side of the intersection to draw towards
				var d_a: float = bridge_pos.distance_squared_to(a)
				var d_b: float = bridge_pos.distance_squared_to(b)
				var end_pt: Vector2
				if d_a < d_b:
					end_pt = bridge_pos + dir * MapGenerator.BANK_OFFSET	# towards b
				else:
					end_pt = bridge_pos - dir * MapGenerator.BANK_OFFSET	# towards a
				
				draw_line(
					bridge_pos,
					end_pt,
					BRIDGE_COL,
					BRIDGE_W,
					true
				)


func _draw() -> void:
	if areas.is_empty() or map_generator == null or map == null:
		return
	
	if simple_mode == true:
		_draw_simple_background()
		return
	
	if before_rivers:
		draw_background()
		_draw_mountain_black_bases()
	else:
		# Draw mountain textures
		for original_area: Area in map.original_walkable_areas:
			var poly_id_draw: int = original_area.polygon_id
			if map.terrain_map[poly_id_draw] != "mountains":
				continue
			if _mountain_textures.has(poly_id_draw):
				var entry: Dictionary = _mountain_textures[poly_id_draw]
				var mountain_polygon_draw: PackedVector2Array = _clip_river_polygons(original_area.polygon, original_area)
				_draw_textured_polygon_with_aabb(mountain_polygon_draw, entry["texture"], entry["aabb"])
		
		_draw_rivers()
		
		# Draw self-shadows directly on mountains so rivers overlapping mountains also receive shadow there
		_draw_mountain_self_shadows()
		
		
	
		# Draw MultiMesh trees (trunks, then ALL shadows, then ALL canopies)
		if _tree_trunk_multimesh and _tree_trunk_multimesh.instance_count > 0:
			draw_multimesh(_tree_trunk_multimesh, null)
		if _tree_shadow_multimesh and _tree_shadow_multimesh.mesh != null:
			draw_multimesh(_tree_shadow_multimesh, null)
		if _tree_canopy_multimesh and _tree_canopy_multimesh.mesh != null:
			draw_multimesh(_tree_canopy_multimesh, null)
		#for original_area in map.original_walkable_areas:	
			#if map.terrain_map[original_area.polygon_id] == "forest":
				#_draw_outline(original_area, 0.05)

		_draw_mountain_shadows()
		
		_draw_roads()
		
	
func _draw_terrain_pattern(
	polygon: PackedVector2Array,
	terrain_type: String
) -> void:
	
	var base: Color = Global.get_color_for_terrain(terrain_type)
	var base_hsv: Vector3 = Vector3(base.h, base.s, base.v)
	var base_v: float = clamp(base_hsv.y + _rng.randf_range(-0.025, 0.025), 0.0, 1.0)
	var base_color: Color = Color.from_hsv(base_hsv.x, base_v, base_hsv.z, base.a)
	var edge_color: Color = (5 * base_color + 3*Color.BLACK) / 8.0
	base_color.v -= 0.1

	if terrain_type == "mountains":
		# Mountains are now rendered via MultiMesh, no need to draw here
		return
	elif terrain_type == "plains":
		_draw_textured_area(polygon, _plains_texture, base_color, edge_color)
		return
	elif terrain_type == "forest":
		_draw_textured_area(polygon, _plains_texture, base_color, edge_color)
		return
		
	var centroid: Vector2 = Vector2.ZERO
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	
	for p: Vector2 in polygon:
		centroid += p
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	if polygon.size() > 0:
		centroid /= polygon.size()

	
	var tri_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(polygon.size()):
		var cur: Vector2  = polygon[i]
		var next: Vector2 = polygon[(i + 1) % polygon.size()]
		tri_pts.append(centroid)
		tri_pts.append(cur)
		tri_pts.append(next)
	
	for i: int in range(0, tri_pts.size(), 3):
		if i + 2 >= tri_pts.size():
			break
		var tri: PackedVector2Array = PackedVector2Array([
			tri_pts[i], tri_pts[i + 1], tri_pts[i + 2]
		])
		var cols: PackedColorArray = PackedColorArray([
			base_color, edge_color, edge_color
		])
		draw_polygon(tri, cols)
	
	if tri_pts.size() < 3:
		draw_colored_polygon(polygon, base_color.lerp(edge_color, 0.5))
		
func draw_background() -> void:
	for obstacle in areas:
		if obstacle.owner_id == -3:
			draw_colored_polygon(obstacle.polygon, Global.background_color)


	for original_area: Area in map.original_walkable_areas:
		var poly_id: int = original_area.polygon_id
		_draw_terrain_pattern(_clip_river_polygons(original_area.polygon, original_area), map.terrain_map[poly_id])
		
	for original_area in map.original_walkable_areas:	
		if map.terrain_map[original_area.polygon_id] in ["plains", "forest"]:
			_draw_outline(original_area, 0.05)

func _draw_outline(original_area: Area, alpha: float = 0.05, darkness: float = 0.3) -> void:
		var polygon: PackedVector2Array = _clip_river_polygons(original_area.polygon, original_area, ROCK_MAX_RADIUS)
		polygon.append(polygon[0])
		var offset_line_polygon = GeometryUtils.find_largest_polygon(
			Geometry2D.offset_polygon(polygon, -DrawComponent.AREA_OUTLINE_THICKNESS)
		)
		offset_line_polygon.append(offset_line_polygon[0])
		var offset_color: Color = Color.DARK_GRAY
		offset_color = offset_color.darkened(darkness)
		offset_color.a = alpha
		draw_polyline(
			offset_line_polygon,
			offset_color,
			DrawComponent.AREA_OUTLINE_THICKNESS,
			true
		)

		#draw_polyline(polygon, DrawComponent.AREA_OUTLINE_COLOR, DrawComponent.AREA_OUTLINE_THICKNESS)

func _draw_simple_background() -> void:
	for obstacle in areas:
		if obstacle.owner_id == -3:
			draw_colored_polygon(obstacle.polygon, Global.background_color)
	
	for original_area: Area in map.original_walkable_areas:
		var pid: int = original_area.polygon_id
		var terrain: String = map.terrain_map[pid]
		var col: Color = Global.get_color_for_terrain(terrain)
		draw_colored_polygon(original_area.polygon, col)
		# outline
		var outline: Color = DrawComponent.AREA_OUTLINE_COLOR
		var poly: PackedVector2Array = original_area.polygon.duplicate()
		poly.append(poly[0])
		draw_polyline(poly, outline, DrawComponent.AREA_OUTLINE_THICKNESS * 0.5, true)
