extends Control
class_name StaticObstacleDrawer

var areas: Array[Area] = []
var map_generator: MapGenerator
var map: Global.Map = null

# MultiMesh for canopy-over-rock shadows
var _rock_shadow_multimesh: MultiMesh = null
var _unit_triangle_mesh: ArrayMesh = null

func setup(p_areas: Array[Area], p_map_generator: MapGenerator, p_map: Global.Map) -> void:
	areas = p_areas
	map_generator = p_map_generator
	map = p_map
	queue_redraw()

func _draw() -> void:
	if areas.is_empty():
		return
	
	_draw_obstacle_rocks()
	_draw_mountain_shadows()
	_draw_canopy_shadows_over_rocks()
	

func _draw_mountain_shadows() -> void:
	var col: Color = Global.get_color_for_terrain("mountains") * StaticBackgroundDrawer.MTN_SHADOW_DARKEN
	col.a = StaticBackgroundDrawer.MTN_SHADOW_DARKEN					# tweak opacity as you like
	
	for original_area: Area in map.original_walkable_areas:
		if map.terrain_map[original_area.polygon_id] != "mountains":
			continue
		
		var shadow_poly: PackedVector2Array = GeometryUtils.translate_polygon(
			original_area.polygon,
			StaticBackgroundDrawer.MTN_SHADOW_OFFSET
		)

		# Fill swept band between original and translated polygons, then clip to lakes
		var band_quads: Array[PackedVector2Array] = StaticBackgroundDrawer.build_between_band_quads(
			original_area.polygon,
			shadow_poly
		)
		for q: PackedVector2Array in band_quads:
			if not Geometry2D.is_polygon_clockwise(q):
				continue
			for obstacle: Area in areas:
				if obstacle.owner_id == -2:
					for clipped_q: PackedVector2Array in Geometry2D.intersect_polygons(q, obstacle.polygon):
						if Geometry2D.is_polygon_clockwise(clipped_q):
							continue
						draw_colored_polygon(clipped_q, col)

# ---------- simplified T-junction helpers (lake openings) ----------
func _seg_intersection_point(
		a1: Vector2, a2: Vector2,
		b1: Vector2, b2: Vector2
	) -> Vector2:
		var den: float = (a2.x - a1.x) * (b2.y - b1.y) - (a2.y - a1.y) * (b2.x - b1.x)
		if den == 0.0:
			return Vector2.ZERO
		var t: float = ((b1.x - a1.x) * (b2.y - b1.y) - (b1.y - a1.y) * (b2.x - b1.x)) / den
		var u: float = ((b1.x - a1.x) * (a2.y - a1.y) - (b1.y - a1.y) * (a2.x - a1.x)) / den
		if t < 0.0:
			return Vector2.ZERO
		else:
			if t > 1.0:
				return Vector2.ZERO
			else:
				if u < 0.0:
					return Vector2.ZERO
				else:
					if u > 1.0:
						return Vector2.ZERO
		return a1 + (a2 - a1) * t

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
	var dir_vec: Vector2 = endpoint - adjacent
	if dir_vec.length() <= 0.0:
		res["p1"] = endpoint
		res["p2"] = endpoint
		res["endpoint"] = endpoint
		res["adjacent"] = adjacent
		res["endpoint_is_end"] = info["endpoint_is_end"]
		return res
	var dir_n: Vector2 = dir_vec.normalized()
	res["p1"] = endpoint - dir_n * extend_len
	res["p2"] = endpoint + dir_n * extend_len
	res["endpoint"] = endpoint
	res["adjacent"] = adjacent
	res["endpoint_is_end"] = info["endpoint_is_end"]
	return res

