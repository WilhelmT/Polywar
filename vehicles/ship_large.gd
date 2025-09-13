extends Ship
class_name ShipLarge

static func get_diameter() -> float:
	return 48.0*sqrt(3)

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.SHIP_LARGE 
