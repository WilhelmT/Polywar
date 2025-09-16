extends Node2D
class_name GameSimulationComponent

const USE_UNION: bool = false


const PLAYER_ID: int = 0

# Static Simulation Variables
const EXPANSION_SPEED: float = 12.0*Global.GLOBAL_SPEED
const MIN_EXPANSION_SPEED: float = 1
const MAX_EXPANSION_SPEED: float = 500

const SIMPLIFICATION_TOLERANCE: float = 0.02#1
const MINIMUM_AREA_STRENGTH: float = 1/100.0/1000.0
const HOLDING_REDUCTION_FACTOR: float = 2.0
const RIVER_HOLDING_REDUCTION_FACTOR: float = 4.0

const OFFSET_MULT_FOR_DETECTING_EXPANSION: float = 1

# Dynamic Variables updated during tick
var union_walkable_areas: Array[Area]
var union_walkable_areas_to_original_walkable_areas: Dictionary[Area, Array]
var adjacent_union_walkable_area: Dictionary[Area, Array] = {}
var union_walkable_area_shared_borders: Dictionary[Area, Dictionary] = {}
var union_walkable_area_river_neighbors: Dictionary[Area, Array] = {}

var intersecting_union_walkable_area_start_of_tick: Dictionary[Area, Dictionary] = {}
var intersecting_boundaries_union_walkable_area_start_of_tick: Dictionary[Area, Dictionary] = {}
var union_walkable_areas_covered: Dictionary[Area, Dictionary] = {}
var union_walkable_areas_partially_covered: Dictionary[Area, Dictionary] = {}


var intersecting_original_walkable_area_start_of_tick: Dictionary[Area, Dictionary] = {}
var intersecting_boundaries_original_walkable_area_start_of_tick: Dictionary[Area, Dictionary] = {}
var original_walkable_areas_covered: Dictionary[Area, Dictionary] = {}
var original_walkable_areas_partially_covered: Dictionary[Area, Dictionary] = {}

var area_source_polygons: Dictionary[Area, Array] = {}
var expanded_sub_areas: Array[Area] = []
var expanded_sub_areas_from_existing: Array[Area] = []
var expanded_sub_areas_from_boundaries: Array[Area] = []
var expanded_sub_areas_from_new: Array[Area] = []
var current_expansion_function: String = ""
var newly_holding_polylines: Dictionary[Area, Dictionary] = {}
var total_holding_circumference_by_other_area: Dictionary[Area, Dictionary] = {}
var total_weighted_holding_circumference_by_other_area: Dictionary[Area, Dictionary] = {}
var newly_expanded_polylines: Dictionary[Area, Dictionary] = {}
var newly_retracting_polylines: Dictionary[Area, Dictionary] = {}
var newly_expanded_areas: Dictionary[Area, Dictionary] = {}
var newly_expanded_areas_full: Dictionary[Area, Array] = {}
var newly_encircled_areas: Dictionary[Area, Array] = {}
var total_weighted_circumferences: Dictionary[Area, float] = {}
var total_active_circumferences: Dictionary[Area, float] = {}
var base_ownerships: Dictionary[Area, Array]
var big_intersecting_areas: Dictionary[Area, Dictionary] = {}
var big_intersecting_areas_circumferences: Dictionary[Area, Dictionary] = {}
var expanded_sub_area_origin_map: Dictionary[Area, Area] = {}
var adjusted_strength_cache: Dictionary[Area, float] = {}
var slightly_offset_area_polygons: Dictionary[Area, Array]
var total_strength_by_owner_id: Dictionary[int, float]
var total_unmodified_strength_by_owner_id: Dictionary[int, float]
var strength_manpower_casualties_sum_start_of_tick: Dictionary[int, float]
var total_manpower_start_of_tick: Dictionary[int, float]
var total_casualties_start_of_tick: Dictionary[int, float]


# Player actions
var clicked_original_walkable_areas: Dictionary[int, bool] = {}
var clicked_union_walkable_areas: Dictionary[int, bool] = {}
var is_mouse_down: bool = false
var pressed_original_area: Area
var current_hover_original_area: Area

# Debugging
var print_time: float = 0.5
var print_iter: float = 0.0
var debug_poly: PackedVector2Array
var debug_points: PackedVector2Array

var areas: Array[Area]
var map: Global.Map

signal requires_redraw

var simulation_time_accum: float = 0.0

# Upgrades
const SHOCK_TROOPS: bool = false
const TERRAIN_FORCES: bool = false
const SABOTEUR: bool = false
const ENCIRCLEMENT_CORPS: bool = false
const ARTILLERY: bool = false

# Stats influencing upgrades
const SHOCK_TROOPS_MULTIPLIER = 2.0
const SABOTEUR_BONUS: float = 3.0
const ENCIRCLEMENT_CORPS_BOUNDARY_SPEED_MULTIPLIER: float = 6.0

# Artillery state
var artillery_shot_accumulator_by_original_area: Dictionary[Area, float] = {}
var artillery_next_agent_id: int = 1
const ARTILLERY_SHOOT_TO_ADJACENT: bool = true
const ARTILLERY_MAX_RATE: float = 1.0
const ARTILLERY_HEX_RADIUS: float = 50.0
const ARTILLERY_TRAIL_SEGMENTS: int = 12
const ARTILLERY_TRAIL_FADE_MIN: float = 0.0
const ARTILLERY_TRAIL_FADE_MAX: float = 1.0
const ARTILLERY_MIN_PIECE_AREA: float = 5.0
const ARTILLERY_MIN_TARGET_INTERSECTION_AREA: float = 10.0

var gd_extension_clip: Clipper2Open

func _ready() -> void:
	gd_extension_clip = Clipper2Open.new()
	collect_end_of_tick()
	# To see debug stuff
	z_index = 100


func _init(
	p_areas: Array[Area],
	p_map: Global.Map
) -> void:
	areas = p_areas
	map = p_map


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_mouse_down = true
				pressed_original_area = _get_original_area_at_point(mb.position)
				current_hover_original_area = pressed_original_area
				if pressed_original_area != null:
					_toggle_original_area(pressed_original_area, mb.position)
			else:
				if is_mouse_down:
					is_mouse_down = false
					pressed_original_area = null
					current_hover_original_area = null
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if is_mouse_down:
			var area_under_cursor: Area = _get_original_area_at_point(mm.position)
			if area_under_cursor != current_hover_original_area:
				if area_under_cursor != null:
					_toggle_original_area(area_under_cursor, mm.position)
				current_hover_original_area = area_under_cursor

func intersecting_walkable_area_start_of_tick() -> Dictionary[Area, Dictionary]:
	if USE_UNION:
		return intersecting_union_walkable_area_start_of_tick
	return intersecting_original_walkable_area_start_of_tick

func adjacent_walkable_area() -> Dictionary[Area, Array]:
	if USE_UNION:
		return adjacent_union_walkable_area
	return map.adjacent_original_walkable_area

func clicked_walkable_areas() -> Dictionary[int, bool]:
	if USE_UNION:
		return clicked_union_walkable_areas
	return clicked_original_walkable_areas

func walkable_areas_covered() -> Dictionary[Area, Dictionary]:
	if USE_UNION:
		return union_walkable_areas_covered
	return original_walkable_areas_covered

func walkable_areas() -> Array[Area]:
	if USE_UNION:
		return union_walkable_areas
	return map.original_walkable_areas

func intersecting_boundaries_walkable_area_start_of_tick() -> Dictionary[Area, Dictionary]:
	if USE_UNION:
		return intersecting_boundaries_union_walkable_area_start_of_tick
	return intersecting_boundaries_original_walkable_area_start_of_tick

func walkable_areas_partially_covered() -> Dictionary[Area, Dictionary]:
	if USE_UNION:
		return union_walkable_areas_partially_covered
	return original_walkable_areas_partially_covered

func walkable_area_shared_borders() -> Dictionary[Area, Dictionary]:
	if USE_UNION:
		return union_walkable_area_shared_borders
	return map.original_walkable_area_shared_borders

func walkable_area_river_neighbors() -> Dictionary[Area, Array]:
	if USE_UNION:
		return union_walkable_area_river_neighbors
	return map.original_walkable_area_river_neighbors

func polygon_to_numbers(polygon: PackedVector2Array) -> float:
	var sign: int = 1
	var area_of_intersected_part: float = GeometryUtils.calculate_polygon_area(
		polygon
	)
	if Geometry2D.is_polygon_clockwise(polygon):
		sign = -1
	return sign*UnitLayer.MAX_UNITS*UnitLayer.NUMBER_PER_UNIT*area_of_intersected_part/(Global.world_size.x*Global.world_size.y)


func deployed_fraction(owner_id: int) -> float:	
	var strength_fraction: float = total_strength_by_owner_id[owner_id]/total_unmodified_strength_by_owner_id[owner_id]
	assert(strength_fraction <= 1.0)
	return strength_fraction

func take_casualty_from_area_loss(owner_id: int, new_casualties: float) -> void:
	var deployed_fraction: float = deployed_fraction(owner_id)
	var casualties_taken: float = new_casualties*deployed_fraction
	var manpower_regained: float = new_casualties-casualties_taken
	# Can't lose more than deployed.
	map.total_casualties[owner_id] += casualties_taken
	map.total_manpower[owner_id] += manpower_regained
	
func take_extra_casualty(owner_id: int, new_casualties: float) -> void:
	# Take extra constant casualty, independent of territory.
	map.total_casualties[owner_id] += new_casualties
	map.total_manpower[owner_id] -= new_casualties

func get_simulation_date_string() -> String:
	var total_hours: int = simulation_time_accum
	var year: int = 2000 + total_hours / (24 * 365)
	var month: int = 1 + (total_hours / (24 * 30)) % 12
	var day: int = 1 + (total_hours / 24) % 30
	var hour: int = total_hours % 24
	var minute: int = int((simulation_time_accum-total_hours)*60)

	#var total_minutes: int = simulation_time_accum
	#var year: int = 1990 + total_minutes / (60 * 24 * 365)
	#var month: int = 1 + (total_minutes / (60 * 24 * 30)) % 12
	#var day: int = 1 + (total_minutes / (60 * 24)) % 30
	#var hour: int = (total_minutes / 60) % 24
	#var minute: int = total_minutes % 60
	return "%04d/%02d/%02d %02d:%02d" % [year, month, day, hour, minute]
		
func _get_original_area_at_point(p: Vector2) -> Area:
	var clicked_areas: Dictionary[Vector2, Area] = GeometryUtils.points_to_areas_mapping([
		p
	], map, map.original_walkable_areas)
	if clicked_areas.has(p):
		var a: Area = clicked_areas[p]
		if a == null:
			return null
		else:
			return a
	else:
		return null

func _toggle_original_area(target_area: Area, at_position: Vector2) -> void:
	if target_area == null:
		return
	if clicked_original_walkable_areas.has(target_area.polygon_id):
		clicked_original_walkable_areas.erase(target_area.polygon_id)
	else:
		clicked_original_walkable_areas[target_area.polygon_id] = true
	get_parent().draw_component.spawn_click_ripple(target_area, at_position, map)
	get_parent().cursor_manager.start_animation()
	
func _clip_obstacle_polygon(
	points: PackedVector2Array,
	obstacle_points: PackedVector2Array,
) -> Array:
	var clipped_polygons: Array[PackedVector2Array] = []
	if (
		Geometry2D.is_polygon_clockwise(obstacle_points) and 
		not Geometry2D.is_polygon_clockwise(points)
	):
		clipped_polygons = Geometry2D.intersect_polygons(points, obstacle_points)
	else:
		clipped_polygons = Geometry2D.clip_polygons(points, obstacle_points)
	return GeometryUtils.split_into_inner_outer_polygons(clipped_polygons)

func process_encircled_holes(holes: Array[PackedVector2Array]) -> Array:
	var processed_holes: Array = []
	for hole: PackedVector2Array in holes:
		hole.reverse()
		processed_holes += clip_obstacles(hole, areas)
	return processed_holes

func clip_obstacles(
		polygon: PackedVector2Array,
		all_areas: Array[Area],
) -> Array:				# returns Array[[outer, holes]]
	var pairs: Array = []
	pairs.append([polygon, []])		# start with the full shape

	for obstacle: Area in all_areas:
		# keep only map obstacles
		if obstacle.owner_id != -2 and obstacle.owner_id != -3:
			continue

		var obstacle_points: PackedVector2Array = obstacle.polygon
		var next_pairs: Array = []

		for pair in pairs:
			var outer_poly: PackedVector2Array = pair[0]
			var accumulated_holes: Array = pair[1]

			var split_result: Array = _clip_obstacle_polygon(
				outer_poly,
				obstacle_points
			)

			var outers: Array = split_result[0]
			var holes: Array = split_result[1]

			for new_outer in outers:
				var new_holes: Array = []
				new_holes.append_array(accumulated_holes)
				new_holes.append_array(holes)
				next_pairs.append([new_outer, new_holes])
		pairs = next_pairs				# continue with refined set

	return pairs # [[PackedVector2Array, Array[PackedVector2Array]], …]

func _apply_clip_result_to_area(
		target_area: Area,
		clip_pairs: Array,
		extra_areas: Array[Area]
) -> void:
	if clip_pairs.is_empty():
		target_area.polygon = PackedVector2Array()
		return

	var largest_index: int = 0
	var largest_area: float = -1.0

	for i: int in range(clip_pairs.size()):
		var outer_poly: PackedVector2Array = clip_pairs[i][0]
		var poly_area: float = GeometryUtils.calculate_polygon_area(outer_poly)
		if poly_area > largest_area:
			largest_area = poly_area
			largest_index = i
	
	target_area.polygon = clip_pairs[largest_index][0]
	target_area.holes.clear()
	for hole: PackedVector2Array in clip_pairs[largest_index][1]:
		target_area.holes.append(hole)
	
	
	for i: int in range(clip_pairs.size()):
		if i == largest_index:
			continue
		var outer_ex: PackedVector2Array = clip_pairs[i][0]
		if outer_ex.size() >= 3 and not Geometry2D.is_polygon_clockwise(outer_ex):
			var spawned: Area = Area.new(
				target_area.color,
				outer_ex,
				target_area.owner_id,
			)
			for hole: PackedVector2Array in clip_pairs[i][1]:
				spawned.holes.append(hole)
			extra_areas.append(spawned)		# holes discarded for now


func merge_overlapping_areas_brute_force() -> void:
	# First group areas by owner
	var areas_by_owner = {}
	for area in areas:
		if area.owner_id in [-3, -2]:
			continue
		if not areas_by_owner.has(area.owner_id):
			areas_by_owner[area.owner_id] = []
		areas_by_owner[area.owner_id].append(area)
	
	# Only merge areas owned by the same player
	for owner_id in areas_by_owner.keys():
		var owner_areas = areas_by_owner[owner_id]
		var merges_occurred = true
		
		# Keep merging until no more changes occur
		while merges_occurred:
			merges_occurred = false
			var i = 0
			while i < owner_areas.size():
				var area = owner_areas[i]
				var initial_areas_count = owner_areas.size()
				_merge_overlapping_area_same_owner(
					area,
					owner_areas,
				)
				# If areas were merged, the count would be different
				if owner_areas.size() < initial_areas_count:
					merges_occurred = true
					break  # Start over as the array has been modified
				i += 1

func _merge_overlapping_area_same_owner(
	area: Area,
	potential_merge_areas: Array,
) -> void:
	# Use an iterative approach instead of recursion
	var areas_to_check = [area]  # Stack of areas to process
	var processed_areas = {}  # Track already processed pairs to avoid redundant checks
	
	while areas_to_check.size() > 0:
		var current_area = areas_to_check.pop_back()
		
		# Check against all potential merge areas
		var i = 0
		while i < potential_merge_areas.size():
			var other_area = potential_merge_areas[i]
			
			# Skip if it's the same area or different owner
			if other_area == current_area or other_area.owner_id != current_area.owner_id:
				i += 1
				continue
			
			# Create a unique key for this area pair to avoid redundant checks
			var pair_key = str(min(current_area.get_instance_id(), other_area.get_instance_id())) + "_" + str(max(current_area.get_instance_id(), other_area.get_instance_id()))
			if processed_areas.has(pair_key):
				i += 1
				continue
			
			processed_areas[pair_key] = true
			
			var merge: Array[PackedVector2Array] = Geometry2D.merge_polygons(current_area.polygon, other_area.polygon)
			var result = GeometryUtils.split_into_inner_outer_polygons(merge)					
			# There should be exactly one outer polygon
			#assert(result[0].size() == 1)
			if result[0].size() == 1:
				var new_outer_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(result[0])
				
				# Determine which area is larger to transfer merged polygon to the largest area
				var current_area_size: float = GeometryUtils.calculate_polygon_area(current_area.polygon)
				var other_area_size: float = GeometryUtils.calculate_polygon_area(other_area.polygon)
				
				var larger_area: Area
				var smaller_area: Area
				var smaller_area_index: int
				
				if current_area_size >= other_area_size:
					larger_area = current_area
					smaller_area = other_area
					smaller_area_index = i
				else:
					larger_area = other_area
					smaller_area = current_area
					# Find current_area's index in potential_merge_areas
					smaller_area_index = potential_merge_areas.find(current_area)
				
				if result[1].size() > 0:
					if not newly_encircled_areas.has(larger_area):
						newly_encircled_areas[larger_area] = []
					var hole_pairs: Array = process_encircled_holes(result[1])
					newly_encircled_areas[larger_area].append_array(hole_pairs)
					
					var total_manpower_consumed: float = 0.0
					for pair: Array in hole_pairs:
						for hole: PackedVector2Array in [pair[0]]+pair[1]:
							total_manpower_consumed += polygon_to_numbers(hole)
					map.total_manpower[larger_area.owner_id] -= total_manpower_consumed
				
				# Update the larger area with the merged polygon
				larger_area.polygon = new_outer_polygon
				# Remove the smaller area and add the larger area back to the check list
				areas.erase(smaller_area)
				if smaller_area_index != -1:
					potential_merge_areas.remove_at(smaller_area_index)
				# Add the larger area back to the stack to check for more merges
				areas_to_check.push_back(larger_area)
				break  # Break to process the modified area
			else:
				#if not (result[0].size() == 2 and result[1].size() == 0):
					#print(1)
				i += 1


func build_area_source_polygons_set() -> Dictionary[Area, Dictionary]:
	var area_source_polygons_set: Dictionary[Area, Dictionary] = {}
	for area in areas:
		if area.owner_id < 0 or not area_source_polygons.has(area):
			continue
			
		var sources_dict: Dictionary = {}
		for source in area_source_polygons[area]:
			sources_dict[source] = true
		area_source_polygons_set[area] = sources_dict
	
	return area_source_polygons_set

