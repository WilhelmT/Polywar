class_name MapGenerator
extends Node

var rng = RandomNumberGenerator.new()

const BANK_OFFSET: float = 8.0

const GENERATION_ATTEMPTS: int = 100

const weights: Dictionary[String, float] = {
	"plains": 0.5,
	"forest": 0.3,
	"mountains": 0.2,
	"lake": 0.2
}

#const weights: Dictionary = {
	#"plains": 0.0,
	#"forest": 0.5,
	#"mountains": 0.5,
	#"lake": 0.2
#}

const use_floodfill_borders := true # Set to true to enable wavy borders

func setup_game(
	mode: Global.GameMode,
	areas: Array[Area],
	minimum_area_strength: float
) -> Global.Map:
	
	var map: Global.Map
	while true:		
		areas.clear()
		# Create world boundaries
		var world_boundary = PackedVector2Array([
			Vector2(0, 0),
			Vector2(Global.world_size.x, 0),
			Vector2(Global.world_size.x, Global.world_size.y),
			Vector2(0, Global.world_size.y)
		])
		world_boundary.reverse()
		areas.append(Area.new(Global.obstacle_color, world_boundary, -3))
		
		match mode:
			Global.GameMode.RANDOM:
				setup_random_game(areas, minimum_area_strength)
			Global.GameMode.CREATE:
				pass
		
		var unmerged_obstacles: Array[Area] = []
		for area in areas:
			if area.owner_id == -2:
				unmerged_obstacles.append(
					Area.new(
						area.color,
						area.polygon,
						area.owner_id,
						GeometryUtils.calculate_centroid(area.polygon)
					)
				)
		
		permanently_merge_obstacles(areas)
		
		map = Global.Map.new()
		var gen_water: bool = true
		if mode == Global.GameMode.CREATE:
			gen_water = false
		if update_map(map, areas, unmerged_obstacles, gen_water, {}):
			break
		
	return map

func spawn_base_for_original(
	map: Global.Map,
	original_area: Area,
	area: Area,
	owner_id: int,
	base_poly: PackedVector2Array
) -> void:
	if map.base_index_by_original_id.has(original_area.polygon_id):
		assert(false)													# Already has a base

	var base: Base = Base.new()
	
	base.polygon	= base_poly
	base.owner_id	= owner_id
	base.original_id= original_area.polygon_id
	
	map.base_index_by_original_id[original_area.polygon_id] = map.bases.size()
	map.bases.append(base)

func setup_random_game(areas: Array[Area], minimum_area_strength: float) -> void:
		areas.append_array(generate_voronoi_map(rng.randi_range(64, 64), true, minimum_area_strength))


func _build_walkable_adjacency(walkables: Array[Area]) -> Dictionary:
	var adjacency: Dictionary = {}
	for i: int in range(walkables.size()):
		var a: Area = walkables[i]
		adjacency[a.polygon_id] = []
	for i: int in range(walkables.size()):
		var a: Area = walkables[i]
		for j: int in range(i + 1, walkables.size()):
			var b: Area = walkables[j]
			if GeometryUtils.are_polygons_adjacent(a.polygon, b.polygon):
				adjacency[a.polygon_id].append(b.polygon_id)
				adjacency[b.polygon_id].append(a.polygon_id)
	return adjacency


func _walkable_is_connected(areas_all: Array[Area]) -> bool:
	var walkables: Array[Area] = []
	for area_it: Area in areas_all:
		if area_it.owner_id == -1:
			walkables.append(area_it)
	if walkables.is_empty():
		return true				# nothing to check
	# create adjacency (edge-touching only)
	var adj: Dictionary = _build_walkable_adjacency(walkables)
	# depth-first search
	var stack: Array[int] = [walkables[0].polygon_id]
	var visited: Dictionary = {}
	visited[walkables[0].polygon_id] = true
	while stack.size() > 0:
		var cur: int = stack.pop_back()
		for nb: int in adj[cur]:
			if visited.has(nb) == false:
				visited[nb] = true
				stack.append(nb)
	return visited.size() == walkables.size()


# Helper: Lloyd relaxation for seed points
func lloyd_relaxation(seed_points: Array, iterations: int) -> Array:
	var points = seed_points.duplicate()
	for _i: int in range(iterations):
		var voronoi = generate_voronoi_cells(points)
		var new_points = []
		for center in points:
			var cell = voronoi[center]
			if cell.size() == 0:
				continue
			# Compute centroid
			var centroid = Vector2.ZERO
			for pt in cell:
				centroid += pt
			centroid /= cell.size()
			new_points.append(centroid)
		points = new_points
	return points

func _safe_round(point: Vector2) -> Vector2:
		var eps: float = 0.01
		return Vector2(max(int(point.x), int(point.x+eps)), max(int(point.y), int(point.y+eps)))
	
func generate_voronoi_map(
	num_points: int,
	add_obstacles: bool,
	minimum_area_strength: float
) -> Array[Area]:
	var num_areas = num_points
	var total_cells = num_areas

	# 2. Generate seed points for Voronoi cells
	var seed_points = []
	var world_area = Global.world_size.x * Global.world_size.y
	var point_density = total_cells / world_area
	var min_distance = sqrt(1.0 / point_density) * 0.75
	var max_attempts = total_cells * 10
	var attempts = 0
	while seed_points.size() < total_cells and attempts < max_attempts:
		attempts += 1
		var x = rng.randf_range(0, Global.world_size.x)
		var y = rng.randf_range(0, Global.world_size.y)
		var new_point = Vector2(x, y)
		var too_close = false
		for existing in seed_points:
			if existing.distance_to(new_point) < min_distance:
				too_close = true
				break
		if not too_close:
			seed_points.append(new_point)

	print("seed_points count: ", seed_points.size())

	# 3. Lloyd relaxation (3 iterations)
	seed_points = lloyd_relaxation(seed_points, 3)

	# 4. Generate Voronoi diagram
	var voronoi_cells: Dictionary[Vector2, PackedVector2Array] = generate_voronoi_cells(seed_points)
	print("voronoi_cells count: ", voronoi_cells.size())

	for center_point: Vector2  in voronoi_cells.keys():
		var cell: PackedVector2Array = voronoi_cells[center_point]
		assert(cell.size() >= 3)
		# This is important to avoid floating point issues around vertices,
		# e.g. merging two obstacles that are "just" adjacent.
		var integer_cell: PackedVector2Array = []
		for point in cell:
			integer_cell.append(_safe_round(point))
		voronoi_cells[center_point] = integer_cell
	
	if use_floodfill_borders:
		# Build adjacency for all cells
		var cell_centers = voronoi_cells.keys()
		var cell_adjacency = {}
		for i in range(cell_centers.size()):
			var a = cell_centers[i]
			cell_adjacency[a] = []
		for i in range(cell_centers.size()):
			var a = cell_centers[i]
			var poly_a = voronoi_cells[a]
			for j in range(i+1, cell_centers.size()):
				var b = cell_centers[j]
				var poly_b = voronoi_cells[b]
				if GeometryUtils.are_polygons_adjacent(poly_a, poly_b):
					cell_adjacency[a].append(b)
					cell_adjacency[b].append(a)
		
		
		# For each pair of adjacent cells, replace shared border with wavy border
		var processed_pairs = {}
		for i in range(cell_centers.size()):
			var a = cell_centers[i]
			for b in cell_adjacency[a]:
				var pair_key = str(min(a.x, b.x), ",", min(a.y, b.y), "-", max(a.x, b.x), ",", max(a.y, b.y))
				if processed_pairs.has(pair_key):
					continue
				processed_pairs[pair_key] = true
				# Find shared polyline
				var poly_a = voronoi_cells[a]
				var poly_b = voronoi_cells[b]
				var shared = MapGenerator._get_shared_border_between_polygons(poly_a, poly_b)
				if shared.size() >= 2:
					var wavy = make_wavy_border_polyline(shared, 8.0, 2)
					# Find indices in both polygons
					var idx_a = find_polyline_indices(poly_a, shared)
					var idx_b = find_polyline_indices(poly_b, shared)
					if idx_a["start"] == -1 or idx_b["start"] == -1:
						print("[WAVY] Shared polyline not found in one of the polygons!", a, b)
						continue
					# Remove old points (excluding endpoints) and insert wavy points in both polygons
					var pairs = [[poly_a, idx_a], [poly_b, idx_b]]
					for p in pairs:
						var poly = p[0]
						var idx = p[1]
						var remove_count = shared.size() - 2
						var insert_at = (idx["start"] + 1) % poly.size()
						for _r in range(remove_count):
							poly.remove_at(insert_at % poly.size())
						# Insert wavy points (excluding endpoints)
						var wavy_points = wavy.duplicate()
						if idx["reversed"]:
							wavy_points = reverse_packed_vector2array(wavy_points)
						for m in range(1, wavy_points.size()-1):
							poly.insert(insert_at + m - 1, wavy_points[m])
					# Update the voronoi_cells dict
					voronoi_cells[a] = poly_a
					voronoi_cells[b] = poly_b
		
		# Repeat after waves introduces.
		#for center_point: Vector2  in voronoi_cells.keys():
			#var cell: PackedVector2Array = voronoi_cells[center_point]
			#assert(cell.size() >= 3)
			## This is important to avoid floating point issues around vertices,
			## e.g. merging two obstacles that are "just" adjacent.
			#var integer_cell: PackedVector2Array = []
			#for point in cell:
				#integer_cell.append(Vector2i(point))
			#voronoi_cells[center_point] = cell
		
	var areas: Array[Area] = []
	for center_point: Vector2  in voronoi_cells.keys():
		var integer_cell: PackedVector2Array = voronoi_cells[center_point]
	
		var actual_center_point: Vector2 = GeometryUtils.calculate_centroid(integer_cell)
		var area: Area = Area.new(
			Global.neutral_color,
			integer_cell,
			-1,
			actual_center_point
		)
		areas.append(area)

	# 8. Assign some areas as lakes/obstacles
	for original_area in areas:
		var become_obstacle = false
		if add_obstacles and randf() < weights["lake"]:
			become_obstacle = true
		if become_obstacle:
			original_area.owner_id = -2
			original_area.color = Global.obstacle_color
			if _walkable_is_connected(areas) == false:
				original_area.owner_id = -1
				original_area.color = Global.neutral_color
	return areas

