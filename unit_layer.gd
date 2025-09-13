extends Node2D
class_name UnitLayer

enum State { SPAWNING, ALIVE, DYING }

# ─────────────── Tunables ───────────────
const slot_reach_time:		float	= 0.5
const spawn_fade_time:		float	= 0.25
const die_fade_time:		float	= 0.25
const max_speed:			float	= 6000.0
const min_speed:			float	= 0.0
const unit_size:			int	= 12
const unit_alpha: float = 1.0#0.75
const HOLDING_SCALE : float = 1.0#sqrt(2.0)
const TRAIL_MINIMUM_LENGTH: float = 0.1
const outline_thickness:	float	= 0.75
const extra_outline_thickness:	float	= 0.5

const MAX_UNITS_DRAW:	int		= 1000


const MAX_UNITS:	int		= 100
const NUMBER_PER_UNIT:	int		= 1000
const POLYLINE_OFFSET:		float	= unit_size*1.25# * 1.125# * 0.75
const use_flags: bool = false  # Toggle between NATO symbols and flags
const HUNGARIAN_MAX_N: int = 24#-1#24

# ─────────────── NATO symbol tuning ───────────────
const SYMBOL_TEXTURE_SIZE: int = unit_size
const FRIENDLY_SCALE: float = 0.40
const ENEMY_SCALE: float = 0.475
const SYMBOL_BASE_LUMA: float = 1.0
const FACE_GRADIENT_STEPS: int = 24
const FACE_CENTER_LIGHTEN: float = 0.5
const FACE_EDGE_DARKEN: float = 0.5

# MultiMesh for GPU instancing with pre-rendered textures
var _friendly_multimesh: MultiMesh
var _enemy_multimesh: MultiMesh

# Pre-rendered textures for NATO symbols or flags (ViewportTexture from SubViewport.get_texture())
var _friendly_texture: Texture2D
var _enemy_texture: Texture2D
#const SHARE_LERP_ALPHA:	float	= 1.0#0.9			# 0→instant share change, 1→frozen
const SLOT_DELTA_FRAC : float = 0.0#125# 0.25 
const SLOT_DELTA : float = 0.5

var _prev_group_share_by_area: Dictionary	= {}	# Area → {original_area: smoothed share}
var _prev_group_slots_by_area : Dictionary = {}   # Area → { group : int }

var _nav_map: RID
var _region_by_area: Dictionary = {}			# Area → RID (NavigationRegion2D)

var _region_to_navigation_layer: Dictionary[RID, int] = {}

var _offset_areas: Dictionary[Area, Array] = {}
var _area_curves: Dictionary = {}


var debug_polylines: Array[PackedVector2Array] = []

# ─────────────── Agent ───────────────
class Agent:
	var area:	Area
	var pos:	Vector2
	var vel:	Vector2	= Vector2.ZERO
	var alpha:	float	= 0.0
	var state:	int		= State.SPAWNING
	var slot:	Vector2	= Vector2.ZERO
	var group:	Area	= null				# NEW: current original_area assignment
	var prev_group : Area = null
	var _path:	PackedVector2Array = PackedVector2Array()
	var holding: bool = false
	var id:		int		= 0					# Unique identifier for trail tracking
	
# ─────────────── State ───────────────
var _agents:			Array[Agent]	= []
var _fake_agents:		Array[Agent]	= []  # Fake units for defensive lines
var _front_by_area:		Dictionary		= {}
@onready var _trail_manager:		TrailManager = $UnitTrailManager

func _ready() -> void:
	_nav_map = get_world_2d().get_navigation_map()
	
	_setup_multimesh()
	
# ─────────────── Helpers ───────────────
func _sim() -> GameSimulationComponent:
	return get_parent().get_parent().game_simulation_component

# ─────────────── MultiMesh Setup ───────────────
func _setup_multimesh() -> void:
	# Pre-render NATO symbols to textures (synchronous like draw_component.gd)
	_create_nato_textures()
	# Create MultiMesh objects using textured quads
	_friendly_multimesh = _create_textured_multimesh()
	_enemy_multimesh = _create_textured_multimesh()
	# Force a redraw now that everything is ready
	queue_redraw()

func _create_textured_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _create_textured_quad_mesh()  # No texture parameter needed
	mm.instance_count = MAX_UNITS_DRAW
	
	# Initialize all instances as transparent
	for i in range(MAX_UNITS_DRAW):
		mm.set_instance_color(i, Color(1,1,1,0))
	
	return mm

func _create_textured_quad_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays : Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Quad vertices (centered at origin, matching unit_size)
	var hw: float = unit_size * 0.5
	var hh: float = unit_size * 0.5
	var vertices := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh),  # Triangle 1
		Vector2(-hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)   # Triangle 2  
	])
	
	# UV coordinates for texture mapping
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),  # Triangle 1
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)   # Triangle 2
	])
	
	# Colors (will be modulated by instance colors)
	var colors := PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE,
		Color.WHITE, Color.WHITE, Color.WHITE
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

func _create_nato_textures() -> void:
	if use_flags:
		print("Creating flag textures (synchronous like draw_component.gd)...")
		_create_flag_textures()
	else:
		print("Creating NATO textures (synchronous like draw_component.gd)...")
		_create_symbol_textures()

func _create_symbol_textures() -> void:
	var texture_size: int = SYMBOL_TEXTURE_SIZE
	
	# Create viewports for rendering (exactly like draw_component.gd pattern)
	var friendly_viewport := SubViewport.new()
	var enemy_viewport := SubViewport.new()
	
	friendly_viewport.size = Vector2i(texture_size, texture_size)
	enemy_viewport.size = Vector2i(texture_size, texture_size)
	friendly_viewport.transparent_bg = true
	enemy_viewport.transparent_bg = true
	
	# Create Controls to draw on (like static_background_drawer.gd)
	var friendly_control := Control.new()
	var enemy_control := Control.new()
	friendly_control.size = Vector2(texture_size, texture_size)
	enemy_control.size = Vector2(texture_size, texture_size)
	
	# Set up draw functions
	friendly_control.draw.connect(_on_draw_symbol.bind(friendly_control, 0, texture_size))
	enemy_control.draw.connect(_on_draw_symbol.bind(enemy_control, 1, texture_size))
	
	# Setup scene tree
	add_child(friendly_viewport)
	add_child(enemy_viewport) 
	friendly_viewport.add_child(friendly_control)
	enemy_viewport.add_child(enemy_control)
	
	# Force rendering (exactly like draw_component.gd)
	friendly_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	enemy_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Get textures directly (synchronous)
	_friendly_texture = friendly_viewport.get_texture()
	_enemy_texture = enemy_viewport.get_texture()
	
	print("NATO textures created: Friendly=", _friendly_texture, " Enemy=", _enemy_texture)

func _create_flag_textures() -> void:
	var texture_size: int = SYMBOL_TEXTURE_SIZE
	
	# Create viewports for rendering
	var friendly_viewport := SubViewport.new()
	var enemy_viewport := SubViewport.new()
	
	friendly_viewport.size = Vector2i(texture_size, texture_size)
	enemy_viewport.size = Vector2i(texture_size, texture_size)
	friendly_viewport.transparent_bg = true
	enemy_viewport.transparent_bg = true
	
	# Create Controls to draw on
	var friendly_control := Control.new()
	var enemy_control := Control.new()
	friendly_control.size = Vector2(texture_size, texture_size)
	enemy_control.size = Vector2(texture_size, texture_size)
	
	# Set up draw functions for flags
	friendly_control.draw.connect(_on_draw_flag.bind(friendly_control, 0, texture_size))
	enemy_control.draw.connect(_on_draw_flag.bind(enemy_control, 1, texture_size))
	
	# Setup scene tree
	add_child(friendly_viewport)
	add_child(enemy_viewport) 
	friendly_viewport.add_child(friendly_control)
	enemy_viewport.add_child(enemy_control)
	
	# Force rendering
	friendly_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	enemy_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Get textures directly (synchronous)
	_friendly_texture = friendly_viewport.get_texture()
	_enemy_texture = enemy_viewport.get_texture()
	
	print("Flag textures created: Friendly=", _friendly_texture, " Enemy=", _enemy_texture)

