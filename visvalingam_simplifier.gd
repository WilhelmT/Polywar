class_name VisvalingamSimplifier
extends RefCounted


# --- small helpers ---------------------------------------------------------
static func _triangle_area(a: Vector2, b: Vector2, c: Vector2) -> float:
	var area: float = abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) * 0.5
	return area


static func _get_significance(
	polygon: PackedVector2Array,
	curr: int,
	prev: int,
	next: int,
	expansion_rate: float,
	adjusted_strength: float,
	map: Global.Map,
	walkable_area: Area,
	exp_cache: Dictionary,
	area: Area,
	clicked_walkable_areas: Dictionary[int, bool],
	point_strength_multipliers: Dictionary[Vector2, float],
) -> float:
	# Be careful not to return INF, return a high number because otherwise almost colinear
	# points cannot be simplified.

	var prev_point: Vector2 = polygon[prev]
	var curr_point: Vector2 = polygon[curr]
	var next_point: Vector2 = polygon[next]
	var sig: float = _triangle_area(prev_point, curr_point, next_point)

	var rate: float
	if exp_cache.has(walkable_area):
		rate = exp_cache[walkable_area]
	else:
		rate = Global.get_expansion_speed(
			expansion_rate,
			adjusted_strength,
			map,
			walkable_area,
			false,
		)
		exp_cache[walkable_area] = rate

	# Apply strength multiplier if point is in enemy territory
	#assert(point_strength_multipliers.has(curr_point))
	if point_strength_multipliers.has(curr_point):
		var strength_multiplier: float = point_strength_multipliers[curr_point]
		rate *= strength_multiplier
	
	var min_rate: float = GameSimulationComponent.MIN_EXPANSION_SPEED
	if rate < min_rate:
		rate = min_rate
	
	const max_rate: float = GameSimulationComponent.MAX_EXPANSION_SPEED
	if rate > max_rate:
		rate = max_rate


	if Global.only_expand_on_click(area.owner_id) and not clicked_walkable_areas.has(walkable_area.polygon_id):
		rate = expansion_rate
	
	# Magic number 2/3...
	rate = pow(rate, 3.0/2.0)

	# Ensure we do not simplify away perfectly aligned with
	# original walkable area vertices.
	var eps: float = 0.01
	if (
		map.original_walkable_areas_verices.has(polygon[curr]) and
		sig != 0
	):
		rate *= eps
	
	if rate == 0.0:
		sig *= 16.0
	else:
		sig /= rate

	return sig


# --- minimal, integer-only binary heap -------------------------------------
static func _heap_swap(heap: Array[int], idx_a: int, idx_b: int, pos: PackedInt32Array) -> void:
	var tmp: int = heap[idx_a]
	heap[idx_a] = heap[idx_b]
	heap[idx_b] = tmp
	pos[heap[idx_a]] = idx_a
	pos[heap[idx_b]] = idx_b


static func _heap_sift_up(
	heap: Array[int],
	start_idx: int,
	pos: PackedInt32Array,
	sig: PackedFloat32Array
) -> void:
	var child: int = start_idx
	while child > 0:
		var parent: int = (child - 1) / 2
		if sig[heap[child]] < sig[heap[parent]]:
			_heap_swap(heap, child, parent, pos)
			child = parent
		else:
			break


static func _heap_sift_down(
	heap: Array[int],
	start_idx: int,
	pos: PackedInt32Array,
	sig: PackedFloat32Array
) -> void:
	var size: int = heap.size()
	var idx: int = start_idx
	while true:
		var smallest: int = idx
		var left: int = 2 * idx + 1
		var right: int = 2 * idx + 2
		if left < size and sig[heap[left]] < sig[heap[smallest]]:
			smallest = left
		if right < size and sig[heap[right]] < sig[heap[smallest]]:
			smallest = right
		if smallest == idx:
			break
		_heap_swap(heap, idx, smallest, pos)
		idx = smallest


static func _heap_push(
	heap: Array[int],
	vertex: int,
	pos: PackedInt32Array,
	sig: PackedFloat32Array
) -> void:
	pos[vertex] = heap.size()
	heap.append(vertex)
	_heap_sift_up(heap, heap.size() - 1, pos, sig)