# Generate Voronoi cells from seed points using the Fortune's algorithm approach
func generate_voronoi_cells(seed_points: Array) -> Dictionary[Vector2, PackedVector2Array]:
	var voronoi_cells: Dictionary[Vector2, PackedVector2Array] = {}
	
	# 1. Create a bounding box larger than the world size to ensure all cells are closed
	var padding = 300  # Extra space around the world to ensure closed polygons
	var bounds = Rect2(
		-padding, -padding, 
		Global.world_size.x + 2*padding, Global.world_size.y + 2*padding
	)
	
	# 2. For each seed point, calculate its Voronoi cell
	for i: int in range(seed_points.size()):
		var cell_vertices = compute_voronoi_cell(seed_points[i], seed_points, i, bounds)
		if cell_vertices.size() >= 3:
			#var integer_cell_vertices: PackedVector2Array = PackedVector2Array()
			#for voroni_point in cell_vertices:
			#	integer_cell_vertices.append(Vector2i(voroni_point))
			#cell_vertices = integer_cell_vertices
			#voronoi_cells[seed_points[i]] = PackedVector2Array(cell_vertices)
			
			voronoi_cells[seed_points[i]] = cell_vertices
			
	return voronoi_cells

# Compute a single Voronoi cell for a seed point
func compute_voronoi_cell(center: Vector2, all_points: Array, center_index: int, bounds: Rect2) -> PackedVector2Array:
	# This function computes a Voronoi cell by:
	# 1. Finding all perpendicular bisectors between this point and all other points
	# 2. Finding the intersection of half-planes defined by these bisectors
	
	# Start with the bounding box as the initial polygon
	var vertices = [
		Vector2(bounds.position.x, bounds.position.y),
		Vector2(bounds.position.x + bounds.size.x, bounds.position.y),
		Vector2(bounds.position.x + bounds.size.x, bounds.position.y + bounds.size.y),
		Vector2(bounds.position.x, bounds.position.y + bounds.size.y)
	]
	
	# For each other point, clip the polygon with the perpendicular bisector
	for j in range(all_points.size()):
		if j == center_index:
			continue
			
		var other = all_points[j]
		
		# Calculate the midpoint between the center and other point
		var midpoint = (center + other) / 2.0
		
		# Calculate the perpendicular direction (normal) to the line between points
		var direction = (other - center).normalized()
		var normal = Vector2(-direction.y, direction.x)
		
		# Define a line through the midpoint in the normal direction
		var line_start = midpoint
		var line_end = midpoint + normal * 1000  # Long enough to intersect with polygon
		
		# Clip the current polygon with this half-plane
		vertices = clip_polygon_with_line(vertices, line_start, line_end, center, other)
		
		# If too few vertices remain, this cell is invalid
		if vertices.size() < 3:
			break
	
	# Clip against world boundary to ensure we stay in bounds
	var world_rect = Rect2(0, 0, Global.world_size.x, Global.world_size.y)
	vertices = clip_polygon_with_rect(vertices, world_rect)
	
	return PackedVector2Array(vertices)

# Helper function to clip a polygon with a line
func clip_polygon_with_line(vertices: Array, line_start: Vector2, line_end: Vector2, 
							center: Vector2, other: Vector2) -> Array:
	var result = []
	var line_dir = (line_end - line_start).normalized()
	
	# Determine which side of the line to keep (the one containing center)
	var center_side = sign((center - line_start).cross(line_dir))
	
	for i in range(vertices.size()):
		var current = vertices[i]
		var next = vertices[(i + 1) % vertices.size()]
		
		# Check which side of the line the current vertex is on
		var current_side = sign((current - line_start).cross(line_dir))
		var next_side = sign((next - line_start).cross(line_dir))
		
		# If current vertex is on the correct side (or on the line), keep it
		if current_side == center_side or current_side == 0:
			result.append(current)
		
		# If the edge crosses the line, add the intersection point
		if current_side != next_side and current_side != 0 and next_side != 0:
			var intersection = line_intersection(current, next, line_start, line_end)
			if intersection != null:
				result.append(intersection)
	
	return result

# Helper function to find intersection of two line segments
func line_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2):
	var denominator = (b.x - a.x) * (d.y - c.y) - (b.y - a.y) * (d.x - c.x)
	
	if denominator == 0:
		return null  # Lines are parallel
	
	var t = ((c.x - a.x) * (d.y - c.y) - (c.y - a.y) * (d.x - c.x)) / denominator
	
	return Vector2(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y))

# Helper function to clip a polygon against a rectangle
func clip_polygon_with_rect(vertices: Array, rect: Rect2) -> Array:
	# Clip against each edge of the rectangle
	var result = vertices
	
	# Left edge
	result = clip_polygon_with_line(result, Vector2(rect.position.x, rect.position.y), 
									Vector2(rect.position.x, rect.position.y + rect.size.y),
									Vector2(rect.position.x + 1, rect.position.y), 
									Vector2(rect.position.x - 1, rect.position.y))
	
	# Right edge
	result = clip_polygon_with_line(result, Vector2(rect.position.x + rect.size.x, rect.position.y), 
									Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
									Vector2(rect.position.x + rect.size.x - 1, rect.position.y), 
									Vector2(rect.position.x + rect.size.x + 1, rect.position.y))
	
	# Top edge
	result = clip_polygon_with_line(result, Vector2(rect.position.x, rect.position.y), 
									Vector2(rect.position.x + rect.size.x, rect.position.y),
									Vector2(rect.position.x, rect.position.y + 1), 
									Vector2(rect.position.x, rect.position.y - 1))
	
	# Bottom edge
	result = clip_polygon_with_line(result, Vector2(rect.position.x, rect.position.y + rect.size.y), 
									Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
									Vector2(rect.position.x, rect.position.y + rect.size.y - 1), 
									Vector2(rect.position.x, rect.position.y + rect.size.y + 1))
	
	return result

func assign_terrain_type() -> String:	
	#return "plains" 
	
	var terrain_types = ["plains", "forest", "mountains"]	
	
	# Simple random assignment
	var rand_val = randf()
	var cumulative = 0.0

	for i in range(terrain_types.size()):
		cumulative += weights[terrain_types[i]]
		if rand_val <= cumulative:
			return terrain_types[i]
	
	assert(false)
	return "plains" 


func calculate_adjacent_original_walkable_area(original_walkable_areas: Array[Area]) -> Dictionary[Area, Array]:
	var adjacency:  Dictionary[Area, Array] = {}
	
	# Cache bounding boxes for quick checks
	var bounding_boxes = {}
	for original_area in original_walkable_areas:
		bounding_boxes[original_area] = GeometryUtils.calculate_bounding_box(original_area.polygon)
	
	# Build adjacency list
	for i in range(original_walkable_areas.size()):
		var original_area_a = original_walkable_areas[i]
		
		if not adjacency.has(original_area_a):
			adjacency[original_area_a] = []
		
		for j in range(i + 1, original_walkable_areas.size()):
			var original_area_b = original_walkable_areas[j]
			
			# Quick bounding box check first
			if GeometryUtils.are_bounding_boxes_overlapping(bounding_boxes[original_area_a], bounding_boxes[original_area_b]):
				# Check if polygons are adjacent
				if GeometryUtils.are_polygons_adjacent(original_area_a.polygon, original_area_b.polygon):
					if not adjacency.has(original_area_b):
						adjacency[original_area_b] = []
					
					# Mark them as adjacent to each other
					adjacency[original_area_a].append(original_area_b)
					adjacency[original_area_b].append(original_area_a)
	
	return adjacency


