extends Node2D
class_name VehicleLayer

const PIN_RADIUS: float = 24.0		# ← constant overall size
const SYMBOL_SIZE: float = 36.0

@onready var vehicle_renderer: VehiclesRenderer = $Vehicles

const outline_thickness: float = 5.0
const extra_outline_thickness: float = 3.0

# Pre-rendered complete pin textures
var _friendly_pin_texture: Texture2D
var _enemy_pin_texture: Texture2D

func _ready() -> void:
	_create_pin_textures()

func _create_pin_textures() -> void:
	print("Creating pin textures...")
	var texture_size: int = 128
	
	# Create viewports
	var friendly_viewport: SubViewport = SubViewport.new()
	var enemy_viewport: SubViewport = SubViewport.new()
	
	friendly_viewport.size = Vector2i(texture_size, texture_size)
	enemy_viewport.size = Vector2i(texture_size, texture_size)
	friendly_viewport.transparent_bg = true
	enemy_viewport.transparent_bg = true
	
	# Create Controls
	var friendly_control: Control = Control.new()
	var enemy_control: Control = Control.new()
	friendly_control.size = Vector2(texture_size, texture_size)
	enemy_control.size = Vector2(texture_size, texture_size)
	
	# Connect draw functions
	friendly_control.draw.connect(_draw_friendly_pin_to_texture.bind(friendly_control, texture_size))
	enemy_control.draw.connect(_draw_enemy_pin_to_texture.bind(enemy_control, texture_size))
	
	# Setup scene
	add_child(friendly_viewport)
	add_child(enemy_viewport) 
	friendly_viewport.add_child(friendly_control)
	enemy_viewport.add_child(enemy_control)
	
	# Render
	friendly_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	enemy_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Get textures
	_friendly_pin_texture = friendly_viewport.get_texture()
	_enemy_pin_texture = enemy_viewport.get_texture()
	
	print("Pin textures created")

func _draw_friendly_pin_to_texture(control: Control, size: int) -> void:
	var tip_pos: Vector2 = Vector2(size/2, size * 0.95)
	var color: Color = Global.get_player_color(0)  # Use actual friendly colors
	var pin_color: Color = Global.get_vehicle_color(0)
	color.a = 0.75
	pin_color.a = 0.75
	_draw_pin_with_nato_scaled(control, tip_pos, color, pin_color, 0, size)

func _draw_enemy_pin_to_texture(control: Control, size: int) -> void:
	var tip_pos: Vector2 = Vector2(size/2, size * 0.95)
	var color: Color = Global.get_player_color(1)  # Use actual enemy colors
	var pin_color: Color = Global.get_vehicle_color(1)
	color.a = 0.75
	pin_color.a = 0.75
	_draw_pin_with_nato_scaled(control, tip_pos, color, pin_color, 1, size)

func _draw_pin_with_nato_scaled(
	control: Control,
	c: Vector2,
	col: Color,
	pin_color: Color,
	owner_id: int,
	texture_size: int
) -> void:
	# Scale to fit texture
	var pin_height: float = PIN_RADIUS * 2.8
	var scale: float = float(texture_size) * 0.8 / pin_height
	
	# Exact same logic as _draw_pin_with_nato but scaled
	var pin_col: Color = col.darkened(0.75)
	var symbol_color: Color = col.lightened(0.35)
	
	var r: float = PIN_RADIUS * scale
	var offset: Vector2 = Vector2(0.0, r * 1.80)
	var centre: Vector2 = c - offset

	# circular head
	control.draw_circle(centre, r, pin_col)

	# triangular tip
	var left: Vector2 = centre + Vector2(-r * 0.60, r * 0.60)
	var right: Vector2 = centre + Vector2(r * 0.60, r * 0.60)
	control.draw_colored_polygon(PackedVector2Array([left, right, c]), pin_col)

	# NATO symbol - call existing function but scale it
	_draw_enhanced_nato_symbol_scaled(control, centre, symbol_color, pin_color, owner_id, scale)

