extends Node2D
class_name PolygonLayer1

const MAX_POLY_POINTS: int = 1024

var _outline_nodes: Dictionary = {} # Dictionary[Area, Array[Line2D]]
var _outline_clip_shader: Shader = null

# Mesh batching
var _fill_mesh_instance: MeshInstance2D
var _fill_mesh: ArrayMesh

# Static texture tinting with hue preservation - separate meshes per player
var _tinted_texture_mesh_instances: Dictionary = {} # Dictionary[int, MeshInstance2D]
var _tinted_texture_meshes: Dictionary = {} # Dictionary[int, ArrayMesh]
var _tinted_texture_shader: Shader = null

var _tmp_fill_vertices: PackedVector2Array = PackedVector2Array()
var _tmp_fill_colors: PackedColorArray = PackedColorArray()
var _tmp_fill_indices: PackedInt32Array = PackedInt32Array()

var _tmp_tinted_vertices: Dictionary = {} # Dictionary[int, PackedVector2Array]
var _tmp_tinted_uvs: Dictionary = {} # Dictionary[int, PackedVector2Array]
var _tmp_tinted_indices: Dictionary = {} # Dictionary[int, PackedInt32Array]

var _above_static_texture_z_index: int = 1

func _ready() -> void:
	_fill_mesh_instance = MeshInstance2D.new()
	_fill_mesh = ArrayMesh.new()
	_fill_mesh_instance.mesh = _fill_mesh
	_fill_mesh_instance.z_index = _above_static_texture_z_index # Above static texture tinted
	add_child(_fill_mesh_instance)

# ---------------------------------------------------------------------------
# Static texture tinting shader with hue preservation
# ---------------------------------------------------------------------------

func _get_tinted_texture_shader() -> Shader:
	if _tinted_texture_shader == null:
		var code: String = """
shader_type canvas_item;

uniform sampler2D static_texture;
uniform vec3 player_hue : source_color;
uniform float saturation_boost : hint_range(-1.0, 1.0) = 0.3;
uniform float value_boost : hint_range(-1.0, 1.0) = 0.00;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 texture_color = texture(static_texture, UV);
	
	// Convert texture color to HSV
	vec3 hsv = rgb2hsv(texture_color.rgb);
	
	// Preserve original brightness and saturation, but use player's hue
	// vec3 tinted_hsv = vec3(player_hue.x, hsv.y, hsv.z);
	float new_saturation = clamp(hsv.y + saturation_boost, 0.0, 1.0);
	float new_value = clamp(hsv.z + value_boost, 0.0, 1.0);
	vec3 tinted_hsv = vec3(player_hue.x, new_saturation, new_value);

	// Convert back to RGB
	vec3 tinted_rgb = hsv2rgb(tinted_hsv);
	
	COLOR = vec4(tinted_rgb, texture_color.a);
}
"""
		_tinted_texture_shader = Shader.new()
		_tinted_texture_shader.code = code
	return _tinted_texture_shader

