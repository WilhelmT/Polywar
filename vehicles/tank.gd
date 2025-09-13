extends Vehicle
class_name Tank

var direction: Vector2	

func get_direction() -> Vector2:
	return direction

static func terrain_multiplier_reduction() -> float:
	return INF#2.0


func _get_base_speed() -> float:
	return 48.0*Global.GLOBAL_SPEED