func group_areas_by_origin() -> Dictionary[int, Array]:
	var areas_by_origin: Dictionary[int, Array] = {}

	for area in areas:
		if area.owner_id < 0:  
			continue
		
		if not expanded_sub_area_origin_map.has(area):
			areas_by_origin[area.polygon_id] = [area]
	

	for area in areas:
		if area.owner_id < 0:  
			continue
		if not expanded_sub_area_origin_map.has(area):
			continue
		areas_by_origin[expanded_sub_area_origin_map[area].polygon_id].append(area)
	
	return areas_by_origin


func build_source_to_areas_map(
	owner_areas: Array,
	area_source_polygons_set: Dictionary[Area, Dictionary],
	areas_lookup: Dictionary
) -> Dictionary[int, Array]:
	var source_to_areas: Dictionary[int, Array] = {}
	
	for area in owner_areas:
		if not areas_lookup.has(area) or not area_source_polygons_set.has(area):
			continue
		
		for source_id in area_source_polygons_set[area].keys():
			if not source_to_areas.has(source_id):
				source_to_areas[source_id] = [area]
			else:
				source_to_areas[source_id].append(area)
	
	return source_to_areas

func find_potential_merges(area: Area, source_to_areas: Dictionary[int, Array], area_source_polygons_set: Dictionary[Area, Dictionary], areas_lookup: Dictionary) -> Array:
	var potential_merges_dict: Dictionary = {}
	
	for source_id in area_source_polygons_set[area].keys():
		if not source_to_areas.has(source_id):
			continue
		
		for other in source_to_areas[source_id]:
			if other != area and areas_lookup.has(other) and not potential_merges_dict.has(other):
				potential_merges_dict[other] = true
	return potential_merges_dict.keys()

func attempt_merge(
		area: Area,
		other: Area,
		area_source_polygons_set: Dictionary[Area, Dictionary],
		allow_holes: bool,
	) -> Dictionary:
	# -------------------------------------------------------------------------
	# result dictionary – caller expects success flag, merged area, holes,
	# and now an array of any additional Area instances we create.
	# -------------------------------------------------------------------------
	var result: Dictionary = {
		"success": false,
		"merged_area": area,
		"holes": [],
		"new_areas": [],
	}
	
	var merged_polygons: Array = GeometryUtils.merge_polygons(
		area.polygon,
		other.polygon,
	)
	if not (
		merged_polygons.size() == 2 and
		(
			(
				merged_polygons[0] == area.polygon and
				merged_polygons[1] == other.polygon
			) or
			(
				merged_polygons[1] == area.polygon and
				merged_polygons[0] == other.polygon
			) 
		)
	):
		var split_result: Array = GeometryUtils.split_into_inner_outer_polygons(
			merged_polygons
		)
		
		if allow_holes or (split_result[1].size() == 0):
			# split_result[0] → outer polygons
			# split_result[1] → holes
			if (split_result[0].size() != 0):
				# -----------------------------------------------------------------
				# Pick the *largest* outer polygon to remain on the original Area.
				# -----------------------------------------------------------------
				var outer_polygons: Array[PackedVector2Array] = split_result[0]
				var main_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
					outer_polygons
				)
				
				area.polygon = main_polygon
				var new_color: Color = (area.color+other.color)/2.0
				area.color = new_color
				 
				# Remove that polygon from the list so we do not duplicate it.
				for i: int in range(outer_polygons.size()):
					if outer_polygons[i] == main_polygon:
						outer_polygons.remove_at(i)
						break
				
				# -----------------------------------------------------------------
				# Merge the source-polygon sets.
				# -----------------------------------------------------------------
				for src_id in area_source_polygons_set[other].keys():
					area_source_polygons_set[area][src_id] = true
				
				# -----------------------------------------------------------------
				# Create a new Area for every *remaining* outer polygon.
				# -----------------------------------------------------------------
				for polygon: PackedVector2Array in outer_polygons:
					polygon = GeometryUtils.remove_duplicate_points(polygon)
					if polygon.size() >= 3 and not Geometry2D.is_polygon_clockwise(polygon):
						var new_area: Area = Area.new(
							new_color,		# same colour
							polygon,		# this outer polygon
							area.owner_id	# same owner
						)
						# Copy the source-polygon set
						var new_sources: Dictionary = {}
						for src_id in area_source_polygons_set[area].keys():
							new_sources[src_id] = true
						for src_id in area_source_polygons_set[other].keys():
							new_sources[src_id] = true
						area_source_polygons_set[new_area] = new_sources
						
						# Store the new Area so the caller can append it to `areas`
						result["new_areas"].append(new_area)
				
				# -----------------------------------------------------------------
				# Pass any holes back to the caller.
				# -----------------------------------------------------------------
				result["holes"] = split_result[1]
				result["success"] = true

	return result

func process_owner_areas(
	owner_areas: Array,
	area_source_polygons_set: Dictionary[Area, Dictionary],
	is_expanded_sub_area: Dictionary
) -> void:
	for allow_holes: bool in [false, true]:
		# Create areas lookup dictionary once for fast membership testing
		var areas_lookup: Dictionary = {}
		for a: Area in areas:
			areas_lookup[a] = true
			
		#owner_areas.sort_custom(func(a,b): return area_source_polygons[a].size() > area_source_polygons[b].size())
		
		var merges_occurred: bool = true
		var processed_areas: Dictionary = {}
		
		
		# Keep trying to merge until no more successful merges
		while merges_occurred and owner_areas.size() > 1:
			merges_occurred = false
			processed_areas.clear()
			
			# Build source to areas mapping
			var source_to_areas = build_source_to_areas_map(owner_areas, area_source_polygons_set, areas_lookup)
			
			# Try merging each area with potential candidates
			var i: int = 0
			while i < owner_areas.size():
				var area = owner_areas[i]
				
				# Skip if already processed or removed
				if processed_areas.has(area) or not areas_lookup.has(area) or not area_source_polygons_set.has(area):
					i += 1
					continue
				
				processed_areas[area] = true
				var merged_this_area: bool = false
				
				# Find potential merges
				var potential_merges = find_potential_merges(area, source_to_areas, area_source_polygons_set, areas_lookup)
				
				# Try merging with each candidate
				for other in potential_merges:
					# --- Prioritize merging expanded_sub_areas INTO non-expanded areas ---
					var area_is_expanded = is_expanded_sub_area.has(area)
					var other_is_expanded = is_expanded_sub_area.has(other)
					var merge_result: Dictionary
					if area_is_expanded and not other_is_expanded:
						# Always merge expanded into non-expanded: other absorbs area
						merge_result = attempt_merge(other, area, area_source_polygons_set, allow_holes)
						if merge_result["success"]:
							for extra_area: Area in merge_result["new_areas"]:
								areas.append(extra_area)
							areas.erase(area)
							areas_lookup.erase(area)
							var area_idx: int = owner_areas.find(area)
							if area_idx != -1:
								owner_areas.remove_at(area_idx)
								if area_idx < i:
									i -= 1
							area_source_polygons_set.erase(area)
							merged_this_area = true
							merges_occurred = true
							if merge_result["holes"].size() > 0:
								if not newly_encircled_areas.has(other):
									newly_encircled_areas[other] = []
								var hole_pairs: Array = process_encircled_holes(merge_result["holes"])
								newly_encircled_areas[other].append_array(hole_pairs)
								var total_manpower_consumed: float = 0.0
								for pair: Array in hole_pairs:
									for hole: PackedVector2Array in [pair[0]]+pair[1]:
										total_manpower_consumed += polygon_to_numbers(hole)
								map.total_manpower[other.owner_id] -= total_manpower_consumed
								
							break
					elif not area_is_expanded and other_is_expanded:
						# area absorbs other (expanded)
						merge_result = attempt_merge(area, other, area_source_polygons_set, allow_holes)
						if merge_result["success"]:
							for extra_area: Area in merge_result["new_areas"]:
								areas.append(extra_area)
							areas.erase(other)
							areas_lookup.erase(other)
							var other_idx: int = owner_areas.find(other)
							if other_idx != -1:
								owner_areas.remove_at(other_idx)
								if other_idx < i:
									i -= 1
							area_source_polygons_set.erase(other)
							merged_this_area = true
							merges_occurred = true
							if merge_result["holes"].size() > 0:
								if not newly_encircled_areas.has(area):
									newly_encircled_areas[area] = []
								var hole_pairs: Array = process_encircled_holes(merge_result["holes"])
								newly_encircled_areas[area].append_array(hole_pairs)
								var total_manpower_consumed: float = 0.0
								for pair: Array in hole_pairs:
									for hole: PackedVector2Array in [pair[0]]+pair[1]:
										total_manpower_consumed += polygon_to_numbers(hole)
								map.total_manpower[area.owner_id] -= total_manpower_consumed
							break
					else:
						# Both expanded or both not, keep current order
						merge_result = attempt_merge(area, other, area_source_polygons_set, allow_holes)
						if merge_result["success"]:
							for extra_area: Area in merge_result["new_areas"]:
								areas.append(extra_area)
							areas.erase(other)
							areas_lookup.erase(other)
							var other_idx: int = owner_areas.find(other)
							if other_idx != -1:
								owner_areas.remove_at(other_idx)
								if other_idx < i:
									i -= 1
							area_source_polygons_set.erase(other)
							merged_this_area = true
							merges_occurred = true
							if merge_result["holes"].size() > 0:
								if not newly_encircled_areas.has(area):
									newly_encircled_areas[area] = []
								var hole_pairs: Array = process_encircled_holes(merge_result["holes"])
								newly_encircled_areas[area].append_array(hole_pairs)
								var total_manpower_consumed: float = 0.0
								for pair: Array in hole_pairs:
									for hole: PackedVector2Array in [pair[0]]+pair[1]:
										total_manpower_consumed += polygon_to_numbers(hole)
								map.total_manpower[area.owner_id] -= total_manpower_consumed
							break
				
				if merged_this_area:
					processed_areas.erase(area)  # Allow this area to be checked again
					continue
				
				i += 1  # Move to next area if no merge occurred

func merge_overlapping_areas() -> Dictionary[Area, Dictionary]:
	var area_source_polygons_set: Dictionary[Area, Dictionary] = build_area_source_polygons_set()
	var areas_by_origin: Dictionary[int, Array] = group_areas_by_origin()
	var is_expanded_sub_area: Dictionary[Area, bool] = {}
	for area in expanded_sub_areas:
		is_expanded_sub_area[area] = true
	for origin_id: int in areas_by_origin:
		process_owner_areas(areas_by_origin[origin_id], area_source_polygons_set, is_expanded_sub_area)

	return area_source_polygons_set

func _add_expanded_area(
	area: Area,
	new_area: Area,
	walkable_area: Area,
	expanded_holes: Array[PackedVector2Array],
	delta: float,
	add_newly_expanded_area: bool,
	area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array],
	new_areas_expanded: Dictionary[Area, Array],
) -> bool:
	if GeometryUtils.remove_duplicate_points(new_area.polygon).size() < 3:
		return false

	var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(new_area.polygon, area_to_walkable_area_polygons[area])
	var result = GeometryUtils.split_into_inner_outer_polygons(clipped)
	if result[0].size()==0:
		return false
	var all_invalid: bool = true
	for clip: PackedVector2Array in result[0]:
		var inter: PackedVector2Array = GeometryUtils.remove_duplicate_points(clip)
		if inter.size() >= 3 and GeometryUtils.calculate_polygon_area(inter) != 0:
			all_invalid = false
		
	if all_invalid:
		return false
	
	var total_manpower_consumed: float = 0.0
	for clip: PackedVector2Array in clipped:
		total_manpower_consumed += polygon_to_numbers(clip)
		var total_manpower_regained: float = 0.0
		for clip_area: Area in new_areas_expanded.get(walkable_area, []):
			for intersect: PackedVector2Array in Geometry2D.intersect_polygons(clip_area.polygon, clip):
				total_manpower_regained += polygon_to_numbers(intersect)
		map.total_manpower[area.owner_id] += total_manpower_regained
	map.total_manpower[area.owner_id] -= total_manpower_consumed

	if add_newly_expanded_area:		
		if (area.owner_id != PLAYER_ID or (area.owner_id == PLAYER_ID and clicked_walkable_areas().has(walkable_area.polygon_id))):
			newly_encircled_areas[area].append_array(
				process_encircled_holes(expanded_holes)
			)
			# TODO Respect holes instead of this. But otherwise it can cause whole areas to blink
			if result[1].size() > 0:
				return true
			#newly_encircled_areas[area].append_array(result[1])
			for newly_expanded_area: PackedVector2Array in result[0]:
				assert(not Geometry2D.is_polygon_clockwise(newly_expanded_area))
				if (
					newly_expanded_area.size() >= 3
				):
					if not newly_expanded_areas[area].has(walkable_area):
						newly_expanded_areas[area][walkable_area] = []
					newly_expanded_areas[area][walkable_area].append(
						newly_expanded_area
					)
	return true

func _create_expanded_areas(
	area: Area,
	expanded: PackedVector2Array,
	expanded_holes: Array[PackedVector2Array],
	new_areas_expanded: Dictionary[Area, Array],
	walkable_area: Area,
	extra_source_walkable_areas: Array[Area],
	delta: float,
	add_newly_expanded_area: bool,
	area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array],
) -> void:
	if not newly_encircled_areas.has(area):
		newly_encircled_areas[area] = []			
	if not newly_expanded_areas.has(area):
		newly_expanded_areas[area] = {}
	if not newly_expanded_areas_full.has(area):
		newly_expanded_areas_full[area] = []
	
	assert(not Geometry2D.is_polygon_clockwise(expanded))
	var new_area = Area.new(
		area.color,
		expanded,
		area.owner_id
	)
	if _add_expanded_area(
		area,
		new_area,
		walkable_area,
		expanded_holes,
		delta,
		add_newly_expanded_area,
		area_to_walkable_area_polygons,
		new_areas_expanded
	):
		expanded_sub_area_origin_map[new_area] = area
		if not new_areas_expanded.has(walkable_area):
			new_areas_expanded[walkable_area] = []
		new_areas_expanded[walkable_area].append(new_area)
		
		# Track which expansion function created this area
		if current_expansion_function == "existing":
			expanded_sub_areas_from_existing.append(new_area)
		elif current_expansion_function == "boundaries":
			expanded_sub_areas_from_boundaries.append(new_area)
		elif current_expansion_function == "new":
			expanded_sub_areas_from_new.append(new_area)
		
		area_source_polygons[new_area] = [walkable_area.polygon_id]
		for extra_source_walkable_area: Area in extra_source_walkable_areas:
			area_source_polygons[new_area].append(extra_source_walkable_area.polygon_id)

func should_expand_subarea(area: Area, walkable_area: Area) -> bool:
	if (
		not walkable_areas_covered()[area][walkable_area] and
		(
			not Global.only_expand_on_click(area.owner_id) or
			clicked_walkable_areas().has(walkable_area.polygon_id)
		)
	):
		return true	
	return false

func expand_areas(delta: float) -> void:	
	var extra_areas_created: Array[Area] = []
	var all_area_strengths_raw: Dictionary[Area, float] = _compute_all_area_strengths_raw()
	var areas_sorted_by_strength: Array[Area] = _sort_areas_by_strength(all_area_strengths_raw)

	var all_area_strengths_over_all_walkable_areas: Dictionary[Area, Dictionary]
	for walkable_area: Area in walkable_areas():
		var all_area_strengths: Dictionary[Area, float] = _compute_all_area_strengths(
			walkable_area,
			all_area_strengths_raw
		)
		all_area_strengths_over_all_walkable_areas[walkable_area] = all_area_strengths

	var area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array] = {}
	for area: Area in areas_sorted_by_strength:
		if area.owner_id < 0:
			continue
		area_to_walkable_area_polygons[area] = area.polygon
	
	
	var expanded_areas: Array[Area] = []
	for area: Area in areas_sorted_by_strength:
		var new_areas_expanded: Dictionary[Area, Array] = {}

		if area.owner_id < 0:
			continue
				
		for walkable_area: Area in walkable_areas():
			var all_area_strengths: Dictionary[Area, float] = all_area_strengths_over_all_walkable_areas[walkable_area]
			current_expansion_function = "existing"
			extra_areas_created.append_array(
				_process_expansion_for_existing_walkable_area(
					area,
					walkable_area,
					delta,
					all_area_strengths,
					all_area_strengths_raw,
					new_areas_expanded,
					area_to_walkable_area_polygons
				)
			)
		if (
			ENCIRCLEMENT_CORPS and
			area.owner_id == GameSimulationComponent.PLAYER_ID
		) or Global.get_doctrine(area.owner_id) == Global.Doctrine.MASS_MOBILISATION:
			for walkable_area: Area in walkable_areas():
				current_expansion_function = "boundaries"
				extra_areas_created.append_array(
					_process_expansion_for_boundaries(
						area,
						walkable_area,
						delta,
						all_area_strengths_raw,
						new_areas_expanded,
						area_to_walkable_area_polygons
					)
				)
		for walkable_area: Area in walkable_areas():
			current_expansion_function = "new"
			extra_areas_created.append_array(
				_process_expansion_for_new_walkable_area(
					area,
					walkable_area,
					delta,
					all_area_strengths_over_all_walkable_areas,
					all_area_strengths_raw,
					new_areas_expanded,
					area_to_walkable_area_polygons
				)
			)

		for walkable_area: Area in new_areas_expanded.keys():
			expanded_areas.append_array(
				new_areas_expanded[walkable_area]
			)
			
	areas.append_array(expanded_areas)
	areas.append_array(extra_areas_created)


