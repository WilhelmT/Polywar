extends Node
	
func calculate_polygon_area(polygon: PackedVector2Array) -> float:
	var n: int = polygon.size()
	var area: float = 0.0
	for i in range(n):
		var j: int = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	area = abs(area) / 2.0
	assert(area>=0)
	return area

func calculate_polygon_circumference(polygon: PackedVector2Array) -> float:
	var n: int = polygon.size()
	var circumference: float = 0.0
	for i in range(n):
		var j: int = (i + 1) % n
		circumference += polygon[i].distance_to(polygon[j])
	return circumference

func calculate_polyline_circumference(polyline: PackedVector2Array) -> float:
	var n: int = polyline.size()
	var circumference: float = 0.0
	for i in range(n - 1):
		circumference += polyline[i].distance_to(polyline[i + 1])
	return circumference
	
func find_largest_polygon(
	polygons: Array[PackedVector2Array],
	accept_clockwise: bool = false,
) -> PackedVector2Array:
	var largest_polygon: PackedVector2Array = PackedVector2Array([])
	var largest_area: float = 0.0
	for i in range(polygons.size()):
		if not accept_clockwise and Geometry2D.is_polygon_clockwise(polygons[i]):
			continue
		var area: float = GeometryUtils.calculate_polygon_area(polygons[i])
		if area > largest_area:
			largest_area = area
			largest_polygon = polygons[i]
	
	return largest_polygon

func calculate_centroid(points: PackedVector2Array) -> Vector2:
	if points.size()==0:
		return Vector2.ZERO
	var centroid = Vector2.ZERO
	var signedArea = 0.0
	var x0: float = 0.0 # Current vertex X
	var y0: float = 0.0 # Current vertex Y
	var x1: float = 0.0 # Next vertex X
	var y1: float = 0.0 # Next vertex Y
	var a: float = 0.0  # Partial signed area
	
	for i: int in range(0, points.size() - 1):
		x0 = points[i].x
		y0 = points[i].y
		x1 = points[i+1].x
		y1 = points[i+1].y
		a = x0*y1 - x1*y0
		signedArea += a
		centroid.x += (x0 + x1) * a
		centroid.y += (y0 + y1) * a

	# Do last vertex separately to avoid performing an expensive
	# modulus operation in each iteration.
	x0 = points[points.size() - 1].x
	y0 = points[points.size() - 1].y
	x1 = points[0].x
	y1 = points[0].y
	a = x0*y1 - x1*y0
	signedArea += a
	centroid.x += (x0 + x1) * a
	centroid.y += (y0 + y1) * a

	signedArea *= 0.5
	centroid.x /= (6.0*signedArea)
	centroid.y /= (6.0*signedArea)

	return centroid

func is_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)

