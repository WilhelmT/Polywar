extends Node2D
class_name Main

var rng = RandomNumberGenerator.new()

var areas: Array[Area] = []

var purchased_areas: Dictionary[Area, int] = {}
var purchased_original_areas: Dictionary[int, bool] = {}

var current_player: int = 0  # 0 = player A (Blue), 1 = player B (Red)
var current_type: String = "territory"
var tank_rotations: Array[int] = [45, 135, 225, 315]
var current_tank_rotation_index: int = 0
var current_vehicle_size: String = "huge"
var current_ship_direction_index: int = 0

var create_seed_points: Array[Vector2] = []
var create_terrain_by_seed: Dictionary[Vector2, String] = {}
var create_current_terrain: String = "plains"
var create_dragging: bool = false
var create_drag_index: int = -1
var create_drag_origin: Vector2 = Vector2.ZERO
const CREATE_PICK_RADIUS: float = 24.0
var create_mode: String = "add"
var create_hover_index: int = -1
var create_last_mouse_pos: Vector2 = Vector2.ZERO
var create_preview_map: Global.Map = null
var create_preview_hover_poly: PackedVector2Array = PackedVector2Array()

var game_phase: String = "setup": set = set_game_phase
var current_mode: Global.GameMode = Global.GameMode.RANDOM

@onready var ui_component: UIComponent = $UiComponent
@onready var draw_component: DrawComponent = $DrawComponent
@onready var cursor_manager: DotPlusCursorManager = $DotPlusCursorManager

var game_simulation_component: GameSimulationComponent

var map_generator: MapGenerator = MapGenerator.new()
var map: Global.Map = Global.Map.new()

func _ready() -> void:
	rng.randomize()
	ui_component.setup_ui(
		current_player,
		game_phase,
		current_type,
		tank_rotations[current_tank_rotation_index],
		current_vehicle_size,
		current_ship_direction_index
	)
	
	# Connect UI signals
	ui_component.assign_blue_pressed.connect(_on_assign_blue_pressed)
	ui_component.assign_red_pressed.connect(_on_assign_red_pressed)
	ui_component.type_territory_pressed.connect(_on_type_territory_pressed)
	ui_component.type_tank_pressed.connect(_on_type_tank_pressed)
	ui_component.type_train_pressed.connect(_on_type_train_pressed)
	ui_component.type_ship_pressed.connect(_on_type_ship_pressed)
	ui_component.tank_rotation_toggled.connect(_on_tank_rotation_toggled)
	ui_component.vehicle_size_small_pressed.connect(_on_vehicle_size_small_pressed)
	ui_component.vehicle_size_medium_pressed.connect(_on_vehicle_size_medium_pressed)
	ui_component.vehicle_size_large_pressed.connect(_on_vehicle_size_large_pressed)
	ui_component.vehicle_size_huge_pressed.connect(_on_vehicle_size_huge_pressed)
	ui_component.reset_pressed.connect(_on_reset_pressed)
	ui_component.clear_map_pressed.connect(_on_clear_map_pressed)
	ui_component.start_new_game_pressed.connect(_on_start_new_game_pressed)
	ui_component.ship_direction_toggled.connect(_on_ship_direction_toggled)
	ui_component.map_mode_random_pressed.connect(_on_map_mode_random_pressed)
	ui_component.map_mode_create_pressed.connect(_on_map_mode_create_pressed)
	ui_component.create_terrain_plains_pressed.connect(_on_create_terrain_plains_pressed)
	ui_component.create_terrain_forest_pressed.connect(_on_create_terrain_forest_pressed)
	ui_component.create_terrain_mountains_pressed.connect(_on_create_terrain_mountains_pressed)
	ui_component.create_terrain_lake_pressed.connect(_on_create_terrain_lake_pressed)
	ui_component.create_mode_add_pressed.connect(_on_create_mode_add_pressed)
	ui_component.create_mode_move_pressed.connect(_on_create_mode_move_pressed)
	ui_component.create_mode_delete_pressed.connect(_on_create_mode_delete_pressed)
	ui_component.create_mode_paint_pressed.connect(_on_create_mode_paint_pressed)
	ui_component.finish_map_pressed.connect(_on_finish_map_pressed)
	ui_component.save_map_pressed.connect(_on_save_map_pressed)
	ui_component.load_map_pressed.connect(_on_load_map_pressed)
	ui_component.save_map_confirmed.connect(_on_save_map_confirmed)
	ui_component.load_map_confirmed.connect(_on_load_map_confirmed)
	
	setup_game(current_mode)

