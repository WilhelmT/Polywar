extends Node2D
class_name TextOverlayLayer

# -------------------------------------------------------------------
#  Helper – number formatting with commas (1,234,567)
# -------------------------------------------------------------------
func _format_with_commas(value: int) -> String:
	var s := str(value)
	var parts: Array[String] = []
	while s.length() > 3:
		parts.insert(0, s.substr(s.length() - 3, 3))  # grab last 3 digits
		s = s.substr(0, s.length() - 3)                # drop them and repeat
	parts.insert(0, s)                                 # leading chunk (< 3 digits)
	return ",".join(parts)

# -------------------------------------------------------------------
#  Helper – signed area of the part of a polygon lying inside a hull
# -------------------------------------------------------------------
func _get_part_in_hull(
		area_polygon: PackedVector2Array,
		border_hull: PackedVector2Array
) -> float:
	var area_part_in_hull: float = 0.0
	for intersect: PackedVector2Array in Geometry2D.intersect_polygons(
			area_polygon,
			border_hull
	):
		var multiplier: float = 1.0
		if Geometry2D.is_polygon_clockwise(intersect):
			multiplier = -1.0
		area_part_in_hull += multiplier * GeometryUtils.calculate_polygon_area(intersect)
	return area_part_in_hull

func scale_polygon(polygon: PackedVector2Array, scale_factor: float) -> PackedVector2Array:
	# Validate input
	var vertex_count: int = polygon.size()
	if vertex_count == 0:
		push_error("scale_polygon(): Polygon is empty.")
		return []

	# ---------------------------------
	# 1. Calculate centroid
	# ---------------------------------
	var centroid: Vector2 = Vector2.ZERO
	for vertex: Vector2 in polygon:
		centroid.x += vertex.x
		centroid.y += vertex.y
	centroid.x /= float(vertex_count)
	centroid.y /= float(vertex_count)

	# ---------------------------------
	# 2–4. Translate → Scale → Translate back
	# ---------------------------------
	var result: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in polygon:
		# Translate to origin
		var translated: Vector2 = vertex - centroid
		# Apply scaling
		var scaled: Vector2 = translated * scale_factor
		# Translate back
		var final_vertex: Vector2 = scaled + centroid
		result.append(final_vertex)

	return result

