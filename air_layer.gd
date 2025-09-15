extends Node2D
class_name AirLayer

enum State { SPAWNING, ALIVE, DYING }

# ─────────────── Tunables ───────────────
const slot_reach_time: float = 0.5
const spawn_fade_time: float = 0.25
const die_fade_time: float = 0.25
const max_speed: float = 2000.0
const min_speed: float = 100.0
const unit_size: int = 16
const unit_alpha: float = 1.0

const TOTAL_AIR_UNITS: int = 25  # Constant pool of air units
const MAX_AIR_UNITS_PER_AREA: int = 25  # Maximum airplanes per original area at full capacity
const AIR_UNIT_ORBIT_SPEED: float = 50  # radians per second
const AIR_SLOWDOWN_FACTOR: float = 0.75  # How much air units slow enemy expansion

# MultiMesh for GPU instancing
var _air_multimesh: MultiMesh
var _shadow_multimesh: MultiMesh
var _air_texture: Texture2D
var _shadow_texture: Texture2D
var texture_size: int = unit_size

# ─────────────── Air Agent ───────────────
class AirAgent:
	var group: Area  # Original area this unit is assigned to
	var pos: Vector2
	var vel: Vector2 = Vector2.ZERO
	var alpha: float = 0.0
	var state: int = State.SPAWNING
	var patrol_path: PackedVector2Array = PackedVector2Array()
	var patrol_progress: float = 0.0  # 0.0 to 1.0 along the patrol path
	var id: int = 0

# ─────────────── State ───────────────
var _air_agents: Array[AirAgent] = []
var _air_capacity_by_original_area: Dictionary[Area, float] = {}  # Original area -> air density
var _patrol_paths_by_original_area: Dictionary[Area, PackedVector2Array] = {}  # Original area -> patrol perimeter

func _ready() -> void:
	_setup_multimesh()

# ─────────────── Helpers ───────────────
func _sim() -> GameSimulationComponent:
	return get_parent().get_parent().game_simulation_component

# ─────────────── MultiMesh Setup ───────────────
func _setup_multimesh() -> void:
	_create_airplane_textures()
	_air_multimesh = _create_textured_multimesh()
	_shadow_multimesh = _create_textured_multimesh()
	queue_redraw()

func _create_textured_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _create_textured_quad_mesh()
	mm.instance_count = TOTAL_AIR_UNITS
	
	# Initialize all instances as transparent
	for i: int in range(TOTAL_AIR_UNITS):
		mm.set_instance_color(i, Color(1,1,1,0))
	
	return mm

func _create_textured_quad_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays : Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Quad vertices (centered at origin, matching unit_size)
	var hw: float = unit_size * 0.5
	var hh: float = unit_size * 0.5
	var vertices := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh),  # Triangle 1
		Vector2(-hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)   # Triangle 2  
	])
	
	# UV coordinates for texture mapping
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),  # Triangle 1
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)   # Triangle 2
	])
	
	# Colors (will be modulated by instance colors)
	var colors := PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE,
		Color.WHITE, Color.WHITE, Color.WHITE
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

func _create_airplane_textures() -> void:
	print("Creating airplane textures...")
	
	# Create airplane texture (no shadow)
	var airplane_viewport := SubViewport.new()
	airplane_viewport.size = Vector2i(texture_size, texture_size)
	airplane_viewport.transparent_bg = true
	
	var airplane_control := Control.new()
	airplane_control.size = Vector2(texture_size, texture_size)
	airplane_control.draw.connect(func(): _draw_airplane_symbol(airplane_control, texture_size))
	
	add_child(airplane_viewport)
	airplane_viewport.add_child(airplane_control)
	airplane_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_air_texture = airplane_viewport.get_texture()
	
	# Create shadow texture (only shadow)
	var shadow_viewport := SubViewport.new()
	shadow_viewport.size = Vector2i(texture_size, texture_size)
	shadow_viewport.transparent_bg = true
	
	var shadow_control := Control.new()
	shadow_control.size = Vector2(texture_size, texture_size)
	shadow_control.draw.connect(func(): _draw_shadow_symbol(shadow_control, texture_size))
	
	add_child(shadow_viewport)
	shadow_viewport.add_child(shadow_control)
	shadow_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_shadow_texture = shadow_viewport.get_texture()
	
	print("Airplane textures created: ", _air_texture, " ", _shadow_texture)