func _physics_process(_delta: float) -> void:
	if game_phase == "simulation":
		ui_component.check_game_over(areas)
		# Ship movement is now handled in game_simulation_component.gd
		if game_simulation_component != null:
			var date_string: String = game_simulation_component.get_simulation_date_string()
			var strength0: float = Global.get_owner_strength(
				0,
				game_simulation_component.areas,
				game_simulation_component.map,
				game_simulation_component.total_weighted_circumferences,
				game_simulation_component.base_ownerships,
			)
			var strength1: float = Global.get_owner_strength(
				1,
				game_simulation_component.areas,
				game_simulation_component.map,
				game_simulation_component.total_weighted_circumferences,
				game_simulation_component.base_ownerships,
			)
			var casualties0: float = map.total_casualties.get(0, 0.0)
			var casualties1: float = map.total_casualties.get(1, 0.0)
			var manpower0: float =  map.total_manpower.get(0, 0.0)
			var manpower1: float = map.total_manpower.get(1, 0.0)
			
			# Get air force information
			var airforce_deployed: int = draw_component.air_layer.get_deployed_air_units_count()
			var airforce_total: int = AirLayer.TOTAL_AIR_UNITS
			ui_component.update_simulation_info(date_string, strength0, strength1, casualties0, casualties1, manpower0, manpower1, airforce_deployed, airforce_total)
	else:
		if ui_component != null:
			ui_component.hide_simulation_info()
		# live preview for CREATE add mode
		if current_mode == Global.GameMode.CREATE:
			if create_mode == "add":
				if create_last_mouse_pos.x > 0.0 and create_last_mouse_pos.x < Global.world_size.x and create_last_mouse_pos.y > 0.0 and create_last_mouse_pos.y < Global.world_size.y:
					var seeds_preview: Array[Vector2] = create_seed_points.duplicate()
					seeds_preview.append(create_last_mouse_pos)
					var terrain_preview: Dictionary[Vector2, String] = create_terrain_by_seed.duplicate()
					terrain_preview[create_last_mouse_pos] = create_current_terrain
					create_preview_map = map_generator.create_map_from_seed_points(seeds_preview, terrain_preview, false)
					create_preview_hover_poly = PackedVector2Array()
					var searched: bool = false
					# search walkables first
					for area_it: Area in create_preview_map.original_walkable_areas:
						if Geometry2D.is_point_in_polygon(create_last_mouse_pos, area_it.polygon):
							create_preview_hover_poly = area_it.polygon.duplicate()
							searched = true
							break
					# if not found, also allow obstacle (lake) preview
					if searched == false and create_preview_hover_poly.size() == 0:
						for obst_it: Area in create_preview_map.original_obstacles:
							if Geometry2D.is_point_in_polygon(create_last_mouse_pos, obst_it.polygon):
								create_preview_hover_poly = obst_it.polygon.duplicate()
								break
					draw_component.queue_redraw()
			else:
				create_preview_map = null
				create_preview_hover_poly = PackedVector2Array()

func set_game_phase(new_value: String) -> void:
	if new_value != game_phase:
		if new_value == "setup":
			game_simulation_component.queue_free()
			game_simulation_component = null
		game_phase = new_value
	if new_value == "setup":
		draw_component.prepare_for_new_game()

