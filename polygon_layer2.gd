extends Node2D
class_name PolygonLayer2


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
		big_intersecting_areas_circumferences = get_parent().get_parent().game_simulation_component.big_intersecting_areas_circumferences

	# Draw static obstacles from texture
	draw_texture(get_parent().obstacles_texture, Vector2.ZERO)
	if get_parent().get_parent().game_simulation_component != null:
		var bg_color = Color.BLACK
		bg_color.a = DrawComponent.DARKEN_UNCLICKED_ALPHA
		for obstacle: Area in map.original_obstacles:
			if not clicked_original_walkable_areas.has(obstacle.polygon_id):
				draw_colored_polygon(obstacle.polygon, bg_color)
