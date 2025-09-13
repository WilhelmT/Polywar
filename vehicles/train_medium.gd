extends Train
class_name TrainMedium


static func get_kind() -> VehicleKind.Type:
	return VehicleKind.Type.TRAIN_LOCOMOTIVE

static func get_num_carts() -> int:
	return 1