func _draw_airplane_symbol(control: Control, size: int) -> void:
	# Draw only the airplane (no shadow) - EXACTLY like UI
	var center: Vector2 = Vector2(size/2, size/2)
	var _scale: float = 1.0
	var col: Color = Color.WHITE
	
	# Draw simple airplane shape - EXACTLY like UI
	var length: float = size * _scale
	var wing_span: float = size * _scale
	
	# Airplane body (vertical line)
	var body_start: Vector2 = center + Vector2(0, -length * 0.5)
	var body_end: Vector2 = center + Vector2(0, length * 0.3)
	control.draw_line(body_start, body_end, col, size*0.125, true)
	
	# Wings (horizontal line)
	var wing_start: Vector2 = center + Vector2(-wing_span * 0.5, -length * 0.1)
	var wing_end: Vector2 = center + Vector2(wing_span * 0.5, -length * 0.1)
	control.draw_line(wing_start, wing_end, col, size*0.09375, true)
	
	# Tail wings (smaller horizontal line)
	var tail_span: float = wing_span * 0.4
	var tail_start: Vector2 = center + Vector2(-tail_span * 0.5, length * 0.2)
	var tail_end: Vector2 = center + Vector2(tail_span * 0.5, length * 0.2)
	control.draw_line(tail_start, tail_end, col, size*0.078125, true)

func _draw_shadow_symbol(control: Control, size: int) -> void:
	# Draw shadow - same shape as airplane, centered (offset handled in transform)
	var center: Vector2 = Vector2(size/2, size/2)
	var _scale: float = 1.0
	var shadow_col: Color = Color.BLACK
	
	# Draw simple airplane shadow - EXACTLY like airplane shape
	var length: float = size * _scale
	var wing_span: float = size * _scale
	
	# Shadow airplane body (vertical line) - centered like the main airplane
	var shadow_body_start: Vector2 = center + Vector2(0, -length * 0.5)
	var shadow_body_end: Vector2 = center + Vector2(0, length * 0.3)
	control.draw_line(shadow_body_start, shadow_body_end, shadow_col, size*0.125, true)
	
	# Shadow wings (horizontal line)
	var shadow_wing_start: Vector2 = center + Vector2(-wing_span * 0.5, -length * 0.1)
	var shadow_wing_end: Vector2 = center + Vector2(wing_span * 0.5, -length * 0.1)
	control.draw_line(shadow_wing_start, shadow_wing_end, shadow_col, size*0.09375, true)
	
	# Shadow tail wings (smaller horizontal line)
	var tail_span: float = wing_span * 0.4
	var shadow_tail_start: Vector2 = center + Vector2(-tail_span * 0.5, length * 0.2)
	var shadow_tail_end: Vector2 = center + Vector2(tail_span * 0.5, length * 0.2)
	control.draw_line(shadow_tail_start, shadow_tail_end, shadow_col, size*0.078125, true)

# ─────────────── Physics tick ───────────────
func _physics_process(delta: float) -> void:
	var sim: GameSimulationComponent = _sim()
	if sim == null:
		return
	
	_update_air_allocation(sim)
	_integrate_air_agents(delta)

