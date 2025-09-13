extends Node2D
class_name PolygonLayer3

func _draw_player_polyline_expansions_extra(
	clicked_original_walkable_areas: Dictionary[int, bool],
	newly_expanded_polylines: Dictionary[Area, Dictionary],
	newly_retracting_polylines: Dictionary[Area, Dictionary],
) -> void:
	for area: Area in newly_retracting_polylines.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID:
			continue
		# Draw retracting polylines
		for original_area in newly_retracting_polylines[area]:
			for poly in newly_retracting_polylines[area][original_area]:
				_draw_polyline_segments_extra(poly, area, original_area, clicked_original_walkable_areas, true)

	for area: Area in newly_expanded_polylines.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID:
			continue
		# Draw expanded polylines
		for original_area in newly_expanded_polylines[area]:
			for poly in newly_expanded_polylines[area][original_area]:
				_draw_polyline_segments_extra(poly, area, original_area, clicked_original_walkable_areas, false)

func _draw_polyline_segments_extra(
	poly: Array,
	area: Area,
	original_area: Area,
	clicked_original_walkable_areas: Dictionary[int, bool],
	representing_enemy_expansion: bool
) -> void:
	var base_color: Color
	if representing_enemy_expansion:
		base_color = Color.RED
	else:
		base_color = area.color
		

	var fade: float = 1.0
	if area.owner_id != GameSimulationComponent.PLAYER_ID:
		fade = 0.5

	var base_fade: float = 0.75
	var c: Color = base_color.lightened(pow(base_fade*fade, 2.0))
	c.a = 1.0
	c.v = 0.8#0.75

	
	if poly.size() > 1:
		const DASH_SPACING: float = DrawComponent.AREA_ADDON_THICKNESS * 0.6
		
		for i in range(poly.size()-1):
			var start_point: Vector2 = poly[i]
			var end_point: Vector2 = poly[i+1]
			var segment_vector: Vector2 = end_point - start_point
			var segment_length: float = segment_vector.length()
			
			if segment_length <= 0.01:
				continue
				
			var direction: Vector2 = segment_vector / segment_length
			var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
			
			# Calculate number of dashes that would fit on this segment
			var num_dashes: int = round(segment_length / DASH_SPACING)

			# If the segment can fit more dashes, space them evenly
			if num_dashes > 0:
				# Calculate spacing based on the number of dashes
				var spacing: float = segment_length / (num_dashes + 1)
				
				for j in range(1, num_dashes + 1):
					var dash_point: Vector2 = start_point + direction * (j * spacing)
					_draw_dash(dash_point, perpendicular, c)

# Helper to draw a single dash (orthogonal line)
func _draw_dash(point: Vector2, perpendicular: Vector2, color: Color) -> void:
	var dash_length: float = DrawComponent.AREA_ADDON_THICKNESS * 0.1
	var dash_start: Vector2 = point + perpendicular * 4.0*dash_length
	var dash_end: Vector2 = point + perpendicular * 2.0*dash_length
	#var dash_start: Vector2 = point + perpendicular * 7*dash_length
	#var dash_end: Vector2 = point + perpendicular * 4.0*dash_length

	#color.a = 0.5
	draw_line(dash_start, dash_end, color, DrawComponent.AREA_ADDON_THICKNESS*0.075, true)

	#color.a = 1.0
	#draw_line(dash_start, dash_end, color, DrawComponent.AREA_ADDON_THICKNESS*0.05, true)


func draw_trench_pattern(
	start: Vector2, 
	dir: Vector2, 
	perp: Vector2, 
	length: float, 
	amp: float, 
	width: float, 
	color: Color, 
	is_first: bool,
	scale_factor: float,
	is_river: bool
) -> void:
	
	if is_river:
		var bank_sep   := amp/2.0                     # centre → each bank
		var bank_w     := width * 0.75                     # bank stroke thickness
		var tie_w      := width * 0.75                # cross-bar thickness
		var tie_step   := length * 0.5 * scale_factor  # one tie mid-segment

		

		# single cross-tie (add more with a while-loop if you like)
		# banks (parallel lines)
		var left_a  := start +  2 * perp * bank_sep
		var left_b  := left_a + dir * length 
		var right_a := start
		var right_b := right_a + dir * length
		var tie_centre := start + dir * (length * 0.5 * scale_factor)


		draw_line(left_a,  left_b,  color, bank_w,  true)   # left bank
		draw_line(right_a, right_b, color, bank_w,  true)   # right bank
		draw_line(tie_centre,
				  tie_centre + 2 * perp * bank_sep,
				  color,
				  tie_w,
				  true)
	
		var circle_color: Color = color
		circle_color.a = 1
		#draw_circle(tie_centre, 5, circle_color)
		#draw_circle(tie_centre + 2 * perp * bank_sep, 5, circle_color)

		return
		
	# Scale the pattern proportionally for partial segments
	var half_length: float = length * 0.5 * scale_factor
	
	# Out perpendicular
	var p1: Vector2 = start + perp * amp
	
	# Forward half-spacing
	var p2: Vector2 = p1 + dir * half_length
	
	# Back to centerline
	var p3: Vector2 = p2 - perp * amp
	
	# Forward to end
	var p4: Vector2 = start + dir * length
		
	# Draw the pattern (same regardless of direction)
	draw_line(start, p1, color, width)
	draw_line(p1 - dir * width * 0.5, p2 + dir * width * 0.5, color, width)
	draw_line(p2, p3, color, width)
	draw_line(p3 - dir * width * 0.5, p4 + dir * width * 0.5, color, width)
	
	# Draw circle at start if this is the first pattern
	#if is_first:
		#draw_circle(start, 10, color)