func merge_polygons(polygon: PackedVector2Array, other_polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	return Geometry2D.merge_polygons(polygon, other_polygon)

func intersect_polygons(polygon: PackedVector2Array, other_polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	return Geometry2D.intersect_polygons(polygon, other_polygon)

func calculate_bounding_box(polygon: PackedVector2Array) -> Rect2:
	if polygon.size() <= 0:
		return Rect2()
	
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	
	for point: Vector2 in polygon:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func are_bounding_boxes_overlapping(rect1: Rect2, rect2: Rect2) -> bool:
	return (
		rect1.end.x >= rect2.position.x and
		rect1.position.x <= rect2.end.x and
		rect1.end.y >= rect2.position.y and
		rect1.position.y <= rect2.end.y
	)

func remove_duplicate_points(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() <= 1:
		return polygon
	
	#const CLIPPER_TOL := 1.0 / 16384.0  # 0.00006103515625
	
	var result: PackedVector2Array = []	
	result.append(polygon[0])
	
	# Check each point against the previous one
	for i: int in range(1, polygon.size()):
		var current_point: Vector2 = polygon[i]
		var previous_point: Vector2 = polygon[i - 1]
		
		if current_point == previous_point:
		#if (current_point - previous_point).length() <= CLIPPER_TOL:
			continue
		#elif (current_point-previous_point).length() < 0.0001:
			#print((current_point-previous_point).length())
			
		result.append(current_point)
	
	# Check if the last point is a duplicate of the first point (for closed polygons)
	if result.size() > 1:
		var first_point: Vector2 = result[0]
		var last_point: Vector2 = result[result.size() - 1]
		
		if last_point == first_point:
		#if (last_point - first_point).length() <= CLIPPER_TOL:
			# Remove the last point if it duplicates the first
			result.remove_at(result.size() - 1)
	
	if polygon != result:
		return remove_duplicate_points(result)
	return result


# Helper function to determine if a polygon is inside another polygon
func is_polygon_inside_polygon(inner_polygon: PackedVector2Array, outer_polygon: PackedVector2Array) -> bool:
	# A polygon is inside another if all its points are inside the outer polygon
	# or if at least one point is inside and all edges don't intersect
	
	var all_points_inside: bool = true
	for point in inner_polygon:
		if not is_point_in_polygon(point, outer_polygon):
			all_points_inside = false
			break
	
	if all_points_inside:
		return true
	
	
	# Check if at least one point is inside and no edges intersect
	var one_point_inside = false
	for point in inner_polygon:
		if is_point_in_polygon(point, outer_polygon):
			one_point_inside = true
			break
	
	if not one_point_inside:
		return false
	
	# Check if any edges intersect
	var outer_size = outer_polygon.size()
	var inner_size = inner_polygon.size()
	
	for i in range(inner_size):
		var inner_from = inner_polygon[i]
		var inner_to = inner_polygon[(i + 1) % inner_size]
		
		for j in range(outer_size):
			var outer_from = outer_polygon[j]
			var outer_to = outer_polygon[(j + 1) % outer_size]
			
			var intersection = Geometry2D.segment_intersects_segment(inner_from, inner_to, outer_from, outer_to)
			if intersection != Vector2.ZERO:  # If there's an intersection
				return false
	
	return true


# Check if two polygons are adjacent (share at least one edge or vertex)
#func are_polygons_adjacent(poly1: PackedVector2Array, poly2: PackedVector2Array) -> bool:
	#poly1 = remove_duplicate_points(poly1)
	#poly2 = remove_duplicate_points(poly2)
	## First check if any edge from poly1 has any vertex from poly2
	#var shared_vertices: int = 0
	#
	## Check if any vertices are close enough to be considered the same
	## TODO Magic Number. Cannot be 0 for some reason
	#const EPSILON: float = 0.0001  # Small threshold for floating point comparison
	#
	#for i: int in range(poly1.size()):
		#var p1_current: Vector2 = poly1[i]
		#var p1_next: Vector2 = poly1[(i + 1) % poly1.size()]
		#
		#for j: int in range(poly2.size()):
			#var p2: Vector2 = poly2[j]
			#
			## Check if p2 is on the edge of poly1
			#if is_point_on_line_segment(p2, p1_current, p1_next, EPSILON):
				#shared_vertices += 1
			#
			## Also check if vertices are the same
			#if p1_current.distance_to(p2) < EPSILON:
				#shared_vertices += 1
#
	## If they share vertices, they're adjacent
	#return shared_vertices >= 2  # Need at least 2 shared points to form an edge


func same_polygon_shifted(
	a: PackedVector2Array,
	b: PackedVector2Array
) -> bool:
	a = remove_duplicate_points(a)
	b = remove_duplicate_points(b)
	
	var n: int = a.size()
	if n != b.size():
		return false                        # different vertex count

	# ‑‑‑ try every possible starting vertex in A (constant‑memory) ------------
	for start: int in range(n):
		var off: Vector2 = a[start] - b[0]          # translation that aligns b[0] to a[start]
		var j: int = 1
		while j < n and a[(start + j) % n] == b[j] + off:
			j += 1
		if j == n:                          # walked the whole ring → perfect match
			return true
	return false

# Godot 4.x  GDScript
func are_polygons_adjacent_contiguous(
		a: PackedVector2Array,
		b: PackedVector2Array
	) -> bool:
	# --‑‑ preparation ---------------------------------------------------------
	a = remove_duplicate_points(a)
	b = remove_duplicate_points(b)

	var size_a := a.size()
	var size_b := b.size()
	if size_a <= 2 or size_b <= 2:
		return false

	# --‑‑ put every edge of polygon B in a lookup table (both orientations) ---
	var edges_b := {}			# { [Vector2,Vector2] : true }
	for j in size_b:
		var p1 := b[j]
		var p2 := b[(j + 1) % size_b]
		edges_b[[p1, p2]] = true	# original direction
		edges_b[[p2, p1]] = true	# reverse direction

	# --‑‑ gather the indices of A’s edges that are also in B ------------------
	var shared_indices : PackedInt32Array = PackedInt32Array()
	for i in size_a:
		var q1 := a[i]
		var q2 := a[(i + 1) % size_a]
		if edges_b.has([q1, q2]):
			shared_indices.push_back(i)

	if shared_indices.is_empty():
		return false			    # no common edge at all

	# --‑‑ check that *all* shared edges form ONE continuous run ---------------
	# Convert to a quick‑lookup set.
	var shared_set := {}
	for idx in shared_indices:
		shared_set[idx] = true

	# Walk forward round polygon A starting from the first shared edge.
	var start := shared_indices[0]
	var visited := 0
	var idx := start
	while shared_set.has(idx):
		visited += 1
		idx = (idx + 1) % size_a
		if idx == start:		    # back to the beginning – stop the loop
			break

	# If the walk reached every shared edge, they were contiguous.
	return visited == shared_indices.size()

# Godot 4.4 GDScript
func are_polygons_adjacent(
	a: PackedVector2Array,
	b: PackedVector2Array
) -> bool:
	# Remove duplicates (assumes you already have this helper)
	a = remove_duplicate_points(a)
	b = remove_duplicate_points(b)

	var size_a: int = a.size()
	var size_b: int = b.size()

	if size_a <= 2 or size_b <= 2:
		return false

	# Check every edge in A against every edge in B
	var i: int = 0
	while i < size_a:
		var a_p1: Vector2 = a[i]
		var a_p2: Vector2 = a[(i + 1) % size_a]	# wrap‑around edge

		var j: int = 0
		while j < size_b:
			var b_p1: Vector2 = b[j]
			var b_p2: Vector2 = b[(j + 1) % size_b]

			if (
				a_p1 == b_p1 and a_p2 == b_p2
			) or (
				a_p1 == b_p2 and a_p2 == b_p1
			):
				return true
			j += 1
		i += 1

	return false

# Helper function to check if a point is on a line segment
func is_point_on_line_segment(p: Vector2, line_start: Vector2, line_end: Vector2, epsilon: float) -> bool:
	# Check if point is collinear and within the line segment bounds
	var d = (p - line_start).dot(line_end - line_start) / line_start.distance_squared_to(line_end)
	
	# If d is between 0 and 1, the projection falls on the line segment
	if d < 0 or d > 1:
		return false
		
	# Calculate the actual distance to the line
	var closest = line_start + (line_end - line_start) * d
	return p.distance_to(closest) < epsilon


func split_into_inner_outer_polygons(polygons: Array[PackedVector2Array]) -> Array:
	var outer_polygons: Array[PackedVector2Array] = []
	var inner_polygons: Array[PackedVector2Array] = []
	for polygon in polygons:
		if not Geometry2D.is_polygon_clockwise(polygon):
			outer_polygons.append(polygon)
		else:
			inner_polygons.append(polygon)
	return [outer_polygons, inner_polygons]

#
#func simplify_polygon_with_terrain_stack(
	#polygon: PackedVector2Array, 
	#tolerance: float,
	#expansion_rate: float,
	#map: Global.Map,
	#point_to_regions_map: Dictionary,
	#clicked_original_walkable_areas: Dictionary
#) -> PackedVector2Array:
	#if polygon.size() <= 2:
		#return polygon
	#
	## Stack to store segment indices to process
	#var stack: Array[Array] = []
	#
	## Array to mark points that should be kept
	#var marked: Array[bool] = []
	#marked.resize(polygon.size())
	#for i: int in range(marked.size()):
		#marked[i] = false
	#
	## Always keep first and last points
	#marked[0] = true
	#marked[polygon.size() - 1] = true
	#
	## Push initial segment
	#stack.append([0, polygon.size() - 1])
	#
	#while not stack.is_empty():
		#var segment: Array = stack.pop_back()
		#var start_idx: int = segment[0]
		#var end_idx: int = segment[1]
		#
		#if end_idx - start_idx <= 1:
			#continue
			#
		#var first_point: Vector2 = polygon[start_idx]
		#var last_point: Vector2 = polygon[end_idx]
		#
		#var max_distance: float = 0.0
		#var furthest_idx: int = start_idx
		#
		## Find the furthest point from the line segment
		#for i: int in range(start_idx + 1, end_idx):
			#var base_distance: float = perpendicular_distance(
				#polygon[i],
				#first_point,
				#last_point
			#)
			#
			#var adjusted_distance: float = base_distance
			##var total_expansion_rate: float = Global.get_expansion_speed(
				##expansion_rate,
				##clicked_original_walkable_areas,
				##map,
				##point_to_regions_map[polygon[i]],
			##)
			##adjusted_distance /= total_expansion_rate
			#
			#if adjusted_distance > max_distance:
				#max_distance = adjusted_distance
				#furthest_idx = i
		#
		## If the furthest point is outside tolerance, keep it and process sub-segments
		#if max_distance > tolerance:
			#marked[furthest_idx] = true
			#stack.append([start_idx, furthest_idx])
			#stack.append([furthest_idx, end_idx])
	#
	#var marked_count: int = 0
	#for is_marked: bool in marked:
		#if is_marked:
			#marked_count += 1
#
	#var result: PackedVector2Array = PackedVector2Array()
	#result.resize(marked_count)
	#var index: int = 0
	#for i: int in range(polygon.size()):
		#if marked[i]:
			#result[index] = polygon[i]
			#index += 1
	#
	#return result


#func simplify_polygon_with_terrain(
	#polygon: PackedVector2Array, 
	#tolerance: float,
	#expansion_rate: float,
	#map: Global.Map,
	#point_to_regions_map: Dictionary,
	#clicked_original_walkable_areas: Dictionary,
#) -> PackedVector2Array:
	#if polygon.size() <= 3:
		#return polygon
#
	#return _simplify_segment_with_terrain(
		#polygon, 
		#0, 
		#polygon.size() - 1, 
		#tolerance,
		#expansion_rate,
		#map,
		#point_to_regions_map,
		#clicked_original_walkable_areas
	#)
#
#func _simplify_segment_with_terrain(
	#polygon: PackedVector2Array, 
	#start_idx: int, 
	#end_idx: int, 
	#tolerance: float,
	#expansion_rate: float,
	#map: Global.Map,
	#point_to_regions_map: Dictionary,
	#clicked_original_walkable_areas: Dictionary
#) -> PackedVector2Array:
	#"""
	#Helper function for the recursive Douglas-Peucker algorithm with terrain adjustment.
	#Processes a segment of the polygon between start and end indices.
	#"""
	#if end_idx - start_idx <= 1:
		#return PackedVector2Array([polygon[start_idx], polygon[end_idx]])
#
	#var first_point: Vector2 = polygon[start_idx]
	#var last_point: Vector2 = polygon[end_idx]
	#
	#var max_distance: float = 0.0
	#var furthest_idx: int = start_idx
	#
	#for i: int in range(start_idx + 1, end_idx):
		#var base_distance: float = perpendicular_distance(
			#polygon[i],
			#first_point,
			#last_point
		#)
		#
		#var adjusted_distance: float = base_distance
		#
		#if map != null:
			#var total_expansion_rate: float = Global.get_expansion_speed(
				#expansion_rate,
				#clicked_original_walkable_areas,
				#map,
				#point_to_regions_map[polygon[i]],
			#)
			#adjusted_distance /= total_expansion_rate
		#
		#if adjusted_distance > max_distance:
			#max_distance = adjusted_distance
			#furthest_idx = i
	#
	#if max_distance > tolerance:
		#var simplified_first: PackedVector2Array = _simplify_segment_with_terrain(
			#polygon, start_idx, furthest_idx, tolerance, 
			#expansion_rate, map, point_to_regions_map, clicked_original_walkable_areas
		#)
		#
		#var simplified_second: PackedVector2Array = _simplify_segment_with_terrain(
			#polygon, furthest_idx, end_idx, tolerance,
			#expansion_rate, map, point_to_regions_map, clicked_original_walkable_areas
		#)
		#
		## Instead of:
		## simplified_first.remove_at(simplified_first.size() - 1)
		## return simplified_first + simplified_second
#
		## Optimized version:
		#var result: PackedVector2Array = PackedVector2Array()
		#result.resize(simplified_first.size() + simplified_second.size() - 1)
#
		## Copy all elements except the last one from simplified_first
		#for i: int in range(simplified_first.size() - 1):
			#result[i] = simplified_first[i]
#
		## Copy all elements from simplified_second
		#for i: int in range(simplified_second.size()):
			#result[simplified_first.size() - 1 + i] = simplified_second[i]
#
		#return result
#
	#return [first_point, last_point]
#
	#

func perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	"""
	Calculate the perpendicular distance from a point to a line segment.
	"""
	var line_length := line_start.distance_to(line_end)
	if line_length == 0.0:
		return point.distance_to(line_start)
		
	# Calculate the normalized projection
	var t := ((point.x - line_start.x) * (line_end.x - line_start.x) + 
			  (point.y - line_start.y) * (line_end.y - line_start.y)) / (line_length * line_length)
	
	t = clamp(t, 0.0, 1.0)
	
	# Calculate the closest point on the line
	var projection := Vector2(
		line_start.x + t * (line_end.x - line_start.x),
		line_start.y + t * (line_end.y - line_start.y)
	)
	
	# Return the distance to this point
	return point.distance_to(projection)


func area_triangle(a: Vector2, b: Vector2, c: Vector2) -> float:
	"""Calculate the area of a triangle using cross product."""
	return 0.5 * abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))


func points_to_areas_mapping(
	polygon: PackedVector2Array,
	map: Global.Map,
	areas_to_consider: Array,
) -> Dictionary[Vector2, Area]:
	var point_to_regions_map: Dictionary[Vector2, Area] = {}
	
	var spatial_grid: Global.SpatialGrid = map.original_walkable_areas_and_obstacles_spatial_grid
	
	for point: Vector2 in polygon:
		var grid_x: int = int(floor(point.x / spatial_grid.grid_cell_size))
		var grid_y: int = int(floor(point.y / spatial_grid.grid_cell_size))
		var grid_key: Vector2i = Vector2i(grid_x, grid_y)
		
		var closest_area = null
		var min_distance_squared: float = INF
		
		# First check if the grid cell exists
		if spatial_grid.area_spatial_grid.has(grid_key):
			# Only check areas that might contain this point
			for area: Area in spatial_grid.area_spatial_grid[grid_key]:
				if area not in areas_to_consider:
					continue
				#var center: Vector2 = area.center  # Using the area's center property
				#var dist_squared: float = point.distance_squared_to(center)
				
				if Geometry2D.is_point_in_polygon(point, area.polygon):
					#if closest_area != null:
						#print(1)
					closest_area = area
					break

		if closest_area == null:
			closest_area = get_closest_area_voroni(point, map, areas_to_consider)
			#assert(closest_area != null)
		point_to_regions_map[point] = closest_area
	return point_to_regions_map

func points_to_areas_mapping_voroni(
	polygon: PackedVector2Array,
	map: Global.Map,
	areas_to_consider: Array,
) -> Dictionary[Vector2, Area]:
	var point_to_regions_map: Dictionary[Vector2, Area] = {}
	
	var spatial_grid: Global.SpatialGrid = map.original_walkable_areas_and_obstacles_spatial_grid
	
	for point: Vector2 in polygon:
		var grid_x: int = int(floor(point.x / spatial_grid.grid_cell_size))
		var grid_y: int = int(floor(point.y / spatial_grid.grid_cell_size))
		var grid_key: Vector2i = Vector2i(grid_x, grid_y)
		
		var closest_area = null
		var min_distance_squared: float = INF
		
		# First check if the grid cell exists
		if spatial_grid.area_spatial_grid.has(grid_key):
			# Only check areas that might contain this point
			for area: Area in spatial_grid.area_spatial_grid[grid_key]:
				if area not in areas_to_consider:
					continue
				var center: Vector2 = area.center  # Using the area's center property
				var dist_squared: float = point.distance_squared_to(center)
				
				if dist_squared < min_distance_squared:
					min_distance_squared = dist_squared
					closest_area = area
					
		point_to_regions_map[point] = get_closest_area_voroni(point, map, areas_to_consider)
	
	return point_to_regions_map

func get_closest_area_voroni(
	point: Vector2,
	map: Global.Map,
	areas_to_consider: Array,
) -> Area:
	
	var spatial_grid: Global.SpatialGrid = map.original_walkable_areas_and_obstacles_spatial_grid
	
	var grid_x: int = int(floor(point.x / spatial_grid.grid_cell_size))
	var grid_y: int = int(floor(point.y / spatial_grid.grid_cell_size))
	var grid_key: Vector2i = Vector2i(grid_x, grid_y)
	
	var closest_area = null
	var min_distance_squared: float = INF
	
	# First check if the grid cell exists
	if spatial_grid.area_spatial_grid.has(grid_key):
		# Only check areas that might contain this point
		for area: Area in spatial_grid.area_spatial_grid[grid_key]:
			if area not in areas_to_consider:
				continue
			var center: Vector2 = area.center  # Using the area's center property
			var dist_squared: float = point.distance_squared_to(center)
			
			if dist_squared < min_distance_squared:
				min_distance_squared = dist_squared
				closest_area = area
				
	return closest_area
	

func get_closest_vertex(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	if polygon.size() == 0:
		return Vector2.ZERO
		
	var closest_vertex: Vector2 = polygon[0]
	var min_distance: float = point.distance_squared_to(polygon[0])
	
	for i in range(1, polygon.size()):
		var vertex: Vector2 = polygon[i]
		var distance: float = point.distance_squared_to(vertex)
		
		if distance < min_distance:
			min_distance = distance
			closest_vertex = vertex
	
	return closest_vertex

func simplify_polyline(polyline: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	# Check if we have enough points to simplify
	var n: int = polyline.size()
	if n <= 2:
		return polyline
		
	# Use a mask to mark points that should be kept
	var mask: Array = []
	mask.resize(n)
	mask.fill(false)
	
	# Always keep the first and last points
	mask[0] = true
	mask[n-1] = true
	
	# Perform Douglas-Peucker algorithm
	_douglas_peucker_recursive(polyline, 0, n - 1, epsilon, mask)
	
	# Create result array from mask
	var result: PackedVector2Array = []
	for i in range(n):
		if mask[i]:
			result.append(polyline[i])
	
	return result
	
func _douglas_peucker_recursive(points: PackedVector2Array, start_idx: int, end_idx: int, epsilon: float, mask: Array) -> void:
	# Find the point with the maximum distance
	var max_dist: float = 0.0
	var index: int = 0
	
	var start_point: Vector2 = points[start_idx]
	var end_point: Vector2 = points[end_idx]
	
	for i in range(start_idx + 1, end_idx):
		var dist: float = perpendicular_distance(points[i], start_point, end_point)
		
		if dist > max_dist:
			max_dist = dist
			index = i
	
	# If max distance is greater than epsilon, recursively simplify
	if max_dist > epsilon:
		# Mark this point to keep
		mask[index] = true
		
		# Recursive calls
		_douglas_peucker_recursive(points, start_idx, index, epsilon, mask)
		_douglas_peucker_recursive(points, index, end_idx, epsilon, mask)
	

func simplify_polyline_close_points(polyline: PackedVector2Array, distance_threshold: float = 1.0) -> PackedVector2Array:
	if polyline.size() < 3:
		return polyline
	
	var simplified: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	
	# Always keep the first point
	simplified.append(polyline[0])
	
	while i < polyline.size() - 1:
		var found_close: bool = false
		var j: int = i + 2  # Start checking from i+2 to skip adjacent point
		
		# Look ahead for close points
		while j < polyline.size():
			var distance: float = polyline[i].distance_to(polyline[j])
			
			if distance < distance_threshold:
				# Found a close point, skip all points between i and j
				#simplified.append(polyline[j])
				i = j
				found_close = true
				break
			
			j += 1
		
		if not found_close:
			# No close point found, move to next point
			i += 1
			if i < polyline.size():
				simplified.append(polyline[i])
	
	# Ensure last point is included if not already
	var last_point: Vector2 = polyline[polyline.size() - 1]
	var last_simplified: Vector2 = simplified[simplified.size() - 1]
	if not last_point.is_equal_approx(last_simplified):
		simplified.append(last_point)
	
	return simplified

func get_closest_point(
	target: Vector2,
	points: PackedVector2Array
) -> Vector2:
	if points.is_empty():
		return target
	
	var closest: Vector2
	var min_distance_squared: float = INF
	
	for p: Vector2 in points:
		var d: float = target.distance_squared_to(p)
		if d < min_distance_squared:
			min_distance_squared = d
			closest = p
	
	return closest

func clamp_point_to_polygon(
	polygon: PackedVector2Array,
	p: Vector2,
	accept_inside: bool
) -> Vector2:
	# If already inside, return as‑is
	if accept_inside and GeometryUtils.is_point_in_polygon(p, polygon):
		return p

	# Otherwise project onto the nearest edge of the polygon
	var closest: Vector2 = p
	var min_d2: float = INF
	var poly: PackedVector2Array = polygon
	var n: int = poly.size()

	for i: int in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if a == b:
			continue
		var proj: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var d2: float = p.distance_squared_to(proj)
		if d2 < min_d2:
			min_d2 = d2
			closest = proj
	#assert(GeometryUtils.is_point_in_polygon(closest, polygon))
	return closest

func clamp_point_to_polygon_with_edge_info(
	polygon: PackedVector2Array,
	point: Vector2
) -> Dictionary:
	var closest_point: Vector2 = point
	var min_distance: float = INF
	var edge_index: int = -1
	var t_on_edge: float = 0.0  # Position along the edge (0.0 = start vertex, 1.0 = end vertex)
	
	for i: int in range(polygon.size()):
		var edge_start: Vector2 = polygon[i]
		var edge_end: Vector2 = polygon[(i + 1) % polygon.size()]
		if edge_start == edge_end:
			continue
		var clamped: Vector2 = Geometry2D.get_closest_point_to_segment(point, edge_start, edge_end)
		var distance: float = point.distance_to(clamped)
		
		if distance < min_distance:
			min_distance = distance
			closest_point = clamped
			edge_index = i
			
			# Calculate t parameter along the edge
			var edge_vector: Vector2 = edge_end - edge_start
			if edge_vector.length_squared() > 0.0001:
				var point_vector: Vector2 = clamped - edge_start
				t_on_edge = point_vector.dot(edge_vector) / edge_vector.length_squared()
				t_on_edge = clamp(t_on_edge, 0.0, 1.0)
			else:
				t_on_edge = 0.0
	
	return {
		"point": closest_point,
		"edge_index": edge_index,
		"t": t_on_edge
	}
	
func scale_polygon_to_area_around_point(
	vertices: PackedVector2Array,
	target_area: float,
	scale_center: Vector2
) -> PackedVector2Array:
	var current_area: float = calculate_polygon_area(vertices)
	
	if current_area <= 0:
		push_warning("Polygon has zero or negative area")
		return vertices
	
	var scale_factor: float = sqrt(target_area / current_area)
	
	var scaled_vertices: PackedVector2Array = PackedVector2Array()
	for vertex in vertices:
		var relative_pos: Vector2 = vertex - scale_center
		var scaled_pos: Vector2 = relative_pos * scale_factor
		var final_pos: Vector2 = scaled_pos + scale_center
		scaled_vertices.append(final_pos)
	
	return scaled_vertices

func translate_polygon(poly: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in poly:
		out.append(v + delta)
	return out

# ─────────── Curve2D optimization for polygon clamping ───────────
func clamp_point_to_polygon_with_curve(polygon: PackedVector2Array, p: Vector2, curve: Curve2D) -> Vector2:
	return curve.get_closest_point(p)


# Convert polygons to triangle transforms for MultiMesh unit-triangle instancing
func triangulate_polygons_to_triangle_transforms(
	polygons: Array[PackedVector2Array]
) -> Array[Transform2D]:
	var transforms: Array[Transform2D] = []
	for poly: PackedVector2Array in polygons:
		if poly.size() < 3:
			continue
		var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		var i: int = 0
		while i < idx.size():
			var a_i: int = idx[i]
			var b_i: int = idx[i + 1]
			var c_i: int = idx[i + 2]
			var p0: Vector2 = poly[a_i]
			var p1: Vector2 = poly[b_i]
			var p2: Vector2 = poly[c_i]
			var t: Transform2D = Transform2D()
			var col_x: Vector2 = p1 - p0
			var col_y: Vector2 = p2 - p0
			t.x = col_x
			t.y = col_y
			t.origin = p0
			transforms.append(t)
			i += 3
	return transforms

# Build the main river polygon from a centerline using offset_polyline
func get_main_river_polygon_from_polyline(
	polyline: PackedVector2Array,
	width_outer: float
) -> PackedVector2Array:
	var empty: PackedVector2Array = PackedVector2Array()
	if polyline.size() < 2:
		return empty
	var outer_polys: Array[PackedVector2Array] = Geometry2D.offset_polyline(
		polyline,
		width_outer,
		Geometry2D.JOIN_ROUND,
		Geometry2D.END_ROUND
	)
	if outer_polys.is_empty():
		return empty
	# Choose the largest CCW polygon
	var main_poly: PackedVector2Array = GeometryUtils.find_largest_polygon(outer_polys)
	return main_poly
