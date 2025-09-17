extends Node2D
class_name DrawComponent

var font: Font = SystemFont.new()

const MIN_FONT_SIZE: float = 24

# Static textures
var background_texture_1: ViewportTexture = null
var background_texture_2: ViewportTexture = null
var obstacles_texture: ViewportTexture = null

var background_drawer_1: StaticBackgroundDrawer = null
var background_drawer_2: StaticBackgroundDrawer = null
var obstacles_drawer: StaticObstacleDrawer = null


# Viewport containers for rendering static textures
var background_viewport_1: SubViewport = null
var background_viewport_2: SubViewport = null
var obstacles_viewport: SubViewport = null
var water_fill_viewport: SubViewport = null
var water_fill_drawer: WaterFillDrawer = null

# Water mask and sprite
var water_mask_viewport: SubViewport = null
var water_mask_drawer: WaterMaskDrawer = null
@onready var water_sprite: Sprite2D = $WaterSprite
var water_material: ShaderMaterial = null
var water_normal_tex: Texture2D = null
var water_uv_offset_tex: Texture2D = null

# River mask/fill and sprite
var river_mask_viewport: SubViewport = null
var river_mask_drawer: RiverMaskDrawer = null
var river_fill_viewport: SubViewport = null
var river_fill_drawer: RiverFillDrawer = null
@onready var river_sprite: Sprite2D = $RiverSprite
var river_material: ShaderMaterial = null

# Tinted composite of bg1 -> river -> bg2
var tinted_composite_viewport: SubViewport = null
var tinted_bg1_sprite: Sprite2D = null
var tinted_river_sprite: Sprite2D = null
var tinted_bg2_sprite: Sprite2D = null
var tinted_composite_texture: ViewportTexture = null

# Flag to indicate if static textures need to be generated
var static_textures_generated: bool = false

# Highlight textures
var territory_highlight_history: Array = [] # Each element is [area, polygon, remaining_time]
const TERRITORY_HIGHLIGHT_DURATION: float = 0.25
const TERRITORY_ENCIRCLEMENT_HIGHLIGHT_DURATION: float = 1.0
var encirclement_text_history: Array = [] # Each element is [position, text, remaining_time]
const TEXT_RISE_DISTANCE: float = 50.0

@onready var background_layer_1 : BackgroundLayer1 = $BackgroundLayer1
@onready var background_layer_2 : BackgroundLayer2 = $BackgroundLayer2
@onready var polygon_layer1 : PolygonLayer1 = $PolygonLayer1
@onready var polygon_layer2 : PolygonLayer2 = $PolygonLayer2
@onready var polygon_layer3 : PolygonLayer3 = $PolygonLayer3
@onready var unit_layer : UnitLayer = $UnitLayer
@onready var artillery_trail_manager: TrailManager = $ArtilleryTrailManager
@onready var air_layer : AirLayer = $AirLayer
@onready var highlight_manager: HighlightManager = $HighlightManager
@onready var text_overlay_layer: TextOverlayLayer = $TextOverlayLayer
@onready var vehicle_layer: VehicleLayer = $VehicleLayer

@onready var world_environment: WorldEnvironment = $WorldEnvironment


const AREA_OUTLINE_THICKNESS: float = 8.0
const AREA_ADDON_THICKNESS: float = 10.0
const AREA_OUTLINE_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)

const DARKEN_UNCLICKED_ALPHA: float = 0.25