# Update: Only draw trench segments near the holding poly
func _draw_stationary_trench_curve(
	curve: Curve2D,
	arc_start: float,
	arc_end: float,
	color: Color,
	is_river: bool,
	spacing: float,
	amp: float,
	width: float
) -> void:
	var perimeter: float = curve.get_baked_length()
	arc_start = fmod(arc_start + perimeter, perimeter)
	arc_end = fmod(arc_end + perimeter, perimeter)
	if arc_end < arc_start:
		arc_end += perimeter
	if arc_end - arc_start == 0.0:
		return
	# Find the first full tooth start after arc_start, aligned to the reference point
	var first_tooth_start: float = arc_start + (spacing - fmod(arc_start, spacing))
	if fmod(arc_start, spacing) == 0.0:
		first_tooth_start = arc_start
	# Draw partial tooth at the start if needed
	if first_tooth_start > arc_start:
		var seg_start: float = arc_start
		var seg_end: float = min(first_tooth_start, arc_end)
		if seg_end - seg_start > 0.0:
			var start_pt: Vector2 = curve.sample_baked(seg_start)
			var end_pt: Vector2 = curve.sample_baked(seg_end)
			var dir: Vector2 = (end_pt - start_pt).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var seg_len: float = (end_pt - start_pt).length()
			if seg_len > 0.0 and seg_len < perimeter and start_pt != end_pt:
				self.draw_trench_pattern(start_pt, dir, perp, seg_len, amp, width, color, true, seg_len / spacing, is_river)
	var pos: float = first_tooth_start
	# Draw all full teeth
	while pos + spacing <= arc_end:
		var seg_start: float = pos
		var seg_end: float = pos + spacing
		if seg_end - seg_start > 0.0:
			var start_pt: Vector2 = curve.sample_baked(seg_start)
			var end_pt: Vector2 = curve.sample_baked(seg_end)
			var dir: Vector2 = (end_pt - start_pt).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var seg_len: float = (end_pt - start_pt).length()
			if seg_len > 0.0 and seg_len < perimeter and start_pt != end_pt:
				self.draw_trench_pattern(start_pt, dir, perp, seg_len, amp, width, color, false, seg_len / spacing, is_river)
		pos += spacing
	# Draw last partial tooth (always grows forward from last full tooth to arc_end)
	if pos < arc_end:
		var seg_start: float = pos
		var seg_end: float = arc_end
		if seg_end - seg_start > 0.0:
			var start_pt: Vector2 = curve.sample_baked(seg_start)
			var end_pt: Vector2 = curve.sample_baked(seg_end)
			var dir: Vector2 = (end_pt - start_pt).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var seg_len: float = (end_pt - start_pt).length()
			if seg_len > 0.0 and seg_len < perimeter and start_pt != end_pt:
				self.draw_trench_pattern(start_pt, dir, perp, seg_len, amp, width, color, false, seg_len / spacing, is_river)

func _draw_player_polyline_holdings(
	map: Global.Map,
	clicked_original_walkable_areas: Dictionary[int, bool],
	newly_holding_polylines: Dictionary[Area, Dictionary],
	newly_expanded_polylines: Dictionary[Area, Dictionary]
) -> void:
	const SPACING: float = DrawComponent.AREA_ADDON_THICKNESS * 3.0 / 1.5
	const AMP: float = SPACING * 0.25
	var width: float = DrawComponent.AREA_ADDON_THICKNESS * 0.15


		
	for area: Area in newly_holding_polylines.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID:
			continue
		for original_area: Area in newly_holding_polylines[area].keys():
			for entry: Dictionary in newly_holding_polylines[area][original_area]:
				var poly: PackedVector2Array = entry["pl"]
				assert(poly.size() == 2)
				var weight: float = entry["weight"]
				var is_river: bool = entry["weight"] < 0.5
				var fade: float = 1.0
				var base_fade: float = 0.75
				var c: Color = area.color.lightened(pow(base_fade * fade, 2.0))
				c.a = 1.0
				c.v = 0.8#0.75
				
				var curve: Curve2D = Curve2D.new()
				for pt: Vector2 in original_area.polygon:
					curve.add_point(pt)
				curve.add_point(original_area.polygon[0])
				curve.bake_interval = 5
				var arc_start: float = curve.get_closest_offset(poly[0])
				var arc_end: float = curve.get_closest_offset(poly[poly.size() - 1])
				if arc_start == arc_end:
					continue

				# Handle degenerate case
				var baked_length: float = curve.get_baked_length()
				var total_arc: float = 1.0
				if arc_end > arc_start:
					total_arc = arc_end-arc_start
				else:
					total_arc = baked_length+arc_end-arc_start
				if total_arc > baked_length / 2.0:
					var temp: float = arc_start
					arc_start = arc_end
					arc_end = temp
				self._draw_stationary_trench_curve(curve, arc_start, arc_end, c, is_river, SPACING, AMP, width)


func _draw_player_polygon_expansions(
	clicked_original_walkable_areas: Dictionary[int, bool],
) -> void:
	for h: Array in get_parent().territory_highlight_history:
		var area: Area = h[0]
		var poly: PackedVector2Array = h[1]
		var time_remaining: float = h[2]
		var original_area: Area = h[3]
		var t: float = clamp(time_remaining / (get_parent().TERRITORY_ENCIRCLEMENT_HIGHLIGHT_DURATION if original_area == null else get_parent().TERRITORY_HIGHLIGHT_DURATION), 0.0, 1.0)
		var fade: float = t
		var base_fade: float = 0.75
		var c: Color = area.color.lightened(pow(base_fade*fade, 2.0))
		c.a  = fade
		
		draw_colored_polygon(poly, c)


func draw_player_strength_setup(
	areas: Array[Area],
	map: Global.Map,
	purchased_areas: Dictionary
) -> void:
	var inverted_purchased_areas: Dictionary = {}
	for area in purchased_areas.keys():
		if not inverted_purchased_areas.has(purchased_areas[area]):
			inverted_purchased_areas[purchased_areas[area]] = []
		inverted_purchased_areas[purchased_areas[area]].append(area)
	
	# Process each group in inverted_purchased_areas
	for sub_areas in inverted_purchased_areas.values():
		var centroid: Vector2 = Vector2.ZERO
		var mean_area: float = 0.0
		var color = sub_areas[0].color if sub_areas.size() > 0 else areas[0].color
		
		for area in sub_areas:
			centroid += GeometryUtils.calculate_centroid(area.polygon)
			mean_area += area.get_total_area()
		
		centroid /= sub_areas.size()
		mean_area /= map.original_walkable_areas_sum
		
		draw_strength_text(centroid, mean_area, color, get_parent().font, get_parent().MIN_FONT_SIZE)

