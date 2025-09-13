extends VehicleMeshBuilder
class_name TankMeshBuilder


func build() -> ArrayMesh:
	var tmpl: TankMesh = TankMesh.new(base_diameter)
	return tmpl.build()