# ─────────────── Air Allocation ───────────────
func _update_air_allocation(sim: GameSimulationComponent) -> void:
	_air_capacity_by_original_area.clear()
	_patrol_paths_by_original_area.clear()
	
	var target_original_areas: Array[Area] = []
	var total_intersection_area: float = 0.0
	
	# Find clicked original areas that have enemy intersections
	for original_area: Area in sim.map.original_walkable_areas:
		if not sim.clicked_original_walkable_areas.has(original_area.polygon_id):
			continue
		
		if not sim.intersecting_original_walkable_area_start_of_tick.has(original_area):
			continue
		
		# Calculate total enemy intersection area for this original area
		var enemy_intersection_area: float = 0.0
		var all_enemy_intersections: Array[PackedVector2Array] = []
		
		for area: Area in sim.intersecting_original_walkable_area_start_of_tick[original_area]:
			if area.owner_id == GameSimulationComponent.PLAYER_ID or area.owner_id < 0:
				continue
			
			# Collect all enemy intersection polygons
			var intersections: Array = sim.intersecting_original_walkable_area_start_of_tick[original_area][area]
			for intersection: PackedVector2Array in intersections:
				if not Geometry2D.is_polygon_clockwise(intersection):
					all_enemy_intersections.append(intersection)
					enemy_intersection_area += GeometryUtils.calculate_polygon_area(intersection)
		
		if enemy_intersection_area > 0.0:
			target_original_areas.append(original_area)
			total_intersection_area += enemy_intersection_area
			
			# Create patrol path from convex hull of all enemy intersections
			if all_enemy_intersections.size() > 0:
				var patrol_path: PackedVector2Array = _create_patrol_path_from_intersections(
					original_area,
					all_enemy_intersections
				)
				_patrol_paths_by_original_area[original_area] = patrol_path

	for original_area: Area in target_original_areas:
		_air_capacity_by_original_area[original_area] = get_air_capacity_by_original_area(original_area)
	
	# Update air agent count and allocation
	_sync_air_agent_counts(target_original_areas, sim)

func _create_patrol_path_from_intersections(
	original_area: Area,
	intersections: Array[PackedVector2Array]
) -> PackedVector2Array:
	# Collect all points from all intersection polygons
	#var all_points: PackedVector2Array = PackedVector2Array()
	#for intersection: PackedVector2Array in intersections:
		#var eps: float = 10
		#if GeometryUtils.calculate_polygon_area(intersection) < eps:
			#continue
		#for point: Vector2 in intersection:
			#all_points.append(point)
	#
	## Calculate convex hull of all points
	#var convex_hull: PackedVector2Array = Geometry2D.convex_hull(all_points)
	#
	## Ensure the patrol path is counter-clockwise for proper patrolling
	#if Geometry2D.is_polygon_clockwise(convex_hull):
		#convex_hull.reverse()
	#
	#var clipped_convex_hull: PackedVector2Array = GeometryUtils.find_largest_polygon(
		#Geometry2D.intersect_polygons(convex_hull, original_area.polygon)
	#)
	#var clipped_convex_hull_reduced: PackedVector2Array = GeometryUtils.find_largest_polygon(
		#Geometry2D.offset_polygon(
			#clipped_convex_hull,
			#-16,#-1.0*unit_size,
			#Geometry2D.JOIN_ROUND
		#)
	#)
	#if clipped_convex_hull_reduced.size() < 3:
		#return GeometryUtils.find_largest_polygon(
			#Geometry2D.offset_polygon(
				#original_area.polygon,
				#-16,#-1.0*unit_size,
				#Geometry2D.JOIN_ROUND
			#)
		#)
	#return clipped_convex_hull_reduced