func permanently_merge_obstacles(areas: Array[Area]) -> void:
	var owner_id: int = -2
	var owned_areas: Array[Area] = areas.filter(func(area): return area.owner_id == owner_id)
	
	# Keep trying to merge until no more merges are possible
	var merged_something = true
	while merged_something:
		merged_something = false
		
		for i in range(owned_areas.size()):
			if merged_something:
				break
			if i >= owned_areas.size():  # Size might change during iteration
				break
				
			var area1 = owned_areas[i]
			
			# Skip if this area was already merged and removed
			if not areas.has(area1):
				continue
				
			for j in range(i+1, owned_areas.size()):
				if merged_something:
					break
				if j >= owned_areas.size():  # Size might change during iteration
					break
					
				var area2 = owned_areas[j]
				
				# Skip if this area was already merged and removed
				if not areas.has(area2):
					continue
				
				# Check if any polygons from area1 are adjacent to any polygons from area2
				if GeometryUtils.are_polygons_adjacent(area1.polygon, area2.polygon):
					# Merge the polygons
					var merged_polygons = GeometryUtils.merge_polygons(area1.polygon, area2.polygon)
					if merged_polygons.size() > 0:  # Successful merge
						var result = GeometryUtils.split_into_inner_outer_polygons(merged_polygons)
						var outer_merged_polygons = result[0]
						if outer_merged_polygons.size()==1:
							area1.polygon = outer_merged_polygons[0]
							areas.erase(area2)
							owned_areas.erase(area2)
							merged_something = true

func calculate_adjacent_original_walkable_area_bounds(original_walkable_areas: Array[Area]) -> Dictionary[Area, Dictionary]:
	var area_bounds: Dictionary[Area, Dictionary] = {}
	for area in original_walkable_areas:
		var min_x = INF
		var min_y = INF
		var max_x = -INF
		var max_y = -INF
		
		# Calculate bounding box for each area's polygon
		for p in area.polygon:
			min_x = min(min_x, p.x)
			min_y = min(min_y, p.y)
			max_x = max(max_x, p.x)
			max_y = max(max_y, p.y)
		
		# Store area index and its bounds
		area_bounds[area] ={
			"polygon_id": area.polygon_id,
			"min_x": min_x,
			"min_y": min_y,
			"max_x": max_x,
			"max_y": max_y
		}
	return area_bounds

func calculate_optimal_grid_size(num_areas: int) -> float:
	var total_area = Global.world_size.x * Global.world_size.y 
	var avg_area_diameter = sqrt(total_area / num_areas)
	return avg_area_diameter
	
func setup_area_spatial_grid(
	areas: Array[Area],
	original_walkable_area_bounds: Dictionary[Area, Dictionary],
) -> Global.SpatialGrid:
	var area_spatial_grid: Dictionary[Vector2i, Array]
	
	var grid_cell_size: float = calculate_optimal_grid_size(areas.size())
	
	for i in range(areas.size()):
		var area = areas[i]
		var bounds = original_walkable_area_bounds[area]
		
		var min_grid_x = int(bounds["min_x"] / grid_cell_size)
		var min_grid_y = int(bounds["min_y"] / grid_cell_size)
		var max_grid_x = int(bounds["max_x"] / grid_cell_size)
		var max_grid_y = int(bounds["max_y"] / grid_cell_size)
		
		# Add this area to all grid cells it overlaps
		for grid_x in range(min_grid_x, max_grid_x + 1):
			for grid_y in range(min_grid_y, max_grid_y + 1):
				var grid_key = Vector2i(grid_x, grid_y)
				if !area_spatial_grid.has(grid_key):
					area_spatial_grid[grid_key] = []
				area_spatial_grid[grid_key].append(area)
	var spatial_grid: Global.SpatialGrid = Global.SpatialGrid.new()
	spatial_grid.grid_cell_size = grid_cell_size
	spatial_grid.area_spatial_grid = area_spatial_grid
	return spatial_grid

# Return the ordered poly-line of every edge that polygon_a and polygon_b share.
static func _get_shared_border_between_polygons(poly_a: PackedVector2Array, poly_b: PackedVector2Array) -> PackedVector2Array:
	var shared: Array = []
	for i in range(poly_a.size()):
		var a0 = poly_a[i]
		var a1 = poly_a[(i+1)%poly_a.size()]
		for j in range(poly_b.size()):
			var b0 = poly_b[j]
			var b1 = poly_b[(j+1)%poly_b.size()]
			if (a0 == b1 and a1 == b0) or (a0 == b0 and a1 == b1):
				shared.append([a0, a1])
	if shared.size() == 0:
		return PackedVector2Array()
	# Now chain together all shared edges into a polyline
	var border = [shared[0][0], shared[0][1]]
	shared.remove_at(0)
	while shared.size() > 0:
		var extended = false
		for k in range(shared.size()):
			var e0 = shared[k][0]
			var e1 = shared[k][1]
			if border[border.size()-1] == e0:
				border.append(e1)
				shared.remove_at(k)
				extended = true
				break
			elif border[border.size()-1] == e1:
				border.append(e0)
				shared.remove_at(k)
				extended = true
				break
			elif border[0] == e0:
				border.insert(0, e1)
				shared.remove_at(k)
				extended = true
				break
			elif border[0] == e1:
				border.insert(0, e0)
				shared.remove_at(k)
				extended = true
				break
		if not extended:
			break
	return PackedVector2Array(border)


func calculate_shared_borders(
	original_walkable_areas: Array[Area]
) -> Dictionary[Area, Dictionary]:
	var shared: Dictionary[Area, Dictionary] = {}

	for i: int in range(original_walkable_areas.size()):
		var area_a: Area = original_walkable_areas[i]
		if not shared.has(area_a):
			shared[area_a] = {}
		
		for j: int in range(i + 1, original_walkable_areas.size()):
			var area_b: Area = original_walkable_areas[j]

			# Only proceed if the polygons actually touch.
			if GeometryUtils.are_polygons_adjacent(area_a.polygon, area_b.polygon):
				var border: PackedVector2Array = _get_shared_border_between_polygons(
					area_a.polygon,
					area_b.polygon
				)
				if border.size() >= 2:
					shared[area_a][area_b] = [border]
					if not shared.has(area_b):
						shared[area_b] = {}
					shared[area_b][area_a] = [PackedVector2Array(border)]
	return shared

func _point_is_in_list(p: Vector2, list: Array[Vector2]) -> bool:
	for q: Vector2 in list:
		if q == p:
			return true
	return false

func _compute_bank(
		river: PackedVector2Array,
		side_sign: float,      # −1 = left, +1 = right (looking downstream)
		offset: float
) -> PackedVector2Array:
	var bank: PackedVector2Array = PackedVector2Array()

	for i: int in range(river.size()):
		var cur: Vector2 = river[i]

		# ---- NORMAL OF CURRENT CORNER ----
		var n_vec: Vector2

		if i == 0:
			var dir: Vector2 = (river[1] - cur).normalized()
			n_vec = Vector2(-dir.y, dir.x)               # left normal
		elif i == river.size() - 1:
			var dir: Vector2 = (cur - river[i - 1]).normalized()
			n_vec = Vector2(-dir.y, dir.x)
		else:
			var dir_prev: Vector2 = (cur - river[i - 1]).normalized()
			if dir_prev == Vector2.ZERO:
				continue
			var dir_next: Vector2 = (river[i + 1] - cur).normalized()
			var n_prev: Vector2 = Vector2(-dir_prev.y, dir_prev.x)
			var n_next: Vector2 = Vector2(-dir_next.y, dir_next.x)

			# bisector on the **requested** side
			n_vec = (n_prev * side_sign + n_next * side_sign).normalized()

			# if the corner is 180 °, fall back to one segment's normal
			if n_vec == Vector2.ZERO:
				n_vec = n_prev * side_sign

			# ---- ADJUST LENGTH SO THE GAP STAYS CONSTANT ----
			var denom: float = n_vec.dot(n_prev * side_sign)   # = cos(½ θ)
			assert(denom > 0)
			var adjusted_offset: float = offset / denom        # <- magic line
			bank.append(cur + n_vec * adjusted_offset)
			continue         # done with interior vertex

		# straight endpoints – no angle correction needed
		bank.append(cur + n_vec * offset * side_sign)

	return bank

func _extend_bank_endpoints(
	bank: PackedVector2Array,
	push: float,
	obstacle: PackedVector2Array,
) -> void:
	if bank.size() < 2:
		return
	# start‐point
	if Global.is_point_on_world_edge(bank[0]):
		assert(bank[0] != bank[1])
		var dir_start: Vector2 = (bank[0] - bank[1]).normalized()
		bank[0] += dir_start * push
	# end-point
	var last: int = bank.size() - 1
	if Global.is_point_on_world_edge(bank[last]) or obstacle.size() > 0:
		assert(bank[last] != bank[last - 1])
		var dir_end: Vector2 = (bank[last] - bank[last - 1]).normalized()
		bank[last] += dir_end * (push if obstacle.size() == 0 else push/2.0)