func _create_tinted_texture_material(texture: Texture2D, player_color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _get_tinted_texture_shader()
	mat.set_shader_parameter("static_texture", texture)
	
	# Get the hue from player color
	var player_hue: float = player_color.h
	mat.set_shader_parameter("player_hue", Vector3(player_hue, 0.0, 0.0))
	
	return mat

func _get_or_create_player_mesh(player_id: int) -> Dictionary:
	if not _tinted_texture_mesh_instances.has(player_id):
		var mesh_instance: MeshInstance2D = MeshInstance2D.new()
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh_instance.mesh = mesh
		add_child(mesh_instance)
		
		_tinted_texture_mesh_instances[player_id] = mesh_instance
		_tinted_texture_meshes[player_id] = mesh
		_tmp_tinted_vertices[player_id] = PackedVector2Array()
		_tmp_tinted_uvs[player_id] = PackedVector2Array()
		_tmp_tinted_indices[player_id] = PackedInt32Array()
	
	return {
		"instance": _tinted_texture_mesh_instances[player_id],
		"mesh": _tinted_texture_meshes[player_id],
		"vertices": _tmp_tinted_vertices[player_id],
		"uvs": _tmp_tinted_uvs[player_id],
		"indices": _tmp_tinted_indices[player_id]
	}

# ---------------------------------------------------------------------------
# Outline shader / materials
# ---------------------------------------------------------------------------

func _get_outline_clip_shader() -> Shader:
	if _outline_clip_shader == null:
		var code: String = """
shader_type canvas_item;

const int MAX_POLY_POINTS = {MAX}; // injected
uniform int polygon_point_count = 0;
uniform vec2 polygon_points[MAX_POLY_POINTS];
uniform bool clip_invert = false;

// Composite texture and tint params
uniform sampler2D static_texture;
uniform vec3 player_hue : source_color;
uniform float saturation_boost : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	if (polygon_point_count < 3) {
		discard;
	}
	int crossings = 0;
	vec2 p = local_pos;
	for (int i = 0; i < polygon_point_count; i++) {
		int j = i + 1;
		if (j >= polygon_point_count) {
			j = 0;
		}
		vec2 a = polygon_points[i];
		vec2 b = polygon_points[j];
		bool cond1 = ((a.y > p.y && b.y <= p.y) || (b.y > p.y && a.y <= p.y));
		if (cond1) {
			float denom = (b.y - a.y);
			if (abs(denom) > 0.0) {
				float t = (p.y - a.y) / denom;
				if (t >= 0.0 && t <= 1.0) {
					float x_int = a.x + t * (b.x - a.x);
					if (x_int >= p.x) {
						crossings += 1;
					}
				}
			}
		}
	}
	bool inside = (crossings % 2) == 1;
	if (clip_invert) {
		if (inside) {
			discard;
		}
	} else {
		if (!inside) {
			discard;
		}
	}

	// Sample composite in screen space, apply hue-preserving tint, then multiply by outline color
	vec4 texture_color = texture(static_texture, SCREEN_UV);
	vec3 hsv = rgb2hsv(texture_color.rgb);
	float new_saturation = clamp(hsv.y + saturation_boost, 0.0, 1.0);
	float new_value = (hsv.z+0.5)/4.0;
	vec3 tinted_hsv = vec3(player_hue.x, new_saturation, new_value);
	vec3 tinted_rgb = hsv2rgb(tinted_hsv);
	vec4 tinted = vec4(tinted_rgb, texture_color.a);
	COLOR = tinted * outline_color;
}
""".replace("{MAX}", str(MAX_POLY_POINTS))
		_outline_clip_shader = Shader.new()
		_outline_clip_shader.code = code
	return _outline_clip_shader


func _create_mask_material_for_polygon(poly: PackedVector2Array, clip_invert: bool) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _get_outline_clip_shader()
	_update_mask_material_for_polygon(mat, poly, clip_invert)
	return mat

func _create_outline_tinted_material_for_polygon(
	poly: PackedVector2Array,
	clip_invert: bool,
	player_id: int,
	outline_color: Color
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _get_outline_clip_shader()
	_update_mask_material_for_polygon(mat, poly, clip_invert)
	var draw_component: DrawComponent = get_parent()
	var composite_tex: Texture2D = draw_component.get_tinted_composite_texture()
	if composite_tex != null:
		mat.set_shader_parameter("static_texture", composite_tex)
	var player_color: Color = Global.get_pure_player_color(player_id)
	var player_hue: float = player_color.h
	mat.set_shader_parameter("player_hue", Vector3(player_hue, 0.0, 0.0))
	mat.set_shader_parameter("outline_color", outline_color)
	return mat


func _update_mask_material_for_polygon(mat: ShaderMaterial, poly: PackedVector2Array, clip_invert: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(MAX_POLY_POINTS)
	var count: int = poly.size()
	if count > MAX_POLY_POINTS:
		count = MAX_POLY_POINTS
	var i: int = 0
	while i < count:
		pts[i] = poly[i]
		i += 1
	mat.set_shader_parameter("polygon_point_count", count)
	mat.set_shader_parameter("polygon_points", pts)
	mat.set_shader_parameter("clip_invert", clip_invert)


# ---------------------------------------------------------------------------
# Outline building
# ---------------------------------------------------------------------------

func _make_outline_node(area: Area, areas: Array[Area]) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	
	var min_width: float = DrawComponent.AREA_OUTLINE_THICKNESS * 0.0
	var max_width: float = DrawComponent.AREA_OUTLINE_THICKNESS * 3.5
	var strength: float = area.get_total_area() / (Global.world_size.x * Global.world_size.y)
	var lower_at: float = 0.05
	var scaled: float = strength / lower_at
	if scaled > 1.0:
		scaled = 1.0
	var t: float = pow(scaled, 0.25)
	#var base_width: float = min_width + (max_width - min_width) * t
	var base_width: float = DrawComponent.AREA_OUTLINE_THICKNESS * 3.5
	
	var effective_width: float = base_width * 2.0

	for _is_outer_outer: bool in [false, true]:
		var _lines: Array[Line2D] = []
		var outer_line: Line2D = Line2D.new()
		outer_line.z_index = _above_static_texture_z_index # Above tinted static texture
		outer_line.name = "OuterOutlineArea_%s" % str(area)
		var outer_line_points: PackedVector2Array = GeometryUtils.remove_duplicate_points(area.polygon)
		outer_line.points = outer_line_points
		_lines.append(outer_line)
		
		var inner_ind: int = 0
		for intersection: PackedVector2Array in area.holes:
			var inner_line: Line2D = Line2D.new()
			inner_line.z_index = _above_static_texture_z_index # Above tinted static texture
			inner_line.name = "InnerOutlineArea_%s" % (str(area) + "_" + str(inner_ind))
			var line_points: PackedVector2Array = intersection
			inner_line.points = line_points
			_lines.append(inner_line)
			inner_ind += 1
		
		for line: Line2D in _lines:
			line.closed = true
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.antialiased = true
			
			var outline_color: Color
			if _is_outer_outer:
				line.width = 10.0
				outline_color = Color.BLACK
			else:
				line.width = effective_width
				outline_color = area.color#.lightened(0.5)
			
			outline_color.a = 1.0
		
			line.material = _create_outline_tinted_material_for_polygon(
				area.polygon,
				false,
				area.owner_id,
				outline_color
			)
		lines.append_array(_lines)
	
		
	return lines


func _sync_outline_nodes(areas: Array[Area]) -> void:
	for dead_area: Area in _outline_nodes.keys():
		var dead_lines: Array[Line2D] = _outline_nodes[dead_area]
		for dead_line: Line2D in dead_lines:
			if dead_line != null:
				dead_line.queue_free()
		_outline_nodes.erase(dead_area)

	for area: Area in areas:
		if area.owner_id >= 0:
			var new_lines: Array[Line2D] = _make_outline_node(area, areas)
			for new_line: Line2D in new_lines:
				add_child(new_line)
			_outline_nodes[area] = new_lines


# ---------------------------------------------------------------------------
# Fill batching with ArrayMesh
# ---------------------------------------------------------------------------

func _append_polygon_to_buffers(poly: PackedVector2Array, color: Color) -> void:
	var tri_indices: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tri_indices.is_empty():
		return

	var base_index: int = _tmp_fill_vertices.size()
	_tmp_fill_vertices.append_array(poly)

	# Add one color per vertex in a single pass
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(poly.size())
	var i: int = 0
	while i < poly.size():
		colors[i] = color
		i += 1
	_tmp_fill_colors.append_array(colors)

	# Add indices with offset
	var offset_indices: PackedInt32Array = PackedInt32Array()
	offset_indices.resize(tri_indices.size())
	var j: int = 0
	while j < tri_indices.size():
		offset_indices[j] = base_index + tri_indices[j]
		j += 1
	_tmp_fill_indices.append_array(offset_indices)


func _append_tinted_texture_polygon(poly: PackedVector2Array, texture_size: Vector2, player_id: int) -> void:
	var tri_indices: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tri_indices.is_empty():
		return

	var player_mesh_data: Dictionary = _get_or_create_player_mesh(player_id)
	var vertices: PackedVector2Array = player_mesh_data["vertices"]
	var uvs: PackedVector2Array = player_mesh_data["uvs"]
	var indices: PackedInt32Array = player_mesh_data["indices"]

	var base_index: int = vertices.size()
	vertices.append_array(poly)

	# Add UV coordinates for texture sampling
	var new_uvs: PackedVector2Array = PackedVector2Array()
	new_uvs.resize(poly.size())
	var i: int = 0
	while i < poly.size():
		# Convert world coordinates to UV coordinates
		var uv: Vector2 = poly[i] / texture_size
		new_uvs[i] = uv
		i += 1
	uvs.append_array(new_uvs)

	# Add indices with offset
	var offset_indices: PackedInt32Array = PackedInt32Array()
	offset_indices.resize(tri_indices.size())
	var j: int = 0
	while j < tri_indices.size():
		offset_indices[j] = base_index + tri_indices[j]
		j += 1
	indices.append_array(offset_indices)


func _rebuild_area_fill_mesh(
	areas: Array[Area],
	clicked_original_walkable_areas: Dictionary,
	map: Global.Map
) -> void:
	_tmp_fill_vertices.clear()
	_tmp_fill_colors.clear()
	_tmp_fill_indices.clear()
	
	# Clear all player mesh data
	for player_id: int in _tmp_tinted_vertices.keys():
		_tmp_tinted_vertices[player_id].clear()
		_tmp_tinted_uvs[player_id].clear()
		_tmp_tinted_indices[player_id].clear()

	# Replace draw_colored_polygon(area.polygon, area.color)
	for area: Area in areas:
		if area.owner_id >= 0:
			_append_polygon_to_buffers(area.polygon, area.color)

	# Replace draw_colored_polygon(original_area.polygon, bg_color)
	if map != null:
		var bg_color: Color = Color.BLACK
		bg_color.a = DrawComponent.DARKEN_UNCLICKED_ALPHA
		for original_area: Area in map.original_walkable_areas:
			if not clicked_original_walkable_areas.has(original_area.polygon_id):
				_append_polygon_to_buffers(original_area.polygon, bg_color)

	# Add tinted static textures for player areas
	_append_tinted_static_textures(areas, map)
	
	_commit_area_fill_mesh(areas, clicked_original_walkable_areas, map)


func _append_tinted_static_textures(areas: Array[Area], map: Global.Map) -> void:
	# Get composite texture (bg1 -> river -> bg2) from parent draw component
	var draw_component: DrawComponent = get_parent()
	if draw_component == null:
		return
	if not draw_component.static_textures_generated:
		return
	var composite_tex: Texture2D = draw_component.get_tinted_composite_texture()
	if composite_tex == null:
		return
	var texture_size: Vector2 = composite_tex.get_size()
	# Add tinted composite texture for each player area
	for area: Area in areas:
		if area.owner_id >= 0:
			_append_tinted_texture_polygon(area.polygon, texture_size, area.owner_id)


func _commit_area_fill_mesh(
	areas: Array[Area],
	clicked_original_walkable_areas: Dictionary,
	map: Global.Map
) -> void:
	# Commit regular fill polygons to mesh
	_fill_mesh.clear_surfaces()
	if _tmp_fill_vertices.size() >= 3 and _tmp_fill_indices.size() >= 3:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _tmp_fill_vertices
		arrays[Mesh.ARRAY_COLOR] = _tmp_fill_colors
		arrays[Mesh.ARRAY_INDEX] = _tmp_fill_indices
		_fill_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Commit tinted texture polygons to separate meshes per player
	var draw_component: DrawComponent = get_parent()
	for player_id: int in _tinted_texture_meshes.keys():
		var mesh: ArrayMesh = _tinted_texture_meshes[player_id]
		var vertices: PackedVector2Array = _tmp_tinted_vertices[player_id]
		var uvs: PackedVector2Array = _tmp_tinted_uvs[player_id]
		var indices: PackedInt32Array = _tmp_tinted_indices[player_id]
		
		mesh.clear_surfaces()
		if vertices.size() >= 3 and indices.size() >= 3:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			
			# Apply shader material with composite texture (bg1 -> river -> bg2) and player hue
			var player_color: Color = Global.get_pure_player_color(player_id)
			var composite_tex: Texture2D = draw_component.get_tinted_composite_texture()
			if composite_tex != null:
				var material: ShaderMaterial = _create_tinted_texture_material(composite_tex, player_color)
				_tinted_texture_mesh_instances[player_id].material = material

func _process(_delta: float) -> void:
	var areas: Array[Area] = get_parent().get_parent().areas
	if get_parent().get_parent().game_simulation_component != null:
		areas = get_parent().get_parent().game_simulation_component.areas
	_sync_outline_nodes(areas)

	var clicked_original_walkable_areas: Dictionary
	var map: Global.Map

	if get_parent().get_parent().game_simulation_component != null:
		clicked_original_walkable_areas = get_parent().get_parent().game_simulation_component.clicked_original_walkable_areas
		map = get_parent().get_parent().game_simulation_component.map

	_rebuild_area_fill_mesh(
		areas,
		clicked_original_walkable_areas,
		map
	)