#
	#return GeometryUtils.find_largest_polygon(
		#Geometry2D.offset_polygon(
			#original_area.polygon,
			#-48,#-1.0*unit_size,
			#Geometry2D.JOIN_ROUND
		#)
	#)
	
	#var reduced: PackedVector2Array = GeometryUtils.find_largest_polygon(
		#Geometry2D.offset_polygon(
			#GeometryUtils.find_largest_polygon(intersections),
			#-16,#-1.0*unit_size,
			#Geometry2D.JOIN_ROUND
		#)
	#)
	#if reduced.size() == 0:
	#return reduced

	return GeometryUtils.find_largest_polygon(intersections)
	#return GeometryUtils.find_largest_polygon(
		#Geometry2D.intersect_polygons(
			#GeometryUtils.find_largest_polygon(
				#Geometry2D.offset_polygon(
					#original_area.polygon,
					#-16,
					#Geometry2D.JOIN_ROUND,
				#)
			#),
			#GeometryUtils.find_largest_polygon(intersections)
		#)
	#)


func _sync_air_agent_counts(target_original_areas: Array[Area], sim: GameSimulationComponent) -> void:
	# Calculate desired air agents per original area based on enemy control percentage (CONTINUOUS)
	var desired_agents_continuous: Dictionary[Area, float] = {}
	var total_desired_float: float = 0.0
	
	for original_area: Area in target_original_areas:
		if not _air_capacity_by_original_area.has(original_area):
			continue

		var allocated_units: float = _air_capacity_by_original_area[original_area]
		desired_agents_continuous[original_area] = allocated_units
		total_desired_float += allocated_units
	
	# Scale down proportionally if we exceed total air units capacity
	# This keeps the continuous allocation proportional
	if total_desired_float > float(TOTAL_AIR_UNITS):
		var scale_factor: float = float(TOTAL_AIR_UNITS) / total_desired_float
		for original_area: Area in desired_agents_continuous.keys():
			desired_agents_continuous[original_area] = desired_agents_continuous[original_area] * scale_factor
	
	# Convert to discrete counts for visualization using proper distribution
	var desired_agents_int: Dictionary[Area, int] = _distribute_discrete_agents(desired_agents_continuous)
	
	# Count current agents per original area
	var current_agents: Dictionary[Area, int] = {}
	for agent: AirAgent in _air_agents:
		if agent.state != State.DYING:
			current_agents[agent.group] = current_agents.get(agent.group, 0) + 1
	
	# Spawn/kill agents as needed
	for original_area: Area in desired_agents_int.keys():
		var desired: int = desired_agents_int[original_area]
		var current: int = current_agents.get(original_area, 0)
		var diff: int = desired - current
		
		if diff > 0:
			for i in range(diff):
				_spawn_air_agent(original_area)
		elif diff < 0:
			_kill_air_agents(original_area, -diff)
	
	# Kill agents for original areas that are no longer targets
	for agent: AirAgent in _air_agents:
		if agent.state != State.DYING and agent.group not in target_original_areas:
			agent.state = State.DYING

func _spawn_air_agent(original_area: Area) -> void:
	var agent: AirAgent = AirAgent.new()
	agent.group = original_area
	
	# Set patrol path if available
	if _patrol_paths_by_original_area.has(original_area):
		agent.patrol_path = _patrol_paths_by_original_area[original_area]
	
	# Start at a random point along the patrol path
	if agent.patrol_path.size() > 0:
		agent.patrol_progress = randf()
		agent.pos = _get_position_along_patrol_path(agent.patrol_path, agent.patrol_progress)
	else:
		# Fallback to center of original area
		agent.pos = GeometryUtils.calculate_centroid(original_area.polygon)
	
	agent.id = agent.get_instance_id()
	_air_agents.append(agent)

func _kill_air_agents(original_area: Area, count: int) -> void:
	var killed: int = 0
	for agent: AirAgent in _air_agents:
		if killed >= count:
			break
		if agent.group == original_area and agent.state == State.ALIVE:
			agent.state = State.DYING
			killed += 1