# Modify the generate_rivers method to compute and store banks
func generate_rivers(
	map: Global.Map,
	use_total_length: bool = true
) -> bool:	
	map.rivers.clear()
	map.river_segments.clear()
	map.original_walkable_area_river_neighbors.clear()
	map.river_banks.clear()
	map.river_end_confluences.clear()
	
	var max_total_len: float = sqrt(Global.world_size.x*Global.world_size.y)*3.0
	var min_total_len: float = max_total_len/2
	
	var target_total_len: float = rng.randf_range(min_total_len, max_total_len)
	var current_total_len: float = 0.0

	var num_rivers: int = 0
	if use_total_length == false:
		num_rivers = rng.randi_range(1, 3)

	# Initialize original_walkable_area_river_neighbors for all areas
	for area: Area in map.original_walkable_areas + map.original_obstacles:
		map.original_walkable_area_river_neighbors[area] = []
	
	# Get all boundary segments between adjacent areas
	var boundary_segments: Array[Dictionary] = _get_all_boundary_segments(map)
	
	var used_edge_points: Array[Vector2] = []	# NEW

	var river_index: int = 0
	var attempts_left: int = GENERATION_ATTEMPTS + 1
	while attempts_left > 0:
		attempts_left -= 1
	
		# stop condition for the selected mode
		if use_total_length == false:
			if river_index >= num_rivers:
				break
		else:
			if current_total_len >= target_total_len:
				break

		var result: Dictionary = _generate_single_river(
			boundary_segments,
			map,
			used_edge_points
		)
		var river: PackedVector2Array = result["poly"] 
		river = GeometryUtils.remove_duplicate_points(river)
		var obstacle: PackedVector2Array = result["obstacle"]
		var conf_point: Vector2 = result["confluence_point"]
		var conf_impacted: int = result["confluence_impacted_index"]
		if river.size() <= 1:
			continue
		
		map.rivers.append(river)
		
		var end_obstacle_info: Dictionary = {
			"obstacle": obstacle,
			"left_bank_info": {},
			"right_bank_info": {},
		}
		# Compute and store river banks
		var extended_river: PackedVector2Array = river.duplicate()
		_extend_bank_endpoints(extended_river, BANK_OFFSET, obstacle)
		var bank_left: PackedVector2Array = _compute_bank(extended_river, -1.0, BANK_OFFSET)
		var bank_right: PackedVector2Array = _compute_bank(extended_river, 1.0, BANK_OFFSET)
		if obstacle.size() > 0:
			var bank_left_info: Dictionary = GeometryUtils.clamp_point_to_polygon_with_edge_info(obstacle, bank_left[-1])
			var bank_right_info: Dictionary = GeometryUtils.clamp_point_to_polygon_with_edge_info(obstacle, bank_right[-1])
			bank_left.append(bank_left_info["point"])
			bank_right.append(bank_right_info["point"])
			end_obstacle_info["left_bank_info"] = bank_left_info
			end_obstacle_info["right_bank_info"] = bank_right_info
		map.river_end_obstacles.append(end_obstacle_info)
		
		map.river_banks.append({
			"left": bank_left,
			"right": bank_right
		})

		# Store confluence information for background drawer
		if conf_impacted >= 0:
			var entry: Dictionary = {}
			entry["point"] = conf_point
			entry["impacted_river_index"] = conf_impacted
			entry["hitting_river_index"] = river_index
			map.river_end_confluences.append(entry)

		_add_river_segments_to_lookup(river, map, river_index)
		_update_original_walkable_area_river_neighbors(river, boundary_segments, map)
		
		# keep world-edge locks
		if Global.is_point_on_world_edge(river[0]):
			used_edge_points.append(river[0])
		if Global.is_point_on_world_edge(river[river.size() - 1]):
			used_edge_points.append(river[river.size() - 1])
		
		# accumulate length when needed
		if use_total_length == true:
			var river_len: float = 0.0
			for j: int in range(river.size() - 1):
				river_len += river[j].distance_to(river[j + 1])
			current_total_len += river_len
		
		river_index += 1

	if attempts_left == 0:
		return false
	return true
		
func _get_all_boundary_segments(map: Global.Map) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var processed_pairs: Dictionary[String, bool] = {}
	var game_world: Rect2 = Rect2(0, 0, Global.world_size.x, Global.world_size.y)
	for area_a: Area in map.original_walkable_area_shared_borders.keys():
		var neighbors_dict: Dictionary = map.original_walkable_area_shared_borders[area_a]
		if area_a.owner_id == -3: continue
		for area_b: Area in neighbors_dict.keys():
			if area_b.owner_id == -3: continue
			var pair_key: String = str(min(area_a.polygon_id, area_b.polygon_id)) + "-" + str(max(area_a.polygon_id, area_b.polygon_id))
			if processed_pairs.has(pair_key):
				continue
			processed_pairs[pair_key] = true
			var shared_border: PackedVector2Array = MapGenerator._get_shared_border_between_polygons(area_a.polygon, area_b.polygon)
			# Store the full polyline as a single segment for river traversal
			if shared_border.size() >= 2:
				var segment: PackedVector2Array = PackedVector2Array([shared_border[0], shared_border[shared_border.size() - 1]])
				if _segment_intersects_world(segment, game_world):
					segments.append({
						"segment": segment,
						"area_a": area_a,
						"area_b": area_b,
						"polyline": shared_border
					})
	# To allow termination in obstacles.
	for walkable: Area in map.original_walkable_areas:
		for obstacle: Area in map.original_obstacles:
			var pair_key: String = str(min(walkable.polygon_id, obstacle.polygon_id)) + "-" + str(max(walkable.polygon_id, obstacle.polygon_id))
			if processed_pairs.has(pair_key):
				continue
			if GeometryUtils.are_polygons_adjacent(walkable.polygon, obstacle.polygon):
				processed_pairs[pair_key] = true
				var border: PackedVector2Array = MapGenerator._get_shared_border_between_polygons(walkable.polygon, obstacle.polygon)
				if border.size() >= 2:
					var seg: PackedVector2Array = PackedVector2Array([border[0], border[border.size() - 1]])
					if _segment_intersects_world(seg, game_world):
						segments.append({
							"segment": seg,
							"area_a": walkable,
							"area_b": obstacle,
							"polyline": border
						})
	return segments

func _segment_intersects_river(
		segment: PackedVector2Array,
		river_segments: Array[PackedVector2Array],
		shared_vertex: Vector2
	) -> bool:
	# Reject any segment that crosses one already laid-down for this same river,
	# except where they merely meet at the current growth vertex.
	for existing: PackedVector2Array in river_segments:
		if _segments_intersect(segment, existing):
			var touches_at_shared: bool = (segment[0] == shared_vertex or segment[1] == shared_vertex) and \
				(existing[0] == shared_vertex or existing[1] == shared_vertex)
			if touches_at_shared == false:
				return true
	return false

func _segment_leads_to_taken_edge(
		segment: PackedVector2Array,
		current_vertex: Vector2,
		used_edge_points: Array[Vector2]
	) -> bool:
	var target: Vector2 = _get_other_vertex_of_segment(segment, current_vertex)
	if Global.is_point_on_world_edge(target):
		for p: Vector2 in used_edge_points:
			if p == target:
				return true
	return false