# Flag drawing function adapted for Control node texture rendering
func _draw_flag_simple(control: Control, owner_id: int, size: int) -> void:
	var c := Vector2(size/2, size/2)  # Center point
	var alpha := 1.0  # Full alpha for texture
	var agent_scale := 1.0  # Full scale
	
	# Calculate flag dimensions
	var hw := size * 0.4 * alpha * agent_scale  # Use similar scaling as NATO symbols
	var hh := size * 0.4 * alpha * agent_scale
	var rect := Rect2(c.x - hw, c.y - hh, hw * 2.0, hh * 2.0)
	
	var value: float = 0.75

	var col: Color = Global.get_vehicle_color(owner_id)
	col.a = alpha
	var outline_col: Color = (3*Color.BLACK+col)/4.0
	outline_col.a = alpha
	var extra_outline_col: Color = outline_col.darkened(0.5)

	# Draw flag stripes
	if owner_id == 0:
		# Ukrainian flag (blue top, yellow bottom)
		var top_col := Color8(0, 87, 183, int(alpha * 255))  # blue
		var bottom_col := Color8(255, 221, 0, int(alpha * 255))  # yellow
		top_col.v = value
		bottom_col.v = value
		control.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5)), top_col, true)
		control.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.5)), bottom_col, true)
	else:
		# Russian flag (white, blue, red thirds)
		var third := rect.size.y / 3.0
		
		var white := Color(1, 1, 1, alpha)
		var blue := Color8(0, 57, 166, int(alpha * 255))
		var red := Color8(213, 43, 30, int(alpha * 255))
		white.v = value
		blue.v = value
		red.v = value
		
		control.draw_rect(Rect2(rect.position, Vector2(rect.size.x, third)), white, true)
		control.draw_rect(Rect2(rect.position + Vector2(0, third), Vector2(rect.size.x, third)), blue, true)
		control.draw_rect(Rect2(rect.position + Vector2(0, third * 2.0), Vector2(rect.size.x, third)), red, true)
	
	# Draw outline
	var outline_compensation: float = size / unit_size
	control.draw_rect(rect, outline_col, false, 2 * outline_thickness * outline_compensation, true)
	control.draw_rect(rect, extra_outline_col, false, 2 * extra_outline_thickness * outline_compensation, true)

func _on_draw_flag(control: Control, owner_id: int, size: int) -> void:
	_draw_flag_simple(control, owner_id, size)

func _on_draw_symbol(control: Control, owner_id: int, size: int) -> void:
	_draw_nato_symbol_simple(control, owner_id, size)

# Exact replica of original _draw_symbol_nato but adapted for Control node
func _draw_nato_symbol_simple(control: Control, owner_id: int, size: int) -> void:
	var c := Vector2(size/2, size/2)  # Center point
	var col := Color(SYMBOL_BASE_LUMA, SYMBOL_BASE_LUMA, SYMBOL_BASE_LUMA, 1.0)
	var alpha := 1.0  # Full alpha
	var agent_scale := 1.0  # Full scale
	
	# ═════════ pre-computed colours (no .darkened(), .lightened()) ═════════
	var body_col: Color = col
	body_col.a = alpha
	var outline_col: Color = (3*Color.BLACK+col)/4.0
	outline_col.a = alpha
	var extra_outline_col: Color = outline_col.darkened(0.5)
	
	var outline_compensation: float = size/unit_size
	# ═════════ friendly – filled rectangle + outline + X ═════════
	if owner_id == 0:
		var scale_factor: float = 0.4
		var hw: float = size * scale_factor * alpha * agent_scale
		var hh: float = size * scale_factor * alpha * agent_scale
		var rect: Rect2 = Rect2(c.x - hw, c.y - hh, hw * 2.0, hh * 2.0)

		# face gradient
		_draw_square_face_gradient(control, rect, body_col)
		control.draw_rect(rect, outline_col, false, outline_thickness*outline_compensation, true)

		# X (2 calls)
		control.draw_line(rect.position, rect.position + rect.size, outline_col, outline_thickness*outline_compensation, true)
		control.draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y),
			  Vector2(rect.position.x + rect.size.x, rect.position.y), outline_col, outline_thickness*outline_compensation, true)
		
		control.draw_rect(rect, extra_outline_col, false, extra_outline_thickness*outline_compensation, true)
		control.draw_line(rect.position, rect.position + rect.size, extra_outline_col, extra_outline_thickness*outline_compensation, true)
		control.draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y),
				  Vector2(rect.position.x + rect.size.x, rect.position.y), extra_outline_col, extra_outline_thickness*outline_compensation, true)

	# ═════════ enemy – diamond + outline + cross ═════════
	else:
		var scale_factor: float = 0.475
		var r: float = size * scale_factor * alpha * agent_scale
		# ♦ centre-relative points (no array dup / append)
		var p0: Vector2 = c + Vector2(0.0, -r)
		var p1: Vector2 = c + Vector2(r, 0.0)
		var p2: Vector2 = c + Vector2(0.0, r)
		var p3: Vector2 = c + Vector2(-r, 0.0)

		var pts: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3])
		_draw_diamond_face_gradient(control, c, r, body_col)
		# inside the enemy branch, after the outline
		var h: float = r * scale_factor			# half-length of the internal lines

		control.draw_polyline(pts + PackedVector2Array([p0]), outline_col, outline_thickness*outline_compensation, true)	# outline
		# diagonal "X" (2 calls)
		control.draw_line(c + Vector2(-h, -h), c + Vector2( h,  h), outline_col, outline_thickness*outline_compensation, true)
		control.draw_line(c + Vector2(-h,  h), c + Vector2( h, -h), outline_col, outline_thickness*outline_compensation, true)

		control.draw_polyline(pts + PackedVector2Array([p0]), extra_outline_col, extra_outline_thickness*outline_compensation, true)	# outline
		# diagonal "X" (2 calls)
		control.draw_line(c + Vector2(-h, -h), c + Vector2( h,  h), extra_outline_col, extra_outline_thickness*outline_compensation, true)
		control.draw_line(c + Vector2(-h,  h), c + Vector2( h, -h), extra_outline_col, extra_outline_thickness*outline_compensation, true)


# ─────────────── Physics tick ───────────────
func _physics_process(delta: float) -> void:
	debug_polylines.clear()

	var sim: Node = _sim()
	if sim == null:
		_agents = []
		_fake_agents = []
		return

	var obstacle_outlines: Array[PackedVector2Array] = []
	for obstacle: Area in sim.map.original_obstacles:
		var obstacle_outline: PackedVector2Array = obstacle.polygon.duplicate()
		obstacle_outline.append(obstacle_outline[0])
		obstacle_outlines.append(obstacle_outline)
	# Refresh navigation for all areas (including obstacles)
	for area: Area in sim.areas:
		if area.owner_id >= 0:
			var traversable_outline: PackedVector2Array = area.polygon.duplicate()
			traversable_outline.append(traversable_outline[0])
			_refresh_navigation_for_area(area, traversable_outline, obstacle_outlines)
	
	_sync_counts(sim)
	_fade_removed_areas(sim)
	_update_frontlines(sim)
	_assign_slots()
	_store_new_area_curves()
	_integrate_agents(delta)

func _store_new_area_curves() -> void:
	_area_curves.clear()
	for ag: Agent in _agents:
		if not _area_curves.has(ag.area):
			if ag.area.polygon.size() == 0:
				continue
			var curve: Curve2D = Curve2D.new()
			for pt: Vector2 in ag.area.polygon:
				curve.add_point(pt)
			curve.add_point(ag.area.polygon[0])
			_area_curves[ag.area] = curve

# ─────────────── Drawing ───────────────
func _draw() -> void:
	# Update MultiMesh instances instead of individual draw calls
	_update_multimesh_instances()

	# Draw all NATO symbols with perfect antialiasing (only 2 draw calls total!)
	if _friendly_multimesh and _friendly_texture:
		draw_multimesh(_friendly_multimesh, _friendly_texture)
			
	if _enemy_multimesh and _enemy_texture:
		draw_multimesh(_enemy_multimesh, _enemy_texture)

	for debug_polyline: PackedVector2Array in debug_polylines:
		draw_polyline_colors(debug_polyline, [Color.MAGENTA])