func _draw_enhanced_nato_symbol_scaled(
	control: Control,
	c: Vector2,
	col: Color,
	pin_color: Color,
	owner_id: int,
	scale: float
) -> void:
	var plate_size: float = SYMBOL_SIZE * scale
	var plate_half: float = plate_size * 0.5
	var corner_radius: float = plate_size * 0.15
	var rivet_radius: float = plate_size * 0.08
	
	var dark: Color = col.darkened(0.5)
	var rect_color: Color = pin_color
	var outline_col: Color = (3*Color.BLACK+pin_color)/4.0
	var extra_outline_col: Color = outline_col.darkened(0.5)

	# Background plate
	_draw_rounded_plate_scaled(control, c, plate_size, corner_radius, dark)
	_draw_rounded_plate_outline_scaled(control, c, plate_size, corner_radius, outline_col, 2.0 * scale)
	
	if owner_id == 0:
		var symbol_size_inner: float = plate_size * 0.875
		var symbol_half: float = symbol_size_inner * 0.5
		var symbol_rect: Rect2 = Rect2(
			c.x - symbol_half * 0.8,
			c.y - symbol_half * 0.8,
			symbol_size_inner * 0.8,
			symbol_size_inner * 0.8
		)
		
		control.draw_rect(symbol_rect, rect_color, true)
		control.draw_rect(symbol_rect, outline_col, false, outline_thickness * scale)
		control.draw_line(
			Vector2(symbol_rect.position.x, symbol_rect.position.y),
			Vector2(symbol_rect.end.x, symbol_rect.end.y),
			outline_col,
			outline_thickness * scale
		)
		control.draw_line(
			Vector2(symbol_rect.end.x, symbol_rect.position.y),
			Vector2(symbol_rect.position.x, symbol_rect.end.y),
			outline_col,
			outline_thickness * scale
		)
		control.draw_rect(symbol_rect, extra_outline_col, false, extra_outline_thickness * scale)
		control.draw_line(
			Vector2(symbol_rect.position.x, symbol_rect.position.y),
			Vector2(symbol_rect.end.x, symbol_rect.end.y),
			extra_outline_col,
			extra_outline_thickness * scale
		)
		control.draw_line(
			Vector2(symbol_rect.end.x, symbol_rect.position.y),
			Vector2(symbol_rect.position.x, symbol_rect.end.y),
			extra_outline_col,
			extra_outline_thickness * scale
		)
	else:
		var diamond_size: float = plate_size * 0.875
		var h: float = diamond_size * 0.5
		var v: float = diamond_size * 0.5
		
		var top: Vector2 = c + Vector2(0, -v)
		var right: Vector2 = c + Vector2(h, 0)
		var bottom: Vector2 = c + Vector2(0, v)
		var left: Vector2 = c + Vector2(-h, 0)
		
		var pts: PackedVector2Array = PackedVector2Array([top, right, bottom, left])
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		
		control.draw_polygon(pts, [rect_color])
		control.draw_polyline_colors(closed, [outline_col], outline_thickness * scale)
		control.draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), outline_col, outline_thickness * scale)
		control.draw_line(right.lerp(bottom, 0.5), top.lerp(left, 0.5), outline_col, outline_thickness * scale)
		control.draw_polyline_colors(closed, [extra_outline_col], extra_outline_thickness * scale)
		control.draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), extra_outline_col, extra_outline_thickness * scale)
		control.draw_line(right.lerp(bottom, 0.5), top.lerp(left, 0.5), extra_outline_col, extra_outline_thickness * scale)

	_draw_corner_rivets_scaled(control, c, plate_half, rivet_radius, col.lightened(0.25), scale)

func _draw_rounded_plate_scaled(control: Control, center: Vector2, size: float, radius: float, color: Color) -> void:
	var half_size: float = size * 0.5
	var rect: Rect2 = Rect2(center.x - half_size, center.y - half_size, size, size)
	control.draw_rect(rect, color, true)

func _draw_rounded_plate_outline_scaled(control: Control, center: Vector2, size: float, radius: float, color: Color, thickness: float) -> void:
	var half_size: float = size * 0.5
	var rect: Rect2 = Rect2(center.x - half_size, center.y - half_size, size, size)
	control.draw_rect(rect, color, false, thickness)

func _draw_corner_rivets_scaled(control: Control, center: Vector2, plate_half: float, rivet_radius: float, color: Color, scale: float) -> void:
	var rivet_offset: float = plate_half * 0.75
	var rivet_positions: Array[Vector2] = [
		center + Vector2(-rivet_offset, -rivet_offset),
		center + Vector2(rivet_offset, -rivet_offset),
		center + Vector2(rivet_offset, rivet_offset),
		center + Vector2(-rivet_offset, rivet_offset)
	]
	for pos: Vector2 in rivet_positions:
		control.draw_circle(pos, rivet_radius, color.darkened(0.3))
		control.draw_circle(pos, rivet_radius * 0.7, color.lightened(0.3))
		control.draw_circle(pos, rivet_radius, Color.BLACK, false, 1.0 * scale)