func _add_to_purchased_area(area: Area) -> void:
	var next_value: int = 0
	if purchased_areas.size() > 0:
		next_value = purchased_areas.values().max()+1
	purchased_areas[area] = next_value

func setup_game(mode: Global.GameMode) -> void:	
	purchased_areas.clear()
		
	map = map_generator.setup_game(mode, areas, GameSimulationComponent.MINIMUM_AREA_STRENGTH)
	ui_component.set_map_mode_display(mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	ui_component.set_create_mode_display(create_mode)
	draw_component.prepare_for_new_game()
	# Reset game state
	game_phase = "setup"
	current_player = 0
	current_type = "territory"
	current_tank_rotation_index = 0
	current_vehicle_size = "huge"
	current_ship_direction_index = 0
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	ui_component.set_create_mode_display(create_mode)

func _on_assign_blue_pressed() -> void:
	current_player = 0
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	ui_component.set_create_mode_display(create_mode)
	queue_redraw()

func _on_assign_red_pressed() -> void:
	current_player = 1
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	ui_component.set_create_mode_display(create_mode)
	queue_redraw()

func _on_type_territory_pressed() -> void:
	current_type = "territory"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	ui_component.set_create_mode_display(create_mode)

func _on_type_tank_pressed() -> void:
	current_type = "tank"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	ui_component.set_create_mode_display(create_mode)

func _on_type_train_pressed() -> void:
	current_type = "train"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)

func _on_type_ship_pressed() -> void:
	current_type = "ship"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)

func _on_tank_rotation_toggled() -> void:
	current_tank_rotation_index = (current_tank_rotation_index + 1) % tank_rotations.size()
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)

func _on_vehicle_size_small_pressed() -> void:
	current_vehicle_size = "small"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)

func _on_vehicle_size_medium_pressed() -> void:
	current_vehicle_size = "medium"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)

func _on_vehicle_size_large_pressed() -> void:
	current_vehicle_size = "large"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)

func _on_vehicle_size_huge_pressed() -> void:
	current_vehicle_size = "huge"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)

func _on_reset_pressed() -> void:
	# Clear all territories but keep the map and current player selection
	areas.clear()
	purchased_areas.clear()
	purchased_original_areas.clear()
	
	# Regenerate the map with neutral areas
	map = map_generator.setup_game(current_mode, areas, GameSimulationComponent.MINIMUM_AREA_STRENGTH)
	create_seed_points.clear()
	create_terrain_by_seed.clear()
	
	game_phase = "setup"
	# Keep current player selection
	map.ships.clear()
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	draw_component.prepare_for_new_game()
	queue_redraw()

func _on_start_new_game_pressed() -> void:
	assert(game_phase == "setup")
	# Start simulation
	start_simulation()

func start_simulation() -> void:
	game_phase = "simulation"
	# Keep neutral areas neutral (they won't expand)
	var new_areas: Array[Area] = []
	for area: Area in areas:
		if area.owner_id != -1:
			new_areas.append(area)
	areas = new_areas
			
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	
	_initialize_causalties_and_manpower(map)

	game_simulation_component = GameSimulationComponent.new(
		areas,
		map
	)
	
	# Transfer purchased original areas from setup phase to clicked areas in simulation phase
	for polygon_id: int in purchased_original_areas.keys():
		game_simulation_component.clicked_original_walkable_areas[polygon_id] = true
	
	# End of frame to not interfere with 
	call_deferred("_connect_simulation_redraw") 
	add_child(game_simulation_component)
	
	