func _line_polygon_intersections(p1: Vector2, p2: Vector2, polygon: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if polygon.size() < 2:
		return out
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2
		if i < polygon.size() - 1:
			b = polygon[i + 1]
		else:
			b = polygon[0]
		var ip: Vector2 = _seg_intersection_point(p1, p2, a, b)
		if ip != Vector2.ZERO:
			var seg_len: float = a.distance_to(b)
			var t: float = 0.0
			var proj_local: float = 0.0
			if seg_len > 0.0:
				proj_local = (ip - a).dot(b - a) / (seg_len * seg_len)
				if proj_local < 0.0:
					proj_local = 0.0
				else:
					if proj_local > 1.0:
						proj_local = 1.0
				t = proj_local
			var rec: Dictionary = {}
			rec["point"] = ip
			rec["edge_index"] = i
			rec["t"] = t
			out.append(rec)
	return out

func _map_point_to_polygon_param(polygon: PackedVector2Array, pt: Vector2) -> Dictionary:
	var best_edge: int = 0
	var best_t: float = 0.0
	var best_d2: float = INF
	if polygon.size() < 2:
		var out_single: Dictionary = {}
		out_single["edge_index"] = 0
		out_single["t"] = 0.0
		return out_single
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2
		if i < polygon.size() - 1:
			b = polygon[i + 1]
		else:
			b = polygon[0]
		var ab: Vector2 = b - a
		var ab_len2: float = ab.length_squared()
		var t_raw: float = 0.0
		if ab_len2 > 0.0:
			t_raw = (pt - a).dot(ab) / ab_len2
			if t_raw < 0.0:
				t_raw = 0.0
			else:
				if t_raw > 1.0:
					t_raw = 1.0
		var proj: Vector2 = a.lerp(b, t_raw)
		var d2: float = proj.distance_squared_to(pt)
		if d2 < best_d2:
			best_d2 = d2
			best_edge = i
			best_t = t_raw
	var out_map: Dictionary = {}
	out_map["edge_index"] = best_edge
	out_map["t"] = best_t
	return out_map

# Get river edge ranges for this specific lake using stored data
func _get_river_edge_ranges_for_lake(lake_polygon: PackedVector2Array) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	
	if map == null:
		return ranges
	
	# Use reduced shoreline (same as rock placement) to find intersections,
	# but map back to original polygon param for consistent edge indexing
	var reduced_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
		Geometry2D.offset_polygon(
			lake_polygon,
			-StaticBackgroundDrawer.ROCK_MIN_RADIUS+1,
			Geometry2D.JOIN_ROUND,
		)
	)
	
	var extend_len: float = MapGenerator.BANK_OFFSET * 4.0
	
	for river_index: int in range(map.river_end_obstacles.size()):
		var end_info: Dictionary = map.river_end_obstacles[river_index]
		var obstacle: PackedVector2Array = end_info["obstacle"]
		
		# Check if this river ends at our specific lake
		if obstacle == lake_polygon:
			# Determine p0 from river centerline endpoints
			var river: PackedVector2Array = map.rivers[river_index]
			if river.size() < 2:
				continue
			var p_a: Vector2 = river[0]
			var p_b: Vector2 = river[river.size() - 1]
			var p0: Vector2 = p_b
			if Geometry2D.is_point_in_polygon(p_a, lake_polygon):
				p0 = p_a
			else:
				if Geometry2D.is_point_in_polygon(p_b, lake_polygon):
					p0 = p_b
				else:
					var cp_a: Vector2 = GeometryUtils.clamp_point_to_polygon(lake_polygon, p_a, false)
					var cp_b: Vector2 = GeometryUtils.clamp_point_to_polygon(lake_polygon, p_b, false)
					var d_a: float = cp_a.distance_to(p_a)
					var d_b: float = cp_b.distance_to(p_b)
					if d_a <= d_b:
						p0 = p_a
					else:
						p0 = p_b
			# Build terminal lines for hitting banks
			if river_index < 0 or river_index >= map.river_banks.size():
				continue
			var banks: Dictionary = map.river_banks[river_index]
			if not (banks.has("left") and banks.has("right")):
				continue
			var hit_left: PackedVector2Array = banks["left"]
			var hit_right: PackedVector2Array = banks["right"]
			var line_left: Dictionary = _build_terminal_line_for_bank(hit_left, p0, extend_len)
			var line_right: Dictionary = _build_terminal_line_for_bank(hit_right, p0, extend_len)
			# Intersect both lines with reduced shoreline
			var ints_l: Array[Dictionary] = _line_polygon_intersections(line_left["p1"], line_left["p2"], reduced_polygon)
			var ints_r: Array[Dictionary] = _line_polygon_intersections(line_right["p1"], line_right["p2"], reduced_polygon)
			if ints_l.size() <= 0 or ints_r.size() <= 0:
				continue
			# pick closest intersection to p0 for each side
			var best_l: Dictionary = {}
			var best_r: Dictionary = {}
			var best_dl: float = INF
			var best_dr: float = INF
			for rec_l: Dictionary in ints_l:
				var pt_l: Vector2 = rec_l["point"]
				var dl: float = pt_l.distance_to(p0)
				if dl < best_dl:
					best_dl = dl
					best_l = rec_l
				else:
					best_dl = best_dl
			for rec_r: Dictionary in ints_r:
				var pt_r: Vector2 = rec_r["point"]
				var dr: float = pt_r.distance_to(p0)
				if dr < best_dr:
					best_dr = dr
					best_r = rec_r
				else:
					best_dr = best_dr
			if not (best_l.has("edge_index") and best_r.has("edge_index")):
				continue
			# Map intersection points back to original shoreline param (edge,t)
			var mapped_l: Dictionary = _map_point_to_polygon_param(lake_polygon, best_l["point"])
			var mapped_r: Dictionary = _map_point_to_polygon_param(lake_polygon, best_r["point"])
			# Order along perimeter for left/right edges using original polygon indices
			var edge_l: int = mapped_l["edge_index"]
			var t_l: float = mapped_l["t"]
			var edge_r: int = mapped_r["edge_index"]
			var t_r: float = mapped_r["t"]
			var pos_l: float = float(edge_l) + t_l
			var pos_r: float = float(edge_r) + t_r
			var left_edge: int = edge_l
			var left_t: float = t_l
			var right_edge: int = edge_r
			var right_t: float = t_r
			# Choose shorter arc around the perimeter between the two points
			var n_edges: int = lake_polygon.size()
			var total_perimeter_param: float = float(n_edges)
			var delta: float = pos_r - pos_l
			if delta < 0.0:
				delta = -delta
			# ensure pos_l <= pos_r for comparison below
			if pos_r < pos_l:
				left_edge = edge_r
				left_t = t_r
				right_edge = edge_l
				right_t = t_l
				var tmp_pl: float = pos_l
				pos_l = pos_r
				pos_r = tmp_pl
			# Recompute delta after potential swap
			delta = pos_r - pos_l
			if delta < 0.0:
				delta = -delta
			var wrap_delta: float = total_perimeter_param - delta
			# If wrapped arc is shorter, flip left/right to take the shorter path
			if wrap_delta < delta:
				var le_tmp: int = left_edge
				var lt_tmp: float = left_t
				left_edge = right_edge
				left_t = right_t
				right_edge = le_tmp
				right_t = lt_tmp
			ranges.append({
				"left_edge": left_edge,
				"left_t": left_t,
				"right_edge": right_edge,
				"right_t": right_t
			})
	
	return ranges