func draw_player_strength_simulation(areas: Array[Area], map: Global.Map) -> void:
	return
	#for area: Area in areas:
		#if area.owner_id < 0:
			#continue
		#
		#var centroid: Vector2 = GeometryUtils.calculate_centroid(area.polygon)
		#centroid = GeometryUtils.clamp_point_to_polygon(area.polygon, centroid, true)
		#var mean_area: float = area.get_strength(map)
		#
		#draw_strength_text(
			#centroid,
			#mean_area,
			#area.color,
			#get_parent().font,
			#get_parent().MIN_FONT_SIZE
		#)


# Utility: turn 1234567 → "1,234,567"
func _format_with_commas(value: int) -> String:
	var s := str(value)
	var parts : Array[String] = []
	while s.length() > 3:
		parts.insert(0, s.substr(s.length() - 3, 3))  # grab last 3 digits
		s = s.substr(0, s.length() - 3)                # drop them and repeat
	parts.insert(0, s)                                 # leading chunk (< 3 digits)
	return ",".join(parts)

func draw_strength_text(
		centroid: Vector2,
		relative_area: float,
		base_color: Color,
		font_ref,
		min_size: int
) -> void:
	return
	var strength_color: Color = (4 * Color.WHITE + base_color) / 5.0
	strength_color.a = 0.75
	
	var strength_outline_color: Color = Color.BLACK
	strength_outline_color.a = 0.75
	
	var font_size: int = max(min_size, sqrt(100 * relative_area * 100))
	
	var raw_value: int = int(round(UnitLayer.MAX_UNITS * relative_area * UnitLayer.NUMBER_PER_UNIT))
	var strength_text: String = _format_with_commas(raw_value)	
	draw_string_outline(
		font_ref,
		centroid - Vector2(font_size, 0),
		strength_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		font_size / 3.0,
		strength_color)
	
	draw_string(
		font_ref,
		centroid - Vector2(font_size, 0),
		strength_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		strength_outline_color)

func _draw_tent_shadows(bases: Array[Base]) -> void:
	var shadow_offset: Vector2 = Vector2(16, 16)  # Same as MTN_SHADOW_OFFSET
	var shadow_darken: float = 0.20  # Same as MTN_SHADOW_DARKEN
	var shadow_alpha: float = 0.25
	
	for base: Base in bases:
		var foot: PackedVector2Array = base.polygon
		if foot.size() < 3:
			continue
		
		var bbox_len: float = GeometryUtils.calculate_bounding_box(foot).size.length()
		var tent_h: float = bbox_len * 0.2
		var wall_h: float = tent_h * 0.2
		var apex: Vector2 = GeometryUtils.calculate_centroid(foot) - Vector2(0, tent_h)
		
		var team_col: Color = Global.get_player_color(base.owner_id) if base.owner_id >= 0 else Global.neutral_color
		var shadow_col: Color = team_col * shadow_darken
		shadow_col.a = shadow_alpha
		
		# Pre-compute raised "wall-top" polygon
		var top_poly: PackedVector2Array = foot.duplicate()
		for i_v: int in range(top_poly.size()):
			top_poly[i_v] -= Vector2(0, wall_h)
		
		# Collect all tent structure polygons (walls + roof triangles)
		var tent_polygons: Array[PackedVector2Array] = []
		
		# Add wall polygons
		for i_e: int in range(foot.size()):
			var g_a: Vector2 = foot[i_e]
			var g_b: Vector2 = foot[(i_e + 1) % foot.size()]
			var t_a: Vector2 = top_poly[i_e]
			var t_b: Vector2 = top_poly[(i_e + 1) % top_poly.size()]
			tent_polygons.append(PackedVector2Array([g_a, g_b, t_b, t_a]))
		
		# Add roof triangles
		for i_e: int in range(top_poly.size()):
			var t_a: Vector2 = top_poly[i_e]
			var t_b: Vector2 = top_poly[(i_e + 1) % top_poly.size()]
			tent_polygons.append(PackedVector2Array([t_a, t_b, apex]))
		
		# Cast shadows from all tent polygons
		for tent_poly: PackedVector2Array in tent_polygons:
			var shadow_poly: PackedVector2Array = GeometryUtils.translate_polygon(tent_poly, shadow_offset)
			
			# Ground shadow = shadow minus the tent structure itself
			var ground_polys: Array[PackedVector2Array] = Geometry2D.clip_polygons(
				shadow_poly,
				tent_poly
			)
			for g: PackedVector2Array in ground_polys:
				draw_colored_polygon(g, shadow_col)