func _generate_single_river(
	boundary_segments: Array[Dictionary],
	map: Global.Map,
	used_edge_points: Array[Vector2]
) -> Dictionary:
	var river: PackedVector2Array = PackedVector2Array()
	var self_segments: Array[PackedVector2Array] = []
	var obstacle: PackedVector2Array = PackedVector2Array()
	var confluence_point: Vector2 = Vector2.ZERO
	var confluence_impacted_index: int = -1

	# Find boundary segments that have vertices on world edges
	var edge_segments: Array[Dictionary] = []
	for segment_data: Dictionary in boundary_segments:
		var segment: PackedVector2Array = segment_data["segment"]
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		
		if Global.is_point_on_world_edge(a) or Global.is_point_on_world_edge(b):
			# Dont start at an obstacle
			if segment_data["area_a"].owner_id == -2 or segment_data["area_b"].owner_id == -2:
				continue
				
			var a_free: bool = _point_is_in_list(a, used_edge_points) == false
			var b_free: bool = _point_is_in_list(b, used_edge_points) == false
			if a_free and b_free:
				edge_segments.append(segment_data)
	
	if edge_segments.is_empty():
		# Ensure stable dictionary shape even on early return
		return {
			"poly": river,
			"obstacle": obstacle,
			"confluence_point": Vector2.ZERO,
			"confluence_impacted_index": -1
		}  # No edge segments found
	# Pick a random edge segment to start from
	var current_segment_data: Dictionary = edge_segments[rng.randi_range(0, edge_segments.size() - 1)]
	var current_segment: PackedVector2Array = current_segment_data["segment"]
	
	# Start at the vertex that's actually on the world edge
	var start_vertex: Vector2
	if Global.is_point_on_world_edge(current_segment[0]):
		start_vertex = current_segment[0]
	else:
		start_vertex = current_segment[1]
	
	river.append(start_vertex)
	var current_point: Vector2 = start_vertex
	
	var visited_segments: Dictionary[PackedVector2Array, bool] = {}
	var current_area: Area = current_segment_data["area_a"]
	var previous_area: Area = null
	var max_iterations: int = 50  # Reasonable limit
	var iterations: int = 0
	
	var found_obstacle: bool = false

	while iterations < max_iterations:
		iterations += 1
		
		# Mark current segment as visited
		visited_segments[current_segment] = true
		self_segments.append(current_segment)

		# Traverse the full polyline from current_point to the other end
		var polyline: PackedVector2Array = current_segment_data["polyline"]
		var start_idx: int = -1
		var end_idx: int = -1
		
		# Find the current point in the polyline
		for i in range(polyline.size()):
			if polyline[i] == current_point:
				start_idx = i
				break
		
		if start_idx == -1:
			# Fallback: just move to the other end of the segment
			var segment_end: Vector2 = _get_other_vertex_of_segment(current_segment, current_point)
			river.append(segment_end)
			current_point = segment_end
		else:
			# Determine direction: go to the other end of the polyline
			if start_idx == 0:
				end_idx = polyline.size() - 1
				# Traverse forward through the polyline
				for i in range(1, polyline.size()):
					river.append(polyline[i])
			else:
				end_idx = 0
				# Traverse backward through the polyline
				for i in range(polyline.size() - 2, -1, -1):
					river.append(polyline[i])
			
			current_point = polyline[end_idx]
			# Detect confluence at shared vertex with any previously stored river
			var impacted_idx_at_vertex: int = _find_impacted_river_at_point(map, current_point)
			if impacted_idx_at_vertex != -1:
				confluence_impacted_index = impacted_idx_at_vertex
				confluence_point = current_point
				break
		
		# Check if we hit an existing river
		if map.river_segments.has(current_segment):
			if map.river_segments_owner.has(current_segment):
				confluence_impacted_index = map.river_segments_owner[current_segment]
				confluence_point = _get_other_vertex_of_segment(current_segment, river[river.size() - 1])
			else:
				confluence_impacted_index = -1
				confluence_point = Vector2.ZERO
			break
		
		if Global.is_point_on_world_edge(current_point):
			assert(not _point_is_in_list(current_point, used_edge_points))
			break

		# Update which areas we're transitioning between
		previous_area = current_area
		if current_area == current_segment_data["area_a"]:
			current_area = current_segment_data["area_b"]
		else:
			current_area = current_segment_data["area_a"]

		# Find next segment to continue on
		var next_segments: Array[Dictionary] = _find_segments_from_point(
			current_point, 
			boundary_segments, 
			visited_segments,
			current_area,
			previous_area
		)
		for cand_data: Dictionary in next_segments:
			if (
				cand_data["area_a"].owner_id == -2 or 
				cand_data["area_b"].owner_id == -2
			):
				found_obstacle = true
				if cand_data["area_a"].owner_id == -2:
					obstacle = cand_data["area_a"].polygon
				else:
					obstacle = cand_data["area_b"].polygon
				break
		if found_obstacle:
			break
				
		var pruned: Array[Dictionary] = []
		for cand_data: Dictionary in next_segments:
			var cand_seg: PackedVector2Array = cand_data["segment"]
			var safe_from_self: bool = _segment_intersects_river(
				cand_seg,
				self_segments,
				current_point
			) == false
			var safe_from_taken_edge: bool = _segment_leads_to_taken_edge(
				cand_seg,
				current_point,
				used_edge_points
			) == false
			
			if safe_from_self and safe_from_taken_edge:
				pruned.append(cand_data)
		next_segments = pruned

		if next_segments.is_empty():
			river.clear()
			break  # No more segments to follow
		
		# Randomly choose next segment
		var next_segment_data: Dictionary = next_segments[rng.randi_range(0, next_segments.size() - 1)]
		current_segment = next_segment_data["segment"]
		current_segment_data = next_segment_data
	
	var out: Dictionary = {}
	out["poly"] = river
	out["obstacle"] = obstacle
	out["confluence_point"] = confluence_point
	out["confluence_impacted_index"] = confluence_impacted_index
	return out

func _get_closest_vertex_on_segment(point: Vector2, segment: PackedVector2Array) -> Vector2:
	var a: Vector2 = segment[0]
	var b: Vector2 = segment[1]
	
	# Only return actual vertices, not points along the segment
	if point.distance_to(a) <= point.distance_to(b):
		return a
	else:
		return b

func _get_other_vertex_of_segment(segment: PackedVector2Array, current_vertex: Vector2) -> Vector2:
	var a: Vector2 = segment[0]
	var b: Vector2 = segment[1]
	
	# Return the vertex that is NOT the current one
	if current_vertex.distance_to(a) < current_vertex.distance_to(b):
		return b
	else:
		return a

func _find_impacted_river_at_point(map: Global.Map, p: Vector2) -> int:
	# returns index of an existing river that has p as a vertex; -1 if none
	for ri: int in range(map.rivers.size()):
		var r: PackedVector2Array = map.rivers[ri]
		for v: Vector2 in r:
			if v == p:
				return ri
	return -1

func _get_random_world_edge_point() -> Vector2:
	var edge: int = rng.randi_range(0, 3)  # 0=top, 1=right, 2=bottom, 3=left
	
	match edge:
		0:  # Top edge
			return Vector2(rng.randf_range(0, Global.world_size.x), 0)
		1:  # Right edge
			return Vector2(Global.world_size.x, rng.randf_range(0, Global.world_size.y))
		2:  # Bottom edge
			return Vector2(rng.randf_range(0, Global.world_size.x), Global.world_size.y)
		3:  # Left edge
			return Vector2(0, rng.randf_range(0, Global.world_size.y))
		_:
			return Vector2(0, 0)


func _get_nearest_world_edge_point(point: Vector2) -> Vector2:
	# Find the nearest point on the world boundary
	var distances: Array[float] = []
	var edge_points: Array[Vector2] = []
	
	# Distance to each edge
	distances.append(point.y)  # Top edge
	edge_points.append(Vector2(point.x, 0))
	
	distances.append(Global.world_size.x - point.x)  # Right edge
	edge_points.append(Vector2(Global.world_size.x, point.y))
	
	distances.append(Global.world_size.y - point.y)  # Bottom edge
	edge_points.append(Vector2(point.x, Global.world_size.y))
	
	distances.append(point.x)  # Left edge
	edge_points.append(Vector2(0, point.y))
	
	# Find closest edge
	var min_distance: float = distances[0]
	var closest_point: Vector2 = edge_points[0]
	
	for i: int in range(1, distances.size()):
		if distances[i] < min_distance:
			min_distance = distances[i]
			closest_point = edge_points[i]
	
	return closest_point


func _find_segments_from_point(
	point: Vector2, 
	boundary_segments: Array[Dictionary], 
	visited_segments: Dictionary[PackedVector2Array, bool],
	current_area: Area,
	previous_area: Area
) -> Array[Dictionary]:
	var connected_segments: Array[Dictionary] = []
	
	for segment_data: Dictionary in boundary_segments:
		var segment: PackedVector2Array = segment_data["segment"]
		
		# Skip already visited segments
		if visited_segments.has(segment):
			continue
		
		# Check if segment connects to the point (must be exact vertex match)
		var connects: bool = (segment[0].distance_to(point) <= 0.0 or 
							  segment[1].distance_to(point) <= 0.0)
		
		if not connects:
			continue
		
		# Only allow segments that lead to a DIFFERENT area than we came from
		# This prevents the river from following the perimeter of the same cell
		var area_a: Area = segment_data["area_a"]
		var area_b: Area = segment_data["area_b"]
		
		# The segment must involve our current area, but lead to a different area
		var leads_to_new_area: bool = false
		if area_a == current_area and area_b != previous_area:
			leads_to_new_area = true
		elif area_b == current_area and area_a != previous_area:
			leads_to_new_area = true
		elif (area_a != current_area and area_a != previous_area) or (area_b != current_area and area_b != previous_area):
			# Allow segments that don't involve current area (crossing to entirely new areas)
			leads_to_new_area = true
		
		if leads_to_new_area:
			connected_segments.append(segment_data)
	
	return connected_segments

func _add_river_segments_to_lookup(river: PackedVector2Array, map: Global.Map, river_index: int) -> void:
	for i: int in range(river.size() - 1):
		var segment: PackedVector2Array = PackedVector2Array([river[i], river[i + 1]])
		map.river_segments[segment] = true
		if map.river_segments_owner.has(segment):
			pass
		else:
			map.river_segments_owner[segment] = river_index

