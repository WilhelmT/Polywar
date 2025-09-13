extends VehicleMeshBuilder
class_name ShipMeshBuilder

func _init(p_diameter: float) -> void:
	base_diameter = p_diameter

# Build a low-poly stylized ship mesh (2D, bow points up/negative Y)
func build() -> ArrayMesh:
	var tmpl: ShipMesh = ShipMesh.new(base_diameter)
	return tmpl.build()