func _initialize_causalties_and_manpower(map: Global.Map) -> void:
	for area in areas:
		if area.owner_id < 0: continue
		if not map.total_casualties.has(area.owner_id):
			map.total_casualties[area.owner_id] = 0.0
			map.total_manpower[area.owner_id] = Global.get_starting_manpower(Global.get_doctrine(area.owner_id))
			map.mass_mobilisation_manpower_deficit[area.owner_id] = 0.0
			
	for vehicle: Vehicle in map.tanks+map.trains+map.ships:
		if vehicle.owner_id < 0: continue
		if not map.total_casualties.has(vehicle.owner_id):
			map.total_casualties[vehicle.owner_id] = 0.0
			map.total_manpower[vehicle.owner_id] = Global.get_starting_manpower(Global.get_doctrine(vehicle.owner_id))
			map.mass_mobilisation_manpower_deficit[vehicle.owner_id] = 0.0
	
func _connect_simulation_redraw():
	game_simulation_component.requires_redraw.connect(
		queue_redraw
	)

func _input(event: InputEvent) -> void:
	# Ignore clicks on the UI panel (right side)
	if event is InputEventMouseButton and event.position.x >= Global.world_size.x:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_phase == "setup" and current_mode == Global.GameMode.CREATE:
			_handle_create_mode_press(event.position)
			return
		if game_phase == "setup":
			if current_type == "territory":
				handle_polygon_purchase(event.position)
			elif current_type == "tank":
				add_tank_to_clicked_territory(event.position)
			elif current_type == "train":
				add_train_to_clicked_territory(event.position)
			elif current_type == "ship":
				add_ship_to_clicked_territory(event.position)
	if event is InputEventMouseMotion:
		create_last_mouse_pos = event.position
		if game_phase == "setup" and current_mode == Global.GameMode.CREATE:
			if create_dragging:
				_handle_create_mode_drag(event.position)
				return
			# update hover highlight when not dragging
			if create_mode == "move" or create_mode == "delete":
				var idx_hover: int = _find_seed_index_at_position(event.position, CREATE_PICK_RADIUS)
				if idx_hover != create_hover_index:
					create_hover_index = idx_hover
					draw_component.queue_redraw()
			return
	if event is InputEventMouseButton and event.pressed == false and event.button_index == MOUSE_BUTTON_LEFT:
		if create_dragging and game_phase == "setup" and current_mode == Global.GameMode.CREATE:
			_handle_create_mode_release(event.position)
			return

func merge_adjacent_areas(owner_id: int) -> void:
	var owned_areas: Array[Area] = areas.filter(func(area): return area.owner_id == owner_id)
	
	var merged = true
	while merged:
		merged = false
		
		# Check each pair of areas
		for i in range(owned_areas.size()):
			var area1 = owned_areas[i]
			
			# Skip if this area was already merged and removed
			if not areas.has(area1):
				continue
				
			for j in range(i+1, owned_areas.size()):
				var area2 = owned_areas[j]
				
				# Skip if this area was already merged and removed
				if not areas.has(area2):
					continue
				
				# Check if any polygons from area1 are adjacent to any polygons from area2
				if (
					GeometryUtils.are_polygons_adjacent(area1.polygon, area2.polygon) and
					(
						not purchased_areas.has(area1) or
						not purchased_areas.has(area2)
					)
				):
					if purchased_areas.has(area1):
						purchased_areas[area2] = purchased_areas[area1]
					elif purchased_areas.has(area2):
						purchased_areas[area1] = purchased_areas[area2]
					else:
						_add_to_purchased_area(area1)
						purchased_areas[area2] = purchased_areas[area1]
					
					merged = true
					break
			
			if merged:
				break

