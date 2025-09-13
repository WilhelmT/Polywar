extends Tank
class_name TankHuge

static func get_diameter() -> float:
	return 16.0*2

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.TANK_HUGE 
