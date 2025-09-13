extends Tank
class_name TankSmall

static func get_diameter() -> float:
	return 42.0*1.0

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.TANK_SMALL
