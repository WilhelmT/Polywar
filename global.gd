extends Node

var world_size: Vector2 = Vector2(2560-320, 1440)
const LIGHT_DIR: Vector2				= Vector2(-1.0/sqrt(2.0), -1.0/sqrt(2.0))

const GLOBAL_SPEED: float = 1.0/1.0

enum Doctrine {
	SUPERIOR_FIREPOWER,
	MASS_MOBILISATION,
	SPECIAL_OPERATIONS,
	MOBILE_WARWARE,
}


enum GameMode {
	RANDOM,
	CREATE,
	FINAL,
}

class SpatialGrid:
	var grid_cell_size: float
	var area_spatial_grid: Dictionary[Vector2i, Array]
	
	func clear() -> void:
		grid_cell_size = 0.0
		area_spatial_grid = {}

class Map:
	var original_walkable_areas: Array[Area]
	var original_walkable_areas_verices: Dictionary[Vector2, bool]
	var original_area_index_by_polygon_id: Dictionary[int, int]
	var original_walkable_areas_and_obstacles_spatial_grid: SpatialGrid
	var original_obstacles: Array[Area]
	var original_obstacles_index_by_polygon_id: Dictionary[int, int]
	var original_unmerged_obstacles: Array[Area]
	var original_unmerged_obstacles_index_by_polygon_id: Dictionary[int, int]
	var original_walkable_areas_sum: float
	var original_walkable_areas_and_obstacles_circumference_sum: float
	var adjacent_original_walkable_area: Dictionary[Area, Array]
	var adjacent_original_walkable_area_and_obstacles: Dictionary[Area, Array]
	var adjacent_original_walkable_area_and_unmerged_obstacles: Dictionary[Area, Array]
	var terrain_map: Dictionary[int, String]
	var original_polygon_areas: Dictionary[int, float]
	var original_polygon_centroid: Dictionary[int, Vector2]
	var original_walkable_area_bounds: Dictionary[Area, Dictionary]
	var original_walkable_area_and_obstacles_bounds: Dictionary[Area, Dictionary]
	var original_walkable_area_bounds_rect: Dictionary[Area, Rect2]
	var original_walkable_area_shared_borders: Dictionary[Area, Dictionary] #  Dictionary[Area, Dictionary[Area, PackedVector2Array]]
	var original_walkable_areas_expanded_along_shared_borders: Dictionary[Area, Dictionary]
	var bases: Array[Base]
	var base_index_by_original_id: Dictionary[int, int]
	var rivers: Array[PackedVector2Array]
	var river_segments: Dictionary[PackedVector2Array, bool]
	var river_segments_owner: Dictionary[PackedVector2Array, int]
	var original_walkable_area_river_neighbors: Dictionary[Area, Array]
	var river_end_obstacles : Array[Dictionary] = []
	var river_banks: Array[Dictionary] = []
	var river_end_confluences: Array[Dictionary] = []
	var roads: Array[PackedVector2Array] = []
	var area_road_neighbors: Dictionary[Area, Array]
	var trains: Array[Train]
	var tanks: Array[Tank]
	var road_node_to_area: Dictionary
	var water_graph: Dictionary
	var ships: Array[Ship]
	var total_casualties: Dictionary[int, float]
	var total_manpower: Dictionary[int, float]
	var mass_mobilisation_manpower_deficit: Dictionary[int, float]

	func clear() -> void:
		original_walkable_areas = []
		original_walkable_areas_verices = {}
		original_area_index_by_polygon_id = {}
		if original_walkable_areas_and_obstacles_spatial_grid != null:
			original_walkable_areas_and_obstacles_spatial_grid.clear()
		original_obstacles = []
		original_obstacles_index_by_polygon_id = {}
		original_unmerged_obstacles = []
		original_unmerged_obstacles_index_by_polygon_id = {}
		original_walkable_areas_sum = 0.0
		original_walkable_areas_and_obstacles_circumference_sum = 0.0
		adjacent_original_walkable_area = {}
		adjacent_original_walkable_area_and_obstacles = {}
		adjacent_original_walkable_area_and_unmerged_obstacles = {}
		terrain_map = {}
		original_polygon_areas = {}
		original_polygon_centroid = {}
		original_walkable_area_bounds = {}
		original_walkable_area_and_obstacles_bounds = {}
		original_walkable_area_bounds_rect = {}
		original_walkable_area_shared_borders = {}
		original_walkable_areas_expanded_along_shared_borders = {}
		bases = []
		base_index_by_original_id = {}
		rivers = []
		river_segments = {}
		river_segments_owner = {}
		original_walkable_area_river_neighbors = {}
		river_end_obstacles = []
		river_banks = []
		river_end_confluences = []
		roads = []
		area_road_neighbors = {}
		trains = []
		tanks = []
		road_node_to_area = {}
		water_graph = {}
		ships = []
		total_casualties = {}
		total_manpower = {}
		mass_mobilisation_manpower_deficit = {}
	
