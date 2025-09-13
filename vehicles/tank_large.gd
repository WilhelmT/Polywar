extends Tank
class_name TankLarge

static func get_diameter() -> float:
	return 42.0*sqrt(3)

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.TANK_LARGE
