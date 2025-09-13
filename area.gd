class_name Area
extends Resource

var color: Color
var polygon: PackedVector2Array
var owner_id: int
var polygon_id: int
var center: Vector2
var holes: Array[PackedVector2Array]

var _stored_area: float = -1
var _stored_circumference: float = -1

const STRENGTH_FROM_BASE: float = 0.1

func _init(
	p_color: Color,
	p_polygon: PackedVector2Array,
	p_owner_id: int,
	p_center: Vector2 = Vector2.ZERO,
	p_holes: Array[PackedVector2Array] = []
) -> void:
	color = p_color
	polygon = p_polygon
	owner_id = p_owner_id
	polygon_id = get_instance_id()
	center = p_center
	holes = p_holes

func clear_cache() -> void:
	_stored_area = -1
	_stored_circumference = -1

func _get_raw_area() -> float:
	if _stored_area != -1:
		return _stored_area
	_stored_area = GeometryUtils.calculate_polygon_area(polygon)
	return _stored_area

func _get_raw_circumference() -> float:
	if _stored_circumference != -1:
		return _stored_circumference
	_stored_circumference = GeometryUtils.calculate_polygon_circumference(polygon)
	return _stored_circumference
	
func get_total_circumference() -> float:
	var outer_circumference: float = _get_raw_circumference()
	var inner_circumference: float = 0.0
	for hole: PackedVector2Array in holes:
		inner_circumference += GeometryUtils.calculate_polygon_circumference(hole)
	return outer_circumference+inner_circumference

func get_total_area() -> float:
	var outer_area: float = _get_raw_area()
	var inner_area: float = 0.0
	for hole: PackedVector2Array in holes:
		inner_area += GeometryUtils.calculate_polygon_area(hole)
	return max(outer_area-inner_area, 0)

func get_strength_unmodified(
	map: Global.Map,
	total_weighted_circumference: float,
	base_ownership: Array,
	areas: Array[Area],
) -> float:
	var strength: float = 0.0
	if Global.get_doctrine(owner_id) == Global.Doctrine.SUPERIOR_FIREPOWER:
		strength = get_total_area() / (Global.world_size.x*Global.world_size.y)
	elif Global.get_doctrine(owner_id) == Global.Doctrine.MASS_MOBILISATION:
		# PI/2.0 is a magic number..
		#return PI/2.0 * sqrt(get_total_area() / (Global.world_size.x*Global.world_size.y)) * (total_weighted_circumference / (2*Global.world_size.x+2*Global.world_size.y))
		strength = sqrt(get_total_area() / (Global.world_size.x*Global.world_size.y)) * (total_weighted_circumference / (2*Global.world_size.x+2*Global.world_size.y))
	elif Global.get_doctrine(owner_id) == Global.Doctrine.SPECIAL_OPERATIONS:
		strength = 0.25
	else:
		assert(false)
	
	return strength + STRENGTH_FROM_BASE*base_ownership.size()


func get_strength(
	map: Global.Map,
	areas: Array[Area],
	total_weighted_circumferences: Dictionary[Area, float],
	base_ownerships: Dictionary[Area, Array],
) -> float:
	var unmodified_strength: float = get_strength_unmodified(
		map,
		total_weighted_circumferences[self],
		base_ownerships[self],
		areas,
	)
	if owner_id >= 0 and map.total_manpower[owner_id]<0:
		var area_required_manpower: float = (
			UnitLayer.MAX_UNITS *
			UnitLayer.NUMBER_PER_UNIT *
			unmodified_strength
		)
		var total_owner_id_strength: float = Global.get_total_owner_strength_unmodified(
			owner_id,
			areas,
			map,
			total_weighted_circumferences,
			base_ownerships,
		)
		var total_id_required_manpower: float = total_owner_id_strength
		var deficit_strength: float = -map.total_manpower[owner_id] / (
			UnitLayer.MAX_UNITS *
			UnitLayer.NUMBER_PER_UNIT
		)
		
		var deficit_fraction: float = area_required_manpower/total_id_required_manpower
		return max(
			0, unmodified_strength - deficit_strength*deficit_fraction
		)
	return unmodified_strength