func _update_multimesh_instances() -> void:
	var friendly_index: int = 0
	var enemy_index: int = 0
	
	if _friendly_multimesh == null: return
	
	# Clear all instances first
	for i in range(MAX_UNITS_DRAW):
		_friendly_multimesh.set_instance_color(i, Color(1,1,1,0))
		_enemy_multimesh.set_instance_color(i, Color(1,1,1,0))
	
	# Update fake agents
	for ag: Agent in _fake_agents:
		assert(ag.alpha == unit_alpha)
		var fake_color: Color = (2*Color.DARK_GRAY+Color.BLUE)/3.0
		fake_color = fake_color.darkened(0.4)
		var indices := _set_multimesh_instance(ag.pos, fake_color, fake_color.a, ag.area.owner_id, ag.holding, friendly_index, enemy_index)
		friendly_index = indices[0]
		enemy_index = indices[1]
	
	# Update real agents  
	for ag: Agent in _agents:
		if ag.alpha > 0.01:
			var agent_color: Color
			if use_flags:
				# For flags, use white tint to preserve original flag colors
				agent_color = (2*Color.WHITE+Global.get_vehicle_color(ag.area.owner_id))/3.0
			else:
				# For NATO symbols, use the vehicle color for tinting
				agent_color = Global.get_vehicle_color(ag.area.owner_id)
			
			# Check if unit's group is in clicked_original_walkable_areas and apply darkening if not
			var final_color: Color = agent_color
			var sim: GameSimulationComponent = _sim()
			if sim != null and ag.group != null:
				if not sim.clicked_original_walkable_areas.has(ag.group.polygon_id):
					# Apply black mask overlay similar to polygon layers
					final_color = final_color.darkened(DrawComponent.DARKEN_UNCLICKED_ALPHA)
			
			var indices := _set_multimesh_instance(ag.pos, final_color, ag.alpha, ag.area.owner_id, ag.holding, friendly_index, enemy_index)
			friendly_index = indices[0]
			enemy_index = indices[1]

func _set_multimesh_instance(
	pos: Vector2,
	col: Color, 
	alpha: float,
	owner_id: int,
	holding: bool,
	friendly_index: int,
	enemy_index: int
) -> Array[int]:
	var agent_scale: float = HOLDING_SCALE if holding else 1.0
	
	# Use the base color to tint the pre-rendered texture
	var tint_color: Color = col
	tint_color.a = alpha
	
	var transform: Transform2D = Transform2D()
	transform = transform.scaled(Vector2(agent_scale, agent_scale))
	transform.origin = pos
	
	assert(friendly_index < MAX_UNITS_DRAW)
	assert(enemy_index < MAX_UNITS_DRAW)
	if owner_id == 0:  # Friendly
		if friendly_index < MAX_UNITS_DRAW:
			_friendly_multimesh.set_instance_transform_2d(friendly_index, transform)
			_friendly_multimesh.set_instance_color(friendly_index, tint_color)
			friendly_index += 1
	else:  # Enemy
		if enemy_index < MAX_UNITS_DRAW:
			_enemy_multimesh.set_instance_transform_2d(enemy_index, transform)
			_enemy_multimesh.set_instance_color(enemy_index, tint_color)
			enemy_index += 1
	
	return [friendly_index, enemy_index]

func _refresh_navigation_for_area(
	area: Area,
	traversable_outline: PackedVector2Array,
	obstacles: Array[PackedVector2Array]
) -> void:
	# 1. Ensure or create the region RID (unchanged)
	var region: RID
	if _region_by_area.has(area):
		region = _region_by_area[area]
	else:
		region = NavigationServer2D.region_create()
		NavigationServer2D.region_set_map(region, _nav_map)
		NavigationServer2D.region_set_enabled(region, true)
		NavigationServer2D.region_set_use_edge_connections(region, true)
		NavigationServer2D.region_set_transform(region, Transform2D.IDENTITY)
		_region_by_area[area] = region

		var navigation_layer: int = int(pow(2,area.owner_id))
		NavigationServer2D.region_set_navigation_layers(region, navigation_layer)
		_region_to_navigation_layer[region] = navigation_layer
		
	# 2. Create source geometry and add your polygon outline
	var source_data := NavigationMeshSourceGeometryData2D.new()
	
	# Player-controlled areas: traversable
	source_data.append_traversable_outlines(
		[
			traversable_outline
		]
	)
	source_data.append_obstruction_outlines(obstacles)

	# 3. Bake into a new NavigationPolygon
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 0.0
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_data)

	# 4. Assign to the region
	NavigationServer2D.region_set_navigation_polygon(region, nav_poly)

# ───────── Agent‑count synch / spawn / kill ─────────
func _sync_counts(sim: GameSimulationComponent) -> void:
	var desired: Dictionary = {}
	var count_per_area: Dictionary = _count_living_agents_per_area()
	for area: Area in sim.areas:
		if area.owner_id >= 0:
			var ideal: float = MAX_UNITS * area.get_strength(
				sim.map,
				sim.areas,
				sim.total_weighted_circumferences,
				sim.base_ownerships,
			)
			var prev_num: int = count_per_area.get(area, 0)
			var num: int = prev_num
			
			const TOTAL_DELTA: int = 1
			var thr: float = TOTAL_DELTA
			var delta: float = ideal - float(prev_num)
			
			if delta >= thr or delta <= -thr:
				num = int(ideal)
				
			if ideal != 0 and prev_num == 0:
				num = int(ideal)
				
			desired[area] = clamp(
				num,
				0,
				MAX_UNITS
			)
			
	var current: Dictionary = {}
	for ag: Agent in _agents:
		if ag.state != State.DYING:
			current[ag.area] = current.get(ag.area, 0) + 1

	for area: Area in desired.keys():
		var diff: int = desired[area] - current.get(area, 0)
		if diff > 0:
			for _i: int in range(diff):
				_spawn_agent(area)
		elif diff < 0:
			_kill_some(area, -diff)


func _spawn_agent(area: Area) -> void:
	var ag: Agent = Agent.new()
	ag.area = area
	ag.pos = GeometryUtils.calculate_centroid(area.polygon)
	#ag.pos  = GeometryUtils.clamp_point_to_polygon(area.polygon, GeometryUtils.calculate_centroid(area.polygon))
	ag.group = null
	ag.id = ag.get_instance_id()
	_agents.append(ag)


func _kill_some(area: Area, n: int) -> void:
	for ag: Agent in _agents:
		if n <= 0:
			break
		if ag.area == area and ag.state == State.ALIVE:
			ag.state = State.DYING
			# Remove trail data for this agent
			if _trail_manager != null:
				_trail_manager.remove_trails(ag.id)
			n -= 1


func _fade_removed_areas(sim: Node) -> void:
	for ag: Agent in _agents:
		if ag.state != State.DYING and ag.area not in sim.areas:
			ag.state = State.DYING
			# Remove trail data for agents from removed areas
			if _trail_manager != null:
				_trail_manager.remove_trails(ag.id)

	# Clean up fake agents for removed areas
	var i: int = 0
	while i < _fake_agents.size():
		var ag: Agent = _fake_agents[i]
		if ag.area not in sim.areas:
			_fake_agents.remove_at(i)
		else:
			i += 1

	for old_area: Area in _region_by_area.keys():
		if old_area not in sim.areas:
			var region: RID = _region_by_area[old_area]
			_region_to_navigation_layer.erase(_region_by_area[old_area])
			_region_by_area.erase(old_area)
			NavigationServer2D.free_rid(region)
			
	
			