func _draw_enhanced_nato_symbol(
	c: Vector2,
	col: Color,
	pin_color: Color,
	owner_id: int
) -> void:
	var plate_size: float = SYMBOL_SIZE
	var plate_half: float = plate_size * 0.5
	var corner_radius: float = plate_size * 0.15
	var rivet_radius: float = plate_size * 0.08
	
	var dark: Color = col.darkened(0.5)
	var rect_color: Color = pin_color#col.lightened(0.125)
	var outline_col: Color = (3*Color.BLACK+pin_color)/4.0
	var extra_outline_col: Color = outline_col.darkened(0.5)

	# Enemy: diamond NATO symbol
	_draw_rounded_plate(c, plate_size, corner_radius, dark)
	_draw_rounded_plate_outline(c, plate_size, corner_radius, outline_col, 2.0)
	
	if owner_id == 0:
		var symbol_size_inner: float = plate_size * 0.875
		var symbol_half: float = symbol_size_inner * 0.5
		var symbol_rect: Rect2 = Rect2(
			c.x - symbol_half * 0.8,
			c.y - symbol_half * 0.8,
			symbol_size_inner * 0.8,
			symbol_size_inner * 0.8
		)
		
		draw_rect(symbol_rect, rect_color, true)
		draw_rect(symbol_rect, outline_col, false, outline_thickness)
		draw_line(
			Vector2(symbol_rect.position.x, symbol_rect.position.y),
			Vector2(symbol_rect.end.x, symbol_rect.end.y),
			outline_col,
			outline_thickness
		)
		draw_line(
			Vector2(symbol_rect.end.x, symbol_rect.position.y),
			Vector2(symbol_rect.position.x, symbol_rect.end.y),
			outline_col,
			outline_thickness
		)
		draw_rect(symbol_rect, extra_outline_col, false, extra_outline_thickness)
		draw_line(
			Vector2(symbol_rect.position.x, symbol_rect.position.y),
			Vector2(symbol_rect.end.x, symbol_rect.end.y),
			extra_outline_col,
			extra_outline_thickness
		)
		draw_line(
			Vector2(symbol_rect.end.x, symbol_rect.position.y),
			Vector2(symbol_rect.position.x, symbol_rect.end.y),
			extra_outline_col,
			extra_outline_thickness
		)
	else:
		var diamond_size: float = plate_size * 0.875
		var h: float = diamond_size * 0.5
		var v: float = diamond_size * 0.5
		
		var top: Vector2 = c + Vector2(0, -v)
		var right: Vector2 = c + Vector2(h, 0)
		var bottom: Vector2 = c + Vector2(0, v)
		var left: Vector2 = c + Vector2(-h, 0)
		
		var pts: PackedVector2Array = PackedVector2Array([top, right, bottom, left])
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		
		draw_polygon(pts, [rect_color])
		draw_polyline_colors(closed, [outline_col], outline_thickness)
		draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), outline_col, outline_thickness)
		draw_line(right.lerp(bottom, 0.5), top.lerp(left, 0.5), outline_col, outline_thickness)
		draw_polyline_colors(closed, [extra_outline_col], extra_outline_thickness)
		draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), extra_outline_col, extra_outline_thickness)
		draw_line(right.lerp(bottom, 0.5), top.lerp(left, 0.5), extra_outline_col, extra_outline_thickness)


	_draw_corner_rivets(c, plate_half, rivet_radius, col.lightened(0.25))
	
func _draw_rounded_plate(center: Vector2, size: float, radius: float, color: Color) -> void:
	var half_size: float = size * 0.5
	var rect: Rect2 = Rect2(center.x - half_size, center.y - half_size, size, size)
	draw_rect(rect, color, true)

func _draw_rounded_plate_outline(center: Vector2, size: float, radius: float, color: Color, thickness: float) -> void:
	var half_size: float = size * 0.5
	var rect: Rect2 = Rect2(center.x - half_size, center.y - half_size, size, size)
	draw_rect(rect, color, false, thickness)