var fog_mask_vp      : SubViewport     # new
var fog_shape_root   : Node2D          # holds Polygon2D children
var fog_rect : ColorRect             # keep reference if you want to fade
const RINGS := [       
	Vector2(8, 1.0),
	#Vector2(48, 0.25),
]
#const RINGS := [  
	#Vector2(16, 0.5),
	#Vector2(13, 0.475),
	#Vector2(32, 0.45),
	#Vector2(40, 0.425),
	#Vector2(48, 0.4),
	#Vector2(56, 0.375),
	#Vector2(64, 0.35), 
	#Vector2(72, 0.325), 
	#Vector2(80, 0.3), 
	#Vector2(88, 0.275),        
	#Vector2(96, 0.25),
	#Vector2(104, 0.22),
	#Vector2(112, 0.2),
	#Vector2(120, 0.175),
	#Vector2(128, 0.15),
	#Vector2(136, 0.125),
	#Vector2(144, 0.1),
	#Vector2(152, 0.075),
	#Vector2(160, 0.05),
	#Vector2(168, 0.025),
#]

func _init_fog_mask() -> void:
	fog_mask_vp = SubViewport.new()
	fog_mask_vp.size               = get_viewport_rect().size
	fog_mask_vp.transparent_bg     = true
	#fog_mask_vp.clear_mode         = SubViewport.CLEAR_MODE_ALWAYS
	fog_mask_vp.disable_3d         = true
	fog_mask_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(fog_mask_vp)                     # hidden off-screen

	fog_shape_root = Node2D.new()
	fog_mask_vp.add_child(fog_shape_root)

func _init_water_layers() -> void:
	water_mask_viewport = SubViewport.new()
	water_mask_viewport.size = get_viewport_rect().size
	water_mask_viewport.transparent_bg = true
	water_mask_viewport.disable_3d = true
	water_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(water_mask_viewport)

	water_mask_drawer = WaterMaskDrawer.new()
	water_mask_viewport.add_child(water_mask_drawer)

	# Lake fill viewport (original style) to be shaded
	water_fill_viewport = SubViewport.new()
	water_fill_viewport.size = get_viewport_rect().size
	water_fill_viewport.transparent_bg = true
	water_fill_viewport.disable_3d = true
	water_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(water_fill_viewport)

	water_fill_drawer = WaterFillDrawer.new()
	water_fill_viewport.add_child(water_fill_drawer)

	# River viewports and sprite
	river_mask_viewport = SubViewport.new()
	river_mask_viewport.size = get_viewport_rect().size
	river_mask_viewport.transparent_bg = true
	river_mask_viewport.disable_3d = true
	river_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(river_mask_viewport)

	river_mask_drawer = RiverMaskDrawer.new()
	river_mask_viewport.add_child(river_mask_drawer)

	river_fill_viewport = SubViewport.new()
	river_fill_viewport.size = get_viewport_rect().size
	river_fill_viewport.transparent_bg = true
	river_fill_viewport.disable_3d = true
	river_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(river_fill_viewport)

	river_fill_drawer = RiverFillDrawer.new()
	river_fill_viewport.add_child(river_fill_drawer)

	river_sprite.centered = false
	water_sprite.centered = false

	water_material = ShaderMaterial.new()
	water_material.shader = load("res://water_wave.gdshader")
	water_normal_tex = load("res://textures/water_normal.png")
	water_uv_offset_tex = load("res://textures/water_uv_offset.png")
	if water_normal_tex != null:
		water_material.set_shader_parameter("water_normal_tex", water_normal_tex)
	else:
		water_material.set_shader_parameter("water_normal_tex", Texture2D.new())
	if water_uv_offset_tex != null:
		water_material.set_shader_parameter("texture_offset_uv", water_uv_offset_tex)
	else:
		water_material.set_shader_parameter("texture_offset_uv", Texture2D.new())
	water_sprite.material = water_material

	river_material = ShaderMaterial.new()
	river_material.shader = load("res://water_wave.gdshader")
	if water_normal_tex != null:
		river_material.set_shader_parameter("water_normal_tex", water_normal_tex)
	else:
		river_material.set_shader_parameter("water_normal_tex", Texture2D.new())
	if water_uv_offset_tex != null:
		river_material.set_shader_parameter("texture_offset_uv", water_uv_offset_tex)
	else:
		river_material.set_shader_parameter("texture_offset_uv", Texture2D.new())
	river_sprite.material = river_material