func _get_position_along_patrol_path(patrol_path: PackedVector2Array, progress: float) -> Vector2:
	if patrol_path.size() < 2:
		return Vector2.ZERO
	
	# Calculate total path length
	var total_length: float = 0.0
	for i in range(patrol_path.size()):
		var next_i: int = (i + 1) % patrol_path.size()
		total_length += patrol_path[i].distance_to(patrol_path[next_i])
	
	# Find position at progress along the path
	var target_distance: float = progress * total_length
	var current_distance: float = 0.0
	
	for i in range(patrol_path.size()):
		var next_i: int = (i + 1) % patrol_path.size()
		var segment_length: float = patrol_path[i].distance_to(patrol_path[next_i])
		
		if current_distance + segment_length >= target_distance:
			var segment_progress: float = (target_distance - current_distance) / segment_length
			return patrol_path[i].lerp(patrol_path[next_i], segment_progress)
		
		current_distance += segment_length
	
	# Fallback to last point
	return patrol_path[patrol_path.size() - 1]

func _calculate_patrol_path_length(patrol_path: PackedVector2Array) -> float:
	if patrol_path.size() < 2:
		return 0.0
	
	var total_length: float = 0.0
	for i in range(patrol_path.size()):
		var next_i: int = (i + 1) % patrol_path.size()  # Wrap around for closed loop
		total_length += patrol_path[i].distance_to(patrol_path[next_i])
	
	return total_length

# ─────────────── Integration (movement) ───────────────
func _integrate_air_agents(delta: float) -> void:
	var i: int = 0
	while i < _air_agents.size():
		var agent: AirAgent = _air_agents[i]
		
		# Fade-in/fade-out handling
		if agent.state == State.SPAWNING:
			agent.alpha += delta / spawn_fade_time
			if agent.alpha >= unit_alpha:
				agent.alpha = unit_alpha
				agent.state = State.ALIVE
		elif agent.state == State.DYING:
			agent.alpha -= delta / die_fade_time
			if agent.alpha <= 0.0:
				_air_agents.remove_at(i)
				continue
		
		# Update patrol movement for alive agents
		if agent.state != State.DYING:
			# Update patrol path if it changed
			if _patrol_paths_by_original_area.has(agent.group):
				var current_patrol_path: PackedVector2Array = _patrol_paths_by_original_area[agent.group]
				if agent.patrol_path != current_patrol_path:
					agent.patrol_path = current_patrol_path
					# Recalculate position on new path
					if agent.patrol_path.size() > 0:
						agent.pos = _get_position_along_patrol_path(agent.patrol_path, agent.patrol_progress)
			
			# Move along patrol path
			if agent.patrol_path.size() > 0:
				# Advance along patrol path - normalize by path length for real velocity
				var patrol_path_length: float = _calculate_patrol_path_length(agent.patrol_path)
				var patrol_speed: float = (AIR_UNIT_ORBIT_SPEED * delta) / patrol_path_length if patrol_path_length > 0.0 else 0.0
				agent.patrol_progress += patrol_speed
				if agent.patrol_progress >= 1.0:
					agent.patrol_progress -= 1.0  # Loop back to start
				
				# Calculate target position
				var target_pos: Vector2 = _get_position_along_patrol_path(agent.patrol_path, agent.patrol_progress)
				
				# Smooth movement towards patrol position
				var to_target: Vector2 = target_pos - agent.pos
				var move_speed: float = min(max_speed, to_target.length() / slot_reach_time)
				move_speed = max(move_speed, min_speed)
				
				# Prevent overshoot - same logic as unit layer
				var distance_to_goal: float = to_target.length()
				if move_speed > distance_to_goal / delta:
					move_speed = distance_to_goal / delta
				
				if to_target.length() > 0.0:
					agent.vel = to_target.normalized() * move_speed
				else:
					agent.vel = Vector2.ZERO
				
				agent.pos += agent.vel * delta
			else:
				# No patrol path available, stay stationary
				agent.vel = Vector2.ZERO
		
		i += 1