# Check if current segment position is within any river opening range
func _is_shore_position_in_river_opening(
	current_segment: int,
	segment_progress: float,
	river_ranges: Array[Dictionary]
) -> bool:
	# If no rivers connect to this lake, place rocks everywhere
	if river_ranges.size() == 0:
		return false  # NOT in opening, so place rock
	
	# Check ALL river ranges - don't exit early
	for range_info: Dictionary in river_ranges:
		var left_edge: int = range_info["left_edge"]
		var left_t: float = range_info["left_t"]
		var right_edge: int = range_info["right_edge"]
		var right_t: float = range_info["right_t"]
		
		# If position is in ANY river opening, skip the rock
		if not _is_segment_position_out_of_range(current_segment, segment_progress, left_edge, left_t, right_edge, right_t):
			return true  # IS in opening, so skip rock
	
	# Position is not in any river opening, so place rock
	return false

func _is_segment_position_out_of_range(
	seg: int, 
	t: float, 
	left_edge: int, 
	left_t: float, 
	right_edge: int, 
	right_t: float
) -> bool:
	# Convert to a single parameter along the polygon perimeter for easy comparison
	var pos: float = float(seg) + t
	var left_pos: float = float(left_edge) + left_t  
	var right_pos: float = float(right_edge) + right_t
	
	# Handle wraparound case
	if left_pos > right_pos:
		return not (pos >= left_pos or pos <= right_pos)
	else:
		return not (pos >= left_pos and pos <= right_pos)

