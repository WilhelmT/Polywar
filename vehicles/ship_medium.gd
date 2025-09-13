extends Ship
class_name ShipMedium

static func get_diameter() -> float:
	return 48.0*sqrt(2)

static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.SHIP_MEDIUM 
