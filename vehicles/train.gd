extends Vehicle
class_name Train

const WIDTH_FRACTION: float = 0.25
const LOCOMOTIVE_LEN_FRAC: float = 1.5
const CONNECTOR_WIDTH_FRACTION: float = 0.125
const GAP_FRACTION: float = 0.5				# empty space between cars

var road: PackedVector2Array
var distance: float = 0.0


static func terrain_multiplier_reduction() -> float:
	return INF

static func get_num_carts() -> int:
	assert(false)
	return 0

static func get_diameter() -> float:
	return 36.0

func get_direction() -> Vector2:
	var remaining: float = distance
	for i: int in range(road.size() - 1):
		var seg_len: float = road[i].distance_to(road[i + 1])
		if remaining <= seg_len:
			return (road[i + 1] - road[i]).normalized()
		remaining -= seg_len
	return Vector2.ZERO


# ────────────────────────────────────────────────────────────────
#  MAIN ENTRY – replaces the TODO in Train.collision_polygon()
# ────────────────────────────────────────────────────────────────
func collision_polygon() -> PackedVector2Array:
	var CART_LEN: float = get_diameter()
	var LOCOMOTIVE_LEN: float = get_diameter() * LOCOMOTIVE_LEN_FRAC
	var GAP_LEN: float = GAP_FRACTION*get_diameter()
	
	# --- dimensions ----------------------------------------------
	var half_cart: float = get_diameter() * WIDTH_FRACTION		# full cart width
	var half_conn: float = get_diameter() * CONNECTOR_WIDTH_FRACTION		# skinny connector

	# --- rear-most / front-most distances along the rail ---------
	var loco_half: float = LOCOMOTIVE_LEN * 0.5
	var cart_half: float = CART_LEN * 0.5
	var gap: float = GAP_LEN

	var base_gap: float = loco_half + gap + cart_half	# centre-to-centre first cart
	var tail_offset: float = base_gap						\
		+ float(get_num_carts() - 1) * (CART_LEN + GAP_LEN)	\
		+ cart_half										# rear buffer
	var nose_offset: float = loco_half						# front buffer

	var s_head: float = distance# + nose_offset				# nose of loco
	var s_tail: float = distance - tail_offset				# tail of last cart

	# -------------------------------------------------------------
	# 1. connector ribbon – offset of the centre line
	# -------------------------------------------------------------
	var centre: PackedVector2Array = PackedVector2Array()

	# collect the rail between s_tail … s_head, wrapping if needed
	centre.append(_pos_and_dir_at(s_tail).pos)
	var loop_len: float = _ensure_road_len()
	var u: float = s_tail
	while true:
		var step: float = min(64.0, s_head - u)	# step ≤ 64 px for smoothness
		if step < 0.0001:
			break
		u += step
		centre.append(_pos_and_dir_at(u).pos)

	var conn_polys: Array[PackedVector2Array] = Geometry2D.offset_polyline(
		centre,
		half_conn,
		Geometry2D.PolyJoinType.JOIN_MITER,
		Geometry2D.PolyEndType.END_SQUARE
	)
	var merged: PackedVector2Array
	if conn_polys.is_empty():
		merged = PackedVector2Array()
	else:
		merged = conn_polys[0]					# largest is always first here

	# -------------------------------------------------------------
	# 2. full-size rectangles for every car
	# -------------------------------------------------------------
	# locomotive
	var loco_info: Dictionary = _pos_and_dir_at(distance)
	merged = Geometry2D.merge_polygons(
		merged,
		_make_rect(loco_info.pos, loco_info.dir, loco_half, half_cart)
	)[0]

	# carts
	for i: int in range(get_num_carts()):
		var centre_s: float = distance - base_gap - float(i) * (CART_LEN + GAP_LEN)
		var info: Dictionary = _pos_and_dir_at(centre_s)
		merged = GeometryUtils.find_largest_polygon(
			Geometry2D.merge_polygons(
				merged,
				_make_rect(info.pos, info.dir, cart_half, half_cart)
			)
		)

	return merged


# ────────────────────────────────────────────────────────────────
#  HELPERS  (place these anywhere in the same script, top-level)
# ────────────────────────────────────────────────────────────────
var _cached_road_len: float = -1.0

func _ensure_road_len() -> float:
	if _cached_road_len < 0.0:
		_cached_road_len = 0.0
		for i: int in range(road.size() - 1):
			_cached_road_len += road[i].distance_to(road[i + 1])
	return _cached_road_len


func _pos_and_dir_at(s: float) -> Dictionary:
	var total: float = _ensure_road_len()
	s = fposmod(s, total)								# wrap around loop
	var remaining: float = s

	for i: int in range(road.size() - 1):
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		var seg_len: float = a.distance_to(b)
		if remaining <= seg_len:
			var t: float = remaining / seg_len
			return {
				"pos": a.lerp(b, t),
				"dir": (b - a).normalized()
			}
		remaining -= seg_len

	# fallback (should never hit)
	return {
		"pos": road[-1],
		"dir": (road[-1] - road[road.size() - 2]).normalized()
	}


func _make_rect(center: Vector2, dir: Vector2,
		half_len: float, half_wid: float) -> PackedVector2Array:
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var poly: PackedVector2Array = PackedVector2Array()

	poly.append(center - right * half_wid - dir * half_len)
	poly.append(center + right * half_wid - dir * half_len)
	poly.append(center + right * half_wid + dir * half_len)
	poly.append(center - right * half_wid + dir * half_len)
	return poly


func _build_box(half: Vector2, dir: Vector2, right: Vector2, fwd: float) -> PackedVector2Array:
	var centre: Vector2 = global_position + dir * fwd
	var pts: PackedVector2Array = PackedVector2Array()

	# produce the four corners in local (right / dir) basis, then rotate+translate
	var corners: Array[Vector2] = [
		Vector2(-half.x, -half.y),
		Vector2( half.x, -half.y),
		Vector2( half.x,  half.y),
		Vector2(-half.x,  half.y)
	]

	for p: Vector2 in corners:
		var world: Vector2 = centre + right * p.x - dir * p.y
		pts.append(world)

	return pts

func _get_base_speed() -> float:
	return 16.0*Global.GLOBAL_SPEED
