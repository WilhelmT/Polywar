extends Resource
class_name TrainMesh

const BOILER_LEN_FRAC:     float = 1.0		# boiler length  = 1.0×diameter
const BOILER_RAD_FRAC:     float = 0.25		# boiler radius  = 0.3×diameter
const CAB_LEN_FRAC:        float = 0.35		# cab length     = 0.35×diameter
const CAB_WIDTH_FACTOR:    float = 1.25		# cab wider than boiler
const STACK_RAD_FRAC:      float = 0.12		# funnel radius  = 0.12×diameter

const HULL_ALPHA:   float = 0.75
const CAB_ALPHA:    float = 0.90
const STACK_ALPHA:  float = 1.0
const FRONT_ALPHA:  float = 0.5

const CIRCLE_SIDES: int   = 6				# facets for chimneys etc.

# ────────────────────────────────────────────────────── members ─────────────
var boiler_len:   float
var boiler_rad:   float
var cab_len:      float
var cab_half_wid: float
var stack_rad:    float

# ───────────────────────────────────────────────────── helper ───────────────
func _add_flat_tri(
		st: SurfaceTool,
		a: Vector2, b: Vector2, c: Vector2,
		normal: Vector2,
		brightness: float) -> void:
	var uv: Vector2 = normal.normalized()
	var col: Color  = Color(brightness, brightness, brightness, 1.0)
	st.set_color(col); st.set_uv(uv); st.add_vertex(Vector3(a.x, a.y, 0.0))
	st.set_color(col); st.set_uv(uv); st.add_vertex(Vector3(b.x, b.y, 0.0))
	st.set_color(col); st.set_uv(uv); st.add_vertex(Vector3(c.x, c.y, 0.0))


func _init(p_diameter: float) -> void:
	var loco_total_len: float = p_diameter * Train.LOCOMOTIVE_LEN_FRAC
	boiler_rad = p_diameter * BOILER_RAD_FRAC
	var nose_extra: float = boiler_rad * 0.5
	boiler_len = loco_total_len #- nose_extra

	# make cab occupy the entire rear half of the boiler (example)
	cab_len = boiler_len * CAB_LEN_FRAC            # ← instead of p_diameter * CAB_LEN_FRAC
	cab_half_wid = boiler_rad * CAB_WIDTH_FACTOR
	stack_rad = p_diameter * STACK_RAD_FRAC


# ──────────────────────────────────────────────────── build ─────────────────
func build() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)						# base tint (brightness via per-tri)

	# ---------------------------------------------------------------- boiler -
	var bl: float = boiler_len * 0.5
	var br: float = boiler_rad
	var boiler_rect: Array[Vector2] = [
		Vector2(-br, -bl), Vector2(br, -bl),
		Vector2(br,  bl),  Vector2(-br,  bl)
	]
	for i: int in range(4):
		var v0: Vector2 = boiler_rect[i]
		var v1: Vector2 = boiler_rect[(i + 1) % 4]
		var mid: Vector2 = (v0 + v1) * 0.5
		_add_flat_tri(st, Vector2.ZERO, v0, v1, mid, HULL_ALPHA)

	# --------------------------------------------------------------- cab cube -
	var cab_half: float = cab_len * 0.5
	var cab_y: float    =  bl - cab_half				# cab centre (rear of boiler)
	var cw: float       =  cab_half_wid
	var cab: Array[Vector2] = [
		Vector2(-cw, cab_y - cab_half), Vector2(cw, cab_y - cab_half),
		Vector2(cw,  cab_y + cab_half), Vector2(-cw, cab_y + cab_half)
	]
	for i: int in range(4):
		var v0c: Vector2 = cab[i]
		var v1c: Vector2 = cab[(i + 1) % 4]
		var midc: Vector2 = (v0c + v1c) * 0.5
		_add_flat_tri(st, Vector2.ZERO, v0c, v1c, midc, CAB_ALPHA)

	# ---------------------------------------------------------- front wedge  -
	var nose: Vector2   = Vector2(0.0, -bl - br * 0.5)	# cow-catcher tip
	_add_flat_tri(st, boiler_rect[0], boiler_rect[1], nose,
				  Vector2(0.0, -1.0), FRONT_ALPHA)

	# ------------------------------------------------------------- chimney  -
	var stack_centre: Vector2 = Vector2(0.0, -bl * 0.4)	# forward third
	for i: int in range(CIRCLE_SIDES):
		var a0: float = TAU * float(i)     / float(CIRCLE_SIDES)
		var a1: float = TAU * float(i + 1) / float(CIRCLE_SIDES)
		var v0s: Vector2 = stack_centre + Vector2(cos(a0), sin(a0)) * stack_rad
		var v1s: Vector2 = stack_centre + Vector2(cos(a1), sin(a1)) * stack_rad
		var mids: Vector2 = (v0s + v1s) * 0.5 - stack_centre
		_add_flat_tri(st, stack_centre, v0s, v1s, mids, STACK_ALPHA)

	# ---------------------------------------------------------------- return -
	return st.commit()
