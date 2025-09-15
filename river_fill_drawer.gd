extends Node2D
class_name RiverFillDrawer

var map: Global.Map = null

func setup(p_map: Global.Map) -> void:
	map = p_map
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	var water_base: Color = StaticBackgroundDrawer.WATER_BASE
	water_base.a = 1.0

	# Build filled river polygons from widest offset and render layered insets like lakes
	var width_outer: float = 1.0 * MapGenerator.BANK_OFFSET
	var layer_count: int = 1000
	var layer_step: float = 1.0
	const DARKEN_MIN: float = 0.5

	for river: PackedVector2Array in map.rivers:
		if river.size() < 2:
			continue
		# Generate main river polygon from centerline
		var main_poly: PackedVector2Array = GeometryUtils.get_main_river_polygon_from_polyline(river, width_outer)
		if main_poly.size() < 3:
			continue
		# Base fill
		draw_colored_polygon(main_poly, water_base)

		# Layered inset fills toward center
		var l: int = 0
		while l < layer_count:
			var found_valid_inset: bool = false
			var inset: float = -float(l + 1) * layer_step
			var darken_amount: float = 0.0 + (float(l) * 0.0035)
			darken_amount = sqrt(darken_amount)
			darken_amount = min(darken_amount, DARKEN_MIN)
			var layer_color: Color = water_base.darkened(darken_amount)
			layer_color.a = 1.0
			var inset_polys: Array[PackedVector2Array] = Geometry2D.offset_polygon(
				main_poly, inset, Geometry2D.JOIN_ROUND
			)
			for inset_poly: PackedVector2Array in inset_polys:
				# Ensure CCW
				if Geometry2D.is_polygon_clockwise(inset_poly):
					continue
				if inset_poly.size() >= 3:
					draw_colored_polygon(inset_poly, layer_color)
					found_valid_inset = true
			l += 1
			if not found_valid_inset:
				break
