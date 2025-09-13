extends Node2D
class_name VehiclesRenderer

const MAX_INSTANCES_PER_KIND: int = 64

var kinds: Dictionary[VehicleKind.Type, VehicleMeshBuilder] = {}
var multimeshes: Dictionary[VehicleKind.Type, MultiMesh] = {}

const FACET_DARK: float = 0.1
const FACET_BRIGHT: float = 1.0
const TRACK_SEGMENTS: int = 16
const TRACK_PERIOD: float = 0.1

var shader: Shader = preload("res://vehicles/vehicle_shader.gdshader")	# can reuse for all

func _ready() -> void:
	_register_kind(VehicleKind.Type.TANK_SMALL, TankMeshBuilder.new(TankSmall.get_diameter()))
	_register_kind(VehicleKind.Type.TANK_MEDIUM, TankMeshBuilder.new(TankMedium.get_diameter()))
	_register_kind(VehicleKind.Type.TANK_LARGE, TankMeshBuilder.new(TankLarge.get_diameter()))
	_register_kind(VehicleKind.Type.TANK_HUGE, TankMeshBuilder.new(TankHuge.get_diameter()))
	
	_register_kind(VehicleKind.Type.TRAIN_LOCOMOTIVE, TrainMeshBuilder.new(Train.get_diameter()))
	_register_kind(VehicleKind.Type.TRAIN_CART, TrainCartMeshBuilder.new(Train.get_diameter()))
	
	_register_kind(VehicleKind.Type.SHIP_SMALL, ShipMeshBuilder.new(ShipSmall.get_diameter()))
	_register_kind(VehicleKind.Type.SHIP_MEDIUM, ShipMeshBuilder.new(ShipMedium.get_diameter()))
	_register_kind(VehicleKind.Type.SHIP_LARGE, ShipMeshBuilder.new(ShipLarge.get_diameter()))
	_register_kind(VehicleKind.Type.SHIP_HUGE, ShipMeshBuilder.new(ShipHuge.get_diameter()))

func _register_kind(kind: VehicleKind.Type, builder: VehicleMeshBuilder) -> void:
	kinds[kind] = builder

	var mesh: ArrayMesh = builder.build()
	
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("LIGHT_DIR", Global.LIGHT_DIR.normalized())
	material.set_shader_parameter("FACET_DARK", FACET_DARK)
	material.set_shader_parameter("FACET_BRIGHT", FACET_BRIGHT)
	material.set_shader_parameter("TRACK_SEGMENTS", TRACK_SEGMENTS)
	material.set_shader_parameter("TRACK_PERIOD", TRACK_PERIOD)
	mesh.surface_set_material(0, material)

	var mm: MultiMesh = MultiMesh.new()
	mm.mesh = mesh
	mm.use_colors = true
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.instance_count = MAX_INSTANCES_PER_KIND
	for i: int in MAX_INSTANCES_PER_KIND:
		mm.set_instance_color(i, Color(1, 1, 1, 0))
	multimeshes[kind] = mm

func _process(_delta: float) -> void:
	_update_instances()

func _update_instances() -> void:
	var map: Global.Map = null
	if get_parent().get_parent().get_parent() != null:
		map = get_parent().get_parent().get_parent().map
	if map == null:
		return

	# 1. clear every multimesh
	for mm: MultiMesh in multimeshes.values():
		for i_clear: int in mm.instance_count:
			mm.set_instance_color(i_clear, Color(1.0, 1.0, 1.0, 0.0))

	# 2. place instances
	var counters: Dictionary[VehicleKind.Type, int] = {}
	for vehicle: Vehicle in map.tanks + map.trains + map.ships:
		# ───────────────────────── locomotive / generic body ─────────────────
		var kind: VehicleKind.Type = vehicle.get_kind()
		if not multimeshes.has(kind):
			assert(false)
			continue								# unsupported kind, skip
		
		var tint: Color = Global.get_vehicle_color(vehicle.owner_id)
		var idx: int = counters.get(kind, 0)
		if idx < MAX_INSTANCES_PER_KIND:
			var dir: Vector2 = vehicle.get_direction()
			if dir.length_squared() < 0.01:
				dir = Vector2.DOWN
			var right: Vector2 = Vector2(-dir.y, dir.x)

			var scale: float = vehicle.get_diameter() / kinds[kind].base_diameter
			var basis: Transform2D = Transform2D(
				right * scale,
				-dir  * scale,
				vehicle.global_position
			)

			var mm: MultiMesh = multimeshes[kind]
			mm.set_instance_transform_2d(idx, basis)

			mm.set_instance_color(idx, tint)
			mm.set_instance_custom_data(idx, Color(dir.x, dir.y, 0.0, 0.0))

			counters[kind] = idx + 1						# advance counter

		# ───────────────────────────── extra carts (trains) ──────────────────
		if vehicle is Train:
			var train: Train = vehicle
			var cart_kind: VehicleKind.Type = VehicleKind.Type.TRAIN_CART
			if multimeshes.has(cart_kind):
				var cart_mm: MultiMesh = multimeshes[cart_kind]
				var cart_idx: int = counters.get(cart_kind, 0)

				# replicate spacing math from Train.collision_polygon()
				var loco_half: float = train.get_diameter() * Train.LOCOMOTIVE_LEN_FRAC * 0.5
				var cart_half: float = train.get_diameter() * 0.5						# cart length = loco diameter
				var gap_len: float = Train.GAP_FRACTION * train.get_diameter()
				var base_gap: float = loco_half + gap_len + cart_half

				for ci: int in range(train.get_num_carts()):
					if cart_idx >= MAX_INSTANCES_PER_KIND:
						break

					var centre_s: float = train.distance - base_gap - float(ci) * (train.get_diameter() + gap_len)
					var info: Dictionary = train._pos_and_dir_at(centre_s)

					var c_dir: Vector2 = info.dir
					if c_dir.length_squared() < 0.01:
						c_dir = Vector2.DOWN
					var c_right: Vector2 = Vector2(-c_dir.y, c_dir.x)

					var scale_cart: float = train.get_diameter() / kinds[cart_kind].base_diameter
					var basis_cart: Transform2D = Transform2D(
						c_right * scale_cart,
						-c_dir   * scale_cart,
						info.pos
					)

					cart_mm.set_instance_transform_2d(cart_idx, basis_cart)
					
					
					cart_mm.set_instance_color(cart_idx, tint)
					cart_mm.set_instance_custom_data(cart_idx, Color(c_dir.x, c_dir.y, 0.0, 0.0))

					cart_idx += 1

				counters[cart_kind] = cart_idx

func _draw() -> void:
	# Default initial values
	var map: Global.Map = null

	map = get_parent().get_parent().get_parent().map

	#for vehicle: Vehicle in map.tanks+map.trains+map.ships:
		#var col: Color = Global.get_player_color(vehicle.owner_id)
		#var closed: PackedVector2Array = vehicle.collision_polygon()
		#col.a = 0.25
		#draw_polygon(closed, [col])
		#closed.append(closed[0])
		#draw_polyline_colors(closed, [Color.BLACK], 4*DrawComponent.AREA_OUTLINE_THICKNESS)


	for mm: MultiMesh in multimeshes.values():
		draw_multimesh(mm, null)
