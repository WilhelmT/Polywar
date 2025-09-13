extends Node2D
class_name RiverMaskDrawer

var map: Global.Map = null

func setup(p_map: Global.Map) -> void:
	map = p_map
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	var width_outer: float = 1.0 * MapGenerator.BANK_OFFSET
	var white: Color = Color(1, 1, 1, 1)
	for river: PackedVector2Array in map.rivers:
		if river.size() < 2:
			continue
		var main_poly: PackedVector2Array = GeometryUtils.get_main_river_polygon_from_polyline(river, width_outer)
		if main_poly.size() < 3:
			continue
		draw_colored_polygon(main_poly, white)
