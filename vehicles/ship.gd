extends Vehicle
class_name Ship

# Ship movement state
# current_node: The node in the water_graph where the ship is currently located
# next_node: The node the ship is moving toward
# path: The sequence of nodes the ship has traversed (for right-turn logic)
var current_node: Vector2 = Vector2.ZERO
var next_node: Vector2 = Vector2.ZERO
var path: Array = []

# Subclasses should override get_diameter, get_kind, and optionally _get_base_speed
# To initialize movement, set current_node and next_node to two connected nodes in water_graph, and path = [current_node, next_node]

func get_direction() -> Vector2:
	if next_node != current_node:
		return (next_node - current_node).normalized()
	return Vector2.RIGHT

func _get_base_speed() -> float:
	# Example base speed, can be overridden
	return 24.0*Global.GLOBAL_SPEED

static func terrain_multiplier_reduction() -> float:
	return INF
	
# Call this each tick to move the ship along the water graph
func move_along_water_graph(map: Global.Map, delta: float) -> void:
	if path.size() < 2:
		return
	var speed = get_speed(map)
	var dist_to_next = global_position.distance_to(next_node)
	if dist_to_next <= speed * delta:
		# Arrive at next node
		global_position = next_node
		current_node = next_node
		var neighbors = map.water_graph.get(current_node, [])
		var prev_node = path[path.size()-2]
		# Remove previous node from candidates for forward movement
		var forward_neighbors = []
		for n in neighbors:
			if n != prev_node:
				forward_neighbors.append(n)
		# If at a dead end (no forward neighbors), reverse direction
		if forward_neighbors.size() == 0:
			next_node = prev_node
			path.append(next_node)
			return
		# If in a lake, prefer to exit to a river if possible
		var in_lake = false
		for area in map.original_obstacles:
			if Geometry2D.is_point_in_polygon(current_node, area.polygon):
				in_lake = true
				break
		if in_lake:
			# Find a neighbor that is not in the lake (i.e., a river node)
			for n in forward_neighbors:
				var is_river = true
				for area in map.original_obstacles:
					if Geometry2D.is_point_in_polygon(n, area.polygon):
						is_river = false
						break
				if is_river:
					next_node = n
					path.append(next_node)
					return
		# Otherwise, pick the rightmost outgoing edge
		var prev_dir = (current_node - prev_node).normalized()
		var rightmost = forward_neighbors[0]
		var max_angle = -INF
		for n in forward_neighbors:
			var dir = (n - current_node).normalized()
			var angle = prev_dir.angle_to(dir)
			if angle < 0:
				angle += TAU
			if angle > max_angle:
				max_angle = angle
				rightmost = n
		next_node = rightmost
		path.append(next_node)
	else:
		# Move toward next node
		var dir = (next_node - global_position).normalized()
		global_position += dir * speed * delta

# Usage:
# - On placement, set current_node = <start node>, next_node = <neighbor>, path = [current_node, next_node]
# - Call move_along_water_graph(map, delta) each tick to move the ship
# - Ship will always turn right at junctions 

func collision_polygon() -> PackedVector2Array:
	var dir: Vector2 = get_direction().normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.DOWN
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var center: Vector2 = global_position
	var diameter: float = get_diameter()
	var hl: float = diameter * 0.5
	var hw: float = diameter * (1.0/3.0) * 0.5
	var side_len: float = hl * 0.60 # HULL_SIDE_FRAC

	# 6-point hull, matching ShipMesh
	var pts: Array[Vector2] = [
		Vector2(0, -hl), # bow (top)
		Vector2(hw, -side_len), # bow right
		Vector2(hw, side_len), # stern right
		Vector2(0, hl), # stern (bottom)
		Vector2(-hw, side_len), # stern left
		Vector2(-hw, -side_len), # bow left
	]

	# Transform points to world space
	var poly: PackedVector2Array = PackedVector2Array()
	for p in pts:
		# Local to world: x*right + y*dir + center
		poly.append(center + right * p.x + dir * p.y)
	poly.reverse()
	return poly