func _collect_holding_line_circumference(
	walkable_area: Area,
) -> void:
	for area: Area in areas:
		if area.owner_id < 0: continue		
		# Skip areas that cannot defend or that were clicked this turn
		if (
			not Global.only_expand_on_click(area.owner_id) or
			clicked_walkable_areas().has(walkable_area.polygon_id)
		) or (
			walkable_areas_covered()[area][walkable_area]
		):
			continue

		for adjacent_walkable_area: Area in adjacent_walkable_area()[walkable_area]:
			if Global.only_expand_on_click(area.owner_id) and not clicked_walkable_areas().has(adjacent_walkable_area.polygon_id):
				continue

			for shared_border: PackedVector2Array in walkable_area_shared_borders()[walkable_area][adjacent_walkable_area]:
				for other_area: Area in areas:
					if other_area.owner_id == area.owner_id or other_area.owner_id < 0:
						continue
								
					if not big_intersecting_areas.has(area):
						continue
					if not big_intersecting_areas[area].has(other_area):
						continue
					
					for intersection: PackedVector2Array in big_intersecting_areas[area][other_area]:
						if Geometry2D.is_polygon_clockwise(intersection):
							continue
						
						for clipped_intersection: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(
							shared_border,
							intersection
						):
							clipped_intersection.reverse()

							# ── Iterate segment-by-segment ────────────────────────────
							var segment_count: int = clipped_intersection.size() - 1
							for i: int in segment_count:
								var p1: Vector2 = clipped_intersection[i]
								var p2: Vector2 = clipped_intersection[i + 1]
								#
								if p1.x == 0 and p2.x == 0:
									continue
								if p1.x == Global.world_size.x and p2.x == Global.world_size.x:
									continue
								if p1.y == 0 and p2.y == 0:
									continue
								if p1.y == Global.world_size.y and p2.y == Global.world_size.y:
									continue
								var segment_polyline: PackedVector2Array = PackedVector2Array([p1, p2])
								var segment_midpoint: Vector2 = (p1 + p2) * 0.5
								
								var holding_reduction_factor: float = HOLDING_REDUCTION_FACTOR
								if walkable_area_river_neighbors().has(adjacent_walkable_area):
									if walkable_area in walkable_area_river_neighbors()[adjacent_walkable_area]:
										holding_reduction_factor = RIVER_HOLDING_REDUCTION_FACTOR
								var new_circumference_addition: float = p1.distance_to(p2)
														
								total_weighted_circumferences[area] += new_circumference_addition/holding_reduction_factor
								total_active_circumferences[area] += new_circumference_addition
							
								total_holding_circumference_by_other_area[area][other_area] += new_circumference_addition
								total_weighted_holding_circumference_by_other_area[area][other_area] += new_circumference_addition/holding_reduction_factor
								
								# ── Record polyline ────────────────────────────────────
								if not newly_holding_polylines.has(area):
									newly_holding_polylines[area] = {}
								if not newly_holding_polylines[area].has(adjacent_walkable_area):
									newly_holding_polylines[area][adjacent_walkable_area] = []
								
								
								var area_holding_polylines: Array = newly_holding_polylines[area][adjacent_walkable_area]
								var stored_weight: float = 1.0 / holding_reduction_factor	# river-aware
								area_holding_polylines.append({
									"pl":		segment_polyline,
									"weight":	stored_weight
								})

func get_strength_density(area: Area) -> float:
	if adjusted_strength_cache.has(area):
		return adjusted_strength_cache[area]
	if area.owner_id < 0:
		return 0.0
	if not total_weighted_circumferences.has(area):
		return 0.0
	if total_weighted_circumferences[area] == 0.0:
		return 0.0

	var adjusted_strength: float = Global.get_strength_density(
		total_weighted_circumferences,
		base_ownerships,
		map,
		area,
		areas,
	)
	adjusted_strength_cache[area] = adjusted_strength
	return adjusted_strength

func _compute_all_area_strengths_raw() -> Dictionary[Area, float]:
	var strengths: Dictionary[Area, float] = {}
	for area: Area in areas:
		strengths[area] = get_strength_density(area)
	return strengths

func _compute_all_area_strengths(
	walkable_area: Area,
	raw_strengths: Dictionary[Area, float],
) -> Dictionary[Area, float]:
	var strengths: Dictionary[Area, float] = {}
	for area: Area in areas:
		if area.owner_id < 0:
			strengths[area] = 0
		elif (
			Global.only_expand_on_click(area.owner_id) and not
			clicked_walkable_areas().has(walkable_area.polygon_id)
		):
			strengths[area] = 0
		else:
			strengths[area] = raw_strengths[area]
	return strengths


func _sort_areas_by_strength(strengths: Dictionary[Area, float]) -> Array[Area]:
	var sorted: Array[Area] = areas.duplicate()
	sorted.sort_custom(func(a: Area, b: Area) -> bool:
		return strengths[a] > strengths[b]
	)
	return sorted

func _get_mul_from_strength_diff(
	area_strength: float,
	enemy_area_strength: float,
	owner_id: int,
) -> float:	
	var mul_diff: float = ((area_strength - enemy_area_strength) / (area_strength + enemy_area_strength))	
	var strength_multiplier: float = 1.0
	if SHOCK_TROOPS and owner_id == PLAYER_ID:
		strength_multiplier = SHOCK_TROOPS_MULTIPLIER
	return strength_multiplier * mul_diff

func _precalculate_point_strength_multipliers(
	polygon: PackedVector2Array,
	area: Area,
	all_area_strengths_raw: Dictionary[Area, float],
	point_to_walkable_areas_map: Dictionary[Vector2, Area],
) -> Dictionary[Vector2, float]:
	var point_multipliers: Dictionary[Vector2, float] = {}
	var area_strength: float = all_area_strengths_raw[area]
	
	for point: Vector2 in polygon:
		var highest_multiplier: float = -INF  # Default when not in enemy territory
		
		var walkable_area: Area = point_to_walkable_areas_map[point]

		# 1. Multiplier from strength diff
		for enemy_area: Area in areas:
			if enemy_area.owner_id < 0 or enemy_area.owner_id == area.owner_id:
				continue
			if not slightly_offset_area_polygons.has(enemy_area):
				continue
			
			if not intersecting_original_walkable_area_start_of_tick[walkable_area].has(enemy_area):
				continue
			for slightly_offset_area_polygon: PackedVector2Array in intersecting_original_walkable_area_start_of_tick[walkable_area][enemy_area]:
			#for slightly_offset_area_polygon: PackedVector2Array in slightly_offset_area_polygons[enemy_area]:
				if Geometry2D.is_point_in_polygon(point, slightly_offset_area_polygon):
					var enemy_strength: float = all_area_strengths_raw[enemy_area]
					var multiplier: float = _get_mul_from_strength_diff(
						area_strength,
						enemy_strength,
						area.owner_id,
					)
					if multiplier > highest_multiplier:
						highest_multiplier = multiplier
		if highest_multiplier == -INF:
			#if area.owner_id == PLAYER_ID:
				#debug_points.append(point)
			highest_multiplier = 1.0

		# 2. Multiplier from air denial
		if area.owner_id != PLAYER_ID:
			var air_layer: AirLayer = get_parent().draw_component.air_layer
			var air_slowdown: float = air_layer.get_air_slowdown_multiplier(walkable_area)
			highest_multiplier *= air_slowdown		
		point_multipliers[point] = highest_multiplier
	
	return point_multipliers

func _process_expansion_for_new_walkable_area(
	area: Area,
	walkable_area: Area,
	delta: float,
	all_area_strengths_over_all_walkable_areas: Dictionary[Area, Dictionary],
	all_area_strengths_raw: Dictionary[Area, float],
	new_areas_expanded: Dictionary[Area, Array],
	area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array]
) -> Array[Area]:
	var extra_enemy_areas_created: Array[Area] = []
	if area.owner_id < 0:
		return extra_enemy_areas_created
		
	if intersecting_walkable_area_start_of_tick()[walkable_area].has(area) == false:
		return extra_enemy_areas_created

	# To allow expansion into new areas without having to click both.
	for adjacent_walkable_area: Area in adjacent_walkable_area()[walkable_area]:
		if should_expand_subarea(area, adjacent_walkable_area):
			var expansions_and_holes: Array = []
			var total_area_that_would_have_cut_enemy: Dictionary[Area, float] = {}
			for enemy_area: Area in areas:
				if enemy_area.owner_id >= 0 and enemy_area.owner_id != area.owner_id:
					total_area_that_would_have_cut_enemy[enemy_area] = 0.0
					
			var all_area_strengths: Dictionary[Area, float] = (
				all_area_strengths_over_all_walkable_areas[adjacent_walkable_area]
			)
			
			var expansion_speed_adjacent_walkable_area: float = Global.get_expansion_speed(
				EXPANSION_SPEED,
				get_strength_density(area),
				map,
				adjacent_walkable_area if not USE_UNION else union_walkable_areas_to_original_walkable_areas[adjacent_walkable_area][0],
				false,
			)
			var expansion_speed: float = expansion_speed_adjacent_walkable_area
			
			# Apply air force slowdown if this is an enemy area
			if area.owner_id != PLAYER_ID and area.owner_id >= 0:
				var air_layer: AirLayer = get_parent().draw_component.air_layer
				var air_slowdown_adjacent_walkable_area: float = air_layer.get_air_slowdown_multiplier(
					adjacent_walkable_area
				)
				var air_slowdown: float = air_slowdown_adjacent_walkable_area
				expansion_speed *= air_slowdown
			
			if expansion_speed == 0:
				continue
			if expansion_speed < MIN_EXPANSION_SPEED:
				expansion_speed = MIN_EXPANSION_SPEED
			if expansion_speed > MAX_EXPANSION_SPEED:
				expansion_speed = MAX_EXPANSION_SPEED
			var adjusted_delta: float = delta * expansion_speed
			
			if not intersecting_boundaries_walkable_area_start_of_tick()[
				walkable_area
			][adjacent_walkable_area].has(area):
				continue
			if not (
				intersecting_walkable_area_start_of_tick()[walkable_area].has(area) and
				intersecting_walkable_area_start_of_tick()[walkable_area][area].size() > 0
			):
				continue
			
			for _intersect: PackedVector2Array in (
				intersecting_boundaries_walkable_area_start_of_tick()[
						walkable_area
					][adjacent_walkable_area][area]
			):
				var slightly_expanded_polygons: Array[PackedVector2Array] = Geometry2D.offset_polyline(
					_intersect,
					adjusted_delta,
					Geometry2D.JOIN_MITER
				)
				var offset_polygons_clipped_holes: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(slightly_expanded_polygons)[1]
				var slightly_expanded_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
					slightly_expanded_polygons
				)
				var expansion: PackedVector2Array = GeometryUtils.find_largest_polygon(
					Geometry2D.intersect_polygons(
						slightly_expanded_polygon,
						adjacent_walkable_area.polygon
					)
				)
				if expansion.size() == 0:
					continue
				
				# Store the original expansion without enemy overlap
				var expansion_without_enemy_overlap: PackedVector2Array = expansion
				var combined_expansion: PackedVector2Array = expansion_without_enemy_overlap
				# First pass: calculate enemy interactions without clipping
				for enemy_area: Area in areas:
					if enemy_area.owner_id < 0 or enemy_area.owner_id == area.owner_id:
						continue
					if all_area_strengths[area] < all_area_strengths[enemy_area]:
						continue
					if intersecting_walkable_area_start_of_tick()[adjacent_walkable_area].has(enemy_area) == false:
						continue
					
					var mul_diff: float = _get_mul_from_strength_diff(
						all_area_strengths[area],
						all_area_strengths[enemy_area],
						area.owner_id,
					)
					var enemy_intersections: Array = intersecting_walkable_area_start_of_tick()[adjacent_walkable_area][enemy_area]
					for enemy_intersection: PackedVector2Array in enemy_intersections:
						if Geometry2D.is_polygon_clockwise(enemy_intersection):
							continue
							
						var total_enemy_cut_area: float = 0.0
						var total_enemy_should_have_cut_area: float = 0.0
						for enemy_intersect: PackedVector2Array in Geometry2D.intersect_polygons(combined_expansion, enemy_intersection):
							var enemy_partial_area: float = polygon_to_numbers(enemy_intersect)
							total_enemy_cut_area += enemy_partial_area
							total_area_that_would_have_cut_enemy[enemy_area] += enemy_partial_area
							total_enemy_should_have_cut_area += enemy_partial_area * mul_diff
						
						combined_expansion = GeometryUtils.find_largest_polygon(
							Geometry2D.clip_polygons(combined_expansion, enemy_intersection)
						)
						
						# Calculate enemy adjusted speed
						var enemy_adjusted_speed: float = expansion_speed
						if total_enemy_cut_area > 0.0:
							enemy_adjusted_speed *= total_enemy_should_have_cut_area / total_enemy_cut_area
							if enemy_adjusted_speed < MIN_EXPANSION_SPEED:
								enemy_adjusted_speed = MIN_EXPANSION_SPEED
							#if ENCIRCLEMENT_CORPS:
								## Applied after minimum, before maximum
								#enemy_adjusted_speed *= ENCIRCLEMENT_CORPS_BOUNDARY_SPEED_MULTIPLIER
							if enemy_adjusted_speed > MAX_EXPANSION_SPEED:
								enemy_adjusted_speed = MAX_EXPANSION_SPEED
						# Create expansion with enemy overlap using adjusted speed
						if total_enemy_cut_area == 0.0:
							continue
						else:
							# Create expansion with enemy overlap using the adjusted speed
							var reduced_adjusted_delta: float = delta * enemy_adjusted_speed
							var reduced_offset_polygons_with_enemy_overlap: Array[PackedVector2Array] = Geometry2D.offset_polyline(
								_intersect,
								reduced_adjusted_delta,
								Geometry2D.JOIN_MITER
							)
							var offset_polygons_clipped_holes_enemy: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(reduced_offset_polygons_with_enemy_overlap)[1]
							offset_polygons_clipped_holes.append_array(offset_polygons_clipped_holes_enemy)
							
							var reduced_offset_polygon_with_enemy_overlap: PackedVector2Array = GeometryUtils.find_largest_polygon(reduced_offset_polygons_with_enemy_overlap)
							if mul_diff > 1:
								reduced_offset_polygon_with_enemy_overlap = GeometryUtils.find_largest_polygon(
									Geometry2D.intersect_polygons(
										reduced_offset_polygon_with_enemy_overlap,
										enemy_intersection
									)
								)
							else:
								reduced_offset_polygon_with_enemy_overlap = GeometryUtils.find_largest_polygon(
									Geometry2D.intersect_polygons(
										reduced_offset_polygon_with_enemy_overlap,
										adjacent_walkable_area.polygon
									)
								)
							
							if reduced_offset_polygon_with_enemy_overlap.size() < 3:
								continue
								
							combined_expansion = GeometryUtils.find_largest_polygon(
								Geometry2D.merge_polygons(
									reduced_offset_polygon_with_enemy_overlap,
									combined_expansion,
								)
							)
		
				#var found_valid_merge: bool = false
				#for intersect: PackedVector2Array in intersecting_original_walkable_area_start_of_tick[original_area][area]:
					#var debug
					#if intersecting_original_walkable_area_start_of_tick[adjacent_original_area].has(area):
						#debug = intersecting_original_walkable_area_start_of_tick[adjacent_original_area][area]
					#var merge: Array[PackedVector2Array] = Geometry2D.merge_polygons(combined_expansion, intersect)
					#if not (
						#merge.size() == 2 and
						#(
							#(
								#merge[0] == combined_expansion and
								#merge[1] == intersect
							#) or
							#(
								#merge[1] == combined_expansion and
								#merge[0] == intersect
							#) 
						#)
					#):
					##if (
						##merge.size() == 1
					##):
						#found_valid_merge = true
				#if not found_valid_merge:
					#continue
							
				expansions_and_holes.append([combined_expansion, offset_polygons_clipped_holes])
			
			if expansions_and_holes.size() > 0:
				extra_enemy_areas_created.append_array(
					 _process_expansions_and_holes(
						expansions_and_holes,
						area,
						adjacent_walkable_area,
						[walkable_area],
						delta,
						all_area_strengths,
						all_area_strengths_raw,
						new_areas_expanded,
						true,
						area_to_walkable_area_polygons,
						total_area_that_would_have_cut_enemy
					)
				)
	return extra_enemy_areas_created
	
