extends VehicleMeshBuilder
class_name TrainCartMeshBuilder

const BODY_ALPHA:		float = 0.85		# same brightness as loco hull
const RECT_SIDES:		int   = 4			# just a box

var half_len:	float
var half_wid:	float

func _init(p_diameter: float) -> void:
	super(p_diameter)							# stores base_diameter
	half_len = p_diameter * 0.5					# cart length  = 1×diameter
	half_wid = p_diameter * 0.25				# width/2 	   = 0.25×diameter

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

func build() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)

	var verts: Array[Vector2] = [
		Vector2(-half_wid, -half_len), Vector2(half_wid, -half_len),
		Vector2(half_wid,  half_len), Vector2(-half_wid,  half_len)
	]
	for i: int in range(RECT_SIDES):
		var a: Vector2 = verts[i]
		var b: Vector2 = verts[(i + 1) % RECT_SIDES]
		var mid: Vector2 = (a + b) * 0.5
		_add_flat_tri(st, Vector2.ZERO, a, b, mid, BODY_ALPHA)
	return st.commit()