func _update_original_walkable_area_river_neighbors(
	river: PackedVector2Array, 
	boundary_segments: Array[Dictionary], 
	map: Global.Map
) -> void:	
	# For each river segment, find which areas it connects
	for i: int in range(river.size() - 1):
		var river_segment: PackedVector2Array = PackedVector2Array([river[i], river[i + 1]])
		
		# Find boundary segments that contain this river segment
		for segment_data: Dictionary in boundary_segments:
			var boundary_polyline: PackedVector2Array = segment_data["polyline"]
			
			# Check if this river segment is part of the boundary polyline
			var is_part_of_boundary: bool = false
			for j in range(boundary_polyline.size() - 1):
				var boundary_segment: PackedVector2Array = PackedVector2Array([boundary_polyline[j], boundary_polyline[j + 1]])
				if (
					(
						boundary_segment[0] == river_segment[0] and boundary_segment[1] == river_segment[1]
					) or 
					(
						boundary_segment[1] == river_segment[0] and boundary_segment[0] == river_segment[1]
					)
				):
					is_part_of_boundary = true
					break
			
			if is_part_of_boundary:
				var area_a: Area = segment_data["area_a"]
				var area_b: Area = segment_data["area_b"]
				
				if area_a.owner_id == -3 or area_b.owner_id == -3: continue
				# Add each as river neighbor to the other
				if not map.original_walkable_area_river_neighbors[area_a].has(area_b):
					map.original_walkable_area_river_neighbors[area_a].append(area_b)
				if not map.original_walkable_area_river_neighbors[area_b].has(area_a):
					map.original_walkable_area_river_neighbors[area_b].append(area_a)

func _shared_border_midpoint(area_a: Area, area_b: Area, map: Global.Map) -> Vector2:
	# Look up the border in either direction
	var border: PackedVector2Array = PackedVector2Array()
	if map.original_walkable_area_shared_borders.has(area_a):
		if map.original_walkable_area_shared_borders[area_a].has(area_b):
			border = map.original_walkable_area_shared_borders[area_a][area_b][0]
	if border.is_empty():
		if map.original_walkable_area_shared_borders.has(area_b):
			if map.original_walkable_area_shared_borders[area_b].has(area_a):
				border = map.original_walkable_area_shared_borders[area_b][area_a][0]

	# Fallback (should not occur with proper Voronoi adjacency)
	if border.is_empty():
		return (area_a.center + area_b.center) * 0.5
	
	# For wavy borders, find the midpoint along the polyline
	if border.size() > 2:
		# Calculate the total length of the polyline
		var total_length: float = 0.0
		for i in range(border.size() - 1):
			total_length += border[i].distance_to(border[i + 1])
		
		# Find the point that's halfway along the polyline
		var target_length: float = total_length * 0.5
		var current_length: float = 0.0
		
		for i in range(border.size() - 1):
			var segment_length: float = border[i].distance_to(border[i + 1])
			if current_length + segment_length >= target_length:
				# Interpolate along this segment
				var t: float = (target_length - current_length) / segment_length
				return border[i].lerp(border[i + 1], t)
			current_length += segment_length
		
		# Fallback to the middle vertex if something goes wrong
		return border[border.size() / 2]
	else:
		# Original logic for single edge
		assert(border.size() == 2)
		var first: Vector2 = border[0]
		var last: Vector2 = border[border.size() - 1]
		return (first + last) * 0.5

func generate_roads(map: Global.Map) -> bool:
	var rng: RandomNumberGenerator = self.rng
	map.roads.clear()

	map.area_road_neighbors = {}
	for area: Area in map.original_walkable_areas:
		map.area_road_neighbors[area] = []
	
	var used_pairs: Dictionary[String, bool] = {}				# global A-B locks
	var roads_polygons: Array = []								# each road's polygon set
	
	var max_total_len: float = sqrt(Global.world_size.x * Global.world_size.y) * 3.0
	var min_total_len: float = max_total_len
	var min_length_allowed: float = (Global.world_size.x + Global.world_size.y)
	
	var target_total_len: float = rng.randf_range(min_total_len, max_total_len)
	var current_total_len: float = 0.0
	
	# convenience for random starts
	var walkables: Array[Area] = map.original_walkable_areas
	
	var attempts_left: int = GENERATION_ATTEMPTS + 1
	while current_total_len < target_total_len and attempts_left > 0:
		attempts_left -= 1
		# ─── pick a random start polygon ──────────────────────────────────
		var start: Area = walkables[rng.randi_range(0, walkables.size() - 1)]
		var start_point: Vector2 = start.center
		
		var road: PackedVector2Array = PackedVector2Array([start_point])
		var road_pairs: Array[String] = []
		var road_polys: Array[int] = [start.polygon_id]
		
		var visited: Dictionary[int, bool] = {}
		visited[start.polygon_id] = true
		
		var cur: Area = start
		var prev_dir: Vector2 = Vector2.ZERO
		var road_length: float = 0.0
		var closed: bool = false
		var max_steps: int = 256			# safety-net
		
		for step: int in range(max_steps):
			var nbs_raw: Array = map.adjacent_original_walkable_area[cur]
			var candidates: Array[Area] = []
			
			# ───── build candidate list ─────────────────────────────────
			for pid: int in nbs_raw:
				if not map.original_area_index_by_polygon_id.has(pid):
					continue
				var idx: int = map.original_area_index_by_polygon_id[pid]
				var next_area: Area = map.original_walkable_areas[idx]
				if next_area.owner_id != -1:
					continue
				
				var pk: String = _pair_key(cur.polygon_id, pid)
				if used_pairs.has(pk):
					continue									# edge taken
				
				# allow revisiting start only for closure
				if pid == start.polygon_id and cur != start:
					candidates.append(next_area)
				elif not visited.has(pid):
					candidates.append(next_area)
			
			if candidates.is_empty():
				break		# dead-end
			
			# ───── smooth angle‐weighted choice ─────────────────────────
			var weights: Array[float] = []
			var total_weight: float = 0.0
			for cand: Area in candidates:
				var dir: Vector2 = (cand.center - cur.center).normalized()
				var angle: float = 0.0
				if prev_dir != Vector2.ZERO:
					angle = abs(prev_dir.angle_to(dir))
				var w: float = pow((PI - angle) / PI, 8)	# sharper turn ⇒ lower weight
				if w < 0.05:
					w = 0.05
				weights.append(w)
				total_weight += w
			
			var pick: float = rng.randf_range(0.0, total_weight)
			var acc: float = 0.0
			var chosen_idx: int = 0
			for i: int in range(weights.size()):
				acc += weights[i]
				if pick <= acc:
					chosen_idx = i
					break
			
			var nxt: Area = candidates[chosen_idx]
			
			# ───── add segment ─────────────────────────────────────────
			var pk_sel: String = _pair_key(cur.polygon_id, nxt.polygon_id)
			road_pairs.append(pk_sel)
			
			var mid: Vector2 = _shared_border_midpoint(cur, nxt, map)
			road.append(mid)
			road.append(nxt.center)

			road_length += cur.center.distance_to(mid)
			road_length += mid.distance_to(nxt.center)

			prev_dir = (nxt.center - mid).normalized()


			if nxt == start:						# closed the loop
				road.append(start_point)			# repeat first point
				closed = true
				break
			
			cur = nxt
			visited[cur.polygon_id] = true
			road_polys.append(cur.polygon_id)
		
		# ─── validation and commit ─────────────────────────────────────
		if closed and road_length >= min_length_allowed:
			var ok: bool = true
			for prev_set: Dictionary in roads_polygons:
				var shared: int = 0
				for pid_it: int in road_polys:
					if prev_set.has(pid_it):
						shared += 1
						if shared > 0:
							ok = false
							break
				if not ok:
					break
			
			if ok:
				var road_id: int = map.roads.size()
				map.roads.append(road)
				current_total_len += road_length
				
				for area: Area in map.original_walkable_areas:
					if Geometry2D.intersect_polyline_with_polygon(
							road,
							area.polygon
					).size() > 0:
						map.area_road_neighbors[area].append(road_id)
				
				for pk: String in road_pairs:
					used_pairs[pk] = true
				
				var poly_set: Dictionary[int, bool] = {}
				for pid_it: int in road_polys:
					poly_set[pid_it] = true
				roads_polygons.append(poly_set)
		# else: silently discard and try again

	# After all roads are generated, map road nodes to areas
	map.road_node_to_area = {}
	for road: PackedVector2Array in map.roads:
		for node: Vector2 in road:
			for area: Area in map.original_walkable_areas:
				if Geometry2D.is_point_in_polygon(node, area.polygon):
					map.road_node_to_area[node] = area
					break

	if attempts_left == 0:
		return false
	return true

static func _pair_key(id_a: int, id_b: int) -> String:
	return str(min(id_a, id_b), ":", max(id_a, id_b))