# ─────────── Front‑line update (offset & grouped) ───────────
func _update_frontlines(sim: Node) -> void:
	_front_by_area.clear()
	
	_offset_areas.clear()
	for ag: Agent in _agents:
		if not _offset_areas.has(ag.area):
			var area: Area = ag.area
			var unclipped_offset_polygons: Array[PackedVector2Array] = Geometry2D.offset_polygon(
				area.polygon,
				-POLYLINE_OFFSET if area.owner_id != GameSimulationComponent.PLAYER_ID else -POLYLINE_OFFSET*1.0,
				# Use round to avoid jitter, that comes from miter.
				Geometry2D.JOIN_ROUND
			)
			#debug_polylines = unclipped_offset_polygons
			#unclipped_offset_polygons = [GeometryUtils.find_largest_polygon(unclipped_offset_polygons)]
			unclipped_offset_polygons = GeometryUtils.split_into_inner_outer_polygons(unclipped_offset_polygons)[0]
			#var unclipped_offset_polygons: Array[PackedVector2Array] = [area.polygon]
			#var offset_polygons: Array[PackedVector2Array] = unclipped_offset_polygons
		
			#var offset_polygons: Array[PackedVector2Array] = []
			#for unclipped_offset_polygon: PackedVector2Array in unclipped_offset_polygons:
				#offset_polygons.append_array(
					#Geometry2D.intersect_polygons(
						#unclipped_offset_polygon,
						#area.polygon
					#)
				#)
			#offset_polygons = GeometryUtils.split_into_inner_outer_polygons(offset_polygons)[0]
			
			var offset_polygons: Array[PackedVector2Array] = unclipped_offset_polygons
			
			#var curves: Array[Curve2D] = []
			#for offset_polygon: PackedVector2Array in offset_polygons:
				#var curve: Curve2D = Curve2D.new()
				##curve.bake_interval = 1
				#for point: Vector2 in offset_polygon:
					#curve.add_point(point)
				#curve.add_point(offset_polygon[0])
				#curves.append(curve)
			
			_offset_areas[area] = offset_polygons
			
	for area: Area in sim.newly_expanded_polylines.keys():
		if not _offset_areas.has(area):
			continue
		var offset_polygons: Array[PackedVector2Array] = _offset_areas[area]

		var dict_groups: Dictionary = {}
		#  weight for holding segments is stored per-entry → placeholder 0.0 here
		var sources: Array = [
			{ "map": sim.newly_expanded_polylines, "weight": 1.0 },
			{ "map": sim.newly_retracting_polylines, "weight": 1.0 },
			{ "map": sim.newly_holding_polylines,  "weight": 1.0 },
		]
		for src_item: Dictionary in sources:
			var group_map: Dictionary = src_item["map"]
			var weight: float = src_item["weight"]
			if group_map.has(area) == false:
				continue
				
			for original_area: Area in group_map[area].keys():
				var segs_list: Array = dict_groups.get(original_area, [])
				
				for entry in group_map[area][original_area]:
					var pl: PackedVector2Array
					var eff_weight: float

					if entry is Dictionary:
						pl = entry["pl"]
						eff_weight = float(entry["weight"])
					else:
						pl = entry							# legacy / expanded case
						eff_weight = weight

					if pl.size() < 2:
						continue
						
					var clamped_offset_pl: PackedVector2Array = PackedVector2Array()
					
					for point: Vector2 in pl:
						var closest_point: Vector2 = point
						var min_distance: float = INF
						
						for ind: int in offset_polygons.size():
							var offset_polygon: PackedVector2Array = offset_polygons[ind]
							#var curve: Curve2D = curves[ind]
							#var clamped_point: Vector2 = GeometryUtils.clamp_point_to_polygon_with_curve(
								#offset_polygon,
								#point,
								#curve
							#)
							#var clamped_point: Vector2 = GeometryUtils.clamp_point_to_polygon(
								#offset_polygon,
								#point,
								#false
							#)
							var clamped_point: Vector2 = point
							#var clamped_point: Vector2 = GeometryUtils.get_closest_point(
								#point,
								#offset_polygon,
							#)	
							var distance: float = point.distance_to(clamped_point)
							
							if distance < min_distance:
								min_distance = distance
								closest_point = clamped_point
	
						clamped_offset_pl.append(closest_point)
					
					segs_list.append({ "pl": clamped_offset_pl, "weight": eff_weight })
				dict_groups[original_area] = segs_list
		_front_by_area[area] = dict_groups


func _assign_optimal(cost: Array) -> Array[int]:
	# The matrix must be non‑empty and square; keep the same asserts
	var n: int = cost.size()
	assert(n > 0 and cost[0].size() == n)

	if n <= HUNGARIAN_MAX_N:
		return _hungarian(cost)
	else:
		return _greedy_assignment(cost)

func _greedy_assignment(cost: Array) -> Array[int]:
	var n: int = cost.size()

	# Track which columns are already taken
	var col_taken: PackedByteArray = PackedByteArray()
	col_taken.resize(n)
	for j: int in range(n):
		col_taken[j] = false

	# Resulting assignment
	var assign: Array[int] = []
	assign.resize(n)

	for i: int in range(n):
		var best_col: int = -1
		var best_val: float = INF

		for j: int in range(n):
			if col_taken[j] == 0:
				var v: float = cost[i][j]
				if v < best_val:
					best_val = v
					best_col = j

		assert(best_col >= 0)

		assign[i] = best_col
		col_taken[best_col] = true

	return assign
# ─────────────────────────────────────────────
# ▸ Slot assignment  (minimal churn → minimal travel)
#   (now split into helpers for profiling clarity)
# ─────────────────────────────────────────────
func _assign_slots() -> void:
	# Clear existing fake agents since they'll be recreated during assignment
	_fake_agents.clear()

	# Check if any areas have frontlines - if not, clear all groups
	var has_any_frontlines: bool = false
	for area: Area in _front_by_area.keys():
		for group: Area in _front_by_area[area]:
			for fronts: Dictionary in _front_by_area[area][group]:
				if fronts.size() != 0:
					has_any_frontlines = true
					break
	
	if not has_any_frontlines:
		# No frontlines exist, so clear all groups
		for ag in _agents:
			ag.group = null
		return
	
	# 0) remember where everyone was before we start reshuffling
	_store_prev_groups()

	# 0-bis) count living agents per controlled area
	var count_per_area: Dictionary = _count_living_agents_per_area()

	# ─── process one area at a time ───
	for area in count_per_area.keys():
		var needed: int = count_per_area[area]
		if needed <= 0:
			continue

		var groups: Dictionary = _front_by_area.get(area, {})
		if groups.is_empty():
			continue

		# 1) length of frontline in each original-area group
		var group_len_data: Dictionary = _calc_group_lengths(groups)
		var group_len: Dictionary = group_len_data["group_len"]
		var total_len: float = group_len_data["total_len"]
		if total_len == 0.0:
			continue

		# 2) target fractional share
		var target: Dictionary = _calc_target_shares(group_len, total_len, needed)

		# 4) integer slot counts per group, with per-group hysteresis
		var group_slots: Dictionary = _calc_group_slot_counts(area, target, needed)

		# 5–8) agent redistribution & Hungarian assignment
		_distribute_and_assign_agents(area, groups, group_slots)


# ─────────── Helper 0a ───────────
func _store_prev_groups() -> void:
	for ag: Agent in _agents:
		ag.prev_group = ag.group


# ─────────── Helper 0b ───────────
func _count_living_agents_per_area() -> Dictionary:
	var count_per_area: Dictionary = {}
	for ag: Agent in _agents:
		if ag.state != State.DYING:
			count_per_area[ag.area] = count_per_area.get(ag.area, 0) + 1
	return count_per_area


# ─────────── Helper 1 ───────────
func _calc_group_lengths(groups: Dictionary) -> Dictionary:
	var group_len: Dictionary = {}
	var total_len: float = 0.0

	for grp: Area in groups.keys():
		var l: float = 0.0
		for entry: Dictionary in groups[grp]:	# {pl, weight}
			l += _poly_len(entry["pl"]) * entry["weight"]  # Use weight for agent allocation
		if l > 0.0:
			group_len[grp] = l
			total_len += l

	return { "group_len": group_len, "total_len": total_len }


# ─────────── Helper 2 ───────────
func _calc_target_shares(
		group_len: Dictionary,
		total_len: float,
		needed: int
) -> Dictionary:
	var target: Dictionary = {}
	for grp in group_len.keys():
		target[grp] = group_len[grp] / total_len * float(needed)
	return target


func _calc_group_slot_counts(area: Area, smooth: Dictionary, needed: int) -> Dictionary:
	# Previous slot map for hysteresis
	var prev_slots: Dictionary = _prev_group_slots_by_area.get(area, {}) as Dictionary
	
	# Build the ordered list of groups we need to consider
	var slot_grps: Array = smooth.keys() as Array
	for g in prev_slots.keys():
		if slot_grps.has(g) == false:
			slot_grps.append(g)
	
	slot_grps.sort_custom(func(a: Variant, b: Variant) -> bool:
		var av: float = 0.0
		if smooth.has(a):
			av = smooth[a] as float
		var bv: float = 0.0
		if smooth.has(b):
			bv = smooth[b] as float
		return av > bv
	)
	
	# First pass: compute provisional counts with hysteresis
	var group_slots: Dictionary = {}
	var used: int = 0
	
	for grp in slot_grps:
		var prev_num: int = 0
		if prev_slots.has(grp):
			prev_num = prev_slots[grp] as int
		
		var num: int = prev_num
		if smooth.has(grp):
			var ideal: float = 0.0
			ideal = smooth[grp] as float
			
			var thr: float = max(SLOT_DELTA_FRAC * ideal, SLOT_DELTA)
			var delta: float = ideal - float(prev_num)
			
			if delta >= thr or delta <= -thr:
				num = int(ideal)
				
			if ideal != 0 and prev_num == 0:
				num = int(ideal)
		else:
			num = 0 
		
		
		group_slots[grp] = num
		used += num
	
	# ── Fix #1 (refined) ──
	# Remove slots from groups that have *no* frontline geometry
	var groups_dict: Dictionary = _front_by_area.get(area, {}) as Dictionary
	var freed: int = 0
	
	for grp_key in group_slots.keys():
		var geom_list: Array = []
		if groups_dict.has(grp_key):
			geom_list = groups_dict[grp_key] as Array
		if geom_list.is_empty():
			freed += group_slots[grp_key] as int
			group_slots[grp_key] = 0
	used -= freed
	
	# Re-distribute freed slots only among groups that still have geometry
	var remainder: int = needed - used
	if remainder != 0:
		remainder = _balance_remainder(group_slots, smooth, remainder, prev_slots)
	
	# Final safety: geometry-less groups must stay at 0
	for grp_key in group_slots.keys():
		var geom_list: Array = []
		if groups_dict.has(grp_key):
			geom_list = groups_dict[grp_key] as Array
		if geom_list.is_empty():
			group_slots[grp_key] = 0
	
	_prev_group_slots_by_area[area] = group_slots
	return group_slots