func _process_expansion_for_boundaries(
	area: Area,
	walkable_area: Area,
	delta: float,
	all_area_strengths_raw: Dictionary[Area, float],
	new_areas_expanded: Dictionary[Area, Array],
	area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array],
) -> Array[Area]:
	
	
	var extra_enemy_areas_created: Array[Area] = []
	if area.owner_id < 0:
		return extra_enemy_areas_created
	if intersecting_walkable_area_start_of_tick()[walkable_area].has(area) == false:
		return extra_enemy_areas_created
	if not should_expand_subarea(area, walkable_area):
		return extra_enemy_areas_created
	
	var total_area_that_would_have_cut_enemy: Dictionary[Area, float] = {}
	for enemy_area: Area in areas:
		if enemy_area.owner_id >= 0 and enemy_area.owner_id != area.owner_id:
			total_area_that_would_have_cut_enemy[enemy_area] = 0.0
	
	# Check boundaries between activated original areas
	for adjacent_walkable_area: Area in adjacent_walkable_area()[walkable_area]:
		if intersecting_walkable_area_start_of_tick()[adjacent_walkable_area].has(area) == false:
			continue
		if not should_expand_subarea(area, adjacent_walkable_area):
			continue
		
		
		var expansions_and_holes: Array = []
		var expansion_speed_walkable_area: float = Global.get_expansion_speed(
			EXPANSION_SPEED,
			get_strength_density(area),
			map,
			walkable_area if not  USE_UNION else union_walkable_areas_to_original_walkable_areas[walkable_area][0],
			false,
		)
		# Apply air force slowdown if this is an enemy area
		if area.owner_id != PLAYER_ID and area.owner_id >= 0:
			var air_layer: AirLayer = get_parent().draw_component.air_layer
			var air_slowdown_walkable_area: float = air_layer.get_air_slowdown_multiplier(
				walkable_area
			)
			expansion_speed_walkable_area *= air_slowdown_walkable_area
		
		# Magic number bonus to avoid simplification of tiny expansion
		if expansion_speed_walkable_area < MIN_EXPANSION_SPEED:
			expansion_speed_walkable_area = MIN_EXPANSION_SPEED
		# Applied after minimum, before maximum
		expansion_speed_walkable_area *= ENCIRCLEMENT_CORPS_BOUNDARY_SPEED_MULTIPLIER
		if expansion_speed_walkable_area > MAX_EXPANSION_SPEED:
			expansion_speed_walkable_area = MAX_EXPANSION_SPEED

		var expansion_speed_adjacent_walkable_area: float = Global.get_expansion_speed(
			EXPANSION_SPEED,
			get_strength_density(area),
			map,
			adjacent_walkable_area if not  USE_UNION else union_walkable_areas_to_original_walkable_areas[adjacent_walkable_area][0],
			false,
		)
		# Apply air force slowdown if this is an enemy area
		if area.owner_id != PLAYER_ID and area.owner_id >= 0:
			var air_layer: AirLayer = get_parent().draw_component.air_layer
			var air_slowdown_adjacent_walkable_area: float = air_layer.get_air_slowdown_multiplier(
				adjacent_walkable_area
			)
			expansion_speed_adjacent_walkable_area *= air_slowdown_adjacent_walkable_area
		
		if expansion_speed_adjacent_walkable_area == 0:
			continue
		if expansion_speed_adjacent_walkable_area < MIN_EXPANSION_SPEED:
			expansion_speed_adjacent_walkable_area = MIN_EXPANSION_SPEED
		# Applied after minimum, before maximum
		expansion_speed_adjacent_walkable_area *= ENCIRCLEMENT_CORPS_BOUNDARY_SPEED_MULTIPLIER
		if expansion_speed_adjacent_walkable_area > MAX_EXPANSION_SPEED:
			expansion_speed_adjacent_walkable_area = MAX_EXPANSION_SPEED

		var expansion_speed: float = max(
			expansion_speed_walkable_area,
			expansion_speed_adjacent_walkable_area
		)

		var adjusted_delta: float = delta * expansion_speed
		
		# Get shared border between the two areas
		for shared_border: PackedVector2Array in map.original_walkable_area_shared_borders[
			walkable_area
		][adjacent_walkable_area]:
			
			#const MAXIMUM_WIDTH_OF_EXPANDED_BOUNDARY: float = 1.0
			var maximum_width_expanded_boundary: PackedVector2Array = GeometryUtils.find_largest_polygon(
				Geometry2D.offset_polyline(
					shared_border,
					expansion_speed_adjacent_walkable_area,
					Geometry2D.JOIN_MITER
				)
			)
			# To keep movement flowing and not stopping at vertices, we comment this out
			# but it does mean that it will extend beyond adjacent_original_area..
			maximum_width_expanded_boundary = GeometryUtils.find_largest_polygon(
				Geometry2D.intersect_polygons(
					maximum_width_expanded_boundary,
					adjacent_walkable_area.polygon,
				)
			)
			var boundary_intersections: Array[PackedVector2Array] = Geometry2D.intersect_polyline_with_polygon(
				shared_border,
				area.polygon
			)
			if boundary_intersections.size() == 1 and boundary_intersections[0]==shared_border:
				continue
			
			for boundary_intersection: PackedVector2Array in boundary_intersections:
				# Expand the boundary using offset_polyline
				var expanded_boundary_polylines: Array[PackedVector2Array] = Geometry2D.offset_polyline(
					boundary_intersection,
					adjusted_delta,
					Geometry2D.JOIN_MITER
				)
				var expanded_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(expanded_boundary_polylines)

				# Clip with adjacent area polygon
				var adjacent_intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
					expanded_polygon,
					maximum_width_expanded_boundary
				)
				var expansion: PackedVector2Array = GeometryUtils.find_largest_polygon(adjacent_intersections)
				
				
				# Store the original expansion without enemy overlap
				var expansion_without_enemy_overlap: PackedVector2Array = expansion
				var combined_expansion: PackedVector2Array = expansion_without_enemy_overlap
				
				# First pass: calculate enemy interactions without clipping
				for enemy_area: Area in areas:
					if enemy_area.owner_id < 0 or enemy_area.owner_id == area.owner_id:
						continue
					if all_area_strengths_raw[area] < all_area_strengths_raw[enemy_area]:
						continue
					if not (
						intersecting_walkable_area_start_of_tick()[adjacent_walkable_area].has(enemy_area)
					):
						continue
					var enemy_intersections: Array = intersecting_walkable_area_start_of_tick()[adjacent_walkable_area][enemy_area]

					var mul_diff: float = _get_mul_from_strength_diff(
						all_area_strengths_raw[area],
						all_area_strengths_raw[enemy_area],
						area.owner_id,
					)
					for enemy_intersection: PackedVector2Array in enemy_intersections:
						if Geometry2D.is_polygon_clockwise(enemy_intersection):
							continue
							
						var total_enemy_cut_area: float = 0.0
						var total_enemy_should_have_cut_area: float = 0.0
						for enemy_intersect: PackedVector2Array in Geometry2D.intersect_polygons(combined_expansion, enemy_intersection):
							var enemy_partial_area: float = polygon_to_numbers(enemy_intersect)
							total_enemy_cut_area += enemy_partial_area
							total_area_that_would_have_cut_enemy[enemy_area] += enemy_partial_area
							total_enemy_should_have_cut_area += enemy_partial_area * mul_diff
						
						combined_expansion = GeometryUtils.find_largest_polygon(
							Geometry2D.clip_polygons(combined_expansion, enemy_intersection)
						)
						
						# Calculate enemy adjusted speed
						var enemy_adjusted_speed: float = expansion_speed
						if total_enemy_cut_area > 0.0:
							enemy_adjusted_speed *= total_enemy_should_have_cut_area / total_enemy_cut_area
							if enemy_adjusted_speed < MIN_EXPANSION_SPEED:
								enemy_adjusted_speed = MIN_EXPANSION_SPEED
							if enemy_adjusted_speed > MAX_EXPANSION_SPEED:
								enemy_adjusted_speed = MAX_EXPANSION_SPEED
						# Create expansion with enemy overlap using adjusted speed
						if total_enemy_cut_area == 0.0:
							continue
						else:
							# Create expansion with enemy overlap using the adjusted speed
							var reduced_adjusted_delta: float = delta * enemy_adjusted_speed
							var reduced_expanded_boundary_polylines: Array[PackedVector2Array] = Geometry2D.offset_polyline(
								boundary_intersection,
								reduced_adjusted_delta, 
								Geometry2D.JOIN_MITER
							)
							
							for reduced_expanded_polygon: PackedVector2Array in reduced_expanded_boundary_polylines:
								var reduced_offset_polygon_with_enemy_overlap: PackedVector2Array
								if mul_diff > 1:
									reduced_offset_polygon_with_enemy_overlap = GeometryUtils.find_largest_polygon(
										Geometry2D.intersect_polygons(
											reduced_expanded_polygon,
											enemy_intersection
										)
									)
								else:
									reduced_offset_polygon_with_enemy_overlap = GeometryUtils.find_largest_polygon(
										Geometry2D.intersect_polygons(
											reduced_expanded_polygon,
											maximum_width_expanded_boundary
										)
									)
								if reduced_offset_polygon_with_enemy_overlap.size() < 3:
									continue
								combined_expansion = GeometryUtils.find_largest_polygon(
									Geometry2D.merge_polygons(
										reduced_offset_polygon_with_enemy_overlap,
										combined_expansion,
									)
								)

				
				var empty_holes: Array[PackedVector2Array] = []
				expansions_and_holes.append([combined_expansion, empty_holes])

		if expansions_and_holes.size() > 0:
			extra_enemy_areas_created.append_array(
				_process_expansions_and_holes(
					expansions_and_holes,
					area,
					adjacent_walkable_area,
					[],
					delta,
					all_area_strengths_raw,
					all_area_strengths_raw,
					new_areas_expanded,
					true,
					area_to_walkable_area_polygons,
					total_area_that_would_have_cut_enemy
				)
			)
	return extra_enemy_areas_created

func _process_expansion_for_existing_walkable_area(
	area: Area,
	walkable_area: Area,
	delta: float,
	all_area_strengths: Dictionary[Area, float],
	all_area_strengths_raw: Dictionary[Area, float],
	new_areas_expanded: Dictionary[Area, Array],
	area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array]
) -> Array[Area]:
	var extra_enemy_areas_created: Array[Area] = []
	if area.owner_id < 0:
		return extra_enemy_areas_created
	if intersecting_walkable_area_start_of_tick()[walkable_area].has(area) == false:
		return extra_enemy_areas_created
	if not should_expand_subarea(area, walkable_area):
		return extra_enemy_areas_created
		
	var total_area_that_would_have_cut_enemy: Dictionary[Area, float] = {}
	for enemy_area: Area in areas:
		if enemy_area.owner_id >= 0 and enemy_area.owner_id != area.owner_id:
			total_area_that_would_have_cut_enemy[enemy_area] = 0.0
	
	var expansions_and_holes: Array = []

	var area_strength: float = all_area_strengths[area]
	var intersecting_polygons: Array = intersecting_walkable_area_start_of_tick()[walkable_area][area]
	for intersection: PackedVector2Array in intersecting_polygons:
		if Geometry2D.is_polygon_clockwise(intersection):
			continue
		var expansion_speed: float = Global.get_expansion_speed(
			EXPANSION_SPEED,
			get_strength_density(area),
			map,
			walkable_area if not USE_UNION else union_walkable_areas_to_original_walkable_areas[walkable_area][0],
			false,
		)
		if area.owner_id != PLAYER_ID and area.owner_id >= 0:
			var air_layer: AirLayer = get_parent().draw_component.air_layer
			var air_slowdown: float = air_layer.get_air_slowdown_multiplier(walkable_area)
			expansion_speed *= air_slowdown
		if expansion_speed == 0:
			continue
		if expansion_speed < MIN_EXPANSION_SPEED:
			expansion_speed = MIN_EXPANSION_SPEED
		if expansion_speed > MAX_EXPANSION_SPEED:
			expansion_speed = MAX_EXPANSION_SPEED
		var adjusted_delta: float = delta * expansion_speed

		var offset_polygons_without_enemy_overlap: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			intersection,
			adjusted_delta,
			Geometry2D.JOIN_MITER
		)
		var offset_polygons_clipped_holes: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(offset_polygons_without_enemy_overlap)[1]
		var expansion_without_enemy_overlap: PackedVector2Array = GeometryUtils.find_largest_polygon(
			offset_polygons_without_enemy_overlap
		)
		expansion_without_enemy_overlap = GeometryUtils.find_largest_polygon(Geometry2D.intersect_polygons(expansion_without_enemy_overlap, walkable_area.polygon))
		var combined_expansion: PackedVector2Array = expansion_without_enemy_overlap

		for enemy_area: Area in areas:
			if enemy_area.owner_id < 0 or enemy_area.owner_id == area.owner_id:
				continue
			if all_area_strengths[area] < all_area_strengths[enemy_area]:
				continue
			if intersecting_walkable_area_start_of_tick()[walkable_area].has(enemy_area) == false:
				continue
			var mul_diff: float = _get_mul_from_strength_diff(
				area_strength,
				all_area_strengths[enemy_area],
				area.owner_id
			)
			var enemy_intersections: Array = intersecting_walkable_area_start_of_tick()[walkable_area][enemy_area]
			for enemy_intersection: PackedVector2Array in enemy_intersections:
				if Geometry2D.is_polygon_clockwise(enemy_intersection):
					continue
				
				var total_enemy_cut_area: float = 0.0
				var total_enemy_should_have_cut_area: float = 0.0
				for enemy_intersect: PackedVector2Array in Geometry2D.intersect_polygons(combined_expansion, enemy_intersection):
					var enemy_partial_area: float = polygon_to_numbers(enemy_intersect)
					total_enemy_cut_area += enemy_partial_area
					total_area_that_would_have_cut_enemy[enemy_area] += enemy_partial_area
					total_enemy_should_have_cut_area += enemy_partial_area * mul_diff
				
				combined_expansion = GeometryUtils.find_largest_polygon(
					Geometry2D.clip_polygons(combined_expansion, enemy_intersection)
				)
				
				var enemy_adjusted_speed: float = expansion_speed
				if total_enemy_cut_area > 0.0:
					enemy_adjusted_speed *= total_enemy_should_have_cut_area / total_enemy_cut_area
					if enemy_adjusted_speed < MIN_EXPANSION_SPEED:
						enemy_adjusted_speed = MIN_EXPANSION_SPEED
					if enemy_adjusted_speed > MAX_EXPANSION_SPEED:
						enemy_adjusted_speed = MAX_EXPANSION_SPEED
				if total_enemy_cut_area == 0.0:
					continue
				else:
					var reduced_adjusted_delta: float = delta * enemy_adjusted_speed
					var reduced_offset_polygons_with_enemy_overlap: Array[PackedVector2Array] = (
						Geometry2D.offset_polygon(
							intersection,
							reduced_adjusted_delta,
							Geometry2D.JOIN_MITER
						)
					)
					var offset_polygons_clipped_holes_enemy: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(reduced_offset_polygons_with_enemy_overlap)[1]
					offset_polygons_clipped_holes.append_array(offset_polygons_clipped_holes_enemy)
					var reduced_offset_polygon_with_enemy_overlap: PackedVector2Array = GeometryUtils.find_largest_polygon(reduced_offset_polygons_with_enemy_overlap)
					if mul_diff > 1:
						reduced_offset_polygon_with_enemy_overlap = GeometryUtils.find_largest_polygon(
							Geometry2D.intersect_polygons(
								reduced_offset_polygon_with_enemy_overlap,
								enemy_intersection
							)
						)
					else:
						reduced_offset_polygon_with_enemy_overlap = GeometryUtils.find_largest_polygon(
							Geometry2D.intersect_polygons(
								reduced_offset_polygon_with_enemy_overlap,
								walkable_area.polygon
							)
						)
					if reduced_offset_polygon_with_enemy_overlap.size() < 3:
						continue
					combined_expansion = GeometryUtils.find_largest_polygon(
						Geometry2D.merge_polygons(
							reduced_offset_polygon_with_enemy_overlap,
							combined_expansion,
						)
					)
		
		expansions_and_holes.append([combined_expansion, offset_polygons_clipped_holes])
		
	if expansions_and_holes.size() > 0:
		extra_enemy_areas_created.append_array(
			_process_expansions_and_holes(
				expansions_and_holes,
				area,
				walkable_area,
				[],
				delta,
				all_area_strengths,
				all_area_strengths_raw,
				new_areas_expanded,
				true,
				area_to_walkable_area_polygons,
				total_area_that_would_have_cut_enemy
			)
		)

	return extra_enemy_areas_created
			
func _process_expansions_and_holes(
	expansions_and_holes: Array,
	area: Area,
	walkable_area: Area,
	extra_source_walkable_areas: Array[Area],
	delta: float,
	all_area_strengths: Dictionary[Area, float],
	all_area_strengths_raw: Dictionary[Area, float],
	new_areas_expanded: Dictionary[Area, Array],
	add_newly_expanded_area: bool,
	area_to_walkable_area_polygons: Dictionary[Area, PackedVector2Array],
	total_area_that_would_have_cut_enemy: Dictionary[Area, float],
) -> Array[Area]:
	var total_area_that_actually_cut_enemy: Dictionary[Area, float] = {}
	for enemy_area: Area in areas:
		if enemy_area.owner_id >= 0 and enemy_area.owner_id != area.owner_id:
			total_area_that_actually_cut_enemy[enemy_area] = 0.0

	
	var extra_enemy_areas_created: Array[Area] = []
	for expansion_and_holes: Array in expansions_and_holes:
		var combined_expansion: PackedVector2Array = expansion_and_holes[0]
		assert(not Geometry2D.is_polygon_clockwise(combined_expansion))
		var offset_polygons_clipped_holes: Array[PackedVector2Array] = expansion_and_holes[1]

		for enemy_area: Area in areas:
			if enemy_area.owner_id < 0:
				continue
			if enemy_area.owner_id == area.owner_id:
				continue

			if not intersecting_walkable_area_start_of_tick()[walkable_area].has(
				enemy_area
			):
				continue

			if all_area_strengths[area] <= all_area_strengths[enemy_area]:
				
				if (
					not Global.only_expand_on_click(enemy_area.owner_id) or
					clicked_walkable_areas().has(walkable_area.polygon_id)
				):
					# If an area was recently created.
					if not (all_area_strengths[area]==0 and all_area_strengths[enemy_area]==0):
						var attacker_strength_ratio: float = all_area_strengths[area]/(all_area_strengths[area]+all_area_strengths[enemy_area])
						
						#for enemy_intersect: PackedVector2Array in intersecting_walkable_area_start_of_tick()[walkable_area][enemy_area]:
							#var intersected_parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
								#enemy_intersect,
								#combined_expansion
							#)
							## Casualties taken from trying to conquer territory 
							## (this is what causes defence to still take casualties).
							#if intersected_parts.size() > 0:
								#var new_casualties: float = 0.0
								#for intersected_part: PackedVector2Array in intersected_parts:
									#new_casualties += polygon_to_numbers(intersected_part)
								#var attacker_casualties: float = (1-attacker_strength_ratio)*new_casualties*deployed_fraction(area.owner_id)
								#var defender_casualties: float = attacker_strength_ratio*new_casualties*deployed_fraction(area.owner_id)
								#take_extra_casualty(area.owner_id, attacker_casualties)
								#take_extra_casualty(enemy_area.owner_id, defender_casualties)

				
				for enemy_intersect: PackedVector2Array in intersecting_walkable_area_start_of_tick()[walkable_area][enemy_area]:
					var clips: Array[PackedVector2Array] = Geometry2D.clip_polygons(
						combined_expansion,
						enemy_intersect
					)
					combined_expansion = GeometryUtils.find_largest_polygon(
						clips
					)
		expansion_and_holes[0] = combined_expansion

		for enemy_area: Area in areas:
			if enemy_area.owner_id < 0:
				continue
			if enemy_area.owner_id == area.owner_id:
				continue

			if not intersecting_walkable_area_start_of_tick()[walkable_area].has(
				enemy_area
			):
				continue
			
			if all_area_strengths[area] > all_area_strengths[enemy_area]:			
				# ----------------------------------------------------------------------
				# ❷  Clip the enemy polygon with the combined expansion.
				# ----------------------------------------------------------------------
				var intersected_parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
					enemy_area.polygon,
					combined_expansion
				)
				if intersected_parts.size() > 0:
					for intersected_part: PackedVector2Array in intersected_parts:
						var new_casualties: float = polygon_to_numbers(intersected_part)
						total_area_that_actually_cut_enemy[enemy_area] += new_casualties

					var clipped_parts: Array[PackedVector2Array] = Geometry2D.clip_polygons(
						enemy_area.polygon,
						combined_expansion
					)
					if clipped_parts.size() == 0:
						# Enemy completely wiped out; mark its polygon empty
						enemy_area.polygon = PackedVector2Array()
					else:
						# Keep the largest piece on the existing Area …
						var largest_part: PackedVector2Array = GeometryUtils.find_largest_polygon(
							clipped_parts
						)
						enemy_area.polygon = largest_part

						# … and turn each remaining outer polygon into a new Area.
						for part: PackedVector2Array in clipped_parts:
							if part == largest_part:
								continue
							if part.size() < 3:
								continue
							if Geometry2D.is_polygon_clockwise(part):
								continue

							var new_enemy: Area = Area.new(
								enemy_area.color,
								part,
								enemy_area.owner_id
							)
							expanded_sub_area_origin_map[new_enemy] = enemy_area
							area_source_polygons[new_enemy] = area_source_polygons[enemy_area].duplicate()
							extra_enemy_areas_created.append(new_enemy)

					# ----------------------------------------------------------------------
					# ❸  Update the cached intersections for the *original* enemy_area.
					# ----------------------------------------------------------------------
					var enemy_intersections: Array = (
						intersecting_walkable_area_start_of_tick()[walkable_area][enemy_area]
					)
					for idx: int in range(enemy_intersections.size()):
						enemy_intersections[idx] = GeometryUtils.find_largest_polygon(
							Geometry2D.clip_polygons(
								enemy_intersections[idx],
								combined_expansion
							)
						)
					
					# The enemy is no longer fully covered.
					walkable_areas_covered()[enemy_area][walkable_area] = false
	
	
	for enemy_area: Area in total_area_that_actually_cut_enemy.keys():
		var _total_area_that_actually_cut_enemy: float = total_area_that_actually_cut_enemy[enemy_area]
		if _total_area_that_actually_cut_enemy == 0.0:
			continue
		var _total_area_that_would_have_cut_enemy: float = total_area_that_would_have_cut_enemy[enemy_area]
		
		
		var attacker_strength_ratio: float = all_area_strengths[area]/(all_area_strengths[area]+all_area_strengths[enemy_area])
		# If an area was recently created.
		if all_area_strengths[area]==0 and all_area_strengths[enemy_area]==0:
			continue
			
		assert(not is_nan(attacker_strength_ratio))


		if (
			not Global.only_expand_on_click(enemy_area.owner_id) or
			clicked_walkable_areas().has(walkable_area.polygon_id)
		):
			# By default, both sides effectively take _total_area_that_would_have_cut_enemy casualties.
			
			# Casualties are exchanged for manpower due to battle.
			if _total_area_that_would_have_cut_enemy>_total_area_that_actually_cut_enemy:
				var defender_casualties: float = (
					attacker_strength_ratio*
					(
						_total_area_that_would_have_cut_enemy-
						_total_area_that_actually_cut_enemy
					)*
					deployed_fraction(area.owner_id)
				)
				take_extra_casualty(enemy_area.owner_id, defender_casualties)
			
			# The enemy actually loses area
			take_casualty_from_area_loss(enemy_area.owner_id, _total_area_that_actually_cut_enemy)
			var attacker_casualties: float = (
				(1-attacker_strength_ratio)*
				_total_area_that_would_have_cut_enemy*
				deployed_fraction(area.owner_id)
			)
			var saboteur_bonus: float = 1.0
			if SABOTEUR and area.owner_id != PLAYER_ID:
				saboteur_bonus = SABOTEUR_BONUS
			# Casualties are exchanged for manpower due to battle.
			take_extra_casualty(area.owner_id, saboteur_bonus*attacker_casualties)
		else:
			# By defaylt, no casualties taken on either side	
			map.total_manpower[enemy_area.owner_id] += _total_area_that_actually_cut_enemy

	for expansion_and_holes: Array in expansions_and_holes:
		var combined_expansion: PackedVector2Array = expansion_and_holes[0]
		var offset_polygons_clipped_holes: Array[PackedVector2Array] = expansion_and_holes[1]
		_create_expanded_areas(
			area,
			combined_expansion,
			offset_polygons_clipped_holes,
			new_areas_expanded,
			walkable_area,
			extra_source_walkable_areas,
			delta,
			add_newly_expanded_area,
			area_to_walkable_area_polygons
		)
	return extra_enemy_areas_created	

