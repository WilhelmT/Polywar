extends Resource
class_name ShipMesh

# Proportions and alpha values
const HULL_LEN_FRAC: float = 1.0
const HULL_WID_FRAC: float = 1/3.0
const HULL_POINT_FRAC: float = 0.22 # how far the point extends
const HULL_SIDE_FRAC: float = 0.60 # how much of the hull is straight sides
const HULL_ALPHA: float = 1.0
const DECK_ALPHA: float = 0.4
const TURRET_ALPHA: float = 0.95
const TURRET_BARREL_ALPHA: float = 0.90
const HULL_SEGMENTS: int = 6 # 2 points per end, 2 per side

# Members
var hull_len: float
var hull_wid: float

func _init(p_diameter: float) -> void:
	hull_len = p_diameter * HULL_LEN_FRAC
	hull_wid = p_diameter * HULL_WID_FRAC

func _add_flat_tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, normal: Vector2, brightness: float) -> void:
	var uv: Vector2 = normal.normalized()
	var col: Color = Color(brightness, brightness, brightness, 1.0)
	st.set_color(col)
	st.set_uv(uv)
	st.add_vertex(Vector3(a.x, a.y, 0))
	st.set_color(col)
	st.set_uv(uv)
	st.add_vertex(Vector3(b.x, b.y, 0))
	st.set_color(col)
	st.set_uv(uv)
	st.add_vertex(Vector3(c.x, c.y, 0))

func build() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)

	# --- Hull shape (rounded pointy ends, straight sides) ---
	var hl: float = hull_len * 0.5
	var hw: float = hull_wid * 0.5
	var point_len: float = hl * HULL_POINT_FRAC
	var side_len: float = hl * HULL_SIDE_FRAC

	# Points: bow, bow-side, mid-side, stern-side, stern
	var pts: Array[Vector2] = [
		Vector2(0, -hl), # bow (top)
		Vector2(hw, -side_len), # bow right
		Vector2(hw, side_len), # stern right
		Vector2(0, hl), # stern (bottom)
		Vector2(-hw, side_len), # stern left
		Vector2(-hw, -side_len), # bow left
	]
	# Triangulate hull (fan from center)
	for i in range(pts.size()):
		var a = pts[i]
		var b = pts[(i + 1) % pts.size()]
		var mid = (a + b) * 0.5
		_add_flat_tri(st, Vector2.ZERO, a, b, mid, HULL_ALPHA)

	# --- Deck (flat, visually distinct, lighter) ---
	var deck_inset: float = 0.18
	var deck_pts: Array[Vector2] = []
	for p in pts:
		deck_pts.append(p * (1.0 - deck_inset))
	for i in range(deck_pts.size()):
		var a = deck_pts[i]
		var b = deck_pts[(i + 1) % deck_pts.size()]
		var mid = (a + b) * 0.25
		_add_flat_tri(st, Vector2.ZERO, a, b, -mid, DECK_ALPHA)

	# --- Main Turret (pyramid, 4 triangles meeting at center) ---
	var turret_w: float = hw * 0.55
	var turret_h: float = hl * 0.16
	var turret_y: float = -hl * 0.18
	var turret_base: Array[Vector2] = [
		Vector2(-turret_w, turret_y - turret_h),
		Vector2(turret_w, turret_y - turret_h),
		Vector2(turret_w, turret_y + turret_h),
		Vector2(-turret_w, turret_y + turret_h)
	]
	var turret_center: Vector2 = Vector2(0, turret_y)
	for i in range(4):
		var a = turret_base[i]
		var b = turret_base[(i + 1) % 4]
		var normal = ((a + b) * 0.5 - turret_center).normalized()
		_add_flat_tri(st, a, b, turret_center, normal, 0.9)

	# --- Main Turret Barrels (thicker, faceted, like tank) ---
	const BARREL_SIDES: int = 4
	var barrel_len: float = hl * 0.25
	var barrel_r: float = turret_w * 0.2
	var barrel_y: float = turret_y - turret_h
	var barrel_x_offsets = [ -barrel_r * 1.8, barrel_r * 1.8 ]
	for x in barrel_x_offsets:
		for s in range(BARREL_SIDES):
			var a0: float = TAU * float(s) / float(BARREL_SIDES)
			var a1: float = TAU * float(s + 1) / float(BARREL_SIDES)
			var p0: Vector2 = Vector2(x, barrel_y) + Vector2(cos(a0), sin(a0)) * barrel_r
			var p1: Vector2 = Vector2(x, barrel_y) + Vector2(cos(a1), sin(a1)) * barrel_r
			var q0: Vector2 = p0 + Vector2(0, -barrel_len)
			var q1: Vector2 = p1 + Vector2(0, -barrel_len)
			var face_n: Vector2 = ((p0 + p1 + q0 + q1) * 0.25 - Vector2(x, barrel_y - barrel_len * 0.5)).normalized()
			_add_flat_tri(st, p0, p1, q1, face_n, 0.85)
			_add_flat_tri(st, p0, q1, q0, face_n, 0.85)

	# --- Command Tower (larger, octagonal base)
	var tower_base_rad: float = hw * 0.35 # larger
	var tower_base_y: float = hl * 0.28 # further back
	var TOWER_SIDES: int = 6
	for i in range(TOWER_SIDES):
		var a0: float = TAU * float(i) / float(TOWER_SIDES)
		var a1: float = TAU * float(i + 1) / float(TOWER_SIDES)
		var v0: Vector2 = Vector2(cos(a0), sin(a0)) * tower_base_rad + Vector2(0, tower_base_y)
		var v1: Vector2 = Vector2(cos(a1), sin(a1)) * tower_base_rad + Vector2(0, tower_base_y)
		var mid: Vector2 = ((v0 + v1) * 0.5).normalized()
		_add_flat_tri(st, Vector2(0, tower_base_y - tower_base_rad * 0.7), v0, v1, mid, 1.0)

	# Side blocks (pyramids, 4 faces like turret)
	var sideblock_w: float = tower_base_rad * 0.6
	var sideblock_h: float = tower_base_rad * 0.32
	for sx in [-1, 1]:
		var base: Array[Vector2] = [
			Vector2(sx * (tower_base_rad + sideblock_w * 0.125), tower_base_y - sideblock_h),
			Vector2(sx * (tower_base_rad + sideblock_w * 1.125), tower_base_y - sideblock_h),
			Vector2(sx * (tower_base_rad + sideblock_w * 1.125), tower_base_y + sideblock_h),
			Vector2(sx * (tower_base_rad + sideblock_w * 0.125), tower_base_y + sideblock_h)
		]
		var center: Vector2 = Vector2(sx * (tower_base_rad + sideblock_w), tower_base_y)
		for i in range(4):
			var a = base[i]
			var b = base[(i + 1) % 4]
			var normal = ((a + b) * 0.5 - center).normalized()
			_add_flat_tri(st, a, b, center, normal, 0.95)

	return st.commit()