# Replace the flag drawing section in _draw_bases with this enhanced version:
func _draw_bases_with_conquest_animation(bases: Array[Base]) -> void:
	var time_ms: int = Time.get_ticks_msec()
	var time_s: float = float(time_ms) * 0.001
	
	var sun_dir: Vector2 = Global.LIGHT_DIR
	var shadow_offset: Vector2 = Vector2(16, 16)
	var shadow_darken: float = 0.20
	var shadow_alpha: float = 0.25
	
	for base: Base in bases:
		var foot: PackedVector2Array = base.polygon
		if foot.size() < 3:
			continue
		
		# Update conquest animation
		if base.is_being_conquered:
			base.conquest_animation_time += get_process_delta_time()
			if base.conquest_animation_time >= base.conquest_animation_duration:
				base.is_being_conquered = false
		
		# Calculate conquest animation progress (0.0 to 1.0)
		var conquest_progress: float = 0.0
		var fire_intensity: float = 0.0
		var shake_intensity: float = 0.0
		
		if base.is_being_conquered:
			var raw_progress: float = base.conquest_animation_time / base.conquest_animation_duration
			conquest_progress = _ease_out_bounce(raw_progress)
			
			# Fire effect is strongest in middle, fades to zero at end
			fire_intensity = sin(raw_progress * PI) * 2.0 * (1.0 - raw_progress * 0.5)
			
			# Shake is strongest at start, fades to zero
			shake_intensity = (1.0 - raw_progress) * 8.0
		
		# Basic dimensions with shake
		var bbox_len: float = GeometryUtils.calculate_bounding_box(foot).size.length()
		var tent_h: float = bbox_len * 0.2
		var wall_h: float = tent_h * 0.2
		var roof_h: float = tent_h - wall_h
		
		var shake_offset: Vector2 = Vector2.ZERO
		if shake_intensity > 0:
			shake_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
		
		var apex: Vector2 = GeometryUtils.calculate_centroid(foot) - Vector2(0, tent_h) + shake_offset
		
		# Color interpolation for conquest
		var base_team_col: Color = Global.get_player_color(base.owner_id) if base.owner_id >= 0 else Global.neutral_color
		if base.is_being_conquered:
			base_team_col = base.conquest_from_color.lerp(base.conquest_to_color, conquest_progress)
		
		# Apply fire effects as overlay, don't replace the base color
		var team_col: Color = base_team_col
		if base.is_being_conquered and fire_intensity > 0:
			var fire_glow: Color = Color(1.0, 0.4, 0.0, fire_intensity * 0.2)
			team_col = team_col.lerp(fire_glow, fire_intensity * 0.3)
		
		# Draw base
		#draw_colored_polygon(foot, team_col)
		
		# Pre-compute raised "wall-top" polygon with shake
		var top_poly: PackedVector2Array = foot.duplicate()
		for i_v: int in range(top_poly.size()):
			top_poly[i_v] -= Vector2(0, wall_h)
			if shake_intensity > 0:
				top_poly[i_v] += Vector2(
					randf_range(-shake_intensity * 0.5, shake_intensity * 0.5),
					randf_range(-shake_intensity * 0.5, shake_intensity * 0.5)
				)
		
		# Draw walls with conquest effects
		for i_e: int in range(foot.size()):
			var g_a: Vector2 = foot[i_e]
			var g_b: Vector2 = foot[(i_e + 1) % foot.size()]
			var t_a: Vector2 = top_poly[i_e]
			var t_b: Vector2 = top_poly[(i_e + 1) % top_poly.size()]
			
			var mid_dir: Vector2 = ((g_a + g_b) * 0.5 - apex).normalized()
			var shade: float = clamp(0.55 + 0.45 * mid_dir.dot(-sun_dir), 0.25, 1.0)
			var wall_col: Color = team_col * shade
			
			# Add fire particles during conquest
			if base.is_being_conquered and fire_intensity > 0.5:
				_draw_fire_particles(g_a, g_b, t_a, t_b, fire_intensity, time_s, base.conquest_to_color)
			
			draw_colored_polygon(PackedVector2Array([g_a, g_b, t_b, t_a]), wall_col)
			
			var thickness: float = 5
			var shadow_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
				Geometry2D.offset_polygon(
					base.polygon,
					2*thickness/3.0,
					Geometry2D.JOIN_ROUND
				)
			)
			draw_polyline(shadow_polygon, Color(0,0,0,0.15), thickness, true)
			draw_polyline(PackedVector2Array([g_a, g_b, t_b, t_a, g_a]), Color.BLACK, 3.0, true)
		
		# Draw roof with conquest effects
		for i_e: int in range(top_poly.size()):
			var t_a: Vector2 = top_poly[i_e]
			var t_b: Vector2 = top_poly[(i_e + 1) % top_poly.size()]
			var mid_dir: Vector2 = ((t_a + t_b) * 0.5 - apex).normalized()
			var shade: float = clamp(0.60 + 0.40 * mid_dir.dot(-sun_dir), 0.30, 1.0)
			var roof_col: Color = team_col * shade
			
			draw_colored_polygon(PackedVector2Array([t_a, t_b, apex]), roof_col)
			draw_polyline(PackedVector2Array([t_a, t_b, apex, t_a]), Color.BLACK, 2.0, true)
		
		# Poles and ropes (with shake)
		var pole_col: Color = Color(0.25, 0.10, 0.05)
		var rope_col: Color = (Color(0.95, 0.91, 0.70, 0.9)+3*pole_col)/4.0
		
		var pole_tops: Array[Vector2] = []
		for i_v: int in range(foot.size()):
			var p_base: Vector2 = foot[i_v]
			var p_top: Vector2 = p_base - Vector2(0, wall_h + roof_h * 0.15)
			if shake_intensity > 0:
				p_top += Vector2(
					randf_range(-shake_intensity * 0.3, shake_intensity * 0.3),
					randf_range(-shake_intensity * 0.3, shake_intensity * 0.3)
				)
			pole_tops.append(p_top)
			draw_line(p_base, p_top, pole_col, 4.0, true)
		
		# Draw ropes with shake
		var sag_ratio: float = 0.20
		var rope_seg: int = 6
		
		for i_v: int in range(pole_tops.size()):
			var a_top: Vector2 = pole_tops[i_v]
			var b_top: Vector2 = pole_tops[(i_v + 1) % pole_tops.size()]
			var span: float = a_top.distance_to(b_top)
			var sag: float = span * sag_ratio
			var dir: Vector2 = (b_top - a_top)
			
			var prev_pt: Vector2 = a_top
			for j: int in range(1, rope_seg + 1):
				var t: float = float(j) / float(rope_seg)
				var pt: Vector2 = a_top + dir * t
				pt.y += sag * 4.0 * t * (1.0 - t)
				
				if shake_intensity > 0:
					pt += Vector2(
						randf_range(-shake_intensity * 0.2, shake_intensity * 0.2),
						randf_range(-shake_intensity * 0.2, shake_intensity * 0.2)
					)
				
				draw_line(prev_pt, pt, rope_col, 1.0, true)
				prev_pt = pt
			
			draw_line(a_top, apex, rope_col, 1.0, true)
		
		# CONQUEST FLAG ANIMATION
		var pole_len: float = tent_h * 0.65
		var flag_pole_top: Vector2 = apex - Vector2(0, pole_len)
		if shake_intensity > 0:
			flag_pole_top += Vector2(
				randf_range(-shake_intensity * 0.4, shake_intensity * 0.4),
				randf_range(-shake_intensity * 0.2, shake_intensity * 0.2)
			)
		
		draw_line(apex, flag_pole_top, pole_col, 3, true)
		
		var flag_h: float = tent_h * 0.35
		var flag_w: float = bbox_len * 0.25
		var wave_len: float = flag_w * 1.4
		var wave_amp: float = flag_h * 0.30
		var wave_spd: float = 1.0
		var n_seg: int = 5
		
		# Increase wave intensity during conquest with smooth easing out
		if base.is_being_conquered:
			var wave_multiplier: float = 1.0 + fire_intensity * 0.8 * (1.0 - conquest_progress * 0.7)
			var speed_multiplier: float = 1.0 + fire_intensity * 2.0 * (1.0 - conquest_progress * 0.8)
			wave_amp *= wave_multiplier
			wave_spd *= speed_multiplier
		
		var f_front: Array[Vector2] = []
		var f_back: Array[Vector2] = []
		for i: int in range(n_seg + 1):
			var t: float = float(i) / float(n_seg)
			var x: float = flag_w * t
			var y: float = sin((x / wave_len + time_s * wave_spd) * TAU) * wave_amp * (1.0 - t)
			
			# Add conquest "burn-in" effect
			if base.is_being_conquered:
				var burn_progress: float = clamp((conquest_progress - t * 0.3), 0.0, 1.0)
				var burn_offset: float = sin(burn_progress * PI * 4.0) * fire_intensity * 3.0
				y += burn_offset
			
			var p_f: Vector2 = flag_pole_top + Vector2(x, y)
			var p_b: Vector2 = p_f + Vector2(0, flag_h)
			f_front.append(p_f)
			f_back.append(p_b)
		
		# Flag colors with conquest transition
		var flag_front_col: Color = team_col.lightened(0.35)
		var flag_back_col: Color = team_col.darkened(0.15)
		flag_front_col.a = 0.85
		flag_back_col.a = 0.85
		
		# Shadow
		var shadow_col: Color = team_col * shadow_darken
		shadow_col.a = shadow_alpha
		
		var pole_shadow_base: Vector2 = apex + shadow_offset
		var pole_shadow_top: Vector2 = flag_pole_top + shadow_offset
		draw_line(pole_shadow_base, pole_shadow_top, shadow_col, 3.0, true)
		
		# Flag shadows
		for i_q: int in range(n_seg):
			var a: Vector2 = f_front[i_q]
			var b: Vector2 = f_front[i_q + 1]
			var c: Vector2 = f_back[i_q + 1]
			var d: Vector2 = f_back[i_q]
			
			var flag_shadow: PackedVector2Array = PackedVector2Array([
				a + 2*shadow_offset + Vector2(0, tent_h),
				b + 2*shadow_offset + Vector2(0, tent_h),
				c + 2*shadow_offset + Vector2(0, tent_h),
				d + 2*shadow_offset + Vector2(0, tent_h)
			])
			draw_colored_polygon(flag_shadow, shadow_col)
		
		# Draw FIRE SWEEP across flag instead of boring particles
		if base.is_being_conquered and conquest_progress > 0.3:
			_draw_fire_sweep_across_flag(base, f_front, f_back, fire_intensity, time_s, conquest_progress)
		
		# Flag outline
		for i_q: int in range(n_seg):
			var a: Vector2 = f_front[i_q]
			var b: Vector2 = f_front[i_q + 1]
			var c: Vector2 = f_back[i_q + 1]
			var d: Vector2 = f_back[i_q]
			draw_polyline([a, b, c, d], Color.BLACK, 5, true)
		
		# Flag polygons with burn-in effect
		for i_q: int in range(n_seg):
			var a: Vector2 = f_front[i_q]
			var b: Vector2 = f_front[i_q + 1]
			var c: Vector2 = f_back[i_q + 1]
			var d: Vector2 = f_back[i_q]
			
			# Create burn-in effect from left to right
			var segment_progress: float = float(i_q) / float(n_seg)
			var local_conquest: float = clamp((conquest_progress - segment_progress * 0.4), 0.0, 1.0)
			
			var front_col: Color = flag_front_col
			var back_col: Color = flag_back_col
			
			if base.is_being_conquered and local_conquest > 0.0:
				# Add fiery transition colors
				var burn_col: Color = Color(1.0, 0.3 + local_conquest * 0.4, 0.0)
				var transition_strength: float = sin(local_conquest * PI) * fire_intensity * 0.5
				
				front_col = front_col.lerp(burn_col, transition_strength)
				back_col = back_col.lerp(burn_col, transition_strength)
			
			draw_colored_polygon(PackedVector2Array([a, b, c, d]), front_col)
			draw_colored_polygon(PackedVector2Array([a, d, c, b]), back_col)
		
		draw_polyline(PackedVector2Array([f_front[0], f_back[0]]), Color.BLACK, 3.0, true)
		
		# Warning overlay (existing code)
		if base.under_attack:
			var pulse: float = 0.5 + 0.5 * sin(time_s * TAU * 2.0)
			var warn: Color = Global.get_player_color(1 if base.owner_id == GameSimulationComponent.PLAYER_ID else GameSimulationComponent.PLAYER_ID)
			warn = (team_col + pulse*warn)/2.0
			warn.a = 0.4 + 0.4 * pulse
			draw_colored_polygon(foot, warn)
			
			# Flag warning overlay
			for i_q: int in range(n_seg):
				var a: Vector2 = f_front[i_q]
				var b: Vector2 = f_front[i_q + 1]
				var c: Vector2 = f_back[i_q + 1]
				var d: Vector2 = f_back[i_q]
				draw_colored_polygon(PackedVector2Array([a, b, c, d]), warn)
			

