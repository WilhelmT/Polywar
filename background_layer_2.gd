extends Node2D
class_name BackgroundLayer2


func _draw_background_cost(
	areas: Array[Area],
	map: Global.Map,
	current_player: int,
) -> void:
	return
	# Draw area labels
	for area: Area in areas:
		if area.owner_id == -1:
			# Draw strength and cost in the middle of each polygon
			var centroid = GeometryUtils.calculate_centroid(area.polygon)
			var strength: float = area.get_total_area() / (Global.world_size.x*Global.world_size.y)
			var font_size: int = max(get_parent().MIN_FONT_SIZE,  sqrt(250*strength*100))
			
			# For neutral areas
			var cost_text =  "%.2f" % (100*strength)
			draw_string(get_parent().font, centroid-Vector2(font_size,0), cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.DARK_GRAY)
			
			var circle_radius = 10
			var circle_highlight = Global.get_player_color(current_player)
			circle_highlight.a = 0.5
			draw_circle(centroid + Vector2(0, -font_size - 5), circle_radius, circle_highlight)

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
	var original_walkable_areas_covered: Dictionary[Area, Dictionary]
	if get_parent().get_parent().game_simulation_component != null:
		simulation_areas = get_parent().get_parent().game_simulation_component.areas
		expanded_sub_areas = get_parent().get_parent().game_simulation_component.expanded_sub_areas
		clicked_original_walkable_areas = get_parent().get_parent().game_simulation_component.clicked_original_walkable_areas
		original_walkable_areas_covered = get_parent().get_parent().game_simulation_component.original_walkable_areas_covered
	# Draw static elements from textures
	draw_texture(get_parent().background_texture_2, Vector2.ZERO)
	
	# Dynamic each game
	if game_phase == "setup":
		_draw_background_cost(
			areas,
			map,
			current_player,
		)
		# Visualize CREATE mode seeds and hover state
		if get_parent().get_parent().current_mode == Global.GameMode.CREATE:
			var seeds: Array[Vector2] = get_parent().get_parent().create_seed_points
			var hover_idx: int = get_parent().get_parent().create_hover_index
			for i: int in range(seeds.size()):
				var c: Color = Color.BLACK
				if i == hover_idx:
					c = Color(1.0, 0.85, 0.2, 1.0)
				draw_circle(seeds[i], 6.0, c)
				# small outline
				draw_circle(seeds[i], 8.0, Color(0.1,0.1,0.1,0.6))
			# preview polygon for add mode
			if get_parent().get_parent().create_mode == "add":
				var prev_poly: PackedVector2Array = get_parent().get_parent().create_preview_hover_poly
				if prev_poly.size() >= 3:
					var magenta: Color = Color(1.0, 0.0, 1.0, 0.4)
					draw_colored_polygon(prev_poly, magenta)
					var outline: PackedVector2Array = prev_poly.duplicate()
					outline.append(outline[0])
					draw_polyline(outline, Color(1.0, 0.0, 1.0, 0.9), 3.0, true)