# ─────────────── Drawing ───────────────
func _draw() -> void:
	_update_multimesh_instances()
	
	# Draw shadows first (behind airplanes)
	if _shadow_multimesh and _shadow_texture:
		draw_multimesh(_shadow_multimesh, _shadow_texture)
	
	# Draw airplanes on top
	if _air_multimesh and _air_texture:
		draw_multimesh(_air_multimesh, _air_texture)
	
	# Debug: Draw patrol paths
	#for original_area: Area in _patrol_paths_by_original_area.keys():
		#var patrol_path: PackedVector2Array = _patrol_paths_by_original_area[original_area]
		#if patrol_path.size() > 2:
			#var path_with_closure: PackedVector2Array = patrol_path.duplicate()
			#path_with_closure.append(patrol_path[0])  # Close the loop
			#draw_polyline(path_with_closure, Color.CYAN, 2.0)

func _update_multimesh_instances() -> void:
	if _air_multimesh == null or _shadow_multimesh == null:
		return
	
	# Clear all instances first
	for i: int in range(TOTAL_AIR_UNITS):
		_air_multimesh.set_instance_color(i, Color(1,1,1,0))
		_shadow_multimesh.set_instance_color(i, Color(1,1,1,0))
	
	# Update air agent instances
	var index: int = 0
	for agent: AirAgent in _air_agents:
		if agent.alpha > 0.01 and index < TOTAL_AIR_UNITS:
			#var agent_color: Color = Color.WHITE  # Air force color
			#agent_color.v *= 0.5
			#var agent_color: Color =agent_color = Color.DARK_CYAN
			var agent_color: Color = Global.get_vehicle_color(GameSimulationComponent.PLAYER_ID)
			agent_color = agent_color.darkened(0.2)
			agent_color.a = agent.alpha
			
			var shadow_color: Color = Color.BLACK
			shadow_color.a = agent.alpha * 0.5  # Shadow opacity
			
			# Both airplane and shadow should have same rotation
			var rotation_angle: float = 0.0
			if agent.vel.length() > 0.0:
				rotation_angle = agent.vel.angle() + PI/2  # +PI/2 because airplane points up
			
			# Airplane transform (rotates with movement)
			var airplane_transform: Transform2D = Transform2D()
			airplane_transform = airplane_transform.rotated(rotation_angle)
			airplane_transform.origin = agent.pos
			
			# Shadow transform (same rotation, but offset position)
			var shadow_offset: Vector2 = Vector2(16, 16)  # Fixed shadow offset in world coordinates
			var shadow_transform: Transform2D = Transform2D()
			shadow_transform = shadow_transform.rotated(rotation_angle)
			shadow_transform.origin = agent.pos + shadow_offset
			
			_air_multimesh.set_instance_transform_2d(index, airplane_transform)
			_air_multimesh.set_instance_color(index, agent_color)
			
			_shadow_multimesh.set_instance_transform_2d(index, shadow_transform)
			_shadow_multimesh.set_instance_color(index, shadow_color)
			
			index += 1

func get_air_capacity_by_original_area(original_area: Area) -> float:
	var sim: GameSimulationComponent = _sim()
	
	# Calculate percentage of original area controlled by enemies
	var enemy_percentage: float = _calculate_enemy_control_percentage(sim, original_area)
	
	if enemy_percentage <= 0.0:
		return 0.0
	
	# Allocate airplanes proportionally to enemy control percentage
	# Maximum of MAX_AIR_UNITS_PER_AREA airplanes per original area
	return enemy_percentage * float(MAX_AIR_UNITS_PER_AREA)