var obstacle_color = Color(0.2, 0.2, 0.2, 1)
var neutral_color: Color = Color(0.7, 0.7, 0.7, 1)
var background_color = Color(0.35, 0.35, 0.35, 1)

func get_total_owner_strength_unmodified(
	owner_id: int,
	areas: Array[Area],
	map: Global.Map,
	total_weighted_circumferences: Dictionary[Area, float],
	base_ownerships: Dictionary[Area, Array]
) -> float:
	var sum_of_areas: float = 0.0
	for area: Area in areas:
		if area.owner_id == owner_id:
			sum_of_areas += area.get_strength_unmodified(map, total_weighted_circumferences[area], base_ownerships[area], areas)
	return (
		UnitLayer.MAX_UNITS *
		UnitLayer.NUMBER_PER_UNIT *
		sum_of_areas
	)

func get_owner_strength(
	owner_id: int,
	areas: Array[Area],
	map: Global.Map,
	total_weighted_circumferences: Dictionary[Area, float],
	base_ownerships: Dictionary[Area, Array]
) -> float:
	var sum_of_areas: float = 0.0
	for area: Area in areas:
		if area.owner_id == owner_id:
			sum_of_areas += area.get_strength(map, areas, total_weighted_circumferences, base_ownerships)
	return (
		UnitLayer.MAX_UNITS *
		UnitLayer.NUMBER_PER_UNIT *
		sum_of_areas
	)

func get_strength_density(
	total_weighted_circumferences: Dictionary[Area, float],
	base_ownerships: Dictionary[Area, Array],
	map: Map,
	area: Area,
	areas: Array[Area],
) -> float:
	var total_circumference: float = area.get_total_circumference()
	if total_circumference == 0.0:
		return 0.0
	var unnormalized_multiplier: float = area.get_strength(map, areas, total_weighted_circumferences, base_ownerships) * ((Global.world_size.x*2+Global.world_size.y*2)/total_circumference)
	var modifier_from_concentration: float = total_circumference / total_weighted_circumferences[area]
	assert(total_weighted_circumferences[area] > 0.0)
	var max_modifier: float = 100
	if modifier_from_concentration > max_modifier:
		modifier_from_concentration = max_modifier
	
	var result: float = unnormalized_multiplier * modifier_from_concentration
	assert(not is_nan(result))
	return result

func get_expansion_speed(
	base_expansion_speed: float,
	adjusted_strength: float,
	map: Map,
	original_area: Area,
	ignore_terrain: bool,
) -> float:
	if original_area.owner_id == -2:
		return 0.0
	assert(original_area.owner_id == -1)
	var terrain_type: String = map.terrain_map[original_area.polygon_id]
	
	var terrain_multiplier: float = 1.0
	if not ignore_terrain:
		terrain_multiplier *= get_multiplier_for_terrain(terrain_type)

	return base_expansion_speed * terrain_multiplier * adjusted_strength

func get_maximum_manpower(doctrine: Global.Doctrine) -> float:
	if doctrine == Global.Doctrine.SUPERIOR_FIREPOWER:
		return 0.25*(UnitLayer.MAX_UNITS)*UnitLayer.NUMBER_PER_UNIT
	if doctrine == Global.Doctrine.SPECIAL_OPERATIONS:
		return 0.1*(UnitLayer.MAX_UNITS)*UnitLayer.NUMBER_PER_UNIT
	if doctrine == Global.Doctrine.MASS_MOBILISATION:
		return (UnitLayer.MAX_UNITS)*UnitLayer.NUMBER_PER_UNIT
	assert(false)
	return 0.0

