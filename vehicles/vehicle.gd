extends Node2D
class_name Vehicle

var owner_id: int

const SEGMENTS: int = 4

static func terrain_multiplier_reduction() -> float:
	assert(false) # subclass responsibility
	return 0.0
	
static func get_diameter() -> float:
	assert(false) # subclass responsibility
	return 0.0

static func get_kind() -> VehicleKind.Type:
	assert(false) # subclass responsibility
	return VehicleKind.Type.TANK_SMALL

func collision_polygon() -> PackedVector2Array:
	var rotation_angle: float = get_direction().angle() + PI * 0.25
	var pts: PackedVector2Array
	for i: int in SEGMENTS:
		var angle: float = TAU * float(i) / float(SEGMENTS)
		var point: Vector2 = Vector2(cos(angle), sin(angle)) * get_diameter() * 0.5
		point = point.rotated(rotation_angle)
		pts.append(global_position + point)
	return pts

func get_direction() -> Vector2:
	assert(false) # subclass responsibility						
	return Vector2.ZERO

func _get_base_speed() -> float:
	assert(false) # subclass responsibility
	return 0.0

func get_speed(map: Global.Map) -> float:
	var original_area: Area = GeometryUtils.points_to_areas_mapping(
		[global_position], map, map.original_walkable_areas
	)[global_position]
	var terrain: String = map.terrain_map[original_area.polygon_id]
	var multiplier: float = Global.get_multiplier_for_terrain(terrain)
	multiplier = 1.0 - (1.0 - multiplier) / terrain_multiplier_reduction()
	return _get_base_speed() * multiplier
