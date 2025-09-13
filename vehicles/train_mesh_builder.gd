extends VehicleMeshBuilder
class_name TrainMeshBuilder


func build() -> ArrayMesh:
	var tmpl: TrainMesh = TrainMesh.new(base_diameter)
	return tmpl.build()	