# ------------------------------------------------------------------
#  Shared helper – spawns a circular "claim area", clips / merges it
#  with the existing map – works for both Train and Tank instances.
# ------------------------------------------------------------------
func _spawn_area_for_vehicle(vehicle: Vehicle) -> void:
	var collision_pairs: Array = clip_obstacles(
		vehicle.collision_polygon(),
		areas,
	)
	#collision_polygon = clip_obstacles(collision_polygon, areas)
	var collision_polygon: PackedVector2Array = PackedVector2Array()
	var collision_area: float = -1.0
	if collision_pairs.size() > 0:
		for pair in collision_pairs:
			var outer_poly: PackedVector2Array = pair[0]
			var a: float = GeometryUtils.calculate_polygon_area(outer_poly)
			if a > collision_area:
				collision_area = a
				collision_polygon = outer_poly
	
	if collision_area == -1:
		return

	
	# ─── 1  Change possible owner if fully inside an enemy sub-area ───
	var new_id: int = vehicle.owner_id
	#var found_owner: bool = false
	for area: Area in areas:
		#if not found_owner and area.owner_id == vehicle.owner_id:
			#var vehicle_areas: Dictionary[Vector2, Area] = GeometryUtils.points_to_areas_mapping(
				#[vehicle.global_position], map, map.original_walkable_areas
			#)
			#var original_area: Area = vehicle_areas[vehicle.global_position]
			#if not newly_expanded_areas.has(area):
				#newly_expanded_areas[area] = {}
			#if not newly_expanded_areas[area].has(original_area):
				#newly_expanded_areas[area][original_area] = []
			#newly_expanded_areas[area][original_area].append(collision_polygon)
			#found_owner = true
		if area.owner_id < 0 or area.owner_id == vehicle.owner_id:
			continue
		var inters: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			area.polygon, collision_polygon
		)
		if inters.size() == 1:
			if GeometryUtils.same_polygon_shifted(inters[0], collision_polygon):
				new_id = area.owner_id
				break
	if new_id != vehicle.owner_id:
		vehicle.owner_id = new_id

	# ─── 2  Clip away enemy area that the circle overlaps ─────────────
	for enemy_area: Area in areas:
		if enemy_area.owner_id < 0 or enemy_area.owner_id == vehicle.owner_id:
			continue

		var intersected_parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			enemy_area.polygon,
			collision_polygon
		)
		if intersected_parts.size() > 0:
			for intersected_part: PackedVector2Array in intersected_parts:
				var new_casualties: float = polygon_to_numbers(intersected_part)
				#map.total_casualties[enemy_area.owner_id] += deployed_fraction(enemy_area.owner_id)*new_casualties
				take_casualty_from_area_loss(enemy_area.owner_id, new_casualties)
			
			var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(
				enemy_area.polygon, collision_polygon
			)
			if clipped.is_empty():
				enemy_area.polygon = PackedVector2Array()
				continue

			var outers: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(clipped)[0]
			var main: PackedVector2Array = GeometryUtils.find_largest_polygon(outers)
			enemy_area.polygon = main
			for poly: PackedVector2Array in outers:
				if poly == main:
					continue
				var extra: Area = Area.new(enemy_area.color, poly, enemy_area.owner_id)
				areas.append(extra)

	var total_area_already_covered: float = 0.0

	# ─── 3  Merge circle with friendly areas (or create new) ──────────
	var merged: bool = false
	for area: Area in areas:
		if area.owner_id != vehicle.owner_id:
			continue
		var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			area.polygon, collision_polygon
		)		
		if not intersections.is_empty():
			for intersection: PackedVector2Array in intersections:
				total_area_already_covered += polygon_to_numbers(intersection)
			
			if merged:
				continue
				
			var merged_polys: Array[PackedVector2Array] = Geometry2D.merge_polygons(
				area.polygon, collision_polygon
			)
			var holes: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(
				merged_polys
			)[1]
			var polys: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(
				merged_polys
			)[0]
			if polys.size() == 1:
				area.polygon = GeometryUtils.find_largest_polygon(merged_polys)
				if newly_encircled_areas.has(area) == false:
					newly_encircled_areas[area] = []
				newly_encircled_areas[area].append_array(
					process_encircled_holes(holes)
				)
				merged = true

	if merged == false:
		var fresh: Area = Area.new(
			Global.get_player_color(vehicle.owner_id), collision_polygon, vehicle.owner_id
		)
		areas.append(fresh)
	
	var new_territory: float = polygon_to_numbers(collision_polygon)
	if new_territory >= total_area_already_covered:
		var manpower_used: float = (new_territory-total_area_already_covered)
		map.total_manpower[vehicle.owner_id] -= manpower_used

func _average_overlap_normal(
		obstacle: PackedVector2Array,
		body: PackedVector2Array,
		body_center: Vector2
) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var hits: int = 0

	var obs_count: int = obstacle.size()
	for i: int in obs_count:
		var a: Vector2 = obstacle[i]
		var b: Vector2 = obstacle[(i + 1) % obs_count]

		var body_count: int = body.size()
		var overlaps: bool = false
		for j: int in body_count:
			var p1: Vector2 = body[j]
			var p2: Vector2 = body[(j + 1) % body_count]
			if Geometry2D.segment_intersects_segment(a, b, p1, p2) != null:
				overlaps = true
				break

		if overlaps == true:
			var seg: Vector2 = b - a
			var n_raw: Vector2 = Vector2(seg.y, -seg.x).normalized()

			# point the normal *towards* the body centre
			var to_body: Vector2 = (body_center - (a + b) * 0.5).normalized()
			var n: Vector2 = n_raw
			if n_raw.dot(to_body) < 0.0:
				n = -n_raw

			sum += n
			hits += 1

	if hits == 0:
		return Vector2.ZERO
	else:
		return (sum / float(hits)).normalized()

func _update_tanks_and_spawn(delta: float) -> void:
	for tank: Tank in map.tanks:
		_spawn_area_for_vehicle(tank)

		var speed: float = tank.get_speed(map)
		
		# Add territorial expansion speed bonus for tanks
		var expansion_speed_bonus: float = _get_tank_expansion_speed_bonus(tank)
		speed += expansion_speed_bonus
		
		var step: Vector2 = tank.direction.normalized() * speed * delta
		var new_pos: Vector2 = tank.global_position + step

		var offset: Vector2 = new_pos - tank.global_position
		var shifted_poly: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in tank.collision_polygon():
			shifted_poly.append(v + offset)

		var all_polys: Array[Area] = map.original_obstacles.duplicate()
		for area_it: Area in areas:
			if area_it.owner_id == -3:
				all_polys.append(area_it)
				break

		var collected_normals: Array[Vector2] = []

		# Check obstacle collisions
		for obs: Area in all_polys:
			var hit: bool = false

			if obs.owner_id == -2:
				hit = Geometry2D.intersect_polygons(shifted_poly, obs.polygon).is_empty() == false
			else:
				for p: Vector2 in shifted_poly:
					if Geometry2D.is_point_in_polygon(p, obs.polygon) == false:
						hit = true
						break

			if hit == true:
				var n: Vector2 = _average_overlap_normal(obs.polygon, shifted_poly, tank.global_position)
				if n != Vector2.ZERO:
					collected_normals.append(n)

		# Check boundary collisions between activated and non-activated areas
		var tank_current_area: Area = _get_original_area_at_point(tank.global_position)
		if tank_current_area != null:
			for adjacent_original_area: Area in map.adjacent_original_walkable_area[tank_current_area]:
				# Check if current area is activated but adjacent area is not
				var current_activated: bool = (
					not Global.only_expand_on_click(tank.owner_id) or
					clicked_original_walkable_areas.has(tank_current_area.polygon_id)
				)
				var adjacent_activated: bool = (
					not Global.only_expand_on_click(tank.owner_id) or
					clicked_original_walkable_areas.has(adjacent_original_area.polygon_id)
				)
				
				if current_activated and not adjacent_activated:
					# Treat the adjacent non-activated area as an obstacle
					# Use the same collision logic as obstacles
					var hit: bool = false
					
					if adjacent_original_area.owner_id == -2:
						hit = Geometry2D.intersect_polygons(shifted_poly, adjacent_original_area.polygon).is_empty() == false
					else:
						for p: Vector2 in shifted_poly:
							if Geometry2D.is_point_in_polygon(p, adjacent_original_area.polygon) == false:
								hit = true
								break
					
					if hit == true:
						var n: Vector2 = _average_overlap_normal(adjacent_original_area.polygon, shifted_poly, tank.global_position)
						if n != Vector2.ZERO:
							collected_normals.append(n)

		if collected_normals.size() > 0:
			var avg: Vector2 = Vector2.ZERO
			for n_vec: Vector2 in collected_normals:
				avg += n_vec
			avg = (avg / float(collected_normals.size())).normalized()

			# ❶ bounce **only** when moving into the obstacle
			if tank.direction.dot(avg) < 0.0:
				tank.direction = tank.direction.bounce(avg).normalized()

			new_pos = tank.global_position + tank.direction.normalized() * speed * delta

		tank.global_position = new_pos

func _get_tank_expansion_speed_bonus(tank: Tank) -> float:
	var expansion_speed_bonus: float = 0.0
	
	# Get the original area where the tank is located
	var tank_original_area: Area = _get_original_area_at_point(tank.global_position)
	if tank_original_area == null:
		return 0.0
	
	# For Player ID tanks, only apply bonus if the original area is clicked
	if tank.owner_id == PLAYER_ID:
		if not clicked_original_walkable_areas.has(tank_original_area.polygon_id):
			return 0.0
	
	# Find the area that controls this tank's position to get its strength
	var controlling_area: Area = null
	for area: Area in areas:
		if area.owner_id == tank.owner_id:
			if Geometry2D.is_point_in_polygon(tank.global_position, area.polygon):
				controlling_area = area
				break
	
	if controlling_area == null:
		return 0.0
	
	# Calculate expansion speed using the same method as territory expansion
	expansion_speed_bonus = Global.get_expansion_speed(
		EXPANSION_SPEED,
		get_strength_density(controlling_area),
		map,
		tank_original_area,
		false,
	)
	
	# Apply air force slowdown if this is not a player tank
	if tank.owner_id != PLAYER_ID and tank.owner_id >= 0:
		var air_layer: AirLayer = get_parent().draw_component.air_layer
		var air_slowdown: float = air_layer.get_air_slowdown_multiplier(tank_original_area)
		expansion_speed_bonus *= air_slowdown
	
	# Apply the same speed limits as territory expansion
	if expansion_speed_bonus < MIN_EXPANSION_SPEED:
		expansion_speed_bonus = MIN_EXPANSION_SPEED
	if expansion_speed_bonus > MAX_EXPANSION_SPEED:
		expansion_speed_bonus = MAX_EXPANSION_SPEED
	
	return expansion_speed_bonus

func _update_trains_and_spawn(delta: float) -> void:
	# Iterate over every train in the map
	for train: Train in map.trains:
		# ────────────────────────────────────────────────────────────────
		# ❶  Spawn / clip / merge the circular area (shared helper)
		# ────────────────────────────────────────────────────────────────
		_spawn_area_for_vehicle(train)

		# ────────────────────────────────────────────────────────────────
		# ❷  Advance the train along its assigned road
		# ────────────────────────────────────────────────────────────────
		var path: PackedVector2Array = train.road
		if path.size() < 2:
			continue								# malformed road

		# Cache total road length once, store in metadata
		if train.has_meta("road_len") == false:
			var len_acc: float = 0.0
			for i: int in path.size() - 1:
				len_acc += path[i].distance_to(path[i + 1])
			train.set_meta("road_len", len_acc)
		var road_len: float = train.get_meta("road_len")
		if road_len == 0.0:
			continue								# degenerate path

		# Move forward
		train.distance += train.get_speed(map) * delta
		train.distance = fmod(train.distance, road_len)

		# Sample new position along the poly-line
		var remaining: float = train.distance
		for i: int in path.size() - 1:
			var seg_len: float = path[i].distance_to(path[i + 1])
			if remaining <= seg_len:
				var t: float = remaining / seg_len
				train.global_position = path[i].lerp(path[i + 1], t)
				break
			remaining -= seg_len

func _update_ships_and_spawn(delta: float) -> void:
	for ship in map.ships:
		_spawn_area_for_vehicle(ship)
		ship.move_along_water_graph(map, delta)

	
func _physics_process(delta: float) -> void:
	simulation_time_accum += delta
	
	print_iter += delta	
	
	_clear_start_of_tick(delta)
	_collect_strength_manpower_casualties_sum()


	var areas_before_updates: Array[Area] = []
	for area: Area in areas:
		areas_before_updates.append(area)
	expand_areas(delta)

	for area: Area in areas:
		if not area in areas_before_updates:
			expanded_sub_areas.append(area)
	if print_iter > print_time:
		print(
			"\n",
			"num expanded areas - \nexisting: ",
			expanded_sub_areas_from_existing.size(),
			" \nboundaries: ",
			expanded_sub_areas_from_boundaries.size(),
			" \nnew: ",
			expanded_sub_areas_from_new.size(),
			" \ntotal: ",
			expanded_sub_areas.size(),
			"\n",
		)	
	var area_source_polygons_set: Dictionary[Area, Dictionary] = merge_overlapping_areas()
	var new_areas: Array[Area] = []
	for area: Area in areas:
		if area.owner_id < 0 or area_source_polygons_set.has(area):
			new_areas.append(area)
	areas = new_areas
	


	merge_overlapping_areas_brute_force()
	
	#var was_clipped: bool = true
	#var areas_checked: Array = []
	#while was_clipped:
		#was_clipped = false
		#
		#var all_area_strengths_raw: Dictionary[Area, float] = _compute_all_area_strengths_raw()
		#
		#var areas_sorted_by_strength: Array[Area] = areas.duplicate()
		#areas_sorted_by_strength.sort_custom(func(a,b): return all_area_strengths_raw[a] > all_area_strengths_raw[b])
		#
		#while areas_sorted_by_strength.size() > 0:
			#var strongest_area: Area = areas_sorted_by_strength.pop_front()
			#if areas_checked.has(strongest_area):
				#continue
			#areas_checked.append(strongest_area)
			#if strongest_area.owner_id < 0:
				#continue
			#was_clipped = clip_weaker_enemies(strongest_area, areas_sorted_by_strength)
			#if was_clipped:
				#break

	var extra_after_clip: Array[Area] = []
	for area: Area in areas:
		if area.owner_id >= 0:
			var clip_pairs: Array = clip_obstacles(area.polygon, areas)
			_apply_clip_result_to_area(area, clip_pairs, extra_after_clip)
	areas.append_array(extra_after_clip)


	# Important that we clear out any small areas, before clipping weaker. It may
	# accidentally lead to casualties..
	remove_small_areas()

	### Battle areas
	var battle_areas: Array[Area] = []
	for area: Area in areas:
		if area.owner_id >= 0:
			battle_areas.append(area)
	for battle_area: Area in battle_areas:
		clip_weaker_enemies(battle_area, battle_areas)

	# Artillery (instant shots with segmented fading trail)
	if ARTILLERY:
		_update_artillery(delta)


	# Important that we clear out any small areas, before simplification proceeds. It may
	# accidentally expand them..
	remove_small_areas()

	# Compute strengths and offset polygons for simplification
	var all_area_strengths_raw: Dictionary[Area, float] = _compute_all_area_strengths_raw()
	for area in areas:
		if area.owner_id >= 0:
			if print_iter > print_time:
				print("before ", area.polygon.size())
			
			var point_to_walkable_areas_map: Dictionary[Vector2, Area] = (
				GeometryUtils.points_to_areas_mapping(area.polygon, map, map.original_walkable_areas)
			)

			var polygon_before_simplificaiton: PackedVector2Array = area.polygon
			var point_strength_multipliers: Dictionary[Vector2, float] = _precalculate_point_strength_multipliers(
				area.polygon,
				area,
				all_area_strengths_raw,
				point_to_walkable_areas_map,
			)
			
			area.polygon = VisvalingamSimplifier.simplify_polygon_visvalingams(
				area.polygon,
				SIMPLIFICATION_TOLERANCE,
				EXPANSION_SPEED,
				map,
				point_to_walkable_areas_map,
				get_strength_density(area),
				area,
				clicked_original_walkable_areas,
				point_strength_multipliers,
			)
			#area.polygon = NavigationServer2D.simplify_path(area.polygon, SIMPLIFICATION_TOLERANCE)
			
			var expanded_areas_from_simplification: Array[PackedVector2Array] = Geometry2D.clip_polygons(
				area.polygon,
				polygon_before_simplificaiton,
			)
			for expanded_area_from_simplification: PackedVector2Array in expanded_areas_from_simplification:
				map.total_manpower[area.owner_id] -= polygon_to_numbers(expanded_area_from_simplification)

			var removed_areas_from_simplification: Array[PackedVector2Array] = Geometry2D.clip_polygons(
				polygon_before_simplificaiton,
				area.polygon,
			)
			for removed_area_from_simplification: PackedVector2Array in removed_areas_from_simplification:
				map.total_manpower[area.owner_id] += polygon_to_numbers(removed_area_from_simplification)
			
			var expanded_areas_from_simplification_inner: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(expanded_areas_from_simplification)[0]
			var expanded_areas_from_simplification_holes: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(expanded_areas_from_simplification)[1]
			
			# TODO Should have to respect holes instead of skipping them
			if expanded_areas_from_simplification_holes.size() == 0:
			
				if not newly_expanded_areas_full.has(area):
					newly_expanded_areas_full[area] = []
				
				for expanded_area_from_simplification: PackedVector2Array in expanded_areas_from_simplification:
					newly_expanded_areas_full[area].append(expanded_areas_from_simplification)

			if print_iter > print_time:
				print("after ", area.polygon.size())
	
	_update_tanks_and_spawn(delta)
	_update_trains_and_spawn(delta)
	_update_ships_and_spawn(delta)
	
	for area in areas:
		area.color = Global.get_player_color(area.owner_id)
		if area.owner_id >= 0:
			assert(not Geometry2D.is_polygon_clockwise(area.polygon))

	
	# Collect after all updates to areas to get all visualizations right.
	for area: Area in areas:
		if area.owner_id >= 0:
			area.clear_cache()
	
	remove_small_areas()

	_update_bases()
	_clear_end_of_tick(delta)
	collect_end_of_tick()
	balance_strength_manpower_casualties()
	regain_manpower(delta)
	clamp_manpower()

	

	if print_iter > print_time:
		if total_strength_by_owner_id.has(1):
			print(max(map.total_manpower[1], 0)+map.total_casualties[1]+total_strength_by_owner_id[1])
			
	requires_redraw.emit()

	if print_iter > print_time:
		print_iter = 0.0
	

