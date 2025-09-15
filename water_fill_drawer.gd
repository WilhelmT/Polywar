extends Node2D
class_name WaterFillDrawer

var areas: Array[Area] = []
var map: Global.Map = null

# Shadow rendering via MultiMesh (performance)
var _shadow_multimesh: MultiMesh = null
var _unit_triangle_mesh: ArrayMesh = null
var _shadow_tri_count: int = 0

func setup(p_areas: Array[Area], p_map: Global.Map) -> void:
	areas = p_areas
	map = p_map
	queue_redraw()

func _draw() -> void:
	if areas.is_empty():
		return
	for obstacle: Area in areas:
		if obstacle.owner_id == -2:
			if obstacle.polygon.size() >= 3:
				for increased_obstacle_polygon: PackedVector2Array in Geometry2D.offset_polygon(
					obstacle.polygon,
					StaticBackgroundDrawer.ROCK_MIN_RADIUS+1,
					Geometry2D.JOIN_ROUND
				):
					if Geometry2D.is_polygon_clockwise(increased_obstacle_polygon):
						continue
					_draw_lake_fill(increased_obstacle_polygon)

	var draw_component: DrawComponent = get_parent().get_parent()
	var bg_drawer: StaticBackgroundDrawer = draw_component.background_drawer_2
	var shadow_polys: Array[PackedVector2Array] = bg_drawer.get_tree_shadow_polygons()
	var water_shadow_col: Color = Color.BLACK
	water_shadow_col.a = StaticBackgroundDrawer.TREE_SHADOW_DARKEN
	_ensure_shadow_multimesh()
	_rebuild_shadow_multimesh(shadow_polys, water_shadow_col)
	if _shadow_multimesh != null and _shadow_multimesh.instance_count > 0:
		draw_multimesh(_shadow_multimesh, null)

	#for original_obstacle: Area in map.original_unmerged_obstacles:
		#if original_obstacle.owner_id == -2:
			#if original_obstacle.polygon.size() >= 3:
				#var water_base: Color = StaticBackgroundDrawer.WATER_BASE
				#water_base.a = 0.025
				#var polyline: PackedVector2Array = original_obstacle.polygon.duplicate()
				#polyline.append(polyline[0])
				#draw_polyline(polyline, water_base, DrawComponent.AREA_OUTLINE_THICKNESS, true)

func _draw_lake_fill(polygon: PackedVector2Array) -> void:
	# Use same water base color as rivers
	var water_base: Color = StaticBackgroundDrawer.WATER_BASE
	#water_base = water_base.darkened(0.0625)
	#print(water_base)
	water_base.a = 1.0
	# Base lake fill
	draw_colored_polygon(polygon, water_base)
	# Inset darker layers toward center
	const LAKE_LAYER_COUNT: int = 1000
	const LAYER_OFFSET_STEP: float = 1.0
	const DARKEN_MIN: float = 0.75
	for layer: int in range(LAKE_LAYER_COUNT):
		var found_valid_inset: bool = false
		var offset: float = -(float(layer + 1) * LAYER_OFFSET_STEP)
		var darken_amount: float = 0.0 + (float(layer) * 0.0035)
		darken_amount = sqrt(darken_amount)
		darken_amount = min(darken_amount, DARKEN_MIN)
		var layer_color: Color = water_base.darkened(darken_amount)
		layer_color.a = 1.0
		var inset_polys: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			polygon, offset, Geometry2D.JOIN_ROUND
		)
		for inset_poly: PackedVector2Array in inset_polys:
			if inset_poly.size() >= 3:
				draw_colored_polygon(inset_poly, layer_color)
				found_valid_inset = true
		if not found_valid_inset:
			break
	

func _ensure_shadow_multimesh() -> void:
	if _unit_triangle_mesh == null:
		_unit_triangle_mesh = ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var verts: PackedVector3Array = PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
		])
		var cols: PackedColorArray = PackedColorArray([
			Color.WHITE, Color.WHITE, Color.WHITE
		])
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		_unit_triangle_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _shadow_multimesh == null:
		_shadow_multimesh = MultiMesh.new()
		_shadow_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_shadow_multimesh.use_colors = true
		_shadow_multimesh.mesh = _unit_triangle_mesh


func _rebuild_shadow_multimesh(
	shadow_polys: Array[PackedVector2Array],
	shadow_color: Color
) -> void:
	# Count triangles
	var total_tris: int = 0
	for poly: PackedVector2Array in shadow_polys:
		if poly.size() >= 3:
			var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
			total_tris += int(idx.size() / 3)
	_shadow_multimesh.instance_count = total_tris
	_shadow_tri_count = total_tris
	if total_tris == 0:
		return
	# Fill instances
	var instance_i: int = 0
	for poly2: PackedVector2Array in shadow_polys:
		if poly2.size() < 3:
			continue
		var idx2: PackedInt32Array = Geometry2D.triangulate_polygon(poly2)
		var k: int = 0
		while k < idx2.size():
			var a_i: int = idx2[k]
			var b_i: int = idx2[k + 1]
			var c_i: int = idx2[k + 2]
			var p0: Vector2 = poly2[a_i]
			var p1: Vector2 = poly2[b_i]
			var p2: Vector2 = poly2[c_i]
			# Map unit triangle (0,0)-(1,0)-(0,1) to (p0,p1,p2)
			var t: Transform2D = Transform2D()
			var col_x: Vector2 = p1 - p0
			var col_y: Vector2 = p2 - p0
			t.x = col_x
			t.y = col_y
			t.origin = p0
			_shadow_multimesh.set_instance_transform_2d(instance_i, t)
			_shadow_multimesh.set_instance_color(instance_i, shadow_color)
			instance_i += 1
			k += 3