func _calculate_enemy_control_percentage(
	sim: GameSimulationComponent,
	original_area: Area
) -> float:
	# Only provide air cover for clicked (player-controlled) original areas
	if not sim.clicked_original_walkable_areas.has(original_area.polygon_id):
		return 0.0
	
	# No intersections means no enemy presence
	if not sim.intersecting_original_walkable_area_start_of_tick.has(original_area):
		return 0.0
	
	# Calculate total area of the original area
	var original_total_area: float = GeometryUtils.calculate_polygon_area(original_area.polygon)
	if original_total_area <= 0.0:
		return 0.0
	
	# Calculate total enemy-controlled area within this original area
	var enemy_controlled_area: float = 0.0
	for area: Area in sim.intersecting_original_walkable_area_start_of_tick[original_area]:
		# Skip player-owned and neutral areas
		if area.owner_id == GameSimulationComponent.PLAYER_ID or area.owner_id < 0:
			continue
			
		# Sum up all enemy intersection areas
		for intersect: PackedVector2Array in sim.intersecting_original_walkable_area_start_of_tick[original_area][area]:
			if not Geometry2D.is_polygon_clockwise(intersect):
				enemy_controlled_area += GeometryUtils.calculate_polygon_area(intersect)
	
	# Return percentage of original area controlled by enemies (0.0 to 1.0)
	return clamp(enemy_controlled_area / original_total_area, 0.0, 1.0)

func get_air_slowdown_multiplier(original_area: Area) -> float:
	#return 1.0
	
	if not _air_capacity_by_original_area.has(original_area):
		return 1.0

	# Use continuous density for slowdown calculation (not discrete visualization)
	var maximum_density: float = _air_capacity_by_original_area[original_area]
	if maximum_density <= 0.0:
		return 1.0
	
	var saturation: float = TOTAL_AIR_UNITS/get_desired_allocation_total()
	# More air units = more slowdown, but with diminishing returns
	# This uses the continuous allocation, so 2.5 planes gives different slowdown than 3 planes
	#return min(1-AIR_SLOWDOWN_FACTOR*(maximum_density/MAX_AIR_UNITS_PER_AREA), 1.0)
	var slowdown: float = min(1-AIR_SLOWDOWN_FACTOR*min(saturation, 1.0), 1.0)
	return slowdown
	
	
func _distribute_discrete_agents(continuous_allocation: Dictionary[Area, float]) -> Dictionary[Area, int]:
	# Use the Largest Remainder Method to distribute discrete agents
	# This ensures the total is always exactly TOTAL_AIR_UNITS (or the sum of continuous values)
	
	var discrete_allocation: Dictionary[Area, int] = {}
	var remainders: Array = []
	var total_continuous: float = 0.0
	
	# Calculate total continuous allocation
	for area: Area in continuous_allocation.keys():
		total_continuous += continuous_allocation[area]
	
	# If no allocation needed, return empty
	if total_continuous <= 0.0:
		return discrete_allocation
	
	# First pass: assign integer parts
	var total_assigned: int = 0
	for area: Area in continuous_allocation.keys():
		var continuous_value: float = continuous_allocation[area]
		var integer_part: int = int(continuous_value)
		var remainder: float = continuous_value - float(integer_part)
		
		discrete_allocation[area] = integer_part
		total_assigned += integer_part
		
		if remainder > 0.0:
			remainders.append({"area": area, "remainder": remainder})
	
	# Second pass: distribute remaining units based on largest remainders
	var target_total: int = int(round(total_continuous))
	var remaining_to_distribute: int = target_total - total_assigned
	
	# Sort by remainder (largest first)
	remainders.sort_custom(func(a, b): return a.remainder > b.remainder)
	
	# Assign remaining units to areas with largest remainders
	for i in range(min(remaining_to_distribute, remainders.size())):
		var area: Area = remainders[i].area
		discrete_allocation[area] += 1
	
	return discrete_allocation

func get_deployed_air_units_count() -> int:
	var deployed_count: int = 0
	for agent: AirAgent in _air_agents:
		if agent.state != State.DYING:
			deployed_count += 1
	return deployed_count

func get_desired_allocation_total() -> float:
	var total: float = 0.0
	for area: Area in _air_capacity_by_original_area.keys():
		total += _air_capacity_by_original_area[area]
	return total