# Updated _draw_lake_shore_rocks method using stored edge information
func _draw_lake_shore_rocks(polygon: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var rock_spacing: float = StaticBackgroundDrawer.ROCK_SPACING
	var rock_offset: float = 0.0  # Distance from shore

	# Fetch canopy shadow polygons generated in StaticBackgroundDrawer (no clipping)
	var draw_component: DrawComponent = get_parent().get_parent()
	var canopy_shadow_polys: Array[PackedVector2Array] = []
	var bg_drawer_2: StaticBackgroundDrawer = draw_component.background_drawer_2
	canopy_shadow_polys = bg_drawer_2.get_tree_shadow_polygons()

	# Get river edge ranges for this lake using stored data
	var reduced_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
		Geometry2D.offset_polygon(
			polygon,
			-StaticBackgroundDrawer.ROCK_MIN_RADIUS+1,
			Geometry2D.JOIN_ROUND,
		)
	)
	#var reduced_polygon: PackedVector2Array = polygon
	var river_ranges: Array[Dictionary] = _get_river_edge_ranges_for_lake(polygon)
	
	# Calculate total perimeter
	var total_perimeter: float = 0.0
	for i: int in range(polygon.size()):
		var next_i: int = (i + 1) % polygon.size()
		total_perimeter += polygon[i].distance_to(polygon[next_i])
	
	var rock_count: int = int(total_perimeter / rock_spacing)
	var actual_spacing: float = total_perimeter / float(rock_count)
	
	# Place rocks along perimeter
	var distance_along: float = 0.0
	var current_segment: int = 0
	var segment_length: float = polygon[0].distance_to(polygon[1])
	
	for r: int in range(rock_count):
		var target_distance: float = float(r) * actual_spacing
		
		# Find which segment we're on
		while distance_along + segment_length < target_distance and current_segment < polygon.size() - 1:
			distance_along += segment_length
			current_segment += 1
			if current_segment < polygon.size() - 1:
				segment_length = polygon[current_segment].distance_to(polygon[current_segment + 1])
			else:
				segment_length = polygon[current_segment].distance_to(polygon[0])
		
		# Calculate position along current segment
		var segment_progress: float = (target_distance - distance_along) / segment_length
		
		# Skip if this position is in a river opening
		if _is_shore_position_in_river_opening(current_segment, segment_progress, river_ranges):
			continue
			
		var seg_start: Vector2 = polygon[current_segment]
		var seg_end: Vector2
		if current_segment < polygon.size() - 1:
			seg_end = polygon[current_segment + 1]
		else:
			seg_end = polygon[0]
		
		var shore_pos: Vector2 = seg_start.lerp(seg_end, segment_progress)
		
		# Calculate inward normal for rock placement
		var tangent: Vector2 = (seg_end - seg_start).normalized()
		var inward_normal: Vector2 = Vector2(tangent.y, -tangent.x)  # 90° rotation inward
		
		# Check if normal points inward by testing with polygon centroid
		var centroid: Vector2 = GeometryUtils.calculate_centroid(polygon)
		if inward_normal.dot(centroid - shore_pos) < 0.0:
			inward_normal = -inward_normal
		
		var rock_pos: Vector2 = shore_pos + inward_normal * rock_offset
		rock_pos = GeometryUtils.clamp_point_to_polygon(
			reduced_polygon,
			rock_pos,
			false,
		)
		
		# Use exact same rock generation as StaticBackgroundDrawer
		var rock_polygon: PackedVector2Array = StaticBackgroundDrawer.generate_rock_polygon(rock_pos, tangent, rng)
		
		var rock_polygon_intersected: PackedVector2Array = GeometryUtils.find_largest_polygon(
			Geometry2D.intersect_polygons(
				rock_polygon,
				polygon
			)
		)
		var rock_facets: Array[Dictionary] = StaticBackgroundDrawer.generate_rock_facets(rock_polygon_intersected, rng)
		
		# Draw rock shadow using same method
		var shadow_poly: PackedVector2Array = GeometryUtils.translate_polygon(rock_polygon_intersected, StaticBackgroundDrawer.ROCK_SHADOW_OFFSET)
		var shadow_color: Color = StaticBackgroundDrawer.ROCK_BASE_COLOR * StaticBackgroundDrawer.ROCK_SHADOW_DARKEN
		shadow_color.a = 0.2
		draw_colored_polygon(shadow_poly, shadow_color)
		
		# Draw rock facets
		for facet: Dictionary in rock_facets:
			draw_colored_polygon(facet["poly"] as PackedVector2Array, facet["col"] as Color)