func _draw_corner_rivets(center: Vector2, plate_half: float, rivet_radius: float, color: Color) -> void:
	var rivet_offset: float = plate_half * 0.75
	var rivet_positions: Array[Vector2] = [
		center + Vector2(-rivet_offset, -rivet_offset),
		center + Vector2(rivet_offset, -rivet_offset),
		center + Vector2(rivet_offset, rivet_offset),
		center + Vector2(-rivet_offset, rivet_offset)
	]
	for pos: Vector2 in rivet_positions:
		draw_circle(pos, rivet_radius, color.darkened(0.3))
		draw_circle(pos, rivet_radius * 0.7, color.lightened(0.3))
		draw_circle(pos, rivet_radius, Color.BLACK, false, 1.0)


func _draw_pin_with_nato(
	c: Vector2,
	col: Color,
	pin_color: Color,
	owner_id: int,
) -> void:
	# --- pin background (darker tone) ---
	var pin_col: Color = col.darkened(0.75)
	var symbol_color: Color = col.lightened(0.35)
	
	# pre-compute
	var r: float = PIN_RADIUS
	var offset: Vector2 = Vector2(0.0, r * 1.80)	# head-to-tip distance

	# circle centre is above the tip by offset
	var centre: Vector2 = c - offset

	# circular head
	draw_circle(centre, r, pin_col)

	# triangular tip (left, right from circle centre; tip at c)
	var left: Vector2  = centre + Vector2(-r * 0.60, r * 0.60)
	var right: Vector2 = centre + Vector2( r * 0.60, r * 0.60)
	draw_colored_polygon(PackedVector2Array([left, right, c]), pin_col)

	# NATO symbol inside the pin head
	_draw_enhanced_nato_symbol(centre, symbol_color, pin_color, owner_id)


# -------------------------------------------------------------------
#  _draw – fetch data from the same parents PolygonLayer used and call main
# -------------------------------------------------------------------
func _draw() -> void:
	# Default initial values
	var map: Global.Map = null

	if get_parent().get_parent() != null:
		map = get_parent().get_parent().map

	if map != null:
		for vehicle: Vehicle in map.tanks + map.trains + map.ships:
			var color: Color = Global.get_player_color(vehicle.owner_id)
			var pin_color: Color = Global.get_vehicle_color(vehicle.owner_id)
			color.a = 0.75
			pin_color.a = 0.75
			#_draw_pin_with_nato(
				#vehicle.global_position,
				#color,
				#pin_color,
				#vehicle.owner_id
			#)
			# Draw saved pin texture - UNCHANGED, no color modification
			var pin_texture: Texture2D = _friendly_pin_texture if vehicle.owner_id == 0 else _enemy_pin_texture
			if pin_texture != null:
				var pin_height: float = PIN_RADIUS * 3.25
				var texture_rect: Rect2 = Rect2(
					vehicle.global_position.x - pin_height * 0.5,
					vehicle.global_position.y - pin_height,
					pin_height,
					pin_height
				)
				# Draw texture AS-IS with no color modification
				draw_texture_rect(pin_texture, texture_rect, false)
		
		# Draw predictive rays for tanks
		for tank: Tank in map.tanks:
			_draw_tank_predictive_ray(tank, map)