# Update _balance_remainder to minimize reallocation from prev_slots, with tiebreaker on smoothed vs quantized target
func _balance_remainder(
		group_slots: Dictionary,
		smooth: Dictionary,
		remainder: int,
		prev_slots: Dictionary
) -> int:
	var slot_grps: Array = smooth.keys()

	while remainder != 0:
		var candidates: Array = []
		for grp_str in slot_grps:
			var grp: Area = grp_str
			var current: int = group_slots.get(grp, 0)
			var prev: int = prev_slots.get(grp, 0)
			var target: float = smooth.get(grp, 0.0)
			# For +1 or -1, compute new diff from prev
			var new_val: int = current + (1 if remainder > 0 else -1)
			if new_val < 0:
				continue
			var diff_prev: float = abs(new_val - prev)
			var diff_target: float = abs(target - float(new_val))
			candidates.append({
				"grp": grp,
				"prev": prev,
				"current": current,
				"target": target,
				"diff_prev": diff_prev,
				"diff_target": diff_target
			})
		# Find min diff_prev
		candidates.sort_custom(func(a, b) -> bool:
			if (
				a["current"] == 0 and a["target"]!=0 and
				(b["current"] != 0 or b["target"]==0)
			):
				return true
			elif (
				b["current"] == 0 and b["target"]!=0 and
				(a["current"] != 0 or a["target"]==0)
			):
				return false
			
			if a["diff_prev"] == b["diff_prev"]:
				# Tiebreaker: minimize diff to smoothed target
				return a["diff_target"] < b["diff_target"]
			return a["diff_prev"] < b["diff_prev"]
		)
		if candidates.size() == 0:
			assert(false)
			return remainder
		var grp_to_adjust: Area = candidates[0]["grp"]
		var current_val: int = group_slots.get(grp_to_adjust, 0)
		if remainder > 0:
			group_slots[grp_to_adjust] = current_val + 1
			remainder -= 1
		else:
			assert(current_val > 0)
			group_slots[grp_to_adjust] = current_val - 1
			remainder += 1
	
	return remainder

# ─────────── Helper 5–8 (main redistribution) ───────────
func _distribute_and_assign_agents(
		area: Area,
		groups: Dictionary,
		group_slots: Dictionary
) -> void:
	# 5) primary rule: keep agents in their current group if possible
	var agents_by_group: Dictionary = {}
	for grp in group_slots.keys():
		agents_by_group[grp] = []
	var surplus: Array = []
	var deficits: Array = []

	for ag: Agent in _agents:
		if ag.area != area or ag.state == State.DYING:
			continue
		if agents_by_group.has(ag.group) and agents_by_group[ag.group].size() < group_slots[ag.group]:
			agents_by_group[ag.group].append(ag)
		else:
			surplus.append(ag)

	for grp: Area in group_slots.keys():
		var missing: int = group_slots[grp] - agents_by_group[grp].size()
		for _i: int in range(missing):
			deficits.append(grp)

	# 6) secondary rule: move surplus to deficits with minimal travel
	if surplus.size() > 0:
		_move_surplus_to_deficits(surplus, deficits, groups, agents_by_group, group_slots)	# ← added arg


	# 7) build slot arrays for each group
	var slots_by_group: Dictionary = _build_slots_for_groups(group_slots, groups)

	# 8) two-stage Hungarian assignment inside each group
	_hungarian_inside_groups(agents_by_group, slots_by_group)

# ─────────── Helper 6a ───────────
func _move_surplus_to_deficits(
		surplus: Array,
		deficits: Array,
		groups: Dictionary,
		agents_by_group: Dictionary,
		group_slots: Dictionary
) -> void:
	var m: int = surplus.size()
	var cost_sd: Array = []
	for i_r: int in range(m):
		var row: Array = []
		for j_c: int in range(m):
			var g_def: Area = deficits[j_c]
			var agent_pos: Vector2 = surplus[i_r].pos
			var target_pos: Vector2 = g_def.center
			
			# Get navigation path distance instead of Euclidean distance
			var path_distance: float = INF
			var region_rid: RID = _region_by_area.get(surplus[i_r].area, RID())
			if region_rid != RID():
				var path: PackedVector2Array = NavigationServer2D.map_get_path(
					_nav_map,
					agent_pos,
					target_pos,
					true,
					_region_to_navigation_layer[region_rid]
				)
				if path.size() >= 2:
					path_distance = 0.0
					for i: int in range(path.size() - 1):
						path_distance += path[i].distance_to(path[i + 1])
				else:
					# Fallback to Euclidean distance if no path found
					path_distance = agent_pos.distance_to(target_pos)
			else:
				# Fallback to Euclidean distance if no region
				path_distance = agent_pos.distance_to(target_pos)
			
			# Add a large penalty if this would move the agent away from their original group
			# This ensures agents stay in their current group when possible
			var group_penalty: float = 0.0
			if group_slots.get(surplus[i_r].prev_group, 0) != 0 and surplus[i_r].prev_group != g_def:
				# Use a very large penalty to make it extremely unlikely for agents to hop groups
				group_penalty = 1.0e12
			
			row.append(path_distance + group_penalty)
		cost_sd.append(row)

	var assign: Array[int] = _assign_optimal(cost_sd)
	
	for i_r: int in range(m):
		var ag_move: Agent = surplus[i_r]
		var grp_new: Area = deficits[assign[i_r]]
		ag_move.group = grp_new
		agents_by_group[grp_new].append(ag_move)

