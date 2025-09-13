extends Node2D
class_name WaterMaskDrawer

var areas: Array[Area] = []
var map: Global.Map = null

func setup(p_areas: Array[Area], p_map: Global.Map) -> void:
	areas = p_areas
	map = p_map
	queue_redraw()

func _draw() -> void:
	if areas.is_empty():
		return
	# Lakes only
	for obstacle: Area in areas:
		if obstacle.owner_id == -2:
			if obstacle.polygon.size() >= 3:
				draw_colored_polygon(obstacle.polygon, Color(1, 1, 1, 1))