# -------------------------------------------------------------------
#  Helper – curved dual‑number label between adjacent areas
# -------------------------------------------------------------------
func draw_label(
		border_hull: PackedVector2Array,
		key: PackedVector2Array,
		area_allocated_to_other_area: float,
		other_area_allocated_to_area: float,
		area: Area,
		other_area: Area,
		font: Font,
		min_font: int,
		world_boundary: PackedVector2Array
) -> void:
	var area_part_in_hull: float = _get_part_in_hull(area.polygon, border_hull)
	var other_area_part_in_hull: float = _get_part_in_hull(other_area.polygon, border_hull)
	var want_inside: bool = true#other_area_part_in_hull > area_part_in_hull
	
	var size_scale: float = 16.0
	# Calculate float font sizes for smooth scaling
	var font_size_float: float = get_parent().MIN_FONT_SIZE * pow(other_area_allocated_to_area * size_scale, 1/3.0)
	var font_size2_float: float = get_parent().MIN_FONT_SIZE * pow(area_allocated_to_other_area * size_scale, 1/3.0)
	var max_font_size: float = get_parent().MIN_FONT_SIZE * pow(size_scale, 1/3.0)
	var min_font_size: float = get_parent().MIN_FONT_SIZE / 2.0
	
	font_size_float = min(font_size_float, max_font_size)
	if other_area_allocated_to_area > 1:
		font_size_float += get_parent().MIN_FONT_SIZE * (other_area_allocated_to_area-1) * 0.5
	font_size_float = max(font_size_float, min_font_size)

	font_size2_float = min(font_size2_float, max_font_size)
	if area_allocated_to_other_area > 1:
		font_size2_float += get_parent().MIN_FONT_SIZE * (area_allocated_to_other_area-1) * 0.5
	font_size2_float = max(font_size2_float, min_font_size)
	
	# Use a large base font size and scale factor for smooth rendering (prevents pixelation)
	var base_font_size: int = 32  # Much larger base font size for better quality
	var font_scale: float = font_size_float / float(base_font_size)
	var font_scale2: float = font_size2_float / float(base_font_size)
	
	var raw_value: int = int(round(UnitLayer.MAX_UNITS * other_area_allocated_to_area * UnitLayer.NUMBER_PER_UNIT))
	var text: String = _format_with_commas(raw_value)

	
	#var world_boundary_reduced: PackedVector2Array = GeometryUtils.find_largest_polygon(
		#Geometry2D.offset_polygon(
			#world_boundary,
			#-3*max_font_size,
		#)
	#)
	#var clipped_border_hull: PackedVector2Array = GeometryUtils.find_largest_polygon(
		#Geometry2D.intersect_polygons(
			#border_hull,
			#world_boundary_reduced
		#)
	#)
	#if clipped_border_hull.size() != 0:
		#border_hull = clipped_border_hull
	#else:
		#border_hull = PackedVector2Array()
		#border_hull.append(
			#GeometryUtils.get_closest_point(
				#GeometryUtils.calculate_centroid(border_hull),
				#world_boundary_reduced
			#)
		#)
	
	var constant_spacing: float = 24.0

	var centroid: Vector2 = GeometryUtils.calculate_centroid(border_hull)
	#var borders_reduced: Array[PackedVector2Array] = [border_hull]
	var borders_reduced: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			border_hull,
			constant_spacing/2.0,
			Geometry2D.JOIN_ROUND,
	)
	#var border_hull_reduced: PackedVector2Array = PackedVector2Array()
	#for border_reduced: PackedVector2Array in borders_reduced:
		#border_hull_reduced.append_array(border_reduced)
	#border_hull_reduced = Geometry2D.convex_hull(border_hull_reduced)
	var border_hull_reduced: PackedVector2Array = GeometryUtils.find_largest_polygon(
		borders_reduced
	)
	#draw_polygon(border_hull_reduced, [Color.MAGENTA])
	
	var borders_increased: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			border_hull,
			constant_spacing+(font_size_float if not want_inside else font_size2_float),
			Geometry2D.JOIN_ROUND,
	)
	#var borders_increased: Array[PackedVector2Array] = [border_hull]
	#var border_hull_increased: PackedVector2Array = PackedVector2Array()
	#for border_increased: PackedVector2Array in borders_increased:
		#border_hull_increased.append_array(border_increased)
	#border_hull_increased = Geometry2D.convex_hull(border_hull_increased)
	var border_hull_increased: PackedVector2Array = GeometryUtils.find_largest_polygon(
		borders_increased
	)
	
	var reduced_valid: bool = border_hull_reduced.size() >= 3
	if reduced_valid == false:
		border_hull_reduced = border_hull_increased
		reduced_valid = true
	var hull_first: PackedVector2Array = border_hull_reduced if want_inside else border_hull_increased
	var hull_second: PackedVector2Array = border_hull_increased if want_inside else border_hull_reduced

	var curve: Curve2D = Curve2D.new()
	for p: Vector2 in hull_first:
		curve.add_point(p)
	if hull_first.size() > 0 and hull_first[0] != hull_first[-1]:
		curve.add_point(hull_first[0])

	var curve_len: float = curve.get_baked_length()
	if curve_len == 0.0:
		return

	var area_polygon_to_clamp: PackedVector2Array = area.polygon if want_inside else other_area.polygon
	var not_area_polygon_to_clamp: PackedVector2Array = other_area.polygon if want_inside else area.polygon
	var start_pos: Vector2 = GeometryUtils.clamp_point_to_polygon(hull_first, GeometryUtils.calculate_centroid(area_polygon_to_clamp), false)
	#var start_pos: Vector2 = (
		#GeometryUtils.clamp_point_to_polygon(hull_first, GeometryUtils.calculate_centroid(area.polygon))+
		#GeometryUtils.clamp_point_to_polygon(hull_first, GeometryUtils.calculate_centroid(other_area.polygon))
	#) / 2.0
	var text_px: float = text.length() * font_size_float
	var dir_val: float = -1.0 if want_inside else 1.0
	var centre_offset: float = fmod(curve.get_closest_offset(start_pos) - dir_val * text_px * 0.5 + curve_len, curve_len)

	var advance: float = 0.0
	for i: int in text.length():
		var glyph: String = text.substr(i, 1)
		advance += font_size_float * 0.5
		var dist: float = fmod(centre_offset + dir_val * advance + curve_len, curve_len)
		var xf: Transform2D = curve.sample_baked_with_rotation(dist)
		var local_pos: Vector2 = to_local(xf.origin)
		var angle: float = xf.get_rotation()
		if want_inside:
			angle += PI
		draw_set_transform(local_pos, angle, Vector2(font_scale, font_scale))
		var text_color: Color = other_area.color
		text_color = (text_color + 3.0 * Color.WHITE) / 4.0
		text_color.a = 1.0
		text_color.v = 0.95
		var outline_color: Color = Color.BLACK
		#outline_color.a = 0.75
		var highlight_color: Color = other_area.color
		highlight_color.a = 0.75
		var extra_outline_color: Color = Color.BLACK
		extra_outline_color.a = 0.75
		#draw_char_outline(font, Vector2.ZERO, glyph, base_font_size, 64, extra_outline_color)
		draw_char_outline(font, Vector2.ZERO, glyph, base_font_size, base_font_size*0.45+5.0, highlight_color)
		draw_char_outline(font, Vector2.ZERO, glyph, base_font_size, base_font_size*0.4+5.0, outline_color)
		draw_char(font, Vector2.ZERO, glyph, base_font_size, text_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		advance += font_size_float * 0.5

	if hull_second.size() >= 3:
		var raw_value2: int = int(round(UnitLayer.MAX_UNITS * area_allocated_to_other_area * UnitLayer.NUMBER_PER_UNIT))
		var text2: String = _format_with_commas(raw_value2)

		var curve2: Curve2D = Curve2D.new()
		for p2: Vector2 in hull_second:
			curve2.add_point(p2)
		if hull_second[0] != hull_second[-1]:
			curve2.add_point(hull_second[0])

		var curve_len2: float = curve2.get_baked_length()
		if curve_len2 > 0.0:
			var start_pos2: Vector2 = GeometryUtils.clamp_point_to_polygon(hull_second, GeometryUtils.calculate_centroid(area_polygon_to_clamp if reduced_valid else not_area_polygon_to_clamp), false)
			var text_px2: float = text2.length() * font_size2_float
			var dir2: float = 1.0 if want_inside or reduced_valid == false else -1.0
			var centre_offset2: float = fmod(curve2.get_closest_offset(start_pos2) - dir2 * text_px2 * 0.5 + curve_len2, curve_len2)

			var advance2: float = 0.0
			for j: int in text2.length():
				var glyph2: String = text2.substr(j, 1)
				advance2 += font_size2_float * 0.5
				var dist2: float = fmod(centre_offset2 + dir2 * advance2 + curve_len2, curve_len2)
				var xf2: Transform2D = curve2.sample_baked_with_rotation(dist2)
				var local_pos2: Vector2 = to_local(xf2.origin)
				var angle2: float = xf2.get_rotation()
				if want_inside == false and reduced_valid:
					angle2 += PI
				draw_set_transform(local_pos2, angle2, Vector2(font_scale2, font_scale2))
				var text_color2: Color = area.color
				text_color2 = (text_color2 + 3.0 * Color.WHITE) / 4.0
				text_color2.a = 1.0
				text_color2.v = 0.95
				var outline_color2: Color = Color.BLACK
				#outline_color2.a = 0.75
				var highlight_color: Color = area.color
				highlight_color.a = 0.75
				var extra_outline_color: Color = Color.BLACK
				extra_outline_color.a = 0.75
				#draw_char_outline(font, Vector2.ZERO, glyph2, base_font_size, 64, extra_outline_color)
				draw_char_outline(font, Vector2.ZERO, glyph2, base_font_size, base_font_size*0.45+5.0, highlight_color)
				draw_char_outline(font, Vector2.ZERO, glyph2, base_font_size, base_font_size*0.4+5.0, outline_color2)
				draw_char(font, Vector2.ZERO, glyph2, base_font_size, text_color2)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				advance2 += font_size2_float * 0.5

# -------------------------------------------------------------------
#  Main routine – compute & draw strength numbers along borders
# -------------------------------------------------------------------
func draw_player_strength_by_area_simulation(
		areas: Array[Area],
		map: Global.Map,
		big_intersecting_areas: Dictionary[Area, Dictionary],
		total_holding_circumference_by_other_area: Dictionary[Area, Dictionary],
		total_weighted_holding_circumference_by_other_area: Dictionary[Area, Dictionary],
		total_weighted_circumferences: Dictionary[Area, float],
		base_ownerships: Dictionary[Area, Array],
		big_intersecting_areas_circumferences: Dictionary[Area, Dictionary],
) -> void:
	
	var world_boundary: PackedVector2Array
	for area: Area in areas:
		if area.owner_id == -3:
			world_boundary = area.polygon.duplicate()
			world_boundary.reverse()
			break
	for area: Area in big_intersecting_areas_circumferences.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID:
			continue
		#if not total_weighted_circumferences.has(area):
			#continue
		var mean_area: float = area.get_strength(map, areas, total_weighted_circumferences, base_ownerships)
		for other_area: Area in big_intersecting_areas_circumferences[area].keys():
			if other_area.owner_id < 0:
				continue
			if other_area.owner_id == area.owner_id:
				continue
			#if not total_weighted_circumferences.has(other_area):
				#continue
			var mean_other_area: float = other_area.get_strength(map, areas, total_weighted_circumferences, base_ownerships)

			var total_common_circumference: float = (
					big_intersecting_areas_circumferences[area][other_area] +
					(total_holding_circumference_by_other_area[area][other_area])
				) / 2.0
			if total_common_circumference == 0.0:
				continue

			var bonus_from_holding: float = total_holding_circumference_by_other_area[area][other_area] - total_weighted_holding_circumference_by_other_area[area][other_area]
			var common_circumference_excluding_bonus_from_holding: float = (
					total_common_circumference - bonus_from_holding
			)

			var area_allocated_to_other_area: float = (
					mean_area * (total_common_circumference / total_weighted_circumferences[area])
			)

			var area_bonus_from_holding_allocated_to_other_area: float = (
					mean_area * (bonus_from_holding / total_weighted_circumferences[area])
			)

			var other_area_allocated_to_area: float = (
					mean_other_area * (total_common_circumference / total_weighted_circumferences[other_area])
			)
			var key: PackedVector2Array = PackedVector2Array()
			for seg: PackedVector2Array in big_intersecting_areas[area][other_area]:
				key.append_array(seg)
				#var hull_color: Color = Color.GREEN
				#hull_color.a = 0.3
				#draw_polygon(
					#GeometryUtils.find_largest_polygon(Geometry2D.offset_polygon(seg, 10)), [hull_color]
				#)
			var hull: PackedVector2Array = Geometry2D.convex_hull(key)
			

			draw_label(
					hull,
					key,
					area_allocated_to_other_area,
					other_area_allocated_to_area,
					area,
					other_area,
					get_parent().font,
					get_parent().MIN_FONT_SIZE,
					world_boundary,
			)

# -------------------------------------------------------------------
#  _draw – fetch data from the same parents PolygonLayer used and call main
# -------------------------------------------------------------------
func _draw() -> void:
	# Default initial values
	var simulation_areas: Array[Area] = []
	var map: Global.Map = null
	var big_intersecting_areas: Dictionary[Area, Dictionary] = {}
	var total_holding_circumference_by_other_area: Dictionary[Area, Dictionary] = {}
	var total_weighted_holding_circumference_by_other_area: Dictionary[Area, Dictionary] = {}
	var total_weighted_circumferences: Dictionary[Area, float] = {}
	var base_ownerships: Dictionary[Area, Array] = {}
	var big_intersecting_areas_circumferences: Dictionary[Area, Dictionary] = {}

	if get_parent().get_parent().game_simulation_component != null:
		simulation_areas = get_parent().get_parent().game_simulation_component.areas
		map = get_parent().get_parent().map
		big_intersecting_areas = get_parent().get_parent().game_simulation_component.big_intersecting_areas
		total_holding_circumference_by_other_area = get_parent().get_parent().game_simulation_component.total_holding_circumference_by_other_area
		total_weighted_holding_circumference_by_other_area = get_parent().get_parent().game_simulation_component.total_weighted_holding_circumference_by_other_area
		total_weighted_circumferences = get_parent().get_parent().game_simulation_component.total_weighted_circumferences
		base_ownerships =  get_parent().get_parent().game_simulation_component.base_ownerships
		big_intersecting_areas_circumferences = get_parent().get_parent().game_simulation_component.big_intersecting_areas_circumferences
	
	# Only draw if we have a map (means we're in simulation phase)
	if map != null:
		draw_player_strength_by_area_simulation(
			simulation_areas,
			map,
			big_intersecting_areas,
			total_holding_circumference_by_other_area,
			total_weighted_holding_circumference_by_other_area,
			total_weighted_circumferences,
			base_ownerships,
			big_intersecting_areas_circumferences,
		)