# ───────────────────────────────────────────────────────────────
# Largest‑remainder slot allocator (Hamilton method)
# Replaces the old rounding‑and‑diff logic.
func _build_slots_for_groups(
		group_slots: Dictionary,
		groups: Dictionary
) -> Dictionary:
	var slots_by_group: Dictionary = {}
	
	# Process every frontline group ----------------------------------------
	for grp_key in group_slots.keys():
		slots_by_group[grp_key] = []
		
		var need_g: int = int(group_slots[grp_key])
		if need_g <= 0:
			continue
		
		# Collect usable polylines for this group --------------------------
		var info: Array[Dictionary] = []
		if groups.has(grp_key):
			var entries: Array = groups[grp_key] as Array
			for entry_dict in entries:
				var pl: PackedVector2Array = entry_dict["pl"]
				var len_pl: float = _poly_len(pl)
				
				# Skip degenerate polylines
				if len_pl <= 0.0 or pl.size() < 2:
					continue
				
				var dict_item: Dictionary = {
					"pl": pl,
					"len": len_pl,
					"weight": entry_dict["weight"]
				}
				info.append(dict_item)
		
		if info.is_empty():
			continue
		
		# Calculate both weighted and unweighted totals -------------------------------------------
		var weighted_len_all: float = 0.0
		var unweighted_len_all: float = 0.0
		for it_dict in info:
			var len_val: float = it_dict["len"]
			var w_val: float = it_dict["weight"]
			weighted_len_all += len_val * w_val
			unweighted_len_all += len_val
		
		if weighted_len_all <= 0.0 or unweighted_len_all <= 0.0:
			continue
		

		
		# Calculate visual multiplier: how many total visual slots we need
		var visual_multiplier: float = unweighted_len_all / weighted_len_all if weighted_len_all > 0.0 else 1.0
		var total_visual_slots: int = ceil(float(need_g) * visual_multiplier)
		
		# Dual allocation: real agents (weighted) and total slots (unweighted) ------------------------------------
		var provisional: Array[Dictionary] = []
		var total_real_agents_floor: int = 0
		var total_slots_floor: int = 0
		
		for it_dict in info:
			# Calculate real agent allocation based on weighted lengths
			var exact_agents: float = (it_dict["len"] * it_dict["weight"]) / weighted_len_all * float(need_g)
			var base_agents: int = int(floor(exact_agents))
			var frac_part_agents: float = exact_agents - float(base_agents)
			
			# Calculate total slot allocation based on unweighted lengths
			var exact_slots: float = it_dict["len"] / unweighted_len_all * float(total_visual_slots)
			var base_slots: int = int(floor(exact_slots))
			var frac_part_slots: float = exact_slots - float(base_slots)
			
			var prov_dict: Dictionary = {
				"item": it_dict,
				"agent_count": base_agents,
				"agent_frac": frac_part_agents,
				"slot_count": base_slots,
				"slot_frac": frac_part_slots
			}
			provisional.append(prov_dict)
			total_real_agents_floor += base_agents
			total_slots_floor += base_slots
		
		# Distribute remaining real agents by largest remainders
		var agents_left: int = need_g - total_real_agents_floor
		if agents_left > 0:
			provisional.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if a.has("agent_frac") and b.has("agent_frac"):
					return a["agent_frac"] > b["agent_frac"]
				return false
			)
			
			var idx: int = 0
			while idx < provisional.size() and agents_left > 0:
				provisional[idx]["agent_count"] = int(provisional[idx]["agent_count"]) + 1
				agents_left -= 1
				idx += 1
				if idx >= provisional.size():
					idx = 0
		
		# Distribute remaining total slots by largest remainders
		var slots_left: int = total_visual_slots - total_slots_floor
		if slots_left > 0:
			provisional.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if a.has("slot_frac") and b.has("slot_frac"):
					return a["slot_frac"] > b["slot_frac"]
				return false
			)
			
			var idx: int = 0
			while idx < provisional.size() and slots_left > 0:
				provisional[idx]["slot_count"] = int(provisional[idx]["slot_count"]) + 1
				slots_left -= 1
				idx += 1
				if idx >= provisional.size():
					idx = 0
		
		# Constrain fake agents to only appear on defensive lines (weight < 1.0)
		for prov_dict in provisional:
			var it_dict: Dictionary = prov_dict["item"]
			var agent_count: int = int(prov_dict["agent_count"])
			var total_slots: int = int(prov_dict["slot_count"])
			var weight: float = it_dict["weight"]
			
			if weight >= 1.0:
				# No fake agents for full-weight polylines
				prov_dict["slot_count"] = agent_count
		
		# Generate actual slot positions ----------------------------------
		#print("provisional.size() ", provisional.size())
		for prov_dict in provisional:
			var it_dict: Dictionary = prov_dict["item"]
			var plx: PackedVector2Array = it_dict["pl"]
			#print(plx.size())
			var lpx: float = it_dict["len"]
			var agent_count: int = int(prov_dict["agent_count"])  # Number of real agents this polyline gets
			var total_slots: int = int(prov_dict["slot_count"])   # Total slots this polyline gets
			

			
			if total_slots <= 0:
				continue
			
			var weight: float = it_dict["weight"]
			var holding_flag: bool = weight < 1.0
			
			var local_spacing: float = lpx / float(total_slots)
			var local_pos: float = local_spacing * 0.5	# first slot in the middle
			
			# Ensure we don't assign more real agents than we have total slots
			var real_agents_for_this_polyline: int = min(agent_count, total_slots)
			
			var i_slot: int = 0
			while i_slot < total_slots:
				var is_real_agent_slot: bool = i_slot < real_agents_for_this_polyline
				var new_slot: Dictionary = {
					"pos": _point_along(plx, local_pos),
					"holding": holding_flag,
					"real_agent": is_real_agent_slot
				}
				slots_by_group[grp_key].append(new_slot)
				
				local_pos += local_spacing
				i_slot += 1
		
		# Final safety check - count real agent slots and total slots ----------------------------------------------
		var real_agent_slot_count: int = 0
		var total_slot_count: int = 0
		var expected_real_agents: int = 0
		var expected_total_slots: int = 0
		
		for prov_dict in provisional:
			var agent_count: int = int(prov_dict["agent_count"])
			var total_slots: int = int(prov_dict["slot_count"])
			expected_real_agents += agent_count
			expected_total_slots += total_slots
		
		for slot: Dictionary in (slots_by_group[grp_key] as Array):
			total_slot_count += 1
			if slot["real_agent"]:
				real_agent_slot_count += 1
		

		
		if real_agent_slot_count != expected_real_agents:
			push_warning(
				"Real agent slot count mismatch in group %s: expected %d, got %d" %
				[str(grp_key), expected_real_agents, real_agent_slot_count]
			)
	
	return slots_by_group

# ─────────── Helper 7 ───────────
#func _build_slots_for_groups(
		#group_slots: Dictionary,
		#groups: Dictionary
#) -> Dictionary:
	#var slots_by_group: Dictionary = {}
	#for grp in group_slots.keys():
		#slots_by_group[grp] = []
		#var need_g: int = group_slots[grp]
		#if need_g <= 0:
			#continue
#
		#var info: Array = []
		#for entry: Dictionary in groups[grp]:
			#var pl: PackedVector2Array = entry["pl"]
			#var len_pl: float = _poly_len(pl)
			## Skip polylines that are too short or have insufficient points
			#if len_pl == 0.0 or pl.size() < 2:
				#continue
			#info.append({ "pl": pl, "len": len_pl, "weight": entry["weight"] })
		#if info.is_empty():
			#continue
		#info.sort_custom(func(a, b) -> bool:
			#return a["len"] > b["len"]
		#)
#
		## Calculate total weighted length
		#var weighted_len_all: float = 0.0
		#for it in info:
			#weighted_len_all += it["len"] * it["weight"]
#
		## First pass: proportional slots
		#var slots_per_polyline: Dictionary = {}
		#var total_assigned: int = 0
		#for it in info:
			#var proportion: float = (it["len"] * it["weight"]) / weighted_len_all
			#var polyline_slots: int = int(proportion * need_g)
			#slots_per_polyline[it] = polyline_slots
			#total_assigned += polyline_slots
#
#
#
		## Adjust rounding error with safety checks
		#var diff: int = need_g - total_assigned
		#while diff != 0:
			#var sorted_items: Array = slots_per_polyline.keys()
			#sorted_items.sort_custom(func(a, b) -> bool:
				#var prop_a: float = (a["len"] * a["weight"]) / weighted_len_all
				#var prop_b: float = (b["len"] * b["weight"]) / weighted_len_all
				#var frac_a: float = prop_a * float(need_g) - float(slots_per_polyline[a])
				#var frac_b: float = prop_b * float(need_g) - float(slots_per_polyline[b])
				#if frac_a == 0 and frac_b != 0: 
					#return false
				#elif frac_b == 0 and frac_a != 0:
					#return true
				#elif diff > 0:
					#return frac_a >= frac_b
				#else:
					#return frac_a < frac_b
			#)			
			#var item = sorted_items[0]
			#if diff > 0:
				#slots_per_polyline[item] += 1
				#diff -= 1
			#else:
				#slots_per_polyline[item] -= 1
				#diff += 1
#
		## Second pass: distribute along each polyline
		#for it in info:
			#var plx: PackedVector2Array = it["pl"]
			#var lpx: float = it["len"]
			#assert(slots_per_polyline[it] >= 0)
			#var polyline_slot_count: int = slots_per_polyline[it]
			#if polyline_slot_count <= 0:
				#continue
#
			#var local_spacing: float = lpx / float(polyline_slot_count)
			#var local: float = local_spacing * 0.5
			#for _i: int in range(polyline_slot_count):
				#slots_by_group[grp].append({
					#"pos":		_point_along(plx, local),
					#"holding":	it["weight"] < 1.0
				#})
				#local += local_spacing
#
		## Final safety check
		#var actual_slots: int = slots_by_group[grp].size()
		#assert(actual_slots == need_g)
	#return slots_by_group