# Fire particle system for walls
func _draw_fire_particles(g_a: Vector2, g_b: Vector2, t_a: Vector2, t_b: Vector2, intensity: float, time: float, to_color: Color) -> void:
	var num_particles: int = int(intensity * 8)
	var wall_center: Vector2 = (g_a + g_b + t_a + t_b) * 0.25
	
	# Choose particle colors based on target color
	var fire_colors: Array[Color] = []
	if to_color.b > to_color.r and to_color.b > to_color.g:  # Blue-ish (player)
		fire_colors = [
			Color(0.8, 0.9, 1.0, 0.8),  # Icy white
			Color(0.4, 0.7, 1.0, 0.7),  # Light blue
			Color(0.2, 0.5, 0.9, 0.6),  # Blue
			Color(0.1, 0.3, 0.7, 0.4)   # Dark blue
		]
	elif to_color.r > to_color.g and to_color.r > to_color.b:  # Red-ish
		fire_colors = [
			Color(1.0, 1.0, 0.0, 0.8),  # Yellow
			Color(1.0, 0.5, 0.0, 0.7),  # Orange  
			Color(1.0, 0.2, 0.0, 0.6),  # Red
			Color(0.8, 0.0, 0.0, 0.4)   # Dark red
		]
	elif to_color.g > to_color.r and to_color.g > to_color.b:  # Green-ish
		fire_colors = [
			Color(0.8, 1.0, 0.4, 0.8),  # Light green
			Color(0.4, 0.9, 0.2, 0.7),  # Green
			Color(0.2, 0.7, 0.1, 0.6),  # Dark green
			Color(0.1, 0.5, 0.0, 0.4)   # Deep green
		]
	else:  # Default/neutral
		fire_colors = [
			Color(1.0, 1.0, 0.0, 0.8),  # Yellow
			Color(1.0, 0.5, 0.0, 0.7),  # Orange  
			Color(1.0, 0.2, 0.0, 0.6),  # Red
			Color(0.8, 0.0, 0.0, 0.4)   # Dark red
		]
	
	for i: int in range(num_particles):
		var particle_time: float = time * 3.0 + float(i) * 0.5
		var x_offset: float = sin(particle_time + float(i)) * 15.0
		var y_offset: float = -abs(cos(particle_time * 1.5 + float(i))) * 35.0 * intensity
		
		var particle_pos: Vector2 = wall_center + Vector2(x_offset, y_offset)
		var particle_size: float = (3.0 + sin(particle_time * 2.0) * 2.0) * intensity
		
		var color_index: int = i % fire_colors.size()
		var particle_color: Color = fire_colors[color_index]
		particle_color.a *= intensity * 0.7
		
		draw_circle(particle_pos, particle_size, particle_color)

