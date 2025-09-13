extends Resource
class_name TankMesh

var TANK_HULL_LEN: float
var TANK_HULL_WID: float
var TANK_TURRET_RAD: float
var TRACK_WID: float
var seg_len: float
const LONG_SEGS: int   = 12      # along barrel
const BARREL_SIDES: int   = 4      # hex-ish cross-section

func _init(p_diameter: float) -> void:
	TANK_HULL_LEN = p_diameter * 0.7
	TANK_HULL_WID = p_diameter * 0.5
	TANK_TURRET_RAD = p_diameter * 0.175
	TRACK_WID = p_diameter * 0.1
	seg_len = p_diameter * 0.55
	
func _add_flat_tri(
		st         : SurfaceTool,
		a          : Vector2, b: Vector2, c: Vector2,
		normal     : Vector2,
		brightness : float) -> void:
	var uv : Vector2 = normal.normalized()
	var col: Color = Color(brightness, brightness, brightness, 1.0)
	st.set_color(col); st.set_uv(uv); st.add_vertex(Vector3(a.x, a.y, 0))
	st.set_color(col); st.set_uv(uv); st.add_vertex(Vector3(b.x, b.y, 0))
	st.set_color(col); st.set_uv(uv); st.add_vertex(Vector3(c.x, c.y, 0))

func _add_track_quad(
		st       : SurfaceTool,
		a        : Vector2, b: Vector2, c: Vector2, d: Vector2,
		side_ix  : float) -> void:
	var col : Color = Color(1.0, 1.0, 1.0, 1.0)
	st.set_color(col); st.set_uv(Vector2(side_ix, 0.0)); st.add_vertex(Vector3(a.x, a.y, 0))
	st.set_color(col); st.set_uv(Vector2(side_ix, 0.0)); st.add_vertex(Vector3(b.x, b.y, 0))
	st.set_color(col); st.set_uv(Vector2(side_ix, 1.0)); st.add_vertex(Vector3(c.x, c.y, 0))
	st.set_color(col); st.set_uv(Vector2(side_ix, 0.0)); st.add_vertex(Vector3(a.x, a.y, 0))
	st.set_color(col); st.set_uv(Vector2(side_ix, 1.0)); st.add_vertex(Vector3(c.x, c.y, 0))
	st.set_color(col); st.set_uv(Vector2(side_ix, 1.0)); st.add_vertex(Vector3(d.x, d.y, 0))

# ────────────────────────────────────────────────────────────────────
func build() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)

	var hull_alpha: float = 0.85
	var outer_hull_alpha: float = 0.5
	var turret_alpha: float = 1.0
	var barrel_alpha: float = 0.925

	# 1. hull – four flat wedges ------------------------------------
	var hl: float = TANK_HULL_LEN * 0.5
	var hw: float = TANK_HULL_WID * 0.5
	var hull: Array[Vector2] = [
		Vector2(-hw, -hl), Vector2(hw, -hl),
		Vector2(hw,  hl),  Vector2(-hw, hl)
	]
	for i: int in range(4):
		var v0: Vector2 = hull[i]
		var v1: Vector2 = hull[(i + 1) % 4]
		var mid: Vector2 = (v0 + v1) * 0.5
		_add_flat_tri(st, Vector2.ZERO, v0, v1, mid, hull_alpha)

	# ── 1b. bevel ring  (outer → inner, brightness 0.70) ───────────────
	var inset_frac : float = 0.15
	var ihl : float = hl * (1.0 - inset_frac)
	var ihw : float = hw * (1.0 - inset_frac)

	var inner : Array[Vector2] = [
		Vector2(-ihw, -ihl), Vector2(ihw, -ihl),
		Vector2(ihw,  ihl),  Vector2(-ihw,  ihl)
	]

	for i: int in range(4):
		var v0 : Vector2 = hull[i]
		var v1 : Vector2 = hull[(i + 1) % 4]
		var w1 : Vector2 = inner[(i + 1) % 4]
		var w0 : Vector2 = inner[i]

		# outward normal ≈ midpoint of outer edge
		var mid : Vector2 = (v0 + v1) * 0.5
		_add_flat_tri(st, v0, v1, w1, mid, outer_hull_alpha)    # quad split into two tris
		_add_flat_tri(st, v0, w1, w0, mid, outer_hull_alpha)
		
	# 2. turret – six wedges ----------------------------------------
	const SIDES: int = 6
	for i: int in range(SIDES):
		var a0: float = TAU * float(i)       / float(SIDES)
		var a1: float = TAU * float(i + 1)   / float(SIDES)
		var v0: Vector2 = Vector2(cos(a0), sin(a0)) * TANK_TURRET_RAD
		var v1: Vector2 = Vector2(cos(a1), sin(a1)) * TANK_TURRET_RAD
		var mid: Vector2 = (v0 + v1) * 0.5
		_add_flat_tri(st, Vector2.ZERO, v0, v1, mid, turret_alpha)

	# 3. barrel – 6×3 facets like the old CPU path ------------------
	
	var half_w : float
	for s: int in range(LONG_SEGS):
		if s <= 3:
			half_w = TANK_TURRET_RAD * 0.4
		elif s < LONG_SEGS-1 and s > LONG_SEGS-4:
			half_w = TANK_TURRET_RAD * 0.35
		elif s == LONG_SEGS-1:
			half_w = TANK_TURRET_RAD * 0.4
		else:
			half_w = TANK_TURRET_RAD * 0.3
		var t0: float =  seg_len * float(s)        / float(LONG_SEGS)
		var t1: float =  seg_len * float(s + 1)    / float(LONG_SEGS)
		for k: int in range(BARREL_SIDES):
			var u0: float = -1.0 +  2.0 * float(k)       / float(BARREL_SIDES)
			var u1: float = -1.0 +  2.0 * float(k + 1)   / float(BARREL_SIDES)
			var l0: Vector2 = Vector2(u0 * half_w, -t0)
			var r0: Vector2 = Vector2(u1 * half_w, -t0)
			var r1: Vector2 = Vector2(u1 * half_w, -t1)
			var l1: Vector2 = Vector2(u0 * half_w, -t1)
			var u_mid: float = (u0 + u1) * 0.5
			var face_n: Vector2 = Vector2(u_mid, -0.30).normalized()
			_add_flat_tri(st, l0, r0, r1, face_n, barrel_alpha)
			_add_flat_tri(st, l0, r1, l1, face_n, barrel_alpha)

	# 4. tracks – one long quad each side (UV.x = ±2) ---------------
	var th: float = TRACK_WID * 0.5
	for side_val: int in [-1, 1]:
		var off: float = side_val * (TANK_HULL_WID * 0.5 + th)
		var a: Vector2 = Vector2(off - th * side_val,  hl)
		var b: Vector2 = Vector2(off + th * side_val,  hl)
		var c: Vector2 = Vector2(off + th * side_val, -hl)
		var d: Vector2 = Vector2(off - th * side_val, -hl)
		_add_track_quad(st, a, b, c, d, float(side_val) * 2.0)

	return st.commit()