func handle_polygon_purchase(pos: Vector2) -> void:
	for area in areas:
		# Check if the area is neutral and if the mouse is inside it
		if area.owner_id == -1:
			if Geometry2D.is_point_in_polygon(pos, area.polygon):
				# Track this original area as purchased
				if current_player == GameSimulationComponent.PLAYER_ID:
					purchased_original_areas[area.polygon_id] = true
				areas.erase(area)
				
				# Determine scale factor based on vehicle size
				var scale_factor: float
				match current_vehicle_size:
					"small":
						scale_factor = 1.0/8.0
					"medium":
						scale_factor = 1.0/4.0
					"large":
						scale_factor = 1.0/2.0
					"huge":
						scale_factor = 1.0
					_:
						assert(false)
				
				#var territory_polygon: PackedVector2Array = GeometryUtils.scale_polygon_to_area_around_point(
					#area.polygon,
					#GeometryUtils.calculate_polygon_area(area.polygon) * scale_factor,
					#area.center
				#)

				var target_area: float = GeometryUtils.calculate_polygon_area(area.polygon) * scale_factor
				var offset_distance: float = 0.0
				var step: float = 1.0
				var max_iterations: int = 2000

				for i in range(max_iterations):
					var test_polygons: Array[PackedVector2Array] = Geometry2D.offset_polygon(
						area.polygon,
						-offset_distance,
						Geometry2D.JOIN_MITER
					)
					
					if test_polygons.is_empty():
						break
						
					var test_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(test_polygons)
					var test_area: float = GeometryUtils.calculate_polygon_area(test_polygon)
					
					if abs(test_area - target_area) < 1.0:  # Close enough
						break
					elif test_area > target_area:
						offset_distance += step
					else:
						offset_distance -= step
						step *= 0.5  # Refine step size

				var territory_polygon: PackedVector2Array = GeometryUtils.find_largest_polygon(
					Geometry2D.offset_polygon(
						area.polygon,
						-offset_distance,
						Geometry2D.JOIN_MITER
					)
				)

				var new_area: Area = Area.new(
					Global.get_player_color(current_player),
					territory_polygon,
					current_player,
					area.center,
				)
				areas.append(new_area)
				
				# After purchase, merge with any adjacent areas owned by the same player
				merge_adjacent_areas(current_player)
				if not purchased_areas.has(new_area):
					_add_to_purchased_area(new_area)
				
				var base_polygon: PackedVector2Array = GeometryUtils.scale_polygon_to_area_around_point(
					area.polygon,
					GeometryUtils.calculate_polygon_area(area.polygon)/16.0,
					area.center
				)
				map_generator.spawn_base_for_original(				# static helper we just wrote
					map,
					area,
					new_area,
					current_player,							# whatever the area's current owner is
					base_polygon
				)
				
				ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
				queue_redraw()

				return

func _draw() -> void:
	draw_component.queue_redraw()
	draw_component.background_layer_1.queue_redraw()
	draw_component.background_layer_2.queue_redraw()
	draw_component.polygon_layer1.queue_redraw()
	draw_component.polygon_layer2.queue_redraw()
	draw_component.polygon_layer3.queue_redraw()
	draw_component.text_overlay_layer.queue_redraw()
	draw_component.vehicle_layer.queue_redraw()
	draw_component.vehicle_layer.vehicle_renderer.queue_redraw()
	draw_component.unit_layer.queue_redraw()
	draw_component.air_layer.queue_redraw()
	draw_component.highlight_manager.queue_redraw()
	if game_simulation_component != null:
		game_simulation_component.queue_redraw()

func _on_clear_map_pressed() -> void:
	# Set all areas to neutral (owner_id = -1)
	var new_areas: Array[Area] = []
	for area: Area in areas:
		if area.owner_id < -1:
			new_areas.append(area)
	new_areas.append_array(map.original_walkable_areas)
	areas = new_areas
	
	purchased_areas.clear()
	
	map.bases.clear()
	map.base_index_by_original_id.clear()
	map.trains.clear()
	map.tanks.clear()
	map.ships.clear()
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	queue_redraw()

func area_has_vehicle(area_center: Vector2) -> bool:
	for tank in map.tanks:
		if tank.global_position == area_center:
			return true
	for train in map.trains:
		if train.global_position == area_center:
			return true
	for ship in map.ships:
		if ship.global_position == area_center:
			return true
	return false