# Fire sweep effect across the flag from right to left
func _draw_fire_sweep_across_flag(base: Base, f_front: Array[Vector2], f_back: Array[Vector2], intensity: float, time: float, progress: float) -> void:
	var sweep_start: float = 0.3  # Start much earlier
	if progress < sweep_start:
		return
		
	var sweep_progress: float = (progress - sweep_start) / (1.0 - sweep_start)
	sweep_progress = clamp(sweep_progress, 0.0, 1.0)
	var sweep_position: float = 1.0 - sweep_progress  # Right to left
	
	for i: int in range(f_front.size() - 1):
		var segment_pos: float = float(i) / float(f_front.size() - 1)
		var distance_from_sweep: float = abs(segment_pos - sweep_position)
		
		# Only draw fire near the sweep line
		if distance_from_sweep < 0.4:
			var fire_strength: float = 1.0 - distance_from_sweep / 0.4
			fire_strength = fire_strength * fire_strength  # Square for sharper falloff
			
			var segment_center: Vector2 = (f_front[i] + f_front[i + 1] + f_back[i] + f_back[i + 1]) * 0.25
			var flag_height: Vector2 = f_back[i] - f_front[i]
			
			# Draw dramatic fire streaks with target colors
			var num_streaks: int = int(fire_strength * 6)
			
			# Choose colors based on target color
			var fire_colors: Array[Color] = []
			var target_color: Color = base.conquest_to_color
			if target_color.b > target_color.r and target_color.b > target_color.g:  # Blue-ish (player)
				fire_colors = [
					Color(0.9, 1.0, 1.2),  # Icy white
					Color(0.5, 0.8, 1.0),  # Light blue
					Color(0.2, 0.6, 0.9)   # Blue
				]
			elif target_color.r > target_color.g and target_color.r > target_color.b:  # Red-ish
				fire_colors = [
					Color(1.2, 1.0, 0.3),  # Bright yellow-white
					Color(1.0, 0.4, 0.0),  # Orange
					Color(0.8, 0.2, 0.0)   # Deep red
				]
			elif target_color.g > target_color.r and target_color.g > target_color.b:  # Green-ish
				fire_colors = [
					Color(0.8, 1.2, 0.4),  # Bright green
					Color(0.4, 1.0, 0.2),  # Green
					Color(0.2, 0.8, 0.1)   # Dark green
				]
			else:  # Default
				fire_colors = [
					Color(1.2, 1.0, 0.3),  # Bright yellow-white
					Color(1.0, 0.4, 0.0),  # Orange
					Color(0.8, 0.2, 0.0)   # Deep red
				]
			
			for streak: int in range(num_streaks):
				var streak_time: float = time * 5.0 + float(streak) * 0.2 + segment_pos * 3.0
				var streak_offset: Vector2 = Vector2(
					sin(streak_time) * 8.0,
					-abs(cos(streak_time * 1.5)) * 30.0 * fire_strength
				)
				
				var streak_pos: Vector2 = segment_center + streak_offset
				var streak_size: float = (4.0 + sin(streak_time * 2.0) * 3.0) * fire_strength
				
				var color_index: int = streak % fire_colors.size()
				var fire_color: Color = fire_colors[color_index]
				fire_color.a = fire_strength * intensity * 0.9
				
				draw_circle(streak_pos, streak_size, fire_color)
			
			# Add intense glow behind the sweep
			if fire_strength > 0.5:
				var glow_color: Color = Color(1.0, 0.6, 0.0, fire_strength * 0.3)
				var glow_rect: PackedVector2Array = PackedVector2Array([
					f_front[i] - flag_height * 0.2,
					f_front[i + 1] - flag_height * 0.2,
					f_back[i + 1] + flag_height * 0.2,
					f_back[i] + flag_height * 0.2
				])
				draw_colored_polygon(glow_rect, glow_color)

