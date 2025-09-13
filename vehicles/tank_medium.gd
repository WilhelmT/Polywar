extends Tank
class_name TankMedium

static func get_diameter() -> float:
	return 42.0*sqrt(2)

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.TANK_MEDIUM