func _populate_trains(map: Global.Map) -> void:
	# No roads → no train
	if map.roads.is_empty():
		return
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	# ❶ pick a random road
	var road_index: int = rng.randi_range(0, map.roads.size() - 1)
	var road: PackedVector2Array = map.roads[road_index]
	
	# ❷ gather areas touching that road
	var candidate_areas: Array[Area] = []
	for area: Area in map.original_walkable_areas:
		if road_index in map.area_road_neighbors[area]:
			candidate_areas.append(area)
	
	if candidate_areas.is_empty():
		return		# rare but possible
	
	# ❸ pick a random touching area
	var area: Area = candidate_areas[rng.randi_range(0, candidate_areas.size() - 1)]
	
	# ❹ find closest point on the road to that area's centroid
	var best_pos: Vector2 = road[0]
	var best_dist: float = INF
	var best_s: float = 0.0
	var acc_len: float = 0.0
	for i: int in road.size() - 1:
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		var ab: Vector2 = b - a
		var seg_len: float = ab.length()
		if seg_len == 0.0:
			continue
		var t: float = clamp((area.center - a).dot(ab) / (seg_len * seg_len), 0.0, 1.0)
		var p: Vector2 = a + ab * t
		var d: float = p.distance_to(area.center)
		if d < best_dist:
			best_dist = d
			best_pos  = p
			best_s    = acc_len + seg_len * t
		acc_len += seg_len
	
	# ❺ build and store the train
	var train: Train = TrainSmall.new()
	train.owner_id	= 1						# red
	train.road		= road
	train.distance	= best_s
	train.global_position = best_pos

	map.trains.append(train)

func _populate_tanks(map: Global.Map) -> void:
	if map.original_walkable_areas.is_empty():
		return

	var rng_local: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_local.randomize()
	
	for ind: int in range(4):
		var start_area: Area = map.original_walkable_areas[
			rng_local.randi_range(0, map.original_walkable_areas.size() - 1)
		]
		var start_pos: Vector2 = start_area.center
		#start_pos = Vector2(-1, 1000)
		var possible_angles: Array[float] = [
			PI/4.0, 3.0*PI/4.0, -3.0*PI/4.0, -PI/4.0
		]
		var angle: float = possible_angles[randi()%possible_angles.size()]
		#angle = possible_angles[1]
		#var angle: float = rng_local.randf_range(0.0, TAU)
		
		var dir: Vector2 = Vector2(cos(angle), sin(angle)).normalized()

		var tank: Tank = TankSmall.new()
		tank.owner_id = 1						# red for now; adjust as you like
		tank.global_position = start_pos
		tank.direction = dir

		map.tanks.append(tank)

func _calculate_areas_expanded_along_shared_borders(
	original_walkable_areas: Array[Area],
	adjacent_original_walkable_area: Dictionary[Area, Array],
	original_area_index_by_polygon_id: Dictionary[int, int]
) -> Dictionary[Area, Dictionary]:
	
	var areas_expanded_along_shared_borders: Dictionary[Area, Dictionary] = {}
	var delta: float = 1.0/Engine.physics_ticks_per_second
	for original_area: Area in original_walkable_areas:
		for adjacent_original_area: Area in adjacent_original_walkable_area[original_area]:			
			var slightly_expanded_adjacent_original_area_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
				Geometry2D.offset_polygon(
					adjacent_original_area.polygon,
					delta,
					Geometry2D.JOIN_MITER
				)
			)
			slightly_expanded_adjacent_original_area_polygon = GeometryUtils.find_largest_polygon(
				Geometry2D.intersect_polygons(
					slightly_expanded_adjacent_original_area_polygon,
					GeometryUtils.find_largest_polygon(
						Geometry2D.merge_polygons(
							adjacent_original_area.polygon,
							original_area.polygon
						)
					)
				)
			)
			if not areas_expanded_along_shared_borders.has(original_area):
				areas_expanded_along_shared_borders[original_area] = {}
			areas_expanded_along_shared_borders[original_area][adjacent_original_area] = slightly_expanded_adjacent_original_area_polygon
	return areas_expanded_along_shared_borders

func update_map(
	map: Global.Map,
	areas: Array[Area],
	unmerged_obstacles: Array[Area],
	generate_water_features: bool,
	preassigned_terrain: Dictionary[int, String]
) -> bool:
	map.clear()

	map.original_unmerged_obstacles = unmerged_obstacles
	for ind: int in range(unmerged_obstacles.size()):
		var unmerged_obstacle: Area = map.original_unmerged_obstacles[ind]
		map.original_unmerged_obstacles_index_by_polygon_id[unmerged_obstacle.polygon_id] = ind

	# Store all polygons (both owned and neutral)
	for area in areas:
		if area.owner_id == -1:
			var terrain_type: String = "plains"
			if preassigned_terrain.has(area.polygon_id):
				terrain_type = preassigned_terrain[area.polygon_id]
			else:
				terrain_type = assign_terrain_type()
			map.terrain_map[area.polygon_id] = terrain_type
			map.original_walkable_areas.append(area)
			map.original_walkable_areas_sum += GeometryUtils.calculate_polygon_area(area.polygon)
			map.original_walkable_areas_and_obstacles_circumference_sum += GeometryUtils.calculate_polygon_circumference(area.polygon)
			map.original_polygon_areas[area.polygon_id] = GeometryUtils.calculate_polygon_area(area.polygon)
			map.original_polygon_centroid[area.polygon_id] = GeometryUtils.calculate_centroid(area.polygon)
		elif area.owner_id == -2:
			map.original_obstacles.append(area)
			map.original_walkable_areas_and_obstacles_circumference_sum += GeometryUtils.calculate_polygon_circumference(area.polygon)
	
	for ind: int in range(map.original_walkable_areas.size()):
		var original_area: Area = map.original_walkable_areas[ind]
		map.original_area_index_by_polygon_id[original_area.polygon_id] = ind
		
		for vertex: Vector2 in original_area.polygon:
			map.original_walkable_areas_verices[vertex] = true
		
	for ind: int in range(map.original_obstacles.size()):
		var obstacle: Area = map.original_obstacles[ind]
		map.original_obstacles_index_by_polygon_id[obstacle.polygon_id] = ind
		

	map.adjacent_original_walkable_area = calculate_adjacent_original_walkable_area(map.original_walkable_areas)
	map.adjacent_original_walkable_area_and_obstacles = calculate_adjacent_original_walkable_area(map.original_walkable_areas+map.original_obstacles)
	map.adjacent_original_walkable_area_and_unmerged_obstacles = calculate_adjacent_original_walkable_area(map.original_walkable_areas+map.original_unmerged_obstacles)
	map.original_walkable_area_bounds = calculate_adjacent_original_walkable_area_bounds(map.original_walkable_areas)
	map.original_walkable_area_and_obstacles_bounds = calculate_adjacent_original_walkable_area_bounds(map.original_walkable_areas+map.original_obstacles)
	
	for original_area: Area in map.original_walkable_areas:
		var bounds: Dictionary = map.original_walkable_area_bounds[original_area]
		var original_rect: Rect2 = Rect2(
			bounds["min_x"], bounds["min_y"],
			bounds["max_x"] - bounds["min_x"], bounds["max_y"] - bounds["min_y"]
		)
		map.original_walkable_area_bounds_rect[original_area] = original_rect
	
	map.original_walkable_areas_and_obstacles_spatial_grid = setup_area_spatial_grid(map.original_walkable_areas+map.original_obstacles, map.original_walkable_area_and_obstacles_bounds)

	map.original_walkable_area_shared_borders = calculate_shared_borders(map.original_walkable_areas)
	map.original_walkable_areas_expanded_along_shared_borders = _calculate_areas_expanded_along_shared_borders(
		map.original_walkable_areas,
		map.adjacent_original_walkable_area,
		map.original_area_index_by_polygon_id
	)
	
	if generate_water_features == true:
		if not generate_rivers(map):
			return false
		# roads optionally remain disabled

	# Build water_graph for ships
	map.water_graph = {}
	if generate_water_features == true:
		# Add river polylines
		for river: PackedVector2Array in map.rivers:
			for i in range(river.size() - 1):
				var a: Vector2 = river[i]
				var b: Vector2 = river[i + 1]
				if map.water_graph.has(a) == false:
					map.water_graph[a] = []
				if map.water_graph.has(b) == false:
					map.water_graph[b] = []
				map.water_graph[a].append(b)
				map.water_graph[b].append(a)
		# Add lake (obstacle) perimeters
		for obstacle: Area in map.original_obstacles:
			var poly: PackedVector2Array = obstacle.polygon
			for i2 in range(poly.size()):
				var aa: Vector2 = poly[i2]
				var bb: Vector2 = poly[(i2 + 1) % poly.size()]
				if map.water_graph.has(aa) == false:
					map.water_graph[aa] = []
				if map.water_graph.has(bb) == false:
					map.water_graph[bb] = []
				map.water_graph[aa].append(bb)
				map.water_graph[bb].append(aa)

		# Connect identical nodes
		var all_nodes: Array = map.water_graph.keys()
		for i3: int in range(all_nodes.size()):
			var na: Vector2 = all_nodes[i3]
			for j3: int in range(i3 + 1, all_nodes.size()):
				var nb: Vector2 = all_nodes[j3]
				if na == nb:
					if map.water_graph[na].has(nb) == false:
						map.water_graph[na].append(nb)
					if map.water_graph[nb].has(na) == false:
						map.water_graph[nb].append(na)

	# Don't remove these functions please. I just want
	# them commented out for now
	#_populate_trains(map)
	#_populate_tanks(map)
	
	return true