# ─────────── Helper 8 ───────────
func _hungarian_inside_groups(
		agents_by_group: Dictionary,
		slots_by_group: Dictionary
) -> void:
	for grp in agents_by_group.keys():
		var ags: Array = agents_by_group[grp]
		var sls: Array = slots_by_group[grp]
		var n_slots: int = sls.size()
		if n_slots == 0:
			continue
		
		# Separate slots into real agent slots and fake agent slots
		var real_agent_slots: Array = []
		var fake_agent_slots: Array = []
		for i: int in range(sls.size()):
			var slot: Dictionary = sls[i]
			if slot["real_agent"]:
				real_agent_slots.append({"slot": slot, "index": i})
			else:
				fake_agent_slots.append({"slot": slot, "index": i})
		
		var n_real_slots: int = real_agent_slots.size()
		if n_real_slots == 0:
			# All slots are fake agent slots - need to get the actual area from agents
			if ags.size() > 0:
				var agent_area: Area = ags[0].area
				for slot_info: Dictionary in fake_agent_slots:
					var slot: Dictionary = slot_info["slot"]
					var fake_agent: Agent = Agent.new()
					fake_agent.area = agent_area
					fake_agent.pos = get_closest_point_to_offset(slot["pos"], fake_agent.area)
					fake_agent.alpha = unit_alpha
					fake_agent.state = State.ALIVE
					fake_agent.holding = slot["holding"]
					fake_agent.group = grp
					_fake_agents.append(fake_agent)
			continue
		
		#assert(ags.size() == n_real_slots)
		# Robust check: handle mismatches gracefully
		if ags.size() != n_real_slots:
			push_warning("Agent count mismatch in group %s: %d real agent slots but %d agents. Adjusting." % [str(grp), n_real_slots, ags.size()])
			# If we have too many agents, truncate the list
			if ags.size() > n_real_slots:
				ags = ags.slice(0, n_real_slots)
			# If we have too few agents, we'll just fill what we can
		
		var agents_to_assign: int = min(ags.size(), n_real_slots)

		# split into incumbents vs entrants
		var incumbents: Array = []
		var entrants: Array = []
		for ag in ags:
			if ag.state == State.DYING: continue
			if ag.prev_group == grp and ag.state != State.SPAWNING:
				incumbents.append(ag)
			else:
				entrants.append(ag)

		# 1) incumbents → Hungarian over real agent slots only (with dummy rows)
		var k_inc: int = min(incumbents.size(), agents_to_assign)
		var cost_inc: Array = []
		for r: int in range(agents_to_assign):
			var row: Array = []
			for c: int in range(agents_to_assign):
				if r < k_inc:
					assert(
						not is_inf(incumbents[r].pos.x) and
						not is_inf(incumbents[r].pos.y) and
						not is_nan(incumbents[r].pos.x) and
						not is_nan(incumbents[r].pos.y)
					)
					row.append(incumbents[r].pos.distance_squared_to(real_agent_slots[c]["slot"]["pos"]))
				else:
					row.append(1.0e12)
			cost_inc.append(row)

		var assign_inc: Array[int]
		if (
			_sim().intersecting_walkable_area_start_of_tick()[grp].has(ags[0].area) and
			_sim().intersecting_walkable_area_start_of_tick()[grp][ags[0].area].size() < 2
		):
			assign_inc = _assign_optimal(cost_inc)
		else:
			assign_inc = _greedy_assignment(cost_inc)

		# reserve chosen real agent slots
		var taken_real: PackedByteArray = PackedByteArray()
		taken_real.resize(agents_to_assign)
		for i: int in range(agents_to_assign):
			taken_real[i] = false

		for r: int in range(k_inc):
			var ag_inc: Agent = incumbents[r]
			var sl_idx: int = assign_inc[r]
			var slot: Dictionary = real_agent_slots[sl_idx]["slot"]
			ag_inc.slot = slot["pos"]
			ag_inc.group = grp
			ag_inc.holding = slot["holding"]
			taken_real[sl_idx] = true

		# 2) entrants → Hungarian on remaining real agent slots
		var remaining_agents: int = agents_to_assign - k_inc
		if entrants.size() > 0 and remaining_agents > 0:
			var free_real_slots: Array = []
			for i_sl: int in range(agents_to_assign):
				if not taken_real[i_sl]:
					free_real_slots.append(real_agent_slots[i_sl])

			var k_ent: int = min(entrants.size(), remaining_agents, free_real_slots.size())
			if k_ent > 0:
				var n_free: int = free_real_slots.size()
				var cost_ent: Array = []
				for r: int in range(n_free):
					var row: Array = []
					for c: int in range(n_free):
						if r < k_ent:
							row.append(entrants[r].pos.distance_squared_to(free_real_slots[c]["slot"]["pos"]))
						else:
							row.append(1.0e12)
					cost_ent.append(row)

				var assign_ent: Array[int]
				if (
					_sim().intersecting_walkable_area_start_of_tick()[grp].has(ags[0].area) and
					_sim().intersecting_walkable_area_start_of_tick()[grp][ags[0].area].size() < 2
				):
					assign_ent = _assign_optimal(cost_ent)
				else:
					assign_ent = _greedy_assignment(cost_ent)
				for r: int in range(k_ent):
					var ag_ent: Agent = entrants[r]
					var sl_idx: int = assign_ent[r]
					var slot: Dictionary = free_real_slots[sl_idx]["slot"]
					ag_ent.slot = slot["pos"]
					ag_ent.group = grp
					ag_ent.holding = slot["holding"]
		
		# 3) Create fake agents for fake agent slots
		if ags.size() > 0:
			var agent_area: Area = ags[0].area
			for slot_info: Dictionary in fake_agent_slots:
				var slot: Dictionary = slot_info["slot"]
				var fake_agent: Agent = Agent.new()
				fake_agent.area = agent_area
				fake_agent.pos = get_closest_point_to_offset(slot["pos"], fake_agent.area)
				fake_agent.alpha = unit_alpha
				fake_agent.state = State.ALIVE
				fake_agent.holding = slot["holding"]
				fake_agent.group = grp
				_fake_agents.append(fake_agent)

# Hungarian implementation (square cost matrix)
func _hungarian(cost: Array) -> Array[int]:
	var n: int = cost.size()
	
	# Assert that cost matrix is valid - all values are real numbers
	assert(n > 0, "Cost matrix must not be empty")
	for i: int in range(n):
		assert(cost[i].size() == n, "Cost matrix must be square")
		for j: int in range(n):
			assert(is_finite(cost[i][j]), "Cost matrix must contain only finite values (not NaN or INF)")
	
	var u: Array[float] = []
	var v: Array[float] = []
	var p: Array[int] = []
	var way: Array[int] = []
	u.resize(n + 1)
	v.resize(n + 1)
	p.resize(n + 1)
	way.resize(n + 1)
	
	for i: int in range(1, n + 1):
		p[0] = i
		var j0: int = 0
		var minv: Array[float] = []
		var used: Array[bool] = []
		minv.resize(n + 1)
		used.resize(n + 1)
		
		for j: int in range(n + 1):
			minv[j] = INF
			used[j] = false
		
		while true:
			used[j0] = true
			var i0: int = p[j0]
			var delta: float = INF
			var j1: int = 0
			
			for j: int in range(1, n + 1):
				if not used[j]:
					var cur: float = cost[i0 - 1][j - 1] - u[i0] - v[j]
					if cur < minv[j]:
						minv[j] = cur
						way[j] = j0
					if minv[j] < delta:
						delta = minv[j]
						j1 = j
			
			for j: int in range(n + 1):
				if used[j]:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			
			j0 = j1
			if p[j0] == 0:
				break
		
		while true:
			var j1: int = way[j0]
			p[j0] = p[j1]
			j0 = j1
			if j0 == 0:
				break
	
	var ans: Array[int] = []
	ans.resize(n)
	for j: int in range(1, n + 1):
		var i: int = p[j]
		ans[i - 1] = j - 1
	
	return ans