# Smooth easing function for satisfying animation
func _ease_out_bounce(t: float) -> float:
	if t < 1.0 / 2.75:
		return 7.5625 * t * t
	elif t < 2.0 / 2.75:
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elif t < 2.5 / 2.75:
		t -= 2.25 / 2.75  
		return 7.5625 * t * t + 0.9375
	else:
		t -= 2.625 / 2.75
		return 7.5625 * t * t + 0.984375


func _draw_player_polygons_addons(
	map: Global.Map,
	areas: Array[Area],
) -> void:
	# Draw vertices of polygons
	#var areas_sorted_by_strength: Array[Area] = areas.duplicate()
	#areas_sorted_by_strength.sort_custom(func(a,b): return a.get_strength(map) < b.get_strength(map))
	
	for area: Area in areas:        		
		var outline_color: Color = Color.BLACK
		outline_color.a = 1.0
		if area.owner_id < 0:
			continue
		# Draw outline for the outer polygon
		var polygon = area.polygon
		polygon = polygon + PackedVector2Array([polygon[0]])
		draw_polyline(
			polygon,
			outline_color,
			0.125*DrawComponent.AREA_OUTLINE_THICKNESS,
			true
		)

		#for more_offset_polygon: PackedVector2Array in Geometry2D.offset_polygon(
			#area.polygon, DrawComponent.AREA_OUTLINE_THICKNESS/2.0, Geometry2D.JOIN_ROUND
		#):
			#if not Geometry2D.is_polygon_clockwise(more_offset_polygon):
				#more_offset_polygon.append(more_offset_polygon[0])
				#var outside_polygon_shadow_color: Color = Color.BLACK
				#outside_polygon_shadow_color.a = 0.1
				#draw_polyline_colors(more_offset_polygon, [outside_polygon_shadow_color], 2*DrawComponent.AREA_OUTLINE_THICKNESS, true)


		var point_color = (Color.LIGHT_GRAY+2*area.color)/3.0
		point_color.a = 0.75
		for other_area in areas:
			if other_area.owner_id == -2:
				var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(area.polygon, other_area.polygon)
				if (
					intersections.size() == 1 and
					GeometryUtils.same_polygon_shifted(intersections[0], other_area.polygon)
				):
					var other_polygon = other_area.polygon
					other_polygon = other_polygon + PackedVector2Array([other_polygon[0]])
					draw_polyline(
						other_polygon,
						outline_color,
						0.125*DrawComponent.AREA_OUTLINE_THICKNESS,
						true
					)

					#for more_offset_polygon: PackedVector2Array in Geometry2D.offset_polygon(
						#intersections[0], -DrawComponent.AREA_OUTLINE_THICKNESS/2.0, Geometry2D.JOIN_ROUND
					#):
						#if not Geometry2D.is_polygon_clockwise(more_offset_polygon):
							#more_offset_polygon.append(more_offset_polygon[0])
							#var outside_polygon_shadow_color: Color = Color.BLACK
							#outside_polygon_shadow_color.a = 0.1
							#draw_polyline_colors(more_offset_polygon, [outside_polygon_shadow_color], 2*DrawComponent.AREA_OUTLINE_THICKNESS, true)
						

					#for point in other_area.polygon:
						#if point in area.polygon:
							#continue
						#draw_rect(Rect2(point, Vector2(12,12)), point_color)
		#
		#for point in area.polygon:
			#draw_rect(Rect2(point, Vector2(12,12)), point_color)



func _draw_player_polyline_expansions(
	clicked_original_walkable_areas: Dictionary[int, bool],
	newly_expanded_polylines: Dictionary[Area, Dictionary],
	newly_retracting_polylines: Dictionary[Area, Dictionary],
	map: Global.Map,
	total_weighted_circumferences: Dictionary[Area, float],
) -> void:
	for area: Area in newly_retracting_polylines.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID:
			continue
		# Draw retracting polylines
		for original_area in newly_retracting_polylines[area]:
			for poly in newly_retracting_polylines[area][original_area]:
				_draw_polyline_segments(poly, area, original_area, clicked_original_walkable_areas, true)

	for area: Area in newly_expanded_polylines.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID:
			continue
		# Draw expanded polylines
		for original_area in newly_expanded_polylines[area]:
			for poly in newly_expanded_polylines[area][original_area]:
				_draw_polyline_segments(poly, area, original_area, clicked_original_walkable_areas, false)

func _draw_polyline_segments(
	poly: Array,
	area: Area,
	original_area: Area,
	clicked_original_walkable_areas: Dictionary[int, bool],
	representing_enemy_expansion: bool
) -> void:
	var base_color: Color
	if representing_enemy_expansion:
		base_color = Color.RED
	else:
		base_color = area.color
	
	var fade: float = 1.0
	if area.owner_id != GameSimulationComponent.PLAYER_ID:
		fade = 0.5

	var base_fade: float = 0.75
	var c: Color = base_color.lightened(pow(base_fade * fade, 2.0))
	c.a = 1.0#0.75
	c.v = 0.8#0.75
		
	
	if poly.size() <= 1:
		return
	
	for i: int in range(poly.size() - 1):
		var next_idx: int = (i + 1) % poly.size()
		var segment_vector: Vector2 = poly[next_idx] - poly[i]
		var segment_length: float = segment_vector.length()
		
		if segment_length <= 0:
			continue
		
		var segment_direction: Vector2 = segment_vector / segment_length
		var perpendicular: Vector2 = Vector2(-segment_direction.y, segment_direction.x)
		
		# Need clarification on what 'position' should be
		var point: Vector2 = poly[i] + segment_direction * position
		var next_point: Vector2 = poly[next_idx] + segment_direction * position
		var orth_start: Vector2 = point + (perpendicular * 0.4*DrawComponent.AREA_ADDON_THICKNESS if not representing_enemy_expansion else Vector2.ZERO)
		var orth_end: Vector2 = next_point + (perpendicular * 0.4*DrawComponent.AREA_ADDON_THICKNESS if not representing_enemy_expansion else Vector2.ZERO)
		
		#c.a = 0.5
		draw_line(
			orth_start,
			orth_end,
			c,
			(
				DrawComponent.AREA_ADDON_THICKNESS*0.075
				if area.owner_id == GameSimulationComponent.PLAYER_ID else
				DrawComponent.AREA_ADDON_THICKNESS),
				true
			)
		#c.a = 1.0
		#draw_line(
			#orth_start,
			#orth_end,
			#c,
			#(
				#0.05 * DrawComponent.AREA_ADDON_THICKNESS
				#if area.owner_id == GameSimulationComponent.PLAYER_ID else
				#DrawComponent.AREA_ADDON_THICKNESS),
				#true
			#)