func clip_weaker_enemies(area: Area, other_areas_sorted: Array[Area]) -> bool:	
	var was_clipped: bool = false
	
	for other_area: Area in other_areas_sorted:
		# Skip obstacles and same-team areas
		if other_area.owner_id<0 or area.owner_id == other_area.owner_id:
			continue

		# STEP 1: Get parts outside the stronger area (use clip_polygons)
		var outside_parts = Geometry2D.clip_polygons(other_area.polygon, area.polygon)
		
		if outside_parts.size() == 0 or (
			outside_parts.size() == 1 and 
			GeometryUtils.calculate_polygon_area(outside_parts[0])==0
		):
			was_clipped = true
			var new_casualties: float = polygon_to_numbers(other_area.polygon)
			#map.total_casualties[other_area.owner_id] += deployed_fraction(other_area.owner_id)*new_casualties
			take_casualty_from_area_loss(other_area.owner_id, new_casualties)
			other_area.polygon = PackedVector2Array()

	return was_clipped

	
#func clip_weaker_enemies(area: Area, other_areas_sorted: Array[Area]) -> bool:
	#var map: Dictionary[Area, Array] = {}
	#
	#var was_clipped: bool = false
	#
	#for other_area: Area in other_areas_sorted:
		## Skip obstacles and same-team areas
		#if other_area.owner_id<0 or area.owner_id == other_area.owner_id:
			#continue
		#
		#var new_areas: Array[Area] = []
		#var parts_to_preserve: Array[PackedVector2Array] = []
		#
		## STEP 1: Get parts outside the stronger area (use clip_polygons)
		#var outside_parts = Geometry2D.clip_polygons(other_area.polygon, area.polygon)
		#
		#if outside_parts.size() != 1:
			#was_clipped = true
		#
		#if outside_parts.size() == 1:
			#other_area.polygon = outside_parts[0]
		#else:
			#for part in outside_parts:
				#if not Geometry2D.is_polygon_clockwise(part):
					#parts_to_preserve.append(part)
			#
			#other_area.polygon = GeometryUtils.find_largest_polygon(
				#parts_to_preserve
			#)
			#
			## STEP 4: Create new areas from all preserved parts
			#for preserved_part in parts_to_preserve:
				#if preserved_part == other_area.polygon:
					#continue
				## Create new area with this part and its relevant holes
				#var new_area = Area.new(
					#other_area.color,
					#preserved_part,
					#other_area.owner_id
				#)
				#new_areas.append(new_area)
		#
			## Map the original area to its new parts (might be empty if completely eliminated)
			#map[other_area] = new_areas
#
	#for other_area: Area in map.keys():
		##areas.erase(other_area)
		#areas.append_array(map[other_area])
		#
	#return was_clipped

func _update_bases() -> void:
	
	var lost_bases_to_neutral_by_owner_id: Dictionary[int, Array]
	for base: Base in map.bases:
		if not lost_bases_to_neutral_by_owner_id.has(base.owner_id):
			lost_bases_to_neutral_by_owner_id[base.owner_id] = []
	
	var neutral_id: int = -1
	for base: Base in map.bases:
		var found_area: bool = false
		for area: Area in base_ownerships.keys():
			if area.owner_id < 0:
				continue
			if base in base_ownerships[area]:
				found_area = true
				break
		if not found_area and base.owner_id != neutral_id:
			lost_bases_to_neutral_by_owner_id[base.owner_id].append(base)
			
		
	for previous_owner_id: int in lost_bases_to_neutral_by_owner_id.keys():
		for base: Base in lost_bases_to_neutral_by_owner_id[previous_owner_id]:
			var manpower_required_for_base: float = Area.STRENGTH_FROM_BASE*UnitLayer.MAX_UNITS*UnitLayer.NUMBER_PER_UNIT
			var current_strength: float = total_strength_by_owner_id[previous_owner_id]
			var current_strength_plus_uncontrolled_bases: float = (
				current_strength + 
				lost_bases_to_neutral_by_owner_id[previous_owner_id].size()*manpower_required_for_base
			)
			if current_strength_plus_uncontrolled_bases < manpower_required_for_base:
				map.total_casualties[previous_owner_id] += (manpower_required_for_base-current_strength_plus_uncontrolled_bases)
				map.total_manpower[previous_owner_id] = 0.0
			else:
				map.total_manpower[previous_owner_id] += manpower_required_for_base
			
			base.owner_id = neutral_id
			var old_color: Color = Global.get_player_color(previous_owner_id)
			var new_color: Color = Global.get_player_color(base.owner_id)
			trigger_conquest_animation(base, old_color, new_color)
			
			
			
	for base : Base in map.bases:
		base.under_attack = false
		var previous_owner_id: = base.owner_id
		var base_area : float = GeometryUtils.calculate_polygon_area(base.polygon)
		if base_area == 0.0:
			continue
		
		for area : Area in areas:
			if area.owner_id < 0 or area.owner_id==base.owner_id:
				continue									# Obstacles / neutral
			var inters : Array[PackedVector2Array] = Geometry2D.intersect_polygons(
				base.polygon,
				area.polygon
			)
			if inters.is_empty():
				continue
			
			if inters.size()==1 and GeometryUtils.same_polygon_shifted(inters[0],base.polygon):
				if area.owner_id != base.owner_id:					
					base.owner_id = area.owner_id			# Capture!
					
					var manpower_required_for_base: float = Area.STRENGTH_FROM_BASE*UnitLayer.MAX_UNITS*UnitLayer.NUMBER_PER_UNIT
					map.total_manpower[area.owner_id] -= manpower_required_for_base
					if previous_owner_id != neutral_id:
						var current_strength: float = total_strength_by_owner_id[previous_owner_id]
						var current_strength_plus_uncontrolled_bases: float = (
							current_strength + 
							lost_bases_to_neutral_by_owner_id[previous_owner_id].size()*manpower_required_for_base
						)
						if current_strength_plus_uncontrolled_bases < manpower_required_for_base:
							map.total_casualties[previous_owner_id] += (manpower_required_for_base-current_strength_plus_uncontrolled_bases)
							map.total_manpower[previous_owner_id] = 0.0
						else:
							map.total_manpower[previous_owner_id] += manpower_required_for_base
				break										# No need to test further
			else:
				if area.owner_id != base.owner_id:
					base.under_attack = true				# Partial overlap

		if base.owner_id != previous_owner_id:
			var old_color: Color = Global.get_player_color(previous_owner_id)
			var new_color: Color = Global.get_player_color(base.owner_id)
			trigger_conquest_animation(base, old_color, new_color)
			

func trigger_conquest_animation(base: Base, from_color: Color, to_color: Color) -> void:
	base.conquest_animation_time = 0.0
	base.conquest_from_color = from_color
	base.conquest_to_color = to_color
	base.is_being_conquered = true

func remove_small_areas() -> void:
	var new_areas: Array[Area] = areas.duplicate()
	for area in areas:
		if area.owner_id < 0: continue
		if not area.get_total_area()/(Global.world_size.x*Global.world_size.y) >= MINIMUM_AREA_STRENGTH:
			new_areas.erase(area)
	areas = new_areas

func balance_strength_manpower_casualties() -> void:
	for owner_id: int in get_playable_ids():
		var strength_manpower_casualties_sum: float = (
			max(map.total_manpower[owner_id], 0)+
			map.total_casualties[owner_id]+
			total_strength_by_owner_id[owner_id]
		)
		var diff: float = (
			strength_manpower_casualties_sum_start_of_tick[owner_id] -
			strength_manpower_casualties_sum
		)
		if diff != 0.0:
			# Tally difference to casualties in case battle happened
			if map.total_casualties[owner_id] != total_casualties_start_of_tick[owner_id] and diff > 0:
				map.total_casualties[owner_id] += diff
				#if diff > 0:
					#map.total_casualties[owner_id] += diff
				#else:
					#map.total_manpower[owner_id] += diff
			else:
				# Need to update cache to stay constant
				var manpower_deficit: float = total_unmodified_strength_by_owner_id[owner_id]-total_strength_by_owner_id[owner_id]
				assert(manpower_deficit >= 0)
				total_strength_by_owner_id[owner_id] += min(diff, manpower_deficit)
				map.total_manpower[owner_id] += diff#(diff-min(diff, manpower_deficit))
					
				
func clamp_manpower() -> void:
	for owner_id: int in map.total_manpower.keys():			
		var total_strength_unmodified: float = Global.get_total_owner_strength_unmodified(
			owner_id,
			areas,
			map,
			total_weighted_circumferences,
			base_ownerships,
		)
		var maximum_fielded_manpower: float = total_strength_unmodified
		
		if Global.get_doctrine(owner_id) == Global.Doctrine.MASS_MOBILISATION:
			var actual_maximum_fielded_manpower: float = 0.0
			for area: Area in areas:
				if area.owner_id == owner_id:
					actual_maximum_fielded_manpower += (
						GeometryUtils.calculate_polygon_area(area.polygon) /
						(Global.world_size.x*Global.world_size.y)
					) * UnitLayer.MAX_UNITS*UnitLayer.NUMBER_PER_UNIT
		
			var old_deficit: float = map.mass_mobilisation_manpower_deficit[owner_id]
			var new_deficit: float = maximum_fielded_manpower-actual_maximum_fielded_manpower
			map.total_manpower[owner_id]  -= (new_deficit-old_deficit)
			map.mass_mobilisation_manpower_deficit[owner_id] = new_deficit
			
		
		
		map.total_manpower[owner_id] = max(map.total_manpower[owner_id], -maximum_fielded_manpower)
		
		map.total_manpower[owner_id] = min(
			map.total_manpower[owner_id],
			Global.get_maximum_manpower(
				Global.get_doctrine(owner_id)
			)
		)
		
func regain_manpower(delta: float) -> void:
	for owner_id: int in map.total_manpower.keys():
		var REGAIN_SPEED: float = 0#500	
		map.total_manpower[owner_id] += delta * REGAIN_SPEED

func get_playable_ids() -> Array[int]:
	var owner_ids_checked: Dictionary[int, bool] = {}
	for area: Area in areas:
		if area.owner_id < 0:
			continue
		if owner_ids_checked.has(area.owner_id):
			continue
		owner_ids_checked[area.owner_id] = true
	for vehicle: Vehicle in map.tanks+map.trains+map.ships:
		if vehicle.owner_id < 0:
			continue
		if owner_ids_checked.has(vehicle.owner_id):
			continue
		owner_ids_checked[vehicle.owner_id] = true
	return owner_ids_checked.keys()
	
func _collect_total_strength_by_id():
	for owner_id: int in get_playable_ids():
		if not total_strength_by_owner_id.has(owner_id):
			total_strength_by_owner_id[owner_id] = 0.0
		if not total_unmodified_strength_by_owner_id.has(owner_id):
			total_unmodified_strength_by_owner_id[owner_id] = 0.0
		total_strength_by_owner_id[owner_id] += Global.get_owner_strength(
			owner_id,
			areas,
			map,
			total_weighted_circumferences,
			base_ownerships
		)
		total_unmodified_strength_by_owner_id[owner_id] += Global.get_total_owner_strength_unmodified(
			owner_id,
			areas,
			map,
			total_weighted_circumferences,
			base_ownerships
		)
		
func _collect_base_ownerships() -> void:
	for area: Area in areas:
		if area.owner_id < 0:
			continue
		base_ownerships[area] = []
	
	for base: Base in map.bases:
		var found_area: bool = false
		for area: Area in areas:
			if found_area:
				break
			if area.owner_id < 0:
				continue
			if Global.get_base_owner_area(base, areas) == area:
				base_ownerships[area].append(base)
				found_area = true
				continue

func _clear_start_of_tick(delta: float) -> void:
	newly_expanded_areas.clear()
	newly_expanded_areas_full.clear()
	newly_encircled_areas.clear()
	expanded_sub_areas.clear()
	expanded_sub_areas_from_existing.clear()
	expanded_sub_areas_from_boundaries.clear()
	expanded_sub_areas_from_new.clear()
	current_expansion_function = ""
	strength_manpower_casualties_sum_start_of_tick.clear()
	total_manpower_start_of_tick.clear()
	total_casualties_start_of_tick.clear()

	debug_poly.clear()
	debug_points.clear()

func _clear_end_of_tick(delta: float) -> void:
	area_source_polygons.clear()
	intersecting_original_walkable_area_start_of_tick.clear()
	intersecting_boundaries_original_walkable_area_start_of_tick.clear()
	original_walkable_areas_covered.clear()	
	original_walkable_areas_partially_covered.clear()
	
	# Clear union data
	union_walkable_areas.clear()
	union_walkable_areas_to_original_walkable_areas.clear()
	adjacent_union_walkable_area.clear()
	union_walkable_area_shared_borders.clear()
	union_walkable_area_river_neighbors.clear()
	clicked_union_walkable_areas.clear()
	intersecting_union_walkable_area_start_of_tick.clear()
	intersecting_boundaries_union_walkable_area_start_of_tick.clear()
	union_walkable_areas_covered.clear()
	union_walkable_areas_partially_covered.clear()
	total_weighted_circumferences.clear()
	total_active_circumferences.clear()
	base_ownerships.clear()
	newly_expanded_polylines.clear()
	newly_retracting_polylines.clear()
	newly_holding_polylines.clear()
	big_intersecting_areas.clear()
	big_intersecting_areas_circumferences.clear()
	total_holding_circumference_by_other_area.clear()
	total_weighted_holding_circumference_by_other_area.clear()
	expanded_sub_area_origin_map.clear()
	adjusted_strength_cache.clear()
	slightly_offset_area_polygons.clear()
	total_strength_by_owner_id.clear()
	total_unmodified_strength_by_owner_id.clear()

func _create_union_areas() -> void:
	# Group original areas by clicked status and terrain type
	var clicked_areas_by_terrain: Dictionary = {}
	var unclicked_areas_by_terrain: Dictionary = {}
	
	for original_area: Area in map.original_walkable_areas:
		var terrain_type: String = map.terrain_map[original_area.polygon_id]
		
		if clicked_original_walkable_areas.has(original_area.polygon_id):
			if not clicked_areas_by_terrain.has(terrain_type):
				clicked_areas_by_terrain[terrain_type] = []
			clicked_areas_by_terrain[terrain_type].append(original_area)
		else:
			if not unclicked_areas_by_terrain.has(terrain_type):
				unclicked_areas_by_terrain[terrain_type] = []
			unclicked_areas_by_terrain[terrain_type].append(original_area)
	
	# Create unions for clicked areas by terrain type
	for terrain_type: String in clicked_areas_by_terrain:
		_create_unions_for_adjacent_areas(clicked_areas_by_terrain[terrain_type])
	
	# Create unions for unclicked areas by terrain type
	for terrain_type: String in unclicked_areas_by_terrain:
		_create_unions_for_adjacent_areas(unclicked_areas_by_terrain[terrain_type])
	
	# Build adjacency and shared borders for unions
	_build_union_adjacency_and_borders()
	
	# Build river neighbors for unions
	_build_union_river_neighbors()
	
	# Build clicked union areas
	_build_clicked_union_areas()

func _create_unions_for_adjacent_areas(area_group: Array) -> void:
	if area_group.is_empty():
		return
	
	# Use union-find algorithm to group adjacent areas
	var parent: Dictionary = {}
	var rank: Dictionary = {}
	
	# Initialize each area as its own parent
	for area: Area in area_group:
		parent[area] = area
		rank[area] = 0
	
	# Check adjacency and union adjacent areas
	for i: int in range(area_group.size()):
		var area1: Area = area_group[i]
		for j: int in range(i + 1, area_group.size()):
			var area2: Area = area_group[j]
			
			# Check if areas are adjacent
			if map.adjacent_original_walkable_area[area1].has(area2):
				_union_find_union(parent, rank, area1, area2)
	
	# Group areas by their root parent
	var groups: Dictionary = {}
	for area: Area in area_group:
		var root: Area = _union_find_find(parent, area)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(area)
	
	# Create union areas for each group
	for root: Area in groups:
		var group_areas: Array = groups[root]
		_create_union_for_area_group(group_areas)