static func _heap_pop(
	heap: Array[int],
	pos: PackedInt32Array,
	sig: PackedFloat32Array
) -> int:
	var root: int = heap[0]
	pos[root] = -1
	if heap.size() == 1:
		heap.pop_back()
		return root
	heap[0] = heap.pop_back()
	pos[heap[0]] = 0
	_heap_sift_down(heap, 0, pos, sig)
	return root


static func _heap_update(
	heap: Array[int],
	vertex: int,
	pos: PackedInt32Array,
	sig: PackedFloat32Array
) -> void:
	var h_idx: int = pos[vertex]
	if h_idx == -1:
		_heap_push(heap, vertex, pos, sig)
		return
	# choose direction based on new significance
	_heap_sift_up(heap, h_idx, pos, sig)
	_heap_sift_down(heap, h_idx, pos, sig)


# --- public entry -----------------------------------------------------------
static func simplify_polygon_visvalingams(
	polygon: PackedVector2Array,
	tolerance: float,
	expansion_rate: float,
	map: Global.Map,
	point_to_regions_map: Dictionary,		# Vector2 -> Area
	adjusted_strength: float,
	area: Area,
	clicked_original_walkable_areas: Dictionary[int, bool],
	point_strength_multipliers: Dictionary[Vector2, float],
) -> PackedVector2Array:
	if polygon.size() <= 3:
		return polygon

	var count: int = polygon.size()

	var original_areas: Array[Area] = []						# plain Array for objects
	original_areas.resize(count)
	for i: int in count:
		original_areas[i] = point_to_regions_map[polygon[i]]

	var next_idx: PackedInt32Array = PackedInt32Array()
	var prev_idx: PackedInt32Array = PackedInt32Array()
	next_idx.resize(count)
	prev_idx.resize(count)
	for i: int in count:
		next_idx[i] = (i + 1) % count
		prev_idx[i] = (i + count - 1) % count

	var active: PackedByteArray = PackedByteArray()
	active.resize(count)
	for i: int in count:
		active[i] = 1

	var sig: PackedFloat32Array = PackedFloat32Array()
	sig.resize(count)

	# ---------- expansion-rate cache ----------
	var exp_cache: Dictionary = {}					# key = Area, value = float

	# ---------- integer-only heap ----------
	var heap: Array[int] = []
	var pos_in_heap: PackedInt32Array = PackedInt32Array()
	pos_in_heap.resize(count)
	for i: int in count:
		pos_in_heap[i] = -1

	for i: int in count:
		sig[i] = _get_significance(
			polygon, i, prev_idx[i], next_idx[i],
			expansion_rate, adjusted_strength,
			map, original_areas[i], exp_cache,
			area,
			clicked_original_walkable_areas,
			point_strength_multipliers,
		)
		_heap_push(heap, i, pos_in_heap, sig)

	# ---------- main loop ----------
	var max_sig: float = 0.0
	while heap.size() > 0:
		var idx: int = _heap_pop(heap, pos_in_heap, sig)

		if active[idx] == 0:
			continue			# already removed by neighbour collapse

		var s: float = sig[idx]
		if s < max_sig:
			s = max_sig
		else:
			max_sig = s

		if s > tolerance:
			break

		# remove vertex
		active[idx] = 0
		var p: int = prev_idx[idx]
		var n: int = next_idx[idx]
		prev_idx[n] = p
		next_idx[p] = n

		# update neighbours
		if active[p] == 1:
			sig[p] = _get_significance(
				polygon, p, prev_idx[p], next_idx[p],
				expansion_rate, adjusted_strength,
				map, original_areas[p], exp_cache,
				area,
				clicked_original_walkable_areas,
				point_strength_multipliers,
			)
			_heap_update(heap, p, pos_in_heap, sig)

		if active[n] == 1:
			sig[n] = _get_significance(
				polygon, n, prev_idx[n], next_idx[n],
				expansion_rate, adjusted_strength,
				map, original_areas[n], exp_cache,
				area,
				clicked_original_walkable_areas,
				point_strength_multipliers,
			)
			_heap_update(heap, n, pos_in_heap, sig)

	# ---------- build result ----------
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		if active[i] == 1:
			result.append(polygon[i])

	if result.size() < 3:
		return polygon
	else:
		return result