func add_tank_to_clicked_territory(pos: Vector2) -> void:
	for area in areas:
		if area.owner_id >= -1:
			if Geometry2D.is_point_in_polygon(pos, area.polygon):
				# Check if area already has a vehicle
				if area_has_vehicle(area.center):
					return
				
				var tank: Tank
				match current_vehicle_size:
					"small":
						tank = TankSmall.new()
					"medium":
						tank = TankMedium.new()
					"large":
						tank = TankLarge.new()
					"huge":
						tank = TankHuge.new()
					_:
						assert(false)
				
				tank.owner_id = current_player
				tank.global_position = area.center
				var angle_rad: float = deg_to_rad(tank_rotations[current_tank_rotation_index])
				tank.direction = Vector2(cos(angle_rad), sin(angle_rad))
				map.tanks.append(tank)
				queue_redraw()
				return

func add_train_to_clicked_territory(pos: Vector2) -> void:
	if map.roads.is_empty():
		return
	for area in areas:
		if area.owner_id >= -1:
			if Geometry2D.is_point_in_polygon(pos, area.polygon):
				# Only allow if area.center is a key in map.road_node_to_area
				if map.road_node_to_area.has(area.center):
					# Check if area already has a vehicle
					if area_has_vehicle(area.center):
						return
					
					var found_road = null
					var found_distance: float = 0.0
					for road in map.roads:
						for i in range(road.size()):
							if road[i] == area.center:
								found_road = road
								# Calculate distance along the road up to this node
								var dist: float = 0.0
								for j in range(i):
									dist += road[j].distance_to(road[j+1])
								found_distance = dist
								break
						if found_road != null:
							break
					assert(found_road != null)
					
					var train: Train
					match current_vehicle_size:
						"small":
							train = TrainSmall.new()
						"medium":
							train = TrainMedium.new()
						"large":
							train = TrainLarge.new()
						"huge":
							train = TrainHuge.new()
						_:
							assert(false)
					
					train.owner_id = current_player
					train.road = found_road
					train.distance = found_distance
					train.global_position = area.center
					map.trains.append(train)
					queue_redraw()
					return

func add_ship_to_clicked_territory(pos: Vector2) -> void:
	if map.water_graph.is_empty():
		return
	# Find nearest water node
	var min_dist = INF
	var nearest_node = null
	for node in map.water_graph.keys():
		var dist = node.distance_to(pos)
		if dist < min_dist:
			min_dist = dist
			nearest_node = node
	# Check for existing vehicle at this node
	if area_has_vehicle(nearest_node):
		return
	var ship: Ship
	match current_vehicle_size:
		"small":
			ship = ShipSmall.new()
		"medium":
			ship = ShipMedium.new()
		"large":
			ship = ShipLarge.new()
		"huge":
			ship = ShipHuge.new()
		_:
			assert(false)
	ship.owner_id = current_player
	ship.global_position = nearest_node
	ship.current_node = nearest_node
	var neighbors = map.water_graph[nearest_node]
	if neighbors.size() > 0:
		var dir_index = clamp(current_ship_direction_index, 0, neighbors.size()-1)
		ship.next_node = neighbors[dir_index]
		ship.path = [nearest_node, neighbors[dir_index]]
	else:
		ship.next_node = nearest_node
		ship.path = [nearest_node]
	map.ships.append(ship)
	queue_redraw()

func _on_ship_direction_toggled() -> void:
	current_ship_direction_index = 1 - current_ship_direction_index
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)

func _on_map_mode_random_pressed() -> void:
	current_mode = Global.GameMode.RANDOM
	setup_game(current_mode)
	queue_redraw()

func _on_map_mode_create_pressed() -> void:
	current_mode = Global.GameMode.CREATE
	setup_game(current_mode)
	create_seed_points.clear()
	create_terrain_by_seed.clear()
	draw_component.prepare_for_new_game()
	queue_redraw()
	# ensure simple mode is applied in background
	draw_component.invalidate_static_textures()
	draw_component.queue_redraw()