func _union_find_find(parent: Dictionary, area: Area) -> Area:
	var current: Area = area
	var path: Array = []
	
	# Find the root and collect path for path compression
	while parent[current] != current:
		path.append(current)
		current = parent[current]
	
	# Path compression: make all nodes point directly to root
	for node: Area in path:
		parent[node] = current
	
	return current

func _union_find_union(parent: Dictionary, rank: Dictionary, area1: Area, area2: Area) -> void:
	var root1: Area = _union_find_find(parent, area1)
	var root2: Area = _union_find_find(parent, area2)
	
	if root1 == root2:
		return
	
	if rank[root1] < rank[root2]:
		parent[root1] = root2
	elif rank[root1] > rank[root2]:
		parent[root2] = root1
	else:
		parent[root2] = root1
		rank[root1] += 1

func _create_union_for_area_group(area_group: Array) -> void:
	if area_group.is_empty():
		return
	
	var merged_polygon: PackedVector2Array = _merge_areas_into_union(area_group)
	var union_area: Area = Area.new(
		area_group[0].color,  # Use color from first area
		merged_polygon,
		area_group[0].owner_id,  # Use owner_id from first area
		GeometryUtils.calculate_centroid(merged_polygon)
	)
	union_walkable_areas_to_original_walkable_areas[union_area] = area_group
	union_walkable_areas.append(union_area)

func _merge_areas_into_union(group_areas: Array) -> PackedVector2Array:
	if group_areas.is_empty():
		return PackedVector2Array()
	
	if group_areas.size() == 1:
		return group_areas[0].polygon
	
	# Merge areas in a way that maintains connectivity
	# Start with the first area
	var result_polygon: PackedVector2Array = group_areas[0].polygon
	var remaining_areas: Array = group_areas.slice(1)
	
	# Keep merging until all areas are merged
	while remaining_areas.size() > 0:
		var best_area: Area = null
		var best_merge_result: Array = []
		
		# Find the area that merges best with current result
		for i: int in range(remaining_areas.size()):
			var area: Area = remaining_areas[i]
			var merge_result: Array = Geometry2D.merge_polygons(result_polygon, area.polygon)
			
			# Check if this merge results in a single connected polygon
			var split: Array = GeometryUtils.split_into_inner_outer_polygons(merge_result)
			var outer: Array[PackedVector2Array] = split[0]
			
			if outer.size() == 1:
				# This merge creates a single connected polygon
				best_area = area
				best_merge_result = merge_result
				break
		
		assert(best_area != null)
		#if best_area == null:
			## No area merges into a single polygon, take the first one
			#best_area = remaining_areas[0]
			#debug_poly = best_area.polygon.duplicate()
			#best_merge_result = Geometry2D.merge_polygons(result_polygon, best_area.polygon)

		# Apply the merge
		var split: Array = GeometryUtils.split_into_inner_outer_polygons(best_merge_result)
		var outer: Array[PackedVector2Array] = split[0]
		var inner: Array[PackedVector2Array] = split[1]
		assert(outer.size() == 1)
		#assert(inner.size() <= 1)
		result_polygon = outer[0]
		
		# Remove the merged area from remaining areas
		remaining_areas.erase(best_area)
	
	return result_polygon

func _build_union_adjacency_and_borders() -> void:
	# Initialize adjacency and shared borders for unions
	for union_area: Area in union_walkable_areas:
		adjacent_union_walkable_area[union_area] = []
		union_walkable_area_shared_borders[union_area] = {}
	
	# Build adjacency between unions
	for i: int in range(union_walkable_areas.size()):
		var union1: Area = union_walkable_areas[i]
		for j: int in range(i + 1, union_walkable_areas.size()):
			var union2: Area = union_walkable_areas[j]
			
			# Check if unions are adjacent by checking if their polygons share a border
			var shared_borders: Array[PackedVector2Array] = _get_shared_border_between_unions(union1, union2)
			if shared_borders.size() > 0:
				adjacent_union_walkable_area[union1].append(union2)
				adjacent_union_walkable_area[union2].append(union1)
				union_walkable_area_shared_borders[union1][union2] = shared_borders
				union_walkable_area_shared_borders[union2][union1] = shared_borders

func _get_shared_border_between_unions(union1: Area, union2: Area) -> Array[PackedVector2Array]:
	# Find all shared borders between two union areas
	# Unions can have multiple separate border segments, so return an array
	var shared_borders: Array[PackedVector2Array] = []
	
	#debug_poly = union2.polygon.duplicate()
	# Use the same logic as the map generator for finding shared edges
	var shared: Array = []
	for i in range(union1.polygon.size()):
		var a0 = union1.polygon[i]
		var a1 = union1.polygon[(i+1)%union1.polygon.size()]
		for j in range(union2.polygon.size()):
			var b0 = union2.polygon[j]
			var b1 = union2.polygon[(j+1)%union2.polygon.size()]
			if (a0 == b1 and a1 == b0) or (a0 == b0 and a1 == b1):
				shared.append([a0, a1])
	
	if shared.size() == 0:
		return shared_borders
	
	# Chain together shared edges into polylines
	# Since unions can have multiple separate border segments, we need to handle multiple chains
	var remaining_shared = shared.duplicate()
	
	while remaining_shared.size() > 0:
		var border = [remaining_shared[0][0], remaining_shared[0][1]]
		remaining_shared.remove_at(0)
		
		# Try to extend this border chain
		var extended = true
		while extended and remaining_shared.size() > 0:
			extended = false
			for k in range(remaining_shared.size()):
				var e0 = remaining_shared[k][0]
				var e1 = remaining_shared[k][1]
				if border[border.size()-1] == e0:
					border.append(e1)
					remaining_shared.remove_at(k)
					extended = true
					break
				elif border[border.size()-1] == e1:
					border.append(e0)
					remaining_shared.remove_at(k)
					extended = true
					break
				elif border[0] == e0:
					border.insert(0, e1)
					remaining_shared.remove_at(k)
					extended = true
					break
				elif border[0] == e1:
					border.insert(0, e0)
					remaining_shared.remove_at(k)
					extended = true
					break
		
		# Add this border segment if it's long enough
		if border.size() >= 2:
			shared_borders.append(PackedVector2Array(border))
	
	return shared_borders

func _build_union_river_neighbors() -> void:
	# Initialize river neighbors for unions
	for union_area: Area in union_walkable_areas:
		union_walkable_area_river_neighbors[union_area] = []
	
	# Build river neighbors by checking which unions are adjacent to rivers
	for union_area: Area in union_walkable_areas:
		# Check if any of the original areas that make up this union are river neighbors
		# For now, we'll use a simple approach: if the union is adjacent to any river area
		# This could be enhanced to be more sophisticated
		for other_union_area: Area in union_walkable_areas:
			if union_area == other_union_area:
				continue
			
			# Check if they share a border and if that border is a river
			if union_walkable_area_shared_borders[union_area].has(other_union_area):
				# For now, we'll assume all shared borders between unions could be rivers
				# This could be enhanced to check actual river data
				union_walkable_area_river_neighbors[union_area].append(other_union_area)

func _build_clicked_union_areas() -> void:	
	# For each union area, check if any of its constituent original areas are clicked
	for union_area: Area in union_walkable_areas:
		var original_area: Area = union_walkable_areas_to_original_walkable_areas[union_area][0]
		if clicked_original_walkable_areas.has(original_area.polygon_id):
			clicked_union_walkable_areas[union_area.polygon_id] = clicked_original_walkable_areas[original_area.polygon_id]
		
func _collect_intersections_with_walkable_areas() -> void:	
	# Process areas - First pass: collect intersections and coverage info
	for original_area: Area in map.original_walkable_areas:
		intersecting_original_walkable_area_start_of_tick[original_area] = {}

	if USE_UNION:
		# Initialize union intersections
		for union_area: Area in union_walkable_areas:
			intersecting_union_walkable_area_start_of_tick[union_area] = {}
		

	for area: Area in areas:
		if area.owner_id < 0:
			continue
		
		# Initialize dictionaries for this area
		var original_walkable_area_covered: Dictionary = {}
		original_walkable_areas_covered[area] = original_walkable_area_covered
		
		# Calculate area bounds once
		var area_bounds: Rect2 = GeometryUtils.calculate_bounding_box(area.polygon)
		
		# Collect polygons to batch process for original walkable areas
		var original_polygons_to_intersect: Array[PackedVector2Array] = []
		var original_area_keys: Array = []
		
		# Process each original walkable area - collect for batching
		for original_area: Area in map.original_walkable_areas:
			var polygon_id: int = original_area.polygon_id
			var original_rect: Rect2 = map.original_walkable_area_bounds_rect[original_area]
			
			# Fast bounds check
			if not area_bounds.intersects(original_rect):
				# No intersection possible, use empty array instead of computing
				original_walkable_area_covered[original_area] = false
				continue

			original_polygons_to_intersect.append(original_area.polygon)
			original_area_keys.append(original_area)
		
		# Batch process original walkable area intersections using Clipper2
		if original_polygons_to_intersect.size() > 0:
			var original_results: Array = intersect_polygons_batched(original_polygons_to_intersect, area.polygon)
			
			for i: int in original_results.size():
				var original_area: Area = original_area_keys[i]
				var intersecting_polygons: Array = original_results[i]
				var fully_covered: bool = false
				
				if intersecting_polygons.size() == 1:
					fully_covered = GeometryUtils.same_polygon_shifted(original_area.polygon, intersecting_polygons[0])
				
				if intersecting_polygons.size() > 0:
					intersecting_original_walkable_area_start_of_tick[original_area][area] = intersecting_polygons
				original_walkable_area_covered[original_area] = fully_covered
		
		if USE_UNION:
			# Collect polygons to batch process for union areas
			var union_polygons_to_intersect: Array[PackedVector2Array] = []
			var union_area_keys: Array = []
			
			# Process each union area for intersections - collect for batching
			for union_area: Area in union_walkable_areas:
				var union_rect: Rect2 = GeometryUtils.calculate_bounding_box(union_area.polygon)
				
				# Fast bounds check
				if not area_bounds.intersects(union_rect):
					continue
				
				union_polygons_to_intersect.append(union_area.polygon)
				union_area_keys.append(union_area)
		
			# Batch process union area intersections using Clipper2
			if union_polygons_to_intersect.size() > 0:
				var union_results: Array = intersect_polygons_batched(union_polygons_to_intersect, area.polygon)
				
				for i: int in union_results.size():
					var union_area: Area = union_area_keys[i]
					var union_intersecting_polygons: Array = union_results[i]
					
					if union_intersecting_polygons.size() != 0:
						intersecting_union_walkable_area_start_of_tick[union_area][area] = union_intersecting_polygons

		var area_sources: Array = []
		for walkable_area: Area in walkable_areas():
			# Record area as source if there's any intersection
			if (
				intersecting_walkable_area_start_of_tick()[walkable_area].has(area) and 
				intersecting_walkable_area_start_of_tick()[walkable_area][area].size() > 0
			):
				area_sources.append(walkable_area.polygon_id)
		area_source_polygons[area] = area_sources
		

	for area: Area in areas:
		if area.owner_id < 0:
			continue
			
		var owner_id: int = area.owner_id
		if not original_walkable_areas_partially_covered.has(area):
			original_walkable_areas_partially_covered[area] = {}
		if not union_walkable_areas_partially_covered.has(area):
			union_walkable_areas_partially_covered[area] = {}
		if not union_walkable_areas_covered.has(area):
			union_walkable_areas_covered[area] = {}
			
		for original_area: Area in map.original_walkable_areas:
			original_walkable_areas_partially_covered[area][original_area]=false
			
			var polygon_id: int = original_area.polygon_id
			# Check for partial coverage and collect for player ID
			if (
				intersecting_original_walkable_area_start_of_tick[original_area].has(area) and
				intersecting_original_walkable_area_start_of_tick[original_area][area].size() > 0
			):
				original_walkable_areas_partially_covered[area][original_area] = true
		
		# Collect union coverage
		for union_area: Area in union_walkable_areas:
			union_walkable_areas_partially_covered[area][union_area] = false
			union_walkable_areas_covered[area][union_area] = false
			
			# Check for partial coverage
			if (
				intersecting_union_walkable_area_start_of_tick[union_area].has(area) and
				intersecting_union_walkable_area_start_of_tick[union_area][area].size() > 0
			):
				union_walkable_areas_partially_covered[area][union_area] = true
				
				# Check for full coverage - same logic as original areas
				var fully_covered: bool = false
				if intersecting_union_walkable_area_start_of_tick[union_area][area].size() == 1:
					fully_covered = GeometryUtils.same_polygon_shifted(union_area.polygon, intersecting_union_walkable_area_start_of_tick[union_area][area][0])
				
				union_walkable_areas_covered[area][union_area] = fully_covered


func _collect_intersecting_boundaries() -> void:
	for walkable_area: Area in walkable_areas():
		intersecting_boundaries_walkable_area_start_of_tick()[walkable_area] = {}
		for adjacent_walkable_area: Area in adjacent_walkable_area()[walkable_area]:
			if walkable_area != adjacent_walkable_area:
				intersecting_boundaries_walkable_area_start_of_tick()[walkable_area][adjacent_walkable_area] = {}

	# Process each expanding area
	for area: Area in areas:
		if area.owner_id < 0:
			continue

		# global collection of polylines to test between unions
		var polylines: Array[PackedVector2Array] = []
		var polyline_keys: Array = []

		for walkable_area: Area in walkable_areas():
			if not walkable_areas_partially_covered()[area][walkable_area]:
				continue

			for adjacent_walkable_area: Area in adjacent_walkable_area()[walkable_area]:
				if walkable_area == adjacent_walkable_area:
					continue

				# mirrored result already computed
				if intersecting_boundaries_walkable_area_start_of_tick()[walkable_area][adjacent_walkable_area].has(area):
					intersecting_boundaries_walkable_area_start_of_tick()[adjacent_walkable_area][walkable_area][area] = (
						intersecting_boundaries_walkable_area_start_of_tick()[walkable_area][adjacent_walkable_area][area]
					)
					continue

				if not should_expand_subarea(area, adjacent_walkable_area):
					continue

				if walkable_area_shared_borders()[walkable_area].has(adjacent_walkable_area):
					var shared_borders: Array = walkable_area_shared_borders()[walkable_area][adjacent_walkable_area]
					for shared_border: PackedVector2Array in shared_borders:
						if shared_border.size() > 0:
							polylines.append(shared_border)
							polyline_keys.append([walkable_area, adjacent_walkable_area])

		# run ONE batched call for this area against its polygon
		if polylines.size() > 0:
			var eps: float = 1#0.0
			var results: Array = intersect_many_polyline_with_polygon_deterministic(polylines, area.polygon, eps)

			for i: int in results.size():
				var key: Array = polyline_keys[i]
				var walkable_area: Area = key[0]
				var adjacent_walkable_area: Area = key[1]
				intersecting_boundaries_walkable_area_start_of_tick()[walkable_area][adjacent_walkable_area][area] = results[i]
				intersecting_boundaries_walkable_area_start_of_tick()[adjacent_walkable_area][walkable_area][area] = results[i]

func intersect_many_polyline_with_polygon_deterministic(
	polylines,
	polygon,
	eps
):
	return gd_extension_clip.intersect_many_polyline_with_polygon_deterministic(polylines, polygon, eps)


func intersect_polygons_batched(
	polygons: Array,
	subject_polygon: PackedVector2Array
) -> Array:
	return gd_extension_clip.intersect_polygons_batched(polygons, subject_polygon)

func _collect_big_cross_area_intersections() -> void:
	for area: Area in areas:
		if area.owner_id < 0: continue
		slightly_offset_area_polygons[area] = Geometry2D.offset_polygon(
			area.polygon,
			OFFSET_MULT_FOR_DETECTING_EXPANSION,
			Geometry2D.JOIN_ROUND
		)
	
	for area: Area in areas:
		if area.owner_id < 0: continue
		big_intersecting_areas[area] = {}
		for other_area: Area in areas:
			if other_area.owner_id < 0: continue
			var empty: Array[PackedVector2Array] = []
			big_intersecting_areas[area][other_area] = empty
	for area: Area in areas:
		if area.owner_id < 0: continue
		
		for slightly_offset_area_polygon: PackedVector2Array in slightly_offset_area_polygons[area]:
			for other_area: Area in areas:
				if other_area.owner_id < 0: continue
				if area.owner_id == other_area.owner_id:
					continue
				
				for slightly_offset_other_area_polygon: PackedVector2Array in slightly_offset_area_polygons[other_area]:
					var all_intersecting: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
						slightly_offset_area_polygon,
						slightly_offset_other_area_polygon,
					) 
					big_intersecting_areas[area][other_area].append_array(
						all_intersecting
					)

	for area: Area in big_intersecting_areas.keys():
		if area.owner_id != GameSimulationComponent.PLAYER_ID: continue
		big_intersecting_areas_circumferences[area] = {}
		for other_area: Area in big_intersecting_areas[area]:
			if (
				big_intersecting_areas_circumferences.has(other_area) and 
				big_intersecting_areas_circumferences[other_area].has(area)
			):
				big_intersecting_areas_circumferences[area][other_area] = big_intersecting_areas_circumferences[other_area][area]
				continue

			big_intersecting_areas_circumferences[area][other_area] = 0
			var polylines: Array[PackedVector2Array] = big_intersecting_areas[area][other_area]
			for polyline: PackedVector2Array in polylines:
				var is_hole: bool = Geometry2D.is_polygon_clockwise(polyline)
				var multiplier: float = 1
				if is_hole:
					multiplier = -1
				polyline = polyline.duplicate()
				polyline.append(polyline[0])
				for walkable_area: Area in walkable_areas():
					if not clicked_walkable_areas().has(walkable_area.polygon_id):
						continue
					
					# Note that it will be missing exactly the holding area!
					for intersecting_polyline: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(
						polyline,
						walkable_area.polygon
					):
						for ind: int in range(intersecting_polyline.size()-1):							
							big_intersecting_areas_circumferences[area][other_area] += multiplier*(intersecting_polyline[ind]-intersecting_polyline[ind+1]).length()