func _draw() -> void:	
	var areas: Array[Area] = get_parent().get_parent().areas
	
	var purchased_areas: Dictionary = get_parent().get_parent().purchased_areas
	var map: Global.Map = get_parent().get_parent().map
	var map_generator: MapGenerator = get_parent().get_parent().map_generator
	var game_phase = get_parent().get_parent().game_phase
	var current_player: int = get_parent().get_parent().current_player
	
	var simulation_areas: Array[Area]
	var expanded_sub_areas: Array[Area]
	var clicked_original_walkable_areas: Dictionary[int, bool]
	var newly_expanded_polylines: Dictionary[Area, Dictionary]
	var newly_retracting_polylines: Dictionary[Area, Dictionary]
	var newly_holding_polylines: Dictionary[Area, Dictionary]
	var total_weighted_circumferences: Dictionary[Area, float]
	var big_intersecting_areas_circumferences: Dictionary[Area, Dictionary] = {}
	if get_parent().get_parent().game_simulation_component != null:
		simulation_areas = get_parent().get_parent().game_simulation_component.areas
		expanded_sub_areas = get_parent().get_parent().game_simulation_component.expanded_sub_areas
		clicked_original_walkable_areas = get_parent().get_parent().game_simulation_component.clicked_original_walkable_areas
		newly_expanded_polylines = get_parent().get_parent().game_simulation_component.newly_expanded_polylines
		newly_retracting_polylines = get_parent().get_parent().game_simulation_component.newly_retracting_polylines
		newly_holding_polylines = get_parent().get_parent().game_simulation_component.newly_holding_polylines
		total_weighted_circumferences = get_parent().get_parent().game_simulation_component.total_weighted_circumferences


	for vehicle: Vehicle in map.tanks+map.trains+map.ships:
		var col: Color = Global.get_player_color(vehicle.owner_id)
		var closed: PackedVector2Array = vehicle.collision_polygon()
		col.a = 0.25
		draw_polygon(closed, [col])
		closed.append(closed[0])
		draw_polyline_colors(closed, [Color.BLACK], 0.5*DrawComponent.AREA_OUTLINE_THICKNESS, true)

	_draw_player_polygons_addons(map, areas if game_phase == "setup" else simulation_areas)

	_draw_player_polyline_expansions(
		clicked_original_walkable_areas,
		newly_expanded_polylines,
		newly_retracting_polylines,
		map,
		total_weighted_circumferences,
	)

	_draw_player_polyline_expansions_extra(
		clicked_original_walkable_areas,
		newly_expanded_polylines,
		newly_retracting_polylines,
	)
	_draw_player_polyline_holdings(
		map,
		clicked_original_walkable_areas,
		newly_holding_polylines,
		newly_expanded_polylines,
	)
	
	_draw_player_polygon_expansions(clicked_original_walkable_areas)


	for entry in get_parent().encirclement_text_history:
		var base_position = entry[0]
		var cost = entry[1]
		#var text: String = "%.2f" % (cost*100)
		var raw_value: int = int(round(cost * UnitLayer.MAX_UNITS * UnitLayer.NUMBER_PER_UNIT))   # 0.955  ->  955
		var text: String = _format_with_commas(raw_value)  # 1.001 -> "1,001"

		var initial_time = entry[2]
		var remaining_time = entry[3]
		var max_time = entry[4]
		var owner_id: int = entry[5]
		
		var base_font_size: int = max(get_parent().MIN_FONT_SIZE, sqrt(5000*cost*100))
		
		# Calculate progress for different phases of animation
		var total_progress = (max_time - remaining_time) / max_time  # 0 to 1 over lifetime
		var ease_in_progress = min(1.0, initial_time / (max_time * 0.15))  # Quick ease in (first 15%)
		var ease_out_progress = 1.0 - min(1.0, remaining_time / (max_time * 0.4))  # Slower ease out (last 40%)
		
		# Calculate size scaling (larger at start, gradually returning to normal)
		var size_scale = 1.0 + 0.5 * (1.0 - ease_in_progress) - 0.75 * ease_out_progress
		var font_size = base_font_size * size_scale
		
		# Calculate vertical offset (gradually rises)
		var rise_offset = -get_parent().TEXT_RISE_DISTANCE * total_progress
		
		# Calculate opacity (fully visible after ease in, fades during ease out)
		var opacity = ease_in_progress * (1.0 - ease_out_progress * 0.8)
		
		var text_color = Color.BLACK
		#text_color = (2*text_color+get_player_color(owner_id))/3.0
		text_color.a = opacity
		
		# Apply all transformations
		var text_position = base_position + Vector2(0, rise_offset)
		
		draw_string(get_parent().font, text_position - Vector2(font_size, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

	# Dynamic each game
	if game_phase == "setup":
		draw_player_strength_setup(
			areas,
			map,
			purchased_areas,
		)
	elif game_phase == "simulation":
		draw_player_strength_simulation(
			simulation_areas,
			map,
		)

	#for area: Area in expanded_sub_areas:
		#if area.owner_id < 0:
			#continue
		#var random_color = Color(randf(), randf(), randf())
		##var random_color = get_player_color(area.owner_id)
		##random_color = (random_color+Color.WHITE)/2.0
		#draw_colored_polygon(area.polygon, random_color)
		#
	#for area: Area in expanded_sub_areas:
		#if area.owner_id < 0:
			#continue
		#var random_color = Color(randf(), randf(), randf())
		#draw_colored_polygon(area.polygon, random_color)


	#_draw_tent_shadows(map.bases)
	#_draw_bases_with_conquest_animation(map.bases)
	
