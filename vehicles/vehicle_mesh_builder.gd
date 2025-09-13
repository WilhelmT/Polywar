extends RefCounted
class_name VehicleMeshBuilder

var base_diameter: float

func _init(p_diameter: float) -> void:
	base_diameter = p_diameter
	
func build() -> ArrayMesh:					# MUST be overridden
	assert(false)
	return ArrayMesh.new()