func _collect_front_lines() -> void:

	for area: Area in areas:
		if area.owner_id < 0: continue
		
		total_weighted_circumferences[area] = 0.0
		total_active_circumferences[area] = 0.0

		newly_expanded_polylines[area] = {}
		newly_retracting_polylines[area] = {}
		newly_holding_polylines[area] = {}
		
		for walkable_area: Area in walkable_areas():
			
			var expanding_polylines: Array[PackedVector2Array] = []
			var retracting_polylines: Array[PackedVector2Array] = []
			var holding_polylines: Array[Dictionary] = []
			newly_expanded_polylines[area][walkable_area] = expanding_polylines
			newly_retracting_polylines[area][walkable_area] = retracting_polylines
			newly_holding_polylines[area][walkable_area] = holding_polylines
			

		for slightly_offset_poly: PackedVector2Array in slightly_offset_area_polygons[area]:
			if slightly_offset_poly.size() == 0: continue
			var slightly_offset_area_polyline: PackedVector2Array = slightly_offset_poly.duplicate()
			slightly_offset_area_polyline.append(slightly_offset_area_polyline[0])
			
			for walkable_area: Area in walkable_areas():
				var expanding_polylines: Array[PackedVector2Array] = newly_expanded_polylines[area][walkable_area]
				if should_expand_subarea(area, walkable_area):
					var total_circumference: float = 0.0			
					for poly_intersect: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(slightly_offset_area_polyline, walkable_area.polygon):
						total_circumference += GeometryUtils.calculate_polyline_circumference(poly_intersect)
						expanding_polylines.append(poly_intersect)

					total_weighted_circumferences[area] += total_circumference
					total_active_circumferences[area] += total_circumference

					
	for area: Area in areas:
		if area.owner_id < 0: continue
		total_holding_circumference_by_other_area[area] = {}
		total_weighted_holding_circumference_by_other_area[area] = {}
		for other_area: Area in areas:
			if other_area.owner_id < 0: continue
			if area.owner_id == other_area.owner_id: continue
			total_holding_circumference_by_other_area[area][other_area] = 0.0
			total_weighted_holding_circumference_by_other_area[area][other_area] = 0.0
	
	for walkable_area: Area in walkable_areas():
		_collect_holding_line_circumference(
			walkable_area,
		)
	
	_turn_expanding_lines_into_retracting()

func _get_stronger_enemy_intersections_for_walkable_area(
		walkable_area: Area,
		area: Area,
		all_area_strengths: Dictionary[Area, float]
	) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not intersecting_walkable_area_start_of_tick().has(walkable_area):
		return result
	var intersecting_in_walkable: Dictionary = intersecting_walkable_area_start_of_tick()[walkable_area]
	for enemy_area: Area in intersecting_in_walkable.keys():
		if enemy_area.owner_id < 0:
			continue
		if enemy_area.owner_id == area.owner_id:
			continue
		if all_area_strengths[area] >= all_area_strengths[enemy_area]:
			continue
		var polys: Array = intersecting_in_walkable[enemy_area]
		if polys.size() > 0:
			result.append_array(polys)
	return result

func _turn_expanding_lines_into_retracting() -> void:
	var all_area_strengths_raw: Dictionary[Area, float] = _compute_all_area_strengths_raw()
	var areas_sorted_by_strength: Array[Area] = _sort_areas_by_strength(all_area_strengths_raw)

	var all_area_strengths_over_all_walkable_areas: Dictionary[Area, Dictionary]
	for walkable_area: Area in walkable_areas():
		var all_area_strengths: Dictionary[Area, float] = _compute_all_area_strengths(
			walkable_area,
			all_area_strengths_raw
		)
		all_area_strengths_over_all_walkable_areas[walkable_area] = all_area_strengths
		
	for walkable_area: Area in walkable_areas():
		var all_area_strengths: Dictionary[Area, float] = all_area_strengths_over_all_walkable_areas[walkable_area]

		for area: Area in areas_sorted_by_strength:
			if area.owner_id < 0:
				continue
			
			var expanding_lines: Array[PackedVector2Array] = newly_expanded_polylines[area][walkable_area]
			if expanding_lines.size() == 0:
				continue
			var new_expanding_lines: Array[PackedVector2Array] = []
			var new_retracting_lines: Array[PackedVector2Array] = []
			var all_enemy_intersections: Array[PackedVector2Array] = _get_stronger_enemy_intersections_for_walkable_area(
				walkable_area,
				area,
				all_area_strengths
			)
			if all_enemy_intersections.size() == 0:
				newly_expanded_polylines[area][walkable_area] = expanding_lines
				newly_retracting_polylines[area][walkable_area] = new_retracting_lines
				continue
			for expanding_line: PackedVector2Array in expanding_lines:
				var current_expanding: Array[PackedVector2Array] = [expanding_line]
				for enemy_intersection: PackedVector2Array in all_enemy_intersections:
					var next_expanding: Array[PackedVector2Array] = []
					for current_line: PackedVector2Array in current_expanding:
						next_expanding.append_array(
							Geometry2D.clip_polyline_with_polygon(current_line, enemy_intersection)
						)
						new_retracting_lines.append_array(
							Geometry2D.intersect_polyline_with_polygon(current_line, enemy_intersection)
						)
					next_expanding = next_expanding
					current_expanding = next_expanding
				new_expanding_lines.append_array(current_expanding)
			newly_expanded_polylines[area][walkable_area] = new_expanding_lines
			newly_retracting_polylines[area][walkable_area] = new_retracting_lines

func _collect_strength_manpower_casualties_sum() -> void:
	for owner_id: int in get_playable_ids():
		strength_manpower_casualties_sum_start_of_tick[owner_id] = (
			max(map.total_manpower[owner_id], 0)+
			map.total_casualties[owner_id]+
			total_strength_by_owner_id[owner_id]
		)
		total_manpower_start_of_tick[owner_id] = map.total_manpower[owner_id]
		total_casualties_start_of_tick[owner_id] = map.total_casualties[owner_id]
		
func collect_end_of_tick() -> void:
	if USE_UNION:
		_create_union_areas()
	_collect_intersections_with_walkable_areas()
	_collect_intersecting_boundaries()
	_collect_big_cross_area_intersections()
	_collect_base_ownerships()
	_collect_front_lines()
	_collect_total_strength_by_id()
	
func _draw() -> void:
	if debug_poly != null and debug_poly.size() > 0:
		var color: Color = Color.PURPLE
		color.a = 0.25
		draw_colored_polygon(debug_poly, color)
		var polyline: PackedVector2Array = debug_poly.duplicate()
		polyline.append(polyline[0])
		draw_polyline(polyline, Color.MAGENTA, 2.0)

	if debug_poly != null and debug_points.size() > 0:
		for point: Vector2 in debug_points:
			draw_circle(point, 3.0, Color.MAGENTA)
		
		
	# Draw artillery piece positions (radius = strike_radius/5)
	if ARTILLERY:
		for original_area: Area in map.original_walkable_areas:
			var pieces: Array[Dictionary] = _collect_artillery_pieces(original_area)
			if pieces.size() == 0:
				continue
			var original_area_size: float = map.original_polygon_areas[original_area.polygon_id]
			assert(original_area_size>0.0)
			var radius_min: float = ARTILLERY_HEX_RADIUS * sqrt(clamp(ARTILLERY_MIN_PIECE_AREA / original_area_size, 0.0, 1.0))
			for piece: Dictionary in pieces:
				var piece_pos: Vector2 = piece["pos"]
				var piece_area: float = piece["area_area"]
				var t: float = sqrt(clamp(piece_area / original_area_size, 0.0, 1.0))
				var strike_radius: float = lerp(radius_min, ARTILLERY_HEX_RADIUS, t)
				var dot_radius: float = strike_radius / 5.0
				#draw_circle(piece_pos, dot_radius+2.0, Color.BLACK)
				#draw_circle(piece_pos, dot_radius, Global.get_vehicle_color(PLAYER_ID))


# =============================
# Artillery (instantaneous)
# =============================
func _update_artillery(delta: float) -> void:
	var draw_comp: DrawComponent = get_parent().draw_component
	var trail_mgr: TrailManager = draw_comp.artillery_trail_manager

	for original_area: Area in map.original_walkable_areas:
		# 1) Build artillery pieces from player-owned intersections in this original area
		var pieces: Array[Dictionary] = _collect_artillery_pieces(original_area)
		if pieces.size() == 0:
			continue

		# 2) Accumulate one fixed shot per second per original area
		var rate: float = ARTILLERY_MAX_RATE
		if not artillery_shot_accumulator_by_original_area.has(original_area):
			artillery_shot_accumulator_by_original_area[original_area] = 0.0
		artillery_shot_accumulator_by_original_area[original_area] += rate * delta

		var fired_any: bool = false
		var is_ready: bool = artillery_shot_accumulator_by_original_area[original_area] >= 1.0
		while artillery_shot_accumulator_by_original_area[original_area] >= 1.0:
			artillery_shot_accumulator_by_original_area[original_area] -= 1.0
			# Collect candidate original areas: self + neighbors (if enabled)
			var candidate_original_areas: Array[Area] = []
			candidate_original_areas.append(original_area)
			if ARTILLERY_SHOOT_TO_ADJACENT:
				for adjacent_original_area: Area in map.adjacent_original_walkable_area[original_area]:
					candidate_original_areas.append(adjacent_original_area)

			# 3) Each piece fires once in sync
			for piece: Dictionary in pieces:
				var piece_pos: Vector2 = piece["pos"]
				var piece_area: float = piece["area_area"]
				var best_info: Dictionary = {}
				var best_dist: float = INF
				for cand_area: Area in candidate_original_areas:
					var info: Dictionary = _find_closest_enemy_boundary_point(cand_area, piece_pos)
					if info.is_empty():
						continue
					var pt: Vector2 = info["point"]
					var d: float = piece_pos.distance_to(pt)
					if d < best_dist:
						best_dist = d
						best_info = info
				if best_info.is_empty():
					continue
				var enemy_area: Area = best_info["enemy_area"]
				var impact_point: Vector2 = best_info["point"]
				# Radius scales with piece area fraction within original area (bounded by max)
				var original_area_size: float = map.original_polygon_areas[original_area.polygon_id]
				var t: float = sqrt(clamp(piece_area / original_area_size, 0.0, 1.0))
				var radius_min: float = ARTILLERY_HEX_RADIUS * sqrt(clamp(ARTILLERY_MIN_PIECE_AREA / original_area_size, 0.0, 1.0))
				var radius: float = lerp(radius_min, ARTILLERY_HEX_RADIUS, t)
				_apply_artillery_impact_with_radius(piece["area"], enemy_area, impact_point, radius)
				fired_any = true
				if trail_mgr != null:
					_emit_artillery_trail(trail_mgr, piece_pos, impact_point)

		if not fired_any and is_ready:
			artillery_shot_accumulator_by_original_area[original_area] = 0.0

func _is_centroid_controlled_by_player(centroid: Vector2) -> bool:
	for area_it: Area in areas:
		if area_it.owner_id == PLAYER_ID:
			if Geometry2D.is_point_in_polygon(centroid, area_it.polygon):
				return true
	return false

func _calculate_player_control_percentage(original_area: Area) -> float:
	var original_total_area: float = map.original_polygon_areas[original_area.polygon_id]
	assert(original_total_area > 0.0)
	if not intersecting_original_walkable_area_start_of_tick.has(original_area):
		return 0.0
	var player_area_sum: float = 0.0
	for area_it: Area in intersecting_original_walkable_area_start_of_tick[original_area]:
		if area_it.owner_id != PLAYER_ID:
			continue
		var intersections: Array = intersecting_original_walkable_area_start_of_tick[original_area][area_it]
		for inter: PackedVector2Array in intersections:
			if Geometry2D.is_polygon_clockwise(inter):
				continue
			player_area_sum = player_area_sum + GeometryUtils.calculate_polygon_area(inter)
	assert(player_area_sum >= 0.0)
	return clamp(player_area_sum / original_total_area, 0.0, 1.0)

func _find_closest_enemy_boundary_point(original_area: Area, from_point: Vector2) -> Dictionary:
	var best_dist: float = INF
	var best_point: Vector2 = Vector2.ZERO
	var best_enemy: Area = null
	if not intersecting_original_walkable_area_start_of_tick.has(original_area):
		return {}
	for area_it: Area in intersecting_original_walkable_area_start_of_tick[original_area]:
		if area_it.owner_id < 0:
			continue
		if area_it.owner_id == PLAYER_ID:
			continue
		if area_it.polygon.size() < 3:
			continue
		for area_it_polygon: PackedVector2Array in intersecting_original_walkable_area_start_of_tick[original_area][area_it]:
			if GeometryUtils.calculate_polygon_area(area_it_polygon) <= ARTILLERY_MIN_TARGET_INTERSECTION_AREA:
				continue
			var closest_on_enemy: Vector2 = GeometryUtils.clamp_point_to_polygon(area_it_polygon, from_point, true)
			var d: float = from_point.distance_to(closest_on_enemy)
			if d < best_dist:
				best_dist = d
				best_point = closest_on_enemy
				best_enemy = area_it
	if best_enemy == null:
		return {}
	var out: Dictionary = {}
	out["enemy_area"] = best_enemy
	out["point"] = best_point
	return out


func _apply_artillery_impact_with_radius(
	area: Area,
	enemy_area: Area,
	impact_point: Vector2,
	radius: float
) -> void:
	# Build regular hex with custom radius
	var hex: PackedVector2Array = PackedVector2Array()
	var sides: int = 6
	var step: float = TAU / float(sides)
	var i: int = 0
	while i < sides:
		var ang: float = step * float(i)
		var pos: Vector2 = impact_point + Vector2(cos(ang), sin(ang)) * radius
		hex.append(pos)
		i = i + 1
	assert(not Geometry2D.is_polygon_clockwise(hex))

	# Calculate removed area casualties
	var removed_parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(enemy_area.polygon, hex)
	var outer_intersects: Array[PackedVector2Array] = GeometryUtils.split_into_inner_outer_polygons(removed_parts)[0]	
	if removed_parts.size() == 0:
		return
	for part: PackedVector2Array in removed_parts:
		var new_casualties: float = polygon_to_numbers(part)
		#map.total_casualties[enemy_area.owner_id] += deployed_fraction(enemy_area.owner_id)*new_casualties
		take_casualty_from_area_loss(enemy_area.owner_id, new_casualties)
		
	# Reverse to get encirclement visualization.
	for outer_intersect: PackedVector2Array in outer_intersects:
		outer_intersect.reverse()
	var hole_pairs: Array = process_encircled_holes(outer_intersects)
	# We add both to get a nice interpolated color
	if not newly_encircled_areas.has(area):
		newly_encircled_areas[area] = []
	if not newly_encircled_areas.has(enemy_area):
		newly_encircled_areas[enemy_area] = []
	newly_encircled_areas[area].append_array(hole_pairs)
	newly_encircled_areas[enemy_area].append_array(hole_pairs)
	

	# Subtract hex from enemy area and split if needed
	var remaining_parts: Array[PackedVector2Array] = Geometry2D.clip_polygons(enemy_area.polygon, hex)
	if remaining_parts.size() == 0:
		enemy_area.polygon = PackedVector2Array()
		return
	var outers_and_holes: Array = GeometryUtils.split_into_inner_outer_polygons(remaining_parts)
	var outers: Array[PackedVector2Array] = outers_and_holes[0]
	
	if outers.size() == 0:
		enemy_area.polygon = PackedVector2Array()
		return
	var main: PackedVector2Array = GeometryUtils.find_largest_polygon(outers)
	enemy_area.polygon = main
	for part_it: PackedVector2Array in outers:
		if part_it == main:
			continue
		if part_it.size() < 3:
			continue
		if Geometry2D.is_polygon_clockwise(part_it):
			continue
		var new_enemy: Area = Area.new(enemy_area.color, part_it, enemy_area.owner_id)
		areas.append(new_enemy)

func _collect_artillery_pieces(original_area: Area) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	if not intersecting_original_walkable_area_start_of_tick.has(original_area):
		return pieces
	
	var original_area_size: float = map.original_polygon_areas[original_area.polygon_id]
	for area_it: Area in intersecting_original_walkable_area_start_of_tick[original_area]:
		if area_it.owner_id != PLAYER_ID:
			continue
		for inter: PackedVector2Array in intersecting_original_walkable_area_start_of_tick[original_area][area_it]:
			if Geometry2D.is_polygon_clockwise(inter):
				continue
			
			var a: float = GeometryUtils.calculate_polygon_area(inter)
			var radius_min: float = ARTILLERY_HEX_RADIUS * sqrt(clamp(ARTILLERY_MIN_PIECE_AREA / original_area_size, 0.0, 1.0))
			var piece_area: float = a
			var t: float = sqrt(clamp(a / original_area_size, 0.0, 1.0))
			var strike_radius: float = lerp(radius_min, ARTILLERY_HEX_RADIUS, t)
			var dot_radius: float = strike_radius / 5.0
			

			var reduced_inter: PackedVector2Array = GeometryUtils.find_largest_polygon(
				Geometry2D.offset_polygon(
					inter,
					-2*dot_radius,
					Geometry2D.JOIN_ROUND
				)
			)
			
			if reduced_inter.size() < 3:
			#if a < ARTILLERY_MIN_PIECE_AREA:
				continue
			# Use centroid clamped to polygon to stay inside
			var centroid_pos: Vector2 = GeometryUtils.calculate_centroid(inter)
			var pos: Vector2 = GeometryUtils.clamp_point_to_polygon(reduced_inter, centroid_pos, true)
			var piece: Dictionary = {}
			piece["pos"] = pos
			piece["area_area"] = a
			piece["area"] = area_it
			pieces.append(piece)
	return pieces

func _emit_artillery_trail(trail_mgr: TrailManager, start_point: Vector2, end_point: Vector2) -> void:
	var agent_id: int = artillery_next_agent_id
	artillery_next_agent_id = artillery_next_agent_id + 1
	# Seed previous position
	trail_mgr.previous_positions[agent_id] = start_point
	# Build segments along the ray
	var total_segments: int = ARTILLERY_TRAIL_SEGMENTS
	var seg: int = 1
	while seg <= total_segments:
		var t: float = float(seg) / float(total_segments)
		var pos: Vector2 = start_point.lerp(end_point, t)
		# Fade progressively towards the target (shorter lifetime near target)
		var fade: float = lerp(ARTILLERY_TRAIL_FADE_MAX, ARTILLERY_TRAIL_FADE_MIN, t)
		trail_mgr.add_trail_segment_custom(pos, agent_id, PLAYER_ID, fade)
		seg = seg + 1
	# Detach this agent to avoid linking future shots
	trail_mgr.remove_trails(agent_id)