func get_starting_manpower(doctrine: Global.Doctrine) -> float:
	if doctrine == Global.Doctrine.SUPERIOR_FIREPOWER:
		return 0.1*(UnitLayer.MAX_UNITS)*UnitLayer.NUMBER_PER_UNIT
	if doctrine == Global.Doctrine.SPECIAL_OPERATIONS:
		return 0.1*(UnitLayer.MAX_UNITS)*UnitLayer.NUMBER_PER_UNIT
	if doctrine == Global.Doctrine.MASS_MOBILISATION:
		return 0.25*(UnitLayer.MAX_UNITS)*UnitLayer.NUMBER_PER_UNIT
	assert(false)
	return 0.0

func get_multiplier_for_terrain(terrain_type: String) -> float:
	if GameSimulationComponent.TERRAIN_FORCES:
		match terrain_type:
			"plains": return 1/2.0
			"forest": return  1/1.0#0.25 # Slower in forests
			"mountains": return 1/2.0#0.06125  # Much slower in mountains
			_: return 0.0


	match terrain_type:
		"plains": return 1/1.0
		"forest": return  1/2.0#0.25 # Slower in forests
		"mountains": return 1/4.0#0.06125  # Much slower in mountains
		_: return 0.0

func get_color_for_terrain(terrain_type: String) -> Color:
	var terrain_color: Color = Color.WHITE
	match terrain_type:
		"plains":
			#terrain_color = Color(0.75, 0.8, 0.35, 0.4)
			#terrain_color = Color(0.35, 0.45, 0.125, 0.5)*1.2
			
			terrain_color = Color(0.35, 0.45, 0.125, 0.5)*1.2
			terrain_color.s *= 0.6
			terrain_color.v *= 0.4
			#print("plains", terrain_color.v)
		"forest":
			terrain_color = Color(0.125, 0.35, 0.125, 0.5)
			terrain_color.s *= 0.75
			terrain_color.v *= 0.5
			#print("forest", terrain_color.v)
		"mountains":
			#terrain_color = Color(0.075, 0.05, 0.025, 0.55)
			terrain_color = Color(0.075, 0.05, 0.025, 0.75)
			terrain_color.v *= 1.25
	return terrain_color


func adjust_color_for_player(
	color: Color,
	player_id: int,
) -> Color:
	var new_color: Color = (10*color+0*Color.BLACK)/10.0
	if Global.only_expand_on_click(player_id):
		new_color.a = 0.25
	else:
		new_color.a = 0.25
	return new_color

func get_player_color(player_id: int) -> Color:
	return adjust_color_for_player(
		get_pure_player_color(
			player_id
		),
		player_id
	)
		
func get_pure_player_color(player_id: int) -> Color:
	if player_id == 0:
		return Color.BLUE
	elif player_id == 1:
		return Color.RED
	else:
		return Color(0.7, 0.7, 0.7, 0.95)

func get_vehicle_color(player_id: int) -> Color:
	var tint: Color = Global.get_player_color(player_id).darkened(0.2)
	tint.a = 1.0
	if tint.h > 0.5:
		tint.h -= 0.075
		tint.v *= 1.25
	else:
		tint.h += 0.025
		tint.v *= 1.25
	if tint.h < 0:
		tint.h = 1-tint.h
	tint.s *= 0.9
	return tint

func is_point_on_world_edge(point: Vector2) -> bool:
	return (point.x <= 0.0 or 
			point.x >= Global.world_size.x or 
			point.y <= 0.0 or 
			point.y >= Global.world_size.y)


func only_expand_on_click(owner_id: int) -> bool:
	if owner_id == GameSimulationComponent.PLAYER_ID:
		return true
	return false
	
func get_doctrine(owner_id: int) -> Doctrine:
	if owner_id == GameSimulationComponent.PLAYER_ID:
		return Global.Doctrine.SUPERIOR_FIREPOWER
		#return Global.Doctrine.MASS_MOBILISATION
	elif owner_id == 1:
		return Global.Doctrine.SUPERIOR_FIREPOWER
		#return Doctrine.SPECIAL_OPERATIONS
		#return Global.Doctrine.MASS_MOBILISATION
	
	return Global.Doctrine.SUPERIOR_FIREPOWER

func get_base_owner_area(base: Base, areas: Array[Area]) -> Area:
	for area: Area in areas:
		if area.owner_id != base.owner_id:
			continue
		if Geometry2D.intersect_polygons(base.polygon, area.polygon).size() > 0:
			return area
	return null
