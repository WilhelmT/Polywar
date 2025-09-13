extends Ship
class_name ShipSmall

static func get_diameter() -> float:
	return 48.0*1.0

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.SHIP_SMALL 