func _on_create_terrain_plains_pressed() -> void:
	create_current_terrain = "plains"
	ui_component.set_create_terrain_display(create_current_terrain)

func _on_create_terrain_forest_pressed() -> void:
	create_current_terrain = "forest"
	ui_component.set_create_terrain_display(create_current_terrain)

func _on_create_terrain_mountains_pressed() -> void:
	create_current_terrain = "mountains"
	ui_component.set_create_terrain_display(create_current_terrain)

func _on_create_terrain_lake_pressed() -> void:
	create_current_terrain = "lake"
	ui_component.set_create_terrain_display(create_current_terrain)

func _snap_to_integer(p: Vector2) -> Vector2:
	var xi: int = int(p.x)
	var yi: int = int(p.y)
	return Vector2(xi, yi)


func _find_seed_index_at_position(pos: Vector2, radius: float) -> int:
	var best_index: int = -1
	var best_dist: float = INF
	for i: int in range(create_seed_points.size()):
		var p: Vector2 = create_seed_points[i]
		var d: float = p.distance_to(pos)
		if d <= radius and d < best_dist:
			best_dist = d
			best_index = i
	return best_index

func _rebuild_create_map_after_seed_change() -> void:
	map = map_generator.create_map_from_seed_points(create_seed_points, create_terrain_by_seed, false)
	draw_component.invalidate_static_textures()
	draw_component.queue_redraw()
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	ui_component.set_map_mode_display(current_mode)
	ui_component.set_create_terrain_display(create_current_terrain)
	queue_redraw()

func _handle_create_mode_press(pos: Vector2) -> void:
	var idx: int = _find_seed_index_at_position(pos, CREATE_PICK_RADIUS)
	if create_mode == "move":
		if idx >= 0:
			create_dragging = true
			create_drag_index = idx
			create_drag_origin = create_seed_points[idx]
			return
		return
	if create_mode == "delete":
		if idx >= 0:
			var old_pos: Vector2 = create_seed_points[idx]
			create_seed_points.remove_at(idx)
			if create_terrain_by_seed.has(old_pos):
				create_terrain_by_seed.erase(old_pos)
			# If seeds remain, rebuild; else, reset to blank CREATE
			if create_seed_points.size() > 0:
				_rebuild_create_map_after_seed_change()
			else:
				setup_game(Global.GameMode.CREATE)
			return
		return
	if create_mode == "paint":
		if idx >= 0:
			var pos_old: Vector2 = create_seed_points[idx]
			create_terrain_by_seed[pos_old] = create_current_terrain
			_rebuild_create_map_after_seed_change()
			return
		return
	# add mode
	if create_mode == "add":
		var snapped: Vector2 = pos
		var exists: bool = false
		for s: Vector2 in create_seed_points:
			if s == snapped:
				exists = true
				break
		if exists == false:
			create_seed_points.append(snapped)
			create_terrain_by_seed[snapped] = create_current_terrain
			# Keep current purchases state cleared for fresh map
			purchased_areas.clear()
			purchased_original_areas.clear()
			_rebuild_create_map_after_seed_change()

func _handle_create_mode_drag(pos: Vector2) -> void:
	if create_drag_index < 0 or create_drag_index >= create_seed_points.size():
		return
	var old_pos: Vector2 = create_seed_points[create_drag_index]
	var terrain: String = "plains"
	if create_terrain_by_seed.has(old_pos):
		terrain = create_terrain_by_seed[old_pos]
	create_seed_points[create_drag_index] = pos
	if create_terrain_by_seed.has(old_pos):
		create_terrain_by_seed.erase(old_pos)
	create_terrain_by_seed[pos] = terrain
	_rebuild_create_map_after_seed_change()

