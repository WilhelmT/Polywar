extends Control
class_name HighlightManager

const MAX_INSTANCES : int   = 512
const BASE_FADE     : float = 0.75          # from the old shader

var mm          : MultiMesh                         # GPU buffer
var life_left   : PackedFloat32Array                # seconds
var life_max    : PackedFloat32Array                # seconds (per slot)
var base_colour : PackedColorArray                  # area colour per slot
var extra_fade  : PackedFloat32Array                # 1.0 or click-strength
var next_slot   : int = 0

const MIN_TRIANGLE_AREA: float = 0.01
# ──────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# unit triangle mesh
	var mesh := ArrayMesh.new()
	var arr  : Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2.ZERO, Vector2(1,0), Vector2(0,1)])
	arr[Mesh.ARRAY_COLOR]  = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	
	# multimesh (fixed capacity)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TransformFormat.TRANSFORM_2D
	mm.use_colors       = true
	mm.mesh             = mesh
	mm.instance_count   = MAX_INSTANCES
	for i in range(MAX_INSTANCES):
		mm.set_instance_color(i, Color(1,1,1,0))
	
	# host-side arrays
	life_left   = PackedFloat32Array(); life_left.resize(MAX_INSTANCES); life_left.fill(0.0)
	life_max    = life_left.duplicate()
	base_colour = PackedColorArray();   base_colour.resize(MAX_INSTANCES)
	extra_fade  = PackedFloat32Array(); extra_fade.resize(MAX_INSTANCES); extra_fade.fill(1.0)

# ──────────────────────────────────────────────────────────────────────────
# PUBLIC API  --------------------------------------------------------------
func add_highlight(
		polygon     : PackedVector2Array,
		area_colour : Color,
		duration    : float,
		extra       : float = 1.0) -> void:
	# duration = 0.5 → normal  · 1.0 → encirclement
	for tri: PackedVector2Array in _triangulate(polygon):
		if GeometryUtils.calculate_polygon_area(tri) < MIN_TRIANGLE_AREA:
			continue
		_store_triangle(tri, area_colour, duration, extra)

# ──────────────────────────────────────────────────────────────────────────
# INTERNALS
func _store_triangle(
		tri       : PackedVector2Array,
		col       : Color,
		dur       : float,
		extra     : float) -> void:
	var a := tri[0]; var b := tri[1]; var c := tri[2]
	var x := b - a;  var y := c - a
	#if x.length_squared() < 1e-4 or y.length_squared() < 1e-4:
		#return
	
	var id := next_slot
	next_slot = (next_slot + 1) % MAX_INSTANCES
	#if not life_left[next_slot] <= 0:
		#print(1)
	mm.set_instance_transform_2d(id, Transform2D(x, y, a))
	
	life_left[id]        = dur
	life_max[id]         = dur
	base_colour[id]      = col
	extra_fade[id]       = extra

	# initialise colour at full strength (fade = 1)
	var final_color := _eval_colour(base_colour[id], 1.0)
	mm.set_instance_color(id, final_color)

func _process(delta: float) -> void:
	for i: int in range(MAX_INSTANCES):
		if life_left[i] <= 0.0:
			continue
		life_left[i] -= delta
		var t    : float = clamp(life_left[i] / life_max[i], 0.0, 1.0)
		var fade : float = t * extra_fade[i]
		if fade < 0.02:
			life_left[i] = 0.0
			mm.set_instance_color(i, Color(1,1,1,0))
		else:
			var col := _eval_colour(base_colour[i], fade)
			mm.set_instance_color(i, col)


func _eval_colour(base: Color, fade: float) -> Color:
	# replicate old: colour.lightened(pow(base_fade*fade, 2))
	var col := base.lightened(pow(BASE_FADE * fade, 2.0))
	col.a = fade
	return col

func _draw() -> void:
	var map: Global.Map = null

	if get_parent().get_parent().game_simulation_component != null:
		map = get_parent().get_parent().map

	# Only draw if we have a map (means we're in simulation phase)
	if map != null:
		draw_multimesh(mm, null)

# -------------------------------------------------------------------------
func _triangulate(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var out : Array[PackedVector2Array] = []
	for poly: PackedVector2Array in [polygon]:#Geometry2D.decompose_polygon_in_convex(polygon):
		var idx := Geometry2D.triangulate_polygon(poly)
		#if idx.size() == 0:
			#idx = Geometry2D.triangulate_polygon(Geometry2D.convex_hull(poly))
		for i in range(idx.size() / 3):
			var triangle: PackedVector2Array = PackedVector2Array([
				poly[idx[i*3]],
				poly[idx[i*3+1]],
				poly[idx[i*3+2]],
			])
			out.append(triangle)
	return out