func _draw_tank_predictive_ray(tank: Tank, map: Global.Map) -> void:
	const TOTAL_RAY_LENGTH: float = 600.0  # 3 times longer
	const MAX_BOUNCES: int = 10
	
	var ray_start: Vector2 = tank.global_position
	var ray_direction: Vector2 = tank.direction.normalized()
	var ray_color: Color = Global.get_vehicle_color(tank.owner_id)
	ray_color.a = 0.7
	
	var current_pos: Vector2 = ray_start
	var current_dir: Vector2 = ray_direction
	var bounces: int = 0
	var total_distance_traveled: float = 0.0

	while bounces < MAX_BOUNCES and total_distance_traveled < TOTAL_RAY_LENGTH:
		var remaining_length: float = TOTAL_RAY_LENGTH - total_distance_traveled
		var ray_end: Vector2 = current_pos + current_dir * remaining_length
		
		# Use a shorter ray segment for collision detection to avoid going through obstacles
		var collision_ray_length: float = remaining_length
		var collision_ray_end: Vector2 = current_pos + current_dir * collision_ray_length
		
		# Check for collisions with obstacles
		var collision_point: Vector2 = Vector2.ZERO
		var collision_normal: Vector2 = Vector2.ZERO
		var collision_found: bool = false
		
		# Check world edge collisions
		var world_edge_collision: Dictionary = _check_world_edge_collision(current_pos, collision_ray_end)
		if world_edge_collision["found"]:
			collision_point = world_edge_collision["point"]
			collision_normal = world_edge_collision["normal"]
			collision_found = true
		
		# Check obstacle collisions using simple point collision
		var simulation_areas: Array[Area] = []
		if get_parent().get_parent().game_simulation_component != null:
			simulation_areas = get_parent().get_parent().game_simulation_component.areas

		# Create ray line for collision detection
		var ray_line: PackedVector2Array = PackedVector2Array([current_pos, collision_ray_end])
		
		for obstacle: Area in map.original_unmerged_obstacles:
			# Check if ray segment intersects with obstacle polygon edges
			var reversed: PackedVector2Array = obstacle.polygon.duplicate()
			#reversed.reverse()
			var intersection_result: Dictionary = _check_ray_polygon_intersection(current_pos, collision_ray_end, reversed)
			if intersection_result["found"]:
				var closest_point: Vector2 = intersection_result["point"]
				var distance: float = current_pos.distance_to(closest_point)
				
				if not collision_found or distance < current_pos.distance_to(collision_point):
					collision_point = closest_point
					collision_normal = intersection_result["normal"]
					collision_found = true
		
		# Check boundary collisions using simple point collision
		var ray_current_area: Area = _get_original_area_at_point(current_pos)
		if ray_current_area != null:
			for adjacent_original_area: Area in map.adjacent_original_walkable_area[ray_current_area]:
				
				# Check if current area is activated but adjacent area is not
				var clicked_original_walkable_areas: Dictionary[int, bool] = {}
				if get_parent().get_parent().game_simulation_component != null:
					clicked_original_walkable_areas = get_parent().get_parent().game_simulation_component.clicked_original_walkable_areas
				
				var current_activated: bool = (
					not Global.only_expand_on_click(tank.owner_id) or
					clicked_original_walkable_areas.has(ray_current_area.polygon_id)
				)
				var adjacent_activated: bool = (
					not Global.only_expand_on_click(tank.owner_id) or
					clicked_original_walkable_areas.has(adjacent_original_area.polygon_id)
				)
				
				if current_activated and not adjacent_activated:
					# Check if ray segment intersects with adjacent non-activated area edges
					var intersection_result: Dictionary = _check_ray_polygon_intersection(current_pos, collision_ray_end, adjacent_original_area.polygon)
					if intersection_result["found"]:
						var closest_point: Vector2 = intersection_result["point"]
						var distance: float = current_pos.distance_to(closest_point)
						
						if not collision_found or distance < current_pos.distance_to(collision_point):
							collision_point = closest_point
							collision_normal = intersection_result["normal"]
							collision_found = true
		
		# Draw the ray segment
		if collision_found:
			var segment_distance: float = current_pos.distance_to(collision_point)
			total_distance_traveled += segment_distance
			draw_line(current_pos, collision_point, ray_color, 0.5, true)
			current_dir = current_dir.bounce(collision_normal).normalized()
			# Move slightly away from collision point to avoid detecting the same collision again
			current_pos = collision_point + current_dir * 1
			bounces += 1
			draw_circle(collision_point, 3.0, Color.YELLOW)
			#print("Bounce ", bounces, " at ", collision_point, " new direction: ", current_dir)
		else:
			var segment_distance: float = current_pos.distance_to(ray_end)
			total_distance_traveled += segment_distance
			draw_line(current_pos, ray_end, ray_color, 0.5, true)
			#print("No collision found, ray ended at ", ray_end)
			break



func _get_original_area_at_point(point: Vector2) -> Area:
	var map: Global.Map = null
	if get_parent().get_parent() != null:
		map = get_parent().get_parent().map
	
	if map == null:
		return null
	
	# Find which original walkable area contains this point
	for original_area: Area in map.original_walkable_areas:
		if Geometry2D.is_point_in_polygon(point, original_area.polygon):
			return original_area
	
	return null