func _handle_create_mode_release(pos: Vector2) -> void:
	create_dragging = false
	create_drag_index = -1

func _on_create_mode_add_pressed() -> void:
	create_mode = "add"
	ui_component.set_create_mode_display(create_mode)

func _on_create_mode_move_pressed() -> void:
	create_mode = "move"
	ui_component.set_create_mode_display(create_mode)

func _on_create_mode_delete_pressed() -> void:
	create_mode = "delete"
	ui_component.set_create_mode_display(create_mode)

func _on_create_mode_paint_pressed() -> void:
	create_mode = "paint"
	ui_component.set_create_mode_display(create_mode)

func _on_finish_map_pressed() -> void:
	# Build a finalized map (no rivers/roads in CREATE so far), then switch to setup phase ready for placement
	if create_seed_points.size() > 0:
		map = map_generator.create_map_from_seed_points(create_seed_points, create_terrain_by_seed, true)
	# Switch to FINAL mode: full visuals, create UI hidden
	current_mode = Global.GameMode.FINAL
	# Rebuild assignable areas: keep obstacles/background; add all neutral originals
	var rebuilt: Array[Area] = []
	for a: Area in areas:
		if a.owner_id < -1:
			rebuilt.append(a)
	rebuilt.append_array(map.original_walkable_areas)
	rebuilt.append_array(map.original_obstacles)
	map_generator.permanently_merge_obstacles(rebuilt)
	areas = rebuilt
	draw_component.prepare_for_new_game()
	draw_component.invalidate_static_textures()
	draw_component.queue_redraw()
	# Hide create controls and clear map mode highlights
	ui_component.set_create_controls_visible(false)
	ui_component.set_map_mode_display(current_mode)
	# Enable assigning territories/vehicles by returning to territory type
	current_type = "territory"
	ui_component.update_ui(current_player, game_phase, current_type, tank_rotations[current_tank_rotation_index], current_vehicle_size, current_ship_direction_index)
	queue_redraw()

func _on_save_map_pressed() -> void:
	if current_mode != Global.GameMode.CREATE:
		return
	# open name prompt handled in UI; logic in _on_save_map_confirmed

func _on_load_map_pressed() -> void:
	# list population handled in UI dialog; logic in _on_load_map_confirmed
	pass

func _on_save_map_confirmed(base_name: String) -> void:
	var dict: Dictionary = {}
	for p: Vector2 in create_seed_points:
		var key: String = str(p.x) + "," + str(p.y)
		var terr: String = "plains"
		if create_terrain_by_seed.has(p):
			terr = create_terrain_by_seed[p]
		dict[key] = terr
	var json: String = JSON.stringify(dict, "\t")
	var dir_path: String = "res://map_saves"
	var file_path: String = dir_path + "/" + base_name + ".json"
	print("[SAVE] dir:", dir_path, " (", ProjectSettings.globalize_path(dir_path), ")")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		print("[SAVE] Failed to open for write:", file_path)
		return
	f.store_string(json)
	f.close()
	print("[SAVE] Wrote:", file_path)

func _on_load_map_confirmed(filename: String) -> void:
	var file_path: String = "res://map_saves/" + filename
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		print("[LOAD] Failed to open:", file_path)
		return
	var content: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	create_seed_points.clear()
	create_terrain_by_seed.clear()
	for k in parsed.keys():
		var s: String = String(k)
		var parts: PackedStringArray = s.split(",")
		if parts.size() == 2:
			var x: float = parts[0].to_float()
			var y: float = parts[1].to_float()
			var v: Vector2 = Vector2(x, y)
			create_seed_points.append(v)
			create_terrain_by_seed[v] = String(parsed[k])
	map = map_generator.create_map_from_seed_points(create_seed_points, create_terrain_by_seed, false)
	draw_component.invalidate_static_textures()
	draw_component.queue_redraw()
	queue_redraw()