# Helper function to check if a value is finite (not NaN or INF)
func is_finite(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	return true


func get_closest_point_to_offset(
	target_pos: Vector2,
	area: Area,
) -> Vector2:
	var closest_point: Vector2
	var min_distance: float = INF
	for offset_polygon: PackedVector2Array in _offset_areas[area]:
		var clamped_point: Vector2 = GeometryUtils.clamp_point_to_polygon(
			offset_polygon,
			target_pos,
			false
		)
		var distance: float = clamped_point.distance_to(target_pos)
		
		if distance < min_distance:
			min_distance = distance
			closest_point = clamped_point
	return closest_point
	
# ─────────── Integration (movement) ───────────
func _integrate_agents(delta: float) -> void:
	var i: int = 0
	while i < _agents.size():
		var ag: Agent = _agents[i]
		# ─── fade‑in / fade‑out handling ───
		if ag.state == State.SPAWNING:
			ag.alpha += delta / spawn_fade_time
			if ag.alpha >= unit_alpha:
				ag.alpha = unit_alpha
				ag.state = State.ALIVE
		elif ag.state == State.DYING:
			ag.alpha -= delta / die_fade_time
			if ag.alpha <= 0.0:
				# Remove trail data for this agent
				if _trail_manager != null:
					_trail_manager.remove_trails(ag.id)
				_agents.remove_at(i)
				continue

		if ag.area.polygon.size() <= 2:
			i += 1
			continue
		
		#ag.pos = get_closest_point_to_offset(ag.pos, ag.area)
		if not GeometryUtils.is_point_in_polygon(ag.pos, ag.area.polygon):
			ag.pos = GeometryUtils.clamp_point_to_polygon_with_curve(ag.area.polygon, ag.pos, _area_curves[ag.area])

		# ─── navigation update (alive only) ───
		if ag.state != State.DYING:
			var target_pos: Vector2 = ag.slot

			target_pos = get_closest_point_to_offset(target_pos, ag.area)

			var region_rid: RID = _region_by_area.get(ag.area, RID())
			if region_rid != RID():
				# Calculate a fresh path every tick
				ag._path = NavigationServer2D.map_get_path(
					_nav_map,
					ag.pos,
					target_pos,
					true,
					_region_to_navigation_layer[_region_by_area[ag.area]]
				)
	
				var dist: float = 0.0
				var prev_pos: Vector2 = ag.pos
				for path_pos: Vector2 in ag._path:
					dist += (path_pos-prev_pos).length()
					prev_pos = path_pos

				if ag._path.size() >= 2:
					var next_pt: Vector2 = ag._path[1]
					var final_pt: Vector2 = ag._path[-1]
					var to_next: Vector2 = next_pt - ag.pos
					var desired_speed: float = dist / slot_reach_time
				
					# Only apply expansion speed boost for offensive lines (not holding/defensive lines)
					if not ag.holding and ag.group != null:
						# TODO use air, borders, min, max
						var expansion_speed: float = Global.get_expansion_speed(
							GameSimulationComponent.EXPANSION_SPEED,
							_sim().get_strength_density(ag.area),
							_sim().map,
							ag.group,
							false,
						)
						#desired_speed = max(desired_speed, 1.0*expansion_speed)
						
						# To get fast but smooth movement close.
						desired_speed = max(desired_speed, 1.0 * expansion_speed * (pow(dist+1, 1.0/2.0)-1))
						# To get fast movement far away.
						desired_speed = max(desired_speed, 0.05 * expansion_speed * dist)
						
					#if desired_speed > max_speed:
						#print(1)
					desired_speed = max(min(max_speed, desired_speed), min_speed)
					
					#var distance_to_goal: float = sqrt((final_pt-ag.pos).length())
					#desired_speed = max(distance_to_goal / delta, desired_speed)
					var desired_vel: Vector2 = to_next.normalized() * desired_speed
					ag.vel = desired_vel
				else:
					ag.vel = Vector2.ZERO

			# Cap absolute speed
			if ag.vel.length() > max_speed:
				ag.vel = ag.vel.normalized() * max_speed

		# ─── apply velocity ───
		var old_pos: Vector2 = ag.pos
		ag.pos += ag.vel * delta
		
		# Add trail segment if agent moved and trail manager exists
		if _trail_manager != null and ag.state != State.DYING and ag.vel.length() >= TRAIL_MINIMUM_LENGTH:
			_trail_manager.add_trail_segment(ag.pos, ag.id, ag.area.owner_id)
		
		#ag.pos = ag._path[-1]
		#ag.pos = GeometryUtils.clamp_point_to_polygon(ag.area.polygon, ag.pos)
		#if not GeometryUtils.is_point_in_polygon(ag.pos, ag.area.polygon):
			#print(ag.pos, ", ",  NavigationServer2D.region_get_closest_point(_region_by_area[ag.area],ag.pos))
			#ag.pos = NavigationServer2D.region_get_closest_point(_region_by_area[ag.area],ag.pos)
		#ag.pos = NavigationServer2D.map_get_closest_point(_region_by_area[ag.area],ag.pos)
		i += 1

# Legacy drawing functions removed - now using MultiMesh GPU instancing	

# ─────────── Drawing helper ───────────
# Draws a miniature flag centred on `c`
#   owner_id == 0 → 🇺🇦  (blue / yellow)
#   owner_id != 0 → 🇷🇺  (white / blue / red)
func _draw_symbol_flag(
		c        : Vector2,
		_col_unused : Color,         # kept for call‑site compatibility
		alpha    : float,
		owner_id : int,
		agent_scale: float,
) -> void:
	var hw := unit_size * 0.5 * alpha * agent_scale
	var hh := unit_size * 0.5 * alpha * agent_scale
	var rect := Rect2(c.x - hw, c.y - hh, unit_size, unit_size)

	var value: float = 0.9
	# Draw stripes -----------------------------------------------------------
	if owner_id == 0:
		# —— Ukrainian flag ——
		var top_col    := Color8(  0, 87, 183, int(alpha * 255))  # blue
		var bottom_col := Color8(255, 221,   0, int(alpha * 255)) # yellow
		top_col.v = value
		bottom_col.v = value
		
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5)),
				  top_col, true)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.5),
						Vector2(rect.size.x, rect.size.y * 0.5)),
				  bottom_col, true)

	else:
		# —— Russian flag ——
		# equal thirds: white, blue, red
		var third := rect.size.y / 3.0

		var white := Color(1, 1, 1, alpha)
		var blue  := Color8(  0, 57,166, int(alpha * 255))
		var red   := Color8(213, 43, 30, int(alpha * 255))
		white.v = value
		blue.v = value
		red.v = value
		
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, third)), white, true)
		draw_rect(Rect2(rect.position + Vector2(0, third),
						Vector2(rect.size.x, third)),                blue,  true)
		draw_rect(Rect2(rect.position + Vector2(0, third * 2.0),
						Vector2(rect.size.x, third)),                red,   true)

	# Outline ---------------------------------------------------------------
	# (drawn last so it's always visible)
	draw_rect(rect, Color.BLACK, false, outline_thickness)

# ─────────── Visual helpers: gradients and highlights ───────────
func _draw_square_face_gradient(control: Control, rect: Rect2, base_col: Color) -> void:
	var steps: int = FACE_GRADIENT_STEPS
	if steps < 1:
		steps = 1
		
	var half_w: float = rect.size.x * 0.5
	var half_h: float = rect.size.y * 0.5
	var max_inset: float = min(half_w, half_h)
	var i: int = 0
	while i <= steps:
		var t: float = float(i) / float(steps)
		var inset: float = max_inset * t
		var inner: Rect2 = Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(2.0*inset, 2.0*inset))
		var col: Color = base_col
		# t=0 is outer edge, t=1 is center
		# So we want to lighten as t approaches 1 (center)
		var center_factor: float = t  # 0 at edge, 1 at center
		var edge_factor: float = 1.0 - t  # 1 at edge, 0 at center
		
		var lighten_amount: float = FACE_CENTER_LIGHTEN * center_factor
		var darken_amount: float = FACE_EDGE_DARKEN * edge_factor
		
		col = col.lightened(lighten_amount)
		col = col.darkened(darken_amount)
		control.draw_rect(inner, col, true, -1, true)
		i += 1

func _draw_diamond_face_gradient(control: Control, center: Vector2, r: float, base_col: Color) -> void:
	var steps: int = FACE_GRADIENT_STEPS
	if steps < 1:
		steps = 1
	var i: int = 0
	while i <= steps:
		var t: float = float(i) / float(steps)
		var rr: float = r * (1.0 - 0.95 * t)
		var p0: Vector2 = center + Vector2(0.0, -rr)
		var p1: Vector2 = center + Vector2(rr, 0.0)
		var p2: Vector2 = center + Vector2(0.0, rr)
		var p3: Vector2 = center + Vector2(-rr, 0.0)
		var pts: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3])
		var col: Color = base_col
		# t=0 is outer edge, t=1 is center
		# So we want to lighten as t approaches 1 (center)
		var center_factor: float = t  # 0 at edge, 1 at center
		var edge_factor: float = 1.0 - t  # 1 at edge, 0 at center
		
		var lighten_amount: float = FACE_CENTER_LIGHTEN * center_factor
		var darken_amount: float = FACE_EDGE_DARKEN * edge_factor
		
		col = col.lightened(lighten_amount)
		col = col.darkened(darken_amount)
		control.draw_polygon(pts, [col])
		i += 1

# ─────────── Geometry helpers ───────────
func _poly_len(pl: PackedVector2Array) -> float:
	var length: float = 0.0
	for i: int in range(pl.size() - 1):
		length += pl[i].distance_to(pl[i + 1])
	return length

func _point_along(pl: PackedVector2Array, d: float) -> Vector2:
	var remaining: float = d
	for i: int in range(pl.size() - 1):
		var seg: float = pl[i].distance_to(pl[i + 1])
		if seg == 0:
			continue
		if remaining <= seg:
			return pl[i].lerp(pl[i + 1], remaining / seg)
		remaining -= seg
	# should not happen
	assert(false)
	return pl[-1]