# Add this helper function for wavy polylines
func make_wavy_border_polyline(polyline: PackedVector2Array, max_angle_degrees: float, steps_per_segment: int) -> PackedVector2Array:
	var result = PackedVector2Array()
	result.append(polyline[0])
	for i in range(polyline.size() - 1):
		var a = polyline[i]
		var b = polyline[i+1]
		var segment_length = a.distance_to(b)
		for s in range(1, steps_per_segment):
			var t = float(s) / steps_per_segment
			var base = a.lerp(b, t)
			var normal = (b - a).normalized().orthogonal()
			# Calculate amplitude based on angle and segment length
			var max_angle_radians = deg_to_rad(max_angle_degrees)
			var amplitude = segment_length * tan(max_angle_radians) * 0.5
	
			var offset: float
			if randi() % 2 == 0:
				offset = amplitude
			else:
				offset = -amplitude
	
			#var offset = rng.randf_range(-amplitude, amplitude)
			# Make integer for same reason as voroni cells were
			result.append(_safe_round(base + normal * offset))
		result.append(b)
	return result

func create_map_from_seed_points(
	seed_points: Array[Vector2],
	terrain_by_seed: Dictionary[Vector2, String],
	add_waves: bool,
) -> Global.Map:
	var areas: Array[Area] = []
	var world_boundary: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0),
		Vector2(Global.world_size.x, 0),
		Vector2(Global.world_size.x, Global.world_size.y),
		Vector2(0, Global.world_size.y)
	])
	world_boundary.reverse()
	areas.append(Area.new(Global.obstacle_color, world_boundary, -3))

	var voronoi_cells: Dictionary[Vector2, PackedVector2Array] = generate_voronoi_cells(seed_points)
	for center_point: Vector2 in voronoi_cells.keys():
		var cell: PackedVector2Array = voronoi_cells[center_point]
		if cell.size() >= 3:
			var integer_cell: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in cell:
				integer_cell.append(_safe_round(p))
			voronoi_cells[center_point] = integer_cell

	if add_waves == true:
		var cell_centers: Array = voronoi_cells.keys()
		var cell_adjacency: Dictionary = {}
		for i: int in range(cell_centers.size()):
			var a: Vector2 = cell_centers[i]
			cell_adjacency[a] = []
		for i2: int in range(cell_centers.size()):
			var ca: Vector2 = cell_centers[i2]
			var poly_a: PackedVector2Array = voronoi_cells[ca]
			for j: int in range(i2 + 1, cell_centers.size()):
				var cb: Vector2 = cell_centers[j]
				var poly_b: PackedVector2Array = voronoi_cells[cb]
				if GeometryUtils.are_polygons_adjacent(poly_a, poly_b):
					(cell_adjacency[ca] as Array).append(cb)
					(cell_adjacency[cb] as Array).append(ca)
		var processed_pairs: Dictionary[String, bool] = {}
		for i3: int in range(cell_centers.size()):
			var a2: Vector2 = cell_centers[i3]
			for b2: Vector2 in cell_adjacency[a2]:
				var pair_key: String = str(min(a2.x, b2.x), ",", min(a2.y, b2.y), "-", max(a2.x, b2.x), ",", max(a2.y, b2.y))
				if processed_pairs.has(pair_key):
					continue
				processed_pairs[pair_key] = true
				var poly_a2: PackedVector2Array = voronoi_cells[a2]
				var poly_b2: PackedVector2Array = voronoi_cells[b2]
				var shared: PackedVector2Array = MapGenerator._get_shared_border_between_polygons(poly_a2, poly_b2)
				if shared.size() >= 2:
					var wavy: PackedVector2Array = make_wavy_border_polyline(shared, 8.0, 2)
					var idx_a: Dictionary = find_polyline_indices(poly_a2, shared)
					var idx_b: Dictionary = find_polyline_indices(poly_b2, shared)
					if idx_a["start"] == -1 or idx_b["start"] == -1:
						continue
					var pairs: Array = [[poly_a2, idx_a], [poly_b2, idx_b]]
					for pair in pairs:
						var poly: PackedVector2Array = pair[0]
						var idx: Dictionary = pair[1]
						var remove_count: int = shared.size() - 2
						var insert_at: int = (idx["start"] + 1) % poly.size()
						for _r: int in range(remove_count):
							poly.remove_at(insert_at % poly.size())
						var wavy_points: PackedVector2Array = wavy.duplicate()
						if idx["reversed"]:
							wavy_points = reverse_packed_vector2array(wavy_points)
						for m: int in range(1, wavy_points.size() - 1):
							poly.insert(insert_at + m - 1, wavy_points[m])
					voronoi_cells[a2] = poly_a2
					voronoi_cells[b2] = poly_b2

	var preassigned_terrain: Dictionary[int, String] = {}
	for center_point2: Vector2 in voronoi_cells.keys():
		var cell2: PackedVector2Array = voronoi_cells[center_point2]
		if cell2.size() >= 3:
			var center2: Vector2 = GeometryUtils.calculate_centroid(cell2)
			var terrain_type2: String = "plains"
			if terrain_by_seed.has(center_point2):
				terrain_type2 = terrain_by_seed[center_point2]
			var owner_id2: int = -1
			var color2: Color = Global.neutral_color
			if terrain_type2 == "lake":
				owner_id2 = -2
				color2 = Global.obstacle_color
			else:
				owner_id2 = -1
				color2 = Global.neutral_color
			var aarea: Area = Area.new(color2, cell2, owner_id2, center2)
			areas.append(aarea)
			if owner_id2 == -1:
				preassigned_terrain[aarea.polygon_id] = terrain_type2

	var unmerged_obstacles: Array[Area] = []
	for area_it: Area in areas:
		if area_it.owner_id == -2:
			unmerged_obstacles.append(Area.new(area_it.color, area_it.polygon, area_it.owner_id, GeometryUtils.calculate_centroid(area_it.polygon)))

	#permanently_merge_obstacles(areas)

	var map: Global.Map = Global.Map.new()
	var ok: bool = update_map(map, areas, unmerged_obstacles, false, preassigned_terrain)
	if ok == false:
		return map
	return map

# Helper: Find maximal shared polyline and its indices in a polygon
func find_polyline_indices(poly: PackedVector2Array, polyline: PackedVector2Array) -> Dictionary:
	# Try forward
	for i in range(poly.size()):
		var _match = true
		for j in range(polyline.size()):
			if poly[(i+j)%poly.size()] != polyline[j]:
				_match = false
				break
		if _match:
			return {"start": i, "end": (i+polyline.size()-1)%poly.size(), "reversed": false}
	# Try reverse
	for i in range(poly.size()):
		var _match = true
		for j in range(polyline.size()):
			if poly[(i+j)%poly.size()] != polyline[polyline.size()-1-j]:
				_match = false
				break
		if _match:
			return {"start": i, "end": (i+polyline.size()-1)%poly.size(), "reversed": true}
	return {"start": -1, "end": -1, "reversed": false}

# Helper: Reverse a PackedVector2Array (GDScript doesn't support [::-1])
func reverse_packed_vector2array(arr: PackedVector2Array) -> PackedVector2Array:
	var out = PackedVector2Array()
	for i in range(arr.size()-1, -1, -1):
		out.append(arr[i])
	return out

# Helper: Check if a segment intersects the world rectangle
func _segment_intersects_world(segment: PackedVector2Array, world_rect: Rect2) -> bool:
	var p1: Vector2 = segment[0]
	var p2: Vector2 = segment[1]
	# Check if either endpoint is inside the world
	if world_rect.has_point(p1) or world_rect.has_point(p2):
		return true
	# Check if the segment intersects any edge of the world rectangle
	var world_edges: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(world_rect.position.x, world_rect.position.y), Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y)]),  # Top
		PackedVector2Array([Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y), Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y + world_rect.size.y)]),  # Right
		PackedVector2Array([Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y + world_rect.size.y), Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y)]),  # Bottom
		PackedVector2Array([Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y), Vector2(world_rect.position.x, world_rect.position.y)])  # Left
	]
	for edge: PackedVector2Array in world_edges:
		if _segments_intersect(segment, edge):
			return true
	return false

# Helper: Check if two segments intersect
func _segments_intersect(seg1: PackedVector2Array, seg2: PackedVector2Array) -> bool:
	var a: Vector2 = seg1[0]
	var b: Vector2 = seg1[1]
	var c: Vector2 = seg2[0]
	var d: Vector2 = seg2[1]
	var denominator: float = (b.x - a.x) * (d.y - c.y) - (b.y - a.y) * (d.x - c.x)
	if abs(denominator) == 0.0:
		return false
	var t: float = ((c.x - a.x) * (d.y - c.y) - (c.y - a.y) * (d.x - c.x)) / denominator
	var u: float = ((c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x)) / denominator
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0