func _ready() -> void:
	# Create the viewports for static textures
	background_viewport_1 = SubViewport.new()
	background_viewport_2 = SubViewport.new()
	obstacles_viewport = SubViewport.new()
	# Configure viewports
	for viewport in [background_viewport_1, background_viewport_2, obstacles_viewport]:
		viewport.size = get_viewport_rect().size
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		
	# Add viewports as children
	add_child(background_viewport_1)
	add_child(background_viewport_2)
	add_child(obstacles_viewport)
	
	# Add drawing nodes to viewports
	background_drawer_1 = StaticBackgroundDrawer.new()
	background_drawer_1.before_rivers = true
	background_drawer_2 = StaticBackgroundDrawer.new()
	background_drawer_2.before_rivers = false

	obstacles_drawer = StaticObstacleDrawer.new()
	
	background_viewport_1.add_child(background_drawer_1)
	background_viewport_2.add_child(background_drawer_2)
	obstacles_viewport.add_child(obstacles_drawer)

	_init_fog_mask()
	_create_fog_overlay()
	_init_water_layers()
	_init_tinted_composite_viewport()

func _update_fog_mask() -> void:
	# 1. clear previous polygons
	for c in fog_shape_root.get_children():
		c.queue_free()

	# 2. draw current player territory as white
	var areas: Array[Area] = []
	if get_parent().game_simulation_component != null:
		areas = get_parent().game_simulation_component.areas
	else:
		areas = get_parent().areas
	for area: Area in areas:
		if area.owner_id < 0:
			continue
		if area.polygon.size() < 3:
			continue
		var p := Polygon2D.new()
		p.polygon = area.polygon           # world coords already
		p.color   = Color.WHITE
		fog_shape_root.add_child(p)

		for r in RINGS:
			for ring in Geometry2D.offset_polygon(
				area.polygon,
				 r.x,
				Geometry2D.JOIN_ROUND
			):
				var halo := Polygon2D.new()
				halo.polygon = ring
				# Use subtract blend mode for clockwise polygons (holes)
				if Geometry2D.is_polygon_clockwise(ring):
					halo.color = Color.WHITE
					var material := CanvasItemMaterial.new()
					material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
					halo.material = material
				else:
					halo.color = Color(1,1,1, clamp(r.y*2, 0, 1))
				fog_shape_root.add_child(halo)

	# 3. ask the VP to redraw (UPDATE_ALWAYS already, but OK)
	fog_mask_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _create_fog_overlay() -> void:
	fog_rect = ColorRect.new()
	fog_rect.color        = Color(0,0,0,0)         # actual dim in shader
	fog_rect.size         = get_viewport_rect().size
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_rect.z_index = 1
	add_child(fog_rect)                             # after map nodes!

	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
		shader_type canvas_item;

		uniform sampler2D mask_tex;
		uniform float darkness : hint_range(0.0,1.0) = 0.1;

		void fragment () {
			vec2 px = vec2(1.0) / vec2(textureSize(mask_tex,0));

			// 5-tap blur to read neighbouring pixels (keeps your soft halo)
			float m = (
				texture(mask_tex, SCREEN_UV).a +
				texture(mask_tex, SCREEN_UV + vec2( px.x, 0)).a +
				texture(mask_tex, SCREEN_UV + vec2(-px.x, 0)).a +
				texture(mask_tex, SCREEN_UV + vec2(0,  px.y)).a +
				texture(mask_tex, SCREEN_UV + vec2(0, -px.y)).a
			) * 0.2;                     //   1  inside core
									  // 0.1  grey ring #1
									  // 0.02 grey ring #2
									  //   0  far outside

			float fog = darkness * (1.0 - m);   // 0 →  darkness
			// optional ease-in for a softer roll-off
			// fog = darkness * pow(1.0 - m, 2.0);

			COLOR = vec4(0.0, 0.0, 0.0, fog);
		}

	""";
	mat.set_shader_parameter("mask_tex", fog_mask_vp.get_texture())
	fog_rect.material = mat
		

func _physics_process(delta: float) -> void:
	call_deferred("_collect_territories_to_remove", delta)
	_update_fog_mask()
	if water_material != null:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		water_material.set_shader_parameter("u_time", t)
		river_material.set_shader_parameter("u_time", t)
	
	#var system_font = font as SystemFont
	#system_font.font_names = []
	#system_font.font_names = ["monospace"]  # Liberation Sans with fallbacks
	#system_font.font_weight = 600  # Make the font bold (400 = normal, 700 = bold, 900 = extra bold)


func _collect_territories_to_remove(delta: float) -> void:
	if get_parent().game_simulation_component != null:
		var map: Global.Map = get_parent().map
		
		# Update territory highlighting timers
		var territories_to_remove = []
		for i in range(territory_highlight_history.size()):
			var entry = territory_highlight_history[i]
			entry[2] -= delta # Decrease the timer
			if entry[2] <= 0:
				territories_to_remove.append(i)		
		territories_to_remove.sort_custom(func(a, b): return a > b)
		for idx in territories_to_remove:
			territory_highlight_history.remove_at(idx)

		
		
		var newly_expanded_areas: Dictionary[Area, Dictionary] = get_parent().game_simulation_component.newly_expanded_areas
		var newly_encircled_areas: Dictionary[Area, Array] = get_parent().game_simulation_component.newly_encircled_areas
		var newly_expanded_areas_full: Dictionary[Area, Array] = get_parent().game_simulation_component.newly_expanded_areas_full
		# Add new territories to our tracking history
		if TERRITORY_HIGHLIGHT_DURATION > 0.0:
			for area: Area in newly_expanded_areas.keys():
				if area.owner_id != GameSimulationComponent.PLAYER_ID:
					continue
				for original_area in newly_expanded_areas[area]:
					for _new_created_polygon: PackedVector2Array in newly_expanded_areas[area][original_area]:
						var new_created_polygons: Array[PackedVector2Array] = []
						if Geometry2D.triangulate_polygon(_new_created_polygon).size()==0:
							new_created_polygons = Geometry2D.merge_polygons(_new_created_polygon, _new_created_polygon)
						else:
							new_created_polygons.append(_new_created_polygon)
						for new_created_polygon: PackedVector2Array in new_created_polygons:
							if Geometry2D.is_polygon_clockwise(new_created_polygon):
								continue
							highlight_manager.add_highlight(new_created_polygon, area.color, TERRITORY_HIGHLIGHT_DURATION)
				for _new_created_polygon: PackedVector2Array in newly_expanded_areas_full[area]:
					var new_created_polygons: Array[PackedVector2Array] = []
					if Geometry2D.triangulate_polygon(_new_created_polygon).size()==0:
						new_created_polygons = Geometry2D.merge_polygons(_new_created_polygon, _new_created_polygon)
					else:
						new_created_polygons.append(_new_created_polygon)
					for new_created_polygon: PackedVector2Array in new_created_polygons:
						if Geometry2D.is_polygon_clockwise(new_created_polygon):
							continue
						highlight_manager.add_highlight(new_created_polygon, area.color, TERRITORY_HIGHLIGHT_DURATION)
											#territory_highlight_history.append([area, new_created_polygon, TERRITORY_HIGHLIGHT_DURATION, original_area])
						
		
		# For encircled territories, we need to track text information
		for area: Area in newly_encircled_areas.keys():
			for new_created_polygons_pair: Array in newly_encircled_areas[area]:
				var outer_polygon: PackedVector2Array = new_created_polygons_pair[0]
				var inner_polygons: Array = new_created_polygons_pair[1]
				var outer_polygon_area: float = GeometryUtils.calculate_polygon_area(outer_polygon)
				var inner_polygon_area: float = 0.0
				for inner_polygon: PackedVector2Array in inner_polygons:
					inner_polygon_area += GeometryUtils.calculate_polygon_area(inner_polygon)
				var cost: float = max(outer_polygon_area-inner_polygon_area, 0)/(Global.world_size.x*Global.world_size.y)
				
				# Ignore if less than 0.001%
				if cost >= 1.0/UnitLayer.MAX_UNITS/UnitLayer.NUMBER_PER_UNIT:
					var centroid = GeometryUtils.calculate_centroid(outer_polygon)
					encirclement_text_history.append([
						centroid, 
						cost, 
						0.0,  # Initial time (for easing in)
						TERRITORY_ENCIRCLEMENT_HIGHLIGHT_DURATION,  # Remaining time
						TERRITORY_ENCIRCLEMENT_HIGHLIGHT_DURATION,   # Max time
						area.owner_id,
					])
					
				if Geometry2D.triangulate_polygon(outer_polygon).size()==0:
					continue
				# Add the polygon to the highlight history
				territory_highlight_history.append([area, outer_polygon, TERRITORY_ENCIRCLEMENT_HIGHLIGHT_DURATION, null])
		
		# Update text fade timers
		var texts_to_remove = []
		for i in range(encirclement_text_history.size()):
			var entry = encirclement_text_history[i]
			entry[2] += delta  # Increase initial time (for ease in)
			entry[3] -= delta   # Decrease the remaining timer
			
			if entry[3] <= 0:
				texts_to_remove.append(i)
		
		# Remove expired text entries
		texts_to_remove.sort_custom(func(a, b): return a > b)
		for idx in texts_to_remove:
			encirclement_text_history.remove_at(idx)


func spawn_click_ripple(
	original_area: Area,
	click_pos: Vector2,
	map: Global.Map,
) -> void:
	var ripple : RipplePolygon = RipplePolygon.new()
	add_child(ripple)
	ripple.z_index = 2  
	ripple.polygon  = original_area.polygon
	ripple.position = Vector2.ZERO            # same canvas space
	ripple.material.set_shader_parameter(
		"centre", click_pos                   # LOCAL space to this node
	)
	
	var terrain: String = map.terrain_map[original_area.polygon_id]
	var base_color: Color = Global.get_color_for_terrain(terrain)
	
	var offsett_color = Color.DARK_GRAY
	offsett_color.r /= 1.25
	offsett_color.g /= 1.25
	offsett_color.b /= 1.25
	var color: Color = (base_color+offsett_color)/2.0
	color.a = 0.2
	ripple.material.set_shader_parameter("base_colour", color)

	var max_radius: float = 0.0
	# TODO Cache
	for point: Vector2 in original_area.polygon:
		max_radius = max((point-click_pos).length()*1, max_radius)
	ripple.material.set_shader_parameter("max_radius", max_radius)

func generate_static_textures() -> void:
	if static_textures_generated:
		return
	
	var areas: Array[Area] = get_parent().areas
	var map_generator: MapGenerator = get_parent().map_generator
	var map: Global.Map = get_parent().map
	# Simple mode only in CREATE (FINAL uses full rendering)
	var simple: bool = (get_parent().current_mode == Global.GameMode.CREATE)
	#var simple: bool = true
	
	# Set up background drawer
	var background_drawer_1 = background_viewport_1.get_child(0)
	var background_drawer_2 = background_viewport_2.get_child(0)
	background_drawer_1.set_simple(simple)
	background_drawer_1.setup(areas, map_generator, map)
	background_drawer_2.set_simple(simple)
	background_drawer_2.setup(areas, map_generator, map)
	
	# Set up obstacle drawer
	var obstacles_drawer = obstacles_viewport.get_child(0)
	obstacles_drawer.setup(areas, map_generator, map)
	
	# Water mask
	if water_mask_drawer != null:
		water_mask_drawer.setup(areas, map)
		water_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if water_sprite != null:
			water_sprite.texture = water_mask_viewport.get_texture()
			if water_sprite.texture != null:
				water_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# River mask
	if river_mask_drawer != null:
		river_mask_drawer.setup(map)
		river_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if river_sprite != null:
			river_sprite.texture = river_mask_viewport.get_texture()
			if river_sprite.texture != null:
				river_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Water fill
	if water_fill_drawer != null:
		water_fill_drawer.setup(areas, map)
		water_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if water_material != null:
			water_material.set_shader_parameter("water_fill_tex", water_fill_viewport.get_texture())
	# River fill
	if river_fill_drawer != null:
		river_fill_drawer.setup(map)
		river_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if river_material != null:
			river_material.set_shader_parameter("water_fill_tex", river_fill_viewport.get_texture())
	
	# Force viewport updates to generate textures
	background_viewport_1.render_target_update_mode = SubViewport.UPDATE_ONCE
	background_viewport_2.render_target_update_mode = SubViewport.UPDATE_ONCE
	obstacles_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	water_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	river_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	river_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Get textures from viewports
	background_texture_1 = background_viewport_1.get_texture()
	background_texture_2 = background_viewport_2.get_texture()
	obstacles_texture = obstacles_viewport.get_texture()
	static_textures_generated = true

	# Update tinted composite sprites and texture
	if tinted_bg1_sprite != null and background_texture_1 != null:
		tinted_bg1_sprite.texture = background_texture_1
	if tinted_bg2_sprite != null and background_texture_2 != null:
		tinted_bg2_sprite.texture = background_texture_2
	if tinted_river_sprite != null and river_mask_viewport != null:
		tinted_river_sprite.texture = river_mask_viewport.get_texture()
	if tinted_composite_viewport != null:
		tinted_composite_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tinted_composite_texture = tinted_composite_viewport.get_texture()
	

func _draw() -> void:
	# Generate static textures if needed
	if not static_textures_generated:
		generate_static_textures()
	#
	#background_layer_1.queue_redraw()
	#background_layer_2.queue_redraw()
	#polygon_layer1.queue_redraw()
	#polygon_layer2.queue_redraw()
	#polygon_layer3.queue_redraw()
	#text_overlay_layer.queue_redraw()
	#vehicle_layer.queue_redraw()
	#vehicle_layer.vehicle_renderer.queue_redraw()
	#unit_layer.queue_redraw()
	#air_layer.queue_redraw()
	#highlight_manager.queue_redraw()
	#
func prepare_for_new_game() -> void:
	territory_highlight_history.clear()
	encirclement_text_history.clear()
	invalidate_static_textures()

	queue_redraw()
	
func invalidate_static_textures() -> void:
	static_textures_generated = false

func _init_tinted_composite_viewport() -> void:
	# Create a viewport that composes bg1 -> river -> bg2 for tint sampling
	tinted_composite_viewport = SubViewport.new()
	tinted_composite_viewport.size = get_viewport_rect().size
	tinted_composite_viewport.transparent_bg = true
	tinted_composite_viewport.disable_3d = true
	tinted_composite_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(tinted_composite_viewport)

	# Background 1
	tinted_bg1_sprite = Sprite2D.new()
	tinted_bg1_sprite.centered = false
	tinted_composite_viewport.add_child(tinted_bg1_sprite)

	# River (animated) using the same material to share u_time
	tinted_river_sprite = Sprite2D.new()
	tinted_river_sprite.centered = false
	tinted_river_sprite.material = river_material
	tinted_composite_viewport.add_child(tinted_river_sprite)

	# Background 2
	tinted_bg2_sprite = Sprite2D.new()
	tinted_bg2_sprite.centered = false
	tinted_composite_viewport.add_child(tinted_bg2_sprite)

	# Expose texture
	tinted_composite_texture = tinted_composite_viewport.get_texture()

func get_tinted_composite_texture() -> ViewportTexture:
	if tinted_composite_viewport == null:
		return null
	return tinted_composite_viewport.get_texture()
