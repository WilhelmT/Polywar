extends Ship
class_name ShipHuge

static func get_diameter() -> float:
	return 24.0*2

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.SHIP_HUGE 