func _ensure_rock_shadow_multimesh() -> void:
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
	if _rock_shadow_multimesh == null:
		_rock_shadow_multimesh = MultiMesh.new()
		_rock_shadow_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_rock_shadow_multimesh.use_colors = true
		_rock_shadow_multimesh.mesh = _unit_triangle_mesh

func _draw_canopy_shadows_over_rocks() -> void:
	# Build transforms for overlaps between canopy shadows and each lake rock polygon, then draw as MultiMesh
	var draw_component: DrawComponent = get_parent().get_parent()
	if draw_component == null:
		return
	var bg_drawer_2: StaticBackgroundDrawer = draw_component.background_drawer_2
	if bg_drawer_2 == null:
		return
	var canopy_shadow_polys: Array[PackedVector2Array] = bg_drawer_2.get_tree_shadow_polygons()
	if canopy_shadow_polys.size() == 0:
		return
	_ensure_rock_shadow_multimesh()
	var transforms: Array[Transform2D] = []
	for obstacle in areas:
		if obstacle.owner_id == -2:
			var lake: PackedVector2Array = obstacle.polygon
			if lake.size() < 3:
				continue
			for sp: PackedVector2Array in canopy_shadow_polys:
				if sp.size() < 3:
					continue
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(lake, sp):
					if overlap.size() >= 3:
						var tris: Array[Transform2D] = GeometryUtils.triangulate_polygons_to_triangle_transforms([overlap])
						for t: Transform2D in tris:
							transforms.append(t)
	_rock_shadow_multimesh.instance_count = transforms.size()
	var shadow_col: Color = Color.BLACK
	shadow_col.a = StaticBackgroundDrawer.TREE_SHADOW_DARKEN
	var i: int = 0
	while i < transforms.size():
		_rock_shadow_multimesh.set_instance_transform_2d(i, transforms[i])
		_rock_shadow_multimesh.set_instance_color(i, shadow_col)
		i += 1
	if _rock_shadow_multimesh.instance_count > 0:
		draw_multimesh(_rock_shadow_multimesh, null)

func _draw_obstacle_rocks() -> void:
	for obstacle in areas:
		if obstacle.owner_id == -2:
			if obstacle.polygon.size() == 0:
				continue
			_draw_lake_shore_rocks(obstacle.polygon, RandomNumberGenerator.new())