func _intersect_polyline_with_polyline(polyline1: PackedVector2Array, polyline2: PackedVector2Array) -> Array[Vector2]:
	var intersections: Array[Vector2] = []
	
	# Check each segment of polyline1 against each segment of polyline2
	for i: int in range(polyline1.size() - 1):
		var seg1_start: Vector2 = polyline1[i]
		var seg1_end: Vector2 = polyline1[i + 1]
		
		for j: int in range(polyline2.size() - 1):
			var seg2_start: Vector2 = polyline2[j]
			var seg2_end: Vector2 = polyline2[j + 1]
			
			var intersection: Variant = Geometry2D.segment_intersects_segment(
				seg1_start, seg1_end, seg2_start, seg2_end
			)
			
			if intersection != null:
				intersections.append(intersection)
	
	return intersections

func _check_world_edge_collision(ray_start: Vector2, ray_end: Vector2) -> Dictionary:
	var result: Dictionary = {
		"found": false,
		"point": Vector2.ZERO,
		"normal": Vector2.ZERO
	}
	
	# Check if ray goes outside world bounds
	var world_size: Vector2 = Global.world_size
	
	# Check left edge (x = 0)
	if ray_start.x >= 0 and ray_end.x < 0:
		var t: float = ray_start.x / (ray_start.x - ray_end.x)
		var intersection: Vector2 = ray_start.lerp(ray_end, t)
		if intersection.y >= 0 and intersection.y <= world_size.y:
			result["found"] = true
			result["point"] = intersection
			result["normal"] = Vector2.RIGHT
			return result
	
	# Check right edge (x = world_size.x)
	if ray_start.x <= world_size.x and ray_end.x > world_size.x:
		var t: float = (world_size.x - ray_start.x) / (ray_end.x - ray_start.x)
		var intersection: Vector2 = ray_start.lerp(ray_end, t)
		if intersection.y >= 0 and intersection.y <= world_size.y:
			result["found"] = true
			result["point"] = intersection
			result["normal"] = Vector2.LEFT
			return result
	
	# Check top edge (y = 0)
	if ray_start.y >= 0 and ray_end.y < 0:
		var t: float = ray_start.y / (ray_start.y - ray_end.y)
		var intersection: Vector2 = ray_start.lerp(ray_end, t)
		if intersection.x >= 0 and intersection.x <= world_size.x:
			result["found"] = true
			result["point"] = intersection
			result["normal"] = Vector2.DOWN
			return result
	
	# Check bottom edge (y = world_size.y)
	if ray_start.y <= world_size.y and ray_end.y > world_size.y:
		var t: float = (world_size.y - ray_start.y) / (ray_end.y - ray_start.y)
		var intersection: Vector2 = ray_start.lerp(ray_end, t)
		if intersection.x >= 0 and intersection.x <= world_size.x:
			result["found"] = true
			result["point"] = intersection
			result["normal"] = Vector2.UP
			return result
	
	return result

func _check_ray_polygon_intersection(ray_start: Vector2, ray_end: Vector2, polygon: PackedVector2Array) -> Dictionary:
	var result: Dictionary = {
		"found": false,
		"point": Vector2.ZERO,
		"normal": Vector2.ZERO
	}
	
	if polygon.size() < 2:
		return result
	
	var closest_distance: float = INF
	var closest_point: Vector2 = Vector2.ZERO
	var closest_normal: Vector2 = Vector2.ZERO
	var ray_direction: Vector2 = (ray_end - ray_start).normalized()
	
	# Check ray against each polygon edge
	for i: int in range(polygon.size()):
		var edge_start: Vector2 = polygon[i]
		var edge_end: Vector2 = polygon[(i + 1) % polygon.size()]
		
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			ray_start, ray_end, edge_start, edge_end
		)
		
		if intersection != null:
			# Check if intersection is in front of the ray (not behind it)
			var to_intersection: Vector2 = intersection - ray_start
			if to_intersection.dot(ray_direction) > 0:
				var distance: float = ray_start.distance_to(intersection)
				if distance < closest_distance:
					closest_distance = distance
					closest_point = intersection
					# Calculate normal for this edge
					var edge_vector: Vector2 = edge_end - edge_start
					closest_normal = Vector2(-edge_vector.y, edge_vector.x).normalized()
	
	if closest_distance < INF:
		result["found"] = true
		result["point"] = closest_point
		result["normal"] = closest_normal
	
	return result
