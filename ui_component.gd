extends Node2D
class_name UIComponent

# Custom Control class for drawing NATO symbols
class NATOSymbolControl extends Control:
	var owner_id: int = 0
	var symbol_size: float = 48.0
	var outline_thickness: float = 4.0
	var extra_outline_thickness: float = 2.0
	
	func _init(player_id: int):
		owner_id = player_id
		custom_minimum_size = Vector2(symbol_size, symbol_size)
	
	func _draw() -> void:
		var center = custom_minimum_size * 0.5
		var pin_color = Global.get_vehicle_color(owner_id)
		pin_color.a = 1.0
		var outline_col = (3*Color.BLACK + pin_color) / 4.0
		var extra_outline_col = outline_col.darkened(0.5)
		
		if owner_id == 0:
			# Blue/Friendly - square with X
			var half_size = symbol_size * 0.4
			var rect = Rect2(center.x - half_size, center.y - half_size, half_size * 2, half_size * 2)
			
			# Fill and outline
			draw_rect(rect, pin_color, true)
			draw_rect(rect, outline_col, false, outline_thickness)
			
			# X marks
			draw_line(
				Vector2(rect.position.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
				outline_col,
				outline_thickness
			)
			draw_line(
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.position.x, rect.end.y),
				outline_col,
				outline_thickness
			)
			
			# Extra outlines
			draw_rect(rect, extra_outline_col, false, extra_outline_thickness)
			draw_line(
				Vector2(rect.position.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
				extra_outline_col,
				extra_outline_thickness
			)
			draw_line(
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.position.x, rect.end.y),
				extra_outline_col,
				extra_outline_thickness
			)
		else:
			# Red/Enemy - diamond with cross
			var diamond_size = symbol_size
			var h = diamond_size * 0.5
			var v = diamond_size * 0.5
			
			var top = center + Vector2(0, -v)
			var right = center + Vector2(h, 0)
			var bottom = center + Vector2(0, v)
			var left = center + Vector2(-h, 0)
			
			var pts = PackedVector2Array([top, right, bottom, left])
			var closed = pts.duplicate()
			closed.append(pts[0])
			
			# Fill and outline
			draw_polygon(pts, [pin_color])
			draw_polyline_colors(closed, [outline_col], outline_thickness)
			
			# Cross marks
			draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), outline_col, outline_thickness)
			draw_line(right.lerp(bottom, 0.5), top.lerp(left, 0.5), outline_col, outline_thickness)
			
			# Extra outlines
			draw_polyline_colors(closed, [extra_outline_col], extra_outline_thickness)
			draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), extra_outline_col, extra_outline_thickness)
			draw_line(right.lerp(bottom, 0.5), top.lerp(left, 0.5), extra_outline_col, extra_outline_thickness)

# UI Color scheme - Military themed
const UI_COLORS = {
	"bg_primary": Color(0.08, 0.12, 0.15, 0.95),        # Dark blue-gray
	"bg_secondary": Color(0.12, 0.16, 0.20, 0.9),       # Lighter blue-gray
	"accent_blue": Color(0.25, 0.45, 0.75, 1.0),        # Military blue
	"accent_red": Color(0.75, 0.25, 0.25, 1.0),         # Military red
	"accent_gold": Color(0.85, 0.75, 0.35, 1.0),        # Gold accent
	"text_primary": Color(0.95, 0.95, 0.98, 1.0),       # Off-white
	"text_secondary": Color(0.85, 0.85, 0.90, 1.0),     # Light gray
	"button_normal": Color(0.20, 0.25, 0.30, 0.9),      # Button background
	"button_hover": Color(0.25, 0.35, 0.45, 1.0),       # Button hover
	"button_pressed": Color(0.15, 0.20, 0.25, 1.0),     # Button pressed
	"border": Color(0.45, 0.55, 0.65, 0.8),             # Border color
	"success": Color(0.25, 0.65, 0.35, 1.0),            # Success green
	"warning": Color(0.85, 0.45, 0.25, 1.0),            # Warning orange
	"manpower": Color(0.85, 0.85, 0.25, 1.0),           # Manpower yellow
	"airforce": Color(0.25, 0.85, 0.85, 1.0),           # Air force cyan
}

# UI elements
var ui_layer: CanvasLayer
var assign_red_button: Button
var assign_blue_button: Button
var type_territory_button: Button
var type_tank_button: Button
var type_train_button: Button
var type_ship_button: Button
var tank_rotation_button: Button
var vehicle_size_small_button: Button
var vehicle_size_medium_button: Button
var vehicle_size_large_button: Button
var vehicle_size_huge_button: Button
var reset_button: Button
var clear_map_button: Button
var start_new_game_button: Button
var ship_direction_button: Button
var quit_game_button: Button

# Signals for button presses
signal assign_red_pressed
signal assign_blue_pressed
signal type_territory_pressed
signal type_tank_pressed
signal type_train_pressed
signal type_ship_pressed
signal tank_rotation_toggled
signal vehicle_size_small_pressed
signal vehicle_size_medium_pressed
signal vehicle_size_large_pressed
signal vehicle_size_huge_pressed
signal reset_pressed
signal clear_map_pressed
signal start_new_game_pressed
signal ship_direction_toggled
signal map_mode_random_pressed
signal map_mode_create_pressed
signal create_terrain_plains_pressed
signal create_terrain_forest_pressed
signal create_terrain_mountains_pressed
signal create_terrain_lake_pressed
signal create_mode_add_pressed
signal create_mode_move_pressed
signal create_mode_delete_pressed
signal create_mode_paint_pressed
signal finish_map_pressed
signal save_map_pressed
signal load_map_pressed
signal save_map_confirmed(filename: String)
signal load_map_confirmed(filename: String)

var tank_rotations: Array[int] = [45, 135, 225, 315]
var current_tank_rotation_index: int = 0

var simulation_panel: Panel = null
var simulation_date_label: Label = null
var simulation_strength_header: Label = null
var simulation_strength_blue_row: HBoxContainer = null
var simulation_strength_red_row: HBoxContainer = null
var simulation_casualties_header: Label = null
var simulation_casualties_blue_row: HBoxContainer = null
var simulation_casualties_red_row: HBoxContainer = null
var simulation_manpower_header: Label = null
var simulation_manpower_blue_row: HBoxContainer = null
var simulation_manpower_red_row: HBoxContainer = null
var simulation_airforce_header: Label = null
var simulation_airforce_row: HBoxContainer = null

var map_mode_section_label: Label = null
var map_mode_random_button: Button = null
var map_mode_create_button: Button = null
var create_terrain_section_label: Label = null
var create_terrain_plains_button: Button = null
var create_terrain_forest_button: Button = null
var create_terrain_mountains_button: Button = null
var create_terrain_lake_button: Button = null
var create_mode_section_label: Label = null
var create_mode_add_button: Button = null
var create_mode_move_button: Button = null
var create_mode_delete_button: Button = null
var create_mode_paint_button: Button = null
var finish_map_button: Button = null
var save_map_button: Button = null
var load_map_button: Button = null
var save_window: Window = null
var save_line_edit: LineEdit = null
var save_ok_button: Button = null
var save_cancel_button: Button = null
var load_window: Window = null
var load_item_list: ItemList = null
var load_ok_button: Button = null
var load_cancel_button: Button = null

func create_styled_button(text: String, size: Vector2) -> Button:
	var button = Button.new()
	button.set_text(text)
	button.set_size(size)
	
	# Create custom theme for this button
	var theme = Theme.new()
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	
	# Normal state
	style_normal.bg_color = UI_COLORS.button_normal
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = UI_COLORS.border
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	# Hover state
	style_hover.bg_color = UI_COLORS.button_hover
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = UI_COLORS.accent_gold
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	
	# Pressed state
	style_pressed.bg_color = UI_COLORS.button_pressed
	style_pressed.border_width_left = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = UI_COLORS.accent_gold
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.corner_radius_bottom_right = 4
	
	theme.set_stylebox("normal", "Button", style_normal)
	theme.set_stylebox("hover", "Button", style_hover)
	theme.set_stylebox("pressed", "Button", style_pressed)
	theme.set_color("font_color", "Button", UI_COLORS.text_primary)
	theme.set_color("font_hover_color", "Button", UI_COLORS.text_primary)
	theme.set_color("font_pressed_color", "Button", UI_COLORS.text_primary)
	theme.set_font_size("font_size", "Button", 14)
	
	button.set_theme(theme)
	return button

func create_styled_panel() -> Panel:
	var panel = Panel.new()
	var theme = Theme.new()
	var style = StyleBoxFlat.new()
	
	style.bg_color = UI_COLORS.bg_primary
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = UI_COLORS.border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	theme.set_stylebox("panel", "Panel", style)
	panel.set_theme(theme)
	return panel

func create_section_panel(bg_color: Color) -> Panel:
	var panel = Panel.new()
	var theme = Theme.new()
	var style = StyleBoxFlat.new()
	
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = UI_COLORS.border.lightened(0.2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	theme.set_stylebox("panel", "Panel", style)
	panel.set_theme(theme)
	return panel

func create_styled_label(text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func setup_ui(
	current_player: int,
	game_phase,
	current_type: String,
	current_tank_rotation: int,
	current_vehicle_size: String,
	current_ship_direction_index: int = 0
) -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Main panel with improved styling
	var panel = create_styled_panel()
	panel.set_position(Vector2(Global.world_size.x, 0))
	panel.set_size(Vector2(320, 600))
	ui_layer.add_child(panel)
	
	# Create a title header
	var title_label = create_styled_label("COMMAND PANEL", 18, UI_COLORS.accent_gold)
	title_label.set_position(Vector2(Global.world_size.x + 20, 10))
	title_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	title_label.set_size(Vector2(280, 25))
	ui_layer.add_child(title_label)
	
	# Player assignment section
	var player_section_label = create_styled_label("FACTION SELECTION", 12, UI_COLORS.text_secondary)
	player_section_label.set_position(Vector2(Global.world_size.x + 20, 45))
	ui_layer.add_child(player_section_label)
	
	assign_blue_button = create_styled_button("BLUE ALLIANCE", Vector2(135, 35))
	assign_blue_button.set_position(Vector2(Global.world_size.x + 20, 65))
	assign_blue_button.connect("pressed", Callable(self, "_on_assign_blue_pressed"))
	ui_layer.add_child(assign_blue_button)
	
	assign_red_button = create_styled_button("RED COALITION", Vector2(135, 35))
	assign_red_button.set_position(Vector2(Global.world_size.x + 165, 65))
	assign_red_button.connect("pressed", Callable(self, "_on_assign_red_pressed"))
	ui_layer.add_child(assign_red_button)

	# Unit type section
	var type_section_label = create_styled_label("UNIT DEPLOYMENT", 12, UI_COLORS.text_secondary)
	type_section_label.set_position(Vector2(Global.world_size.x + 20, 115))
	ui_layer.add_child(type_section_label)

	type_territory_button = create_styled_button("TERRITORY", Vector2(65, 35))
	type_territory_button.set_position(Vector2(Global.world_size.x + 20, 135))
	type_territory_button.connect("pressed", Callable(self, "_on_type_territory_pressed"))
	ui_layer.add_child(type_territory_button)

	type_tank_button = create_styled_button("ARMOR", Vector2(65, 35))
	type_tank_button.set_position(Vector2(Global.world_size.x + 90, 135))
	type_tank_button.connect("pressed", Callable(self, "_on_type_tank_pressed"))
	ui_layer.add_child(type_tank_button)

	type_train_button = create_styled_button("RAIL", Vector2(65, 35))
	type_train_button.set_position(Vector2(Global.world_size.x + 160, 135))
	type_train_button.connect("pressed", Callable(self, "_on_type_train_pressed"))
	ui_layer.add_child(type_train_button)

	type_ship_button = create_styled_button("NAVAL", Vector2(65, 35))
	type_ship_button.set_position(Vector2(Global.world_size.x + 230, 135))
	type_ship_button.connect("pressed", Callable(self, "_on_type_ship_pressed"))
	ui_layer.add_child(type_ship_button)

	# Unit configuration section
	var config_section_label = create_styled_label("UNIT CONFIGURATION", 12, UI_COLORS.text_secondary)
	config_section_label.set_position(Vector2(Global.world_size.x + 20, 185))
	ui_layer.add_child(config_section_label)

	tank_rotation_button = create_styled_button("BEARING: " + str(current_tank_rotation) + "°", Vector2(280, 35))
	tank_rotation_button.set_position(Vector2(Global.world_size.x + 20, 205))
	tank_rotation_button.connect("pressed", Callable(self, "_on_tank_rotation_toggled"))
	ui_layer.add_child(tank_rotation_button)

	# Vehicle size section
	var size_section_label = create_styled_label("UNIT SIZE", 12, UI_COLORS.text_secondary)
	size_section_label.set_position(Vector2(Global.world_size.x + 20, 255))
	ui_layer.add_child(size_section_label)

	vehicle_size_small_button = create_styled_button("LIGHT", Vector2(135, 35))
	vehicle_size_small_button.set_position(Vector2(Global.world_size.x + 20, 275))
	vehicle_size_small_button.connect("pressed", Callable(self, "_on_vehicle_size_small_pressed"))
	ui_layer.add_child(vehicle_size_small_button)

	vehicle_size_medium_button = create_styled_button("MEDIUM", Vector2(135, 35))
	vehicle_size_medium_button.set_position(Vector2(Global.world_size.x + 165, 275))
	vehicle_size_medium_button.connect("pressed", Callable(self, "_on_vehicle_size_medium_pressed"))
	ui_layer.add_child(vehicle_size_medium_button)

	vehicle_size_large_button = create_styled_button("HEAVY", Vector2(135, 35))
	vehicle_size_large_button.set_position(Vector2(Global.world_size.x + 20, 320))
	vehicle_size_large_button.connect("pressed", Callable(self, "_on_vehicle_size_large_pressed"))
	ui_layer.add_child(vehicle_size_large_button)

	vehicle_size_huge_button = create_styled_button("SUPER-HEAVY", Vector2(135, 35))
	vehicle_size_huge_button.set_position(Vector2(Global.world_size.x + 165, 320))
	vehicle_size_huge_button.connect("pressed", Callable(self, "_on_vehicle_size_huge_pressed"))
	ui_layer.add_child(vehicle_size_huge_button)

	# Ship direction button
	ship_direction_button = create_styled_button("HEADING: 1", Vector2(280, 35))
	ship_direction_button.set_position(Vector2(Global.world_size.x + 20, 205))
	ship_direction_button.connect("pressed", Callable(self, "_on_ship_direction_toggled"))
	ui_layer.add_child(ship_direction_button)

	# Map control section
	var map_section_label = create_styled_label("MAP OPERATIONS", 12, UI_COLORS.text_secondary)
	map_section_label.set_position(Vector2(Global.world_size.x + 20, 375))
	ui_layer.add_child(map_section_label)

	clear_map_button = create_styled_button("CLEAR BATTLEFIELD", Vector2(280, 35))
	clear_map_button.set_position(Vector2(Global.world_size.x + 20, 395))
	clear_map_button.connect("pressed", Callable(self, "_on_clear_map_pressed"))
	ui_layer.add_child(clear_map_button)

	reset_button = create_styled_button("GENERATE NEW MAP", Vector2(280, 35))
	reset_button.set_position(Vector2(Global.world_size.x + 20, 440))
	reset_button.connect("pressed", Callable(self, "_on_reset_pressed"))
	ui_layer.add_child(reset_button)

	start_new_game_button = create_styled_button("COMMENCE OPERATIONS", Vector2(280, 45))
	start_new_game_button.set_position(Vector2(Global.world_size.x + 20, 485))
	start_new_game_button.connect("pressed", Callable(self, "_on_start_new_game_pressed"))
	ui_layer.add_child(start_new_game_button)

	# --- Create Mode Controls (placed under existing sections) ---
	map_mode_section_label = create_styled_label("MAP MODE", 12, UI_COLORS.text_secondary)
	map_mode_section_label.set_position(Vector2(Global.world_size.x + 20, 540))
	ui_layer.add_child(map_mode_section_label)

	map_mode_random_button = create_styled_button("RANDOM MAP", Vector2(135, 35))
	map_mode_random_button.set_position(Vector2(Global.world_size.x + 20, 560))
	map_mode_random_button.connect("pressed", Callable(self, "_on_map_mode_random_pressed"))
	ui_layer.add_child(map_mode_random_button)

	map_mode_create_button = create_styled_button("CREATE MAP", Vector2(135, 35))
	map_mode_create_button.set_position(Vector2(Global.world_size.x + 165, 560))
	map_mode_create_button.connect("pressed", Callable(self, "_on_map_mode_create_pressed"))
	ui_layer.add_child(map_mode_create_button)

	create_terrain_section_label = create_styled_label("CREATE TERRAIN", 12, UI_COLORS.text_secondary)
	create_terrain_section_label.set_position(Vector2(Global.world_size.x + 20, 610))
	ui_layer.add_child(create_terrain_section_label)

	create_terrain_plains_button = create_styled_button("PLAINS", Vector2(65, 35))
	create_terrain_plains_button.set_position(Vector2(Global.world_size.x + 20, 630))
	create_terrain_plains_button.connect("pressed", Callable(self, "_on_create_terrain_plains_pressed"))
	ui_layer.add_child(create_terrain_plains_button)

	create_terrain_forest_button = create_styled_button("FOREST", Vector2(65, 35))
	create_terrain_forest_button.set_position(Vector2(Global.world_size.x + 90, 630))
	create_terrain_forest_button.connect("pressed", Callable(self, "_on_create_terrain_forest_pressed"))
	ui_layer.add_child(create_terrain_forest_button)

	create_terrain_mountains_button = create_styled_button("MOUNTAINS", Vector2(95, 35))
	create_terrain_mountains_button.set_position(Vector2(Global.world_size.x + 160, 630))
	create_terrain_mountains_button.connect("pressed", Callable(self, "_on_create_terrain_mountains_pressed"))
	ui_layer.add_child(create_terrain_mountains_button)

	create_terrain_lake_button = create_styled_button("LAKE", Vector2(65, 35))
	create_terrain_lake_button.set_position(Vector2(Global.world_size.x + 260, 630))
	create_terrain_lake_button.connect("pressed", Callable(self, "_on_create_terrain_lake_pressed"))
	ui_layer.add_child(create_terrain_lake_button)

	# Create Mode selection
	create_mode_section_label = create_styled_label("CREATE MODE", 12, UI_COLORS.text_secondary)
	create_mode_section_label.set_position(Vector2(Global.world_size.x + 20, 680))
	ui_layer.add_child(create_mode_section_label)

	create_mode_add_button = create_styled_button("ADD", Vector2(85, 35))
	create_mode_add_button.set_position(Vector2(Global.world_size.x + 20, 700))
	create_mode_add_button.connect("pressed", Callable(self, "_on_create_mode_add_pressed"))
	ui_layer.add_child(create_mode_add_button)

	create_mode_move_button = create_styled_button("MOVE", Vector2(85, 35))
	create_mode_move_button.set_position(Vector2(Global.world_size.x + 115, 700))
	create_mode_move_button.connect("pressed", Callable(self, "_on_create_mode_move_pressed"))
	ui_layer.add_child(create_mode_move_button)

	create_mode_delete_button = create_styled_button("DELETE", Vector2(85, 35))
	create_mode_delete_button.set_position(Vector2(Global.world_size.x + 210, 700))
	create_mode_delete_button.connect("pressed", Callable(self, "_on_create_mode_delete_pressed"))
	ui_layer.add_child(create_mode_delete_button)

	create_mode_paint_button = create_styled_button("PAINT", Vector2(85, 35))
	create_mode_paint_button.set_position(Vector2(Global.world_size.x + 20, 740))
	create_mode_paint_button.connect("pressed", Callable(self, "_on_create_mode_paint_pressed"))
	ui_layer.add_child(create_mode_paint_button)

	# Finish Map button
	var finish_y: float = 785
	finish_map_button = create_styled_button("FINISH MAP", Vector2(280, 40))
	finish_map_button.set_position(Vector2(Global.world_size.x + 20, finish_y))
	finish_map_button.connect("pressed", Callable(self, "_on_finish_map_pressed"))
	ui_layer.add_child(finish_map_button)

	# Save/Load buttons
	save_map_button = create_styled_button("SAVE MAP", Vector2(135, 35))
	save_map_button.set_position(Vector2(Global.world_size.x + 20, finish_y + 45))
	save_map_button.connect("pressed", Callable(self, "_on_save_map_pressed"))
	ui_layer.add_child(save_map_button)

	load_map_button = create_styled_button("LOAD MAP", Vector2(135, 35))
	load_map_button.set_position(Vector2(Global.world_size.x + 165, finish_y + 45))
	load_map_button.connect("pressed", Callable(self, "_on_load_map_pressed"))
	ui_layer.add_child(load_map_button)

	# Save Window
	save_window = Window.new()
	save_window.title = "Save Map"
	save_window.size = Vector2(300, 140)
	ui_layer.add_child(save_window)
	var save_root: VBoxContainer = VBoxContainer.new()
	save_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_root.add_theme_constant_override("separation", 10)
	save_window.add_child(save_root)
	var save_label: Label = create_styled_label("Filename (without .json):", 14, UI_COLORS.text_primary)
	save_root.add_child(save_label)
	save_line_edit = LineEdit.new()
	save_root.add_child(save_line_edit)
	var save_buttons: HBoxContainer = HBoxContainer.new()
	save_buttons.add_theme_constant_override("separation", 10)
	save_ok_button = create_styled_button("Save", Vector2(120, 30))
	save_ok_button.connect("pressed", Callable(self, "_on_save_confirm_pressed"))
	save_cancel_button = create_styled_button("Cancel", Vector2(120, 30))
	save_cancel_button.connect("pressed", Callable(self, "_on_save_cancel_pressed"))
	save_buttons.add_child(save_ok_button)
	save_buttons.add_child(save_cancel_button)
	save_root.add_child(save_buttons)

	# Load Window
	load_window = Window.new()
	load_window.title = "Load Map"
	load_window.size = Vector2(360, 320)
	ui_layer.add_child(load_window)
	var load_root: VBoxContainer = VBoxContainer.new()
	load_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_root.add_theme_constant_override("separation", 10)
	load_window.add_child(load_root)
	var load_label: Label = create_styled_label("Choose a map:", 14, UI_COLORS.text_primary)
	load_root.add_child(load_label)
	load_item_list = ItemList.new()
	load_item_list.select_mode = ItemList.SELECT_SINGLE
	load_item_list.custom_minimum_size = Vector2(0, 220)
	load_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	load_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_root.add_child(load_item_list)
	var load_buttons: HBoxContainer = HBoxContainer.new()
	load_buttons.add_theme_constant_override("separation", 10)
	load_ok_button = create_styled_button("Load", Vector2(120, 30))
	load_ok_button.connect("pressed", Callable(self, "_on_load_confirm_pressed"))
	load_cancel_button = create_styled_button("Cancel", Vector2(120, 30))
	load_cancel_button.connect("pressed", Callable(self, "_on_load_cancel_pressed"))
	load_buttons.add_child(load_ok_button)
	load_buttons.add_child(load_cancel_button)
	load_root.add_child(load_buttons)

	# Start dialogs hidden
	save_window.hide()
	load_window.hide()
	
	# --- Simulation Info Panel ---
	simulation_panel = create_styled_panel()
	simulation_panel.set_position(Vector2(Global.world_size.x + 0, 60))
	simulation_panel.set_size(Vector2(320, 960))
	simulation_panel.hide()
	ui_layer.add_child(simulation_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	var margin_container: MarginContainer = MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	simulation_panel.add_child(margin_container)
	margin_container.add_child(main_vbox)

	# Date section with improved styling
	var date_panel: Panel = create_section_panel(Color(0.10, 0.15, 0.25, 0.9))
	date_panel.custom_minimum_size = Vector2(280, 110)
	date_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var date_section: VBoxContainer = VBoxContainer.new()
	date_section.add_theme_constant_override("separation", 8)
	
	var date_margin: MarginContainer = MarginContainer.new()
	date_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	date_margin.add_theme_constant_override("margin_left", 15)
	date_margin.add_theme_constant_override("margin_right", 15)
	date_margin.add_theme_constant_override("margin_top", 20)
	date_margin.add_theme_constant_override("margin_bottom", 20)
	date_panel.add_child(date_margin)
	date_margin.add_child(date_section)
	
	simulation_date_label = create_styled_label("", 32, UI_COLORS.text_primary)
	simulation_date_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	date_section.add_child(simulation_date_label)
	
	var simulation_time_label: Label = create_styled_label("", 24, UI_COLORS.text_primary)
	simulation_time_label.name = "time_label"
	simulation_time_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	date_section.add_child(simulation_time_label)
	
	main_vbox.add_child(date_panel)

	# Strength section with improved styling
	var strength_panel: Panel = create_section_panel(Color(0.08, 0.20, 0.12, 0.9))
	strength_panel.custom_minimum_size = Vector2(280, 200)
	strength_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var strength_section: VBoxContainer = VBoxContainer.new()
	strength_section.add_theme_constant_override("separation", 15)
	
	var strength_margin: MarginContainer = MarginContainer.new()
	strength_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strength_margin.add_theme_constant_override("margin_left", 15)
	strength_margin.add_theme_constant_override("margin_right", 15)
	strength_margin.add_theme_constant_override("margin_top", 20)
	strength_margin.add_theme_constant_override("margin_bottom", 20)
	strength_panel.add_child(strength_margin)
	strength_margin.add_child(strength_section)
	
	simulation_strength_header = create_styled_label("STRENGTH", 22, UI_COLORS.success)
	simulation_strength_header.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	strength_section.add_child(simulation_strength_header)

	# Add a header separator line
	var strength_separator: ColorRect = ColorRect.new()
	strength_separator.color = UI_COLORS.success.lightened(0.3)
	strength_separator.custom_minimum_size = Vector2(240, 2)
	strength_section.add_child(strength_separator)

	# Strength blue row with improved design
	simulation_strength_blue_row = HBoxContainer.new()
	simulation_strength_blue_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_strength_blue_row.add_theme_constant_override("separation", 20)
	
	var blue_flag_container: PanelContainer = PanelContainer.new()
	blue_flag_container.add_theme_color_override("panel", UI_COLORS.accent_blue.darkened(0.3))
	var blue_nato_symbol: NATOSymbolControl = NATOSymbolControl.new(0)
	blue_flag_container.add_child(blue_nato_symbol)
	simulation_strength_blue_row.add_child(blue_flag_container)
	
	var blue_strength_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	blue_strength_label.name = "value"
	blue_strength_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	blue_strength_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_strength_blue_row.add_child(blue_strength_label)
	strength_section.add_child(simulation_strength_blue_row)

	# Strength red row with improved design
	simulation_strength_red_row = HBoxContainer.new()
	simulation_strength_red_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_strength_red_row.add_theme_constant_override("separation", 20)
	
	var red_flag_container: PanelContainer = PanelContainer.new()
	red_flag_container.add_theme_color_override("panel", UI_COLORS.accent_red.darkened(0.3))
	var red_nato_symbol: NATOSymbolControl = NATOSymbolControl.new(1)
	red_flag_container.add_child(red_nato_symbol)
	simulation_strength_red_row.add_child(red_flag_container)
	
	var red_strength_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	red_strength_label.name = "value"
	red_strength_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	red_strength_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_strength_red_row.add_child(red_strength_label)
	strength_section.add_child(simulation_strength_red_row)
	
	main_vbox.add_child(strength_panel)

	# Manpower section with improved styling
	var manpower_panel: Panel = create_section_panel(Color(0.25, 0.25, 0.08, 0.9))
	manpower_panel.custom_minimum_size = Vector2(280, 200)
	manpower_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var manpower_section: VBoxContainer = VBoxContainer.new()
	manpower_section.add_theme_constant_override("separation", 15)
	
	var manpower_margin: MarginContainer = MarginContainer.new()
	manpower_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	manpower_margin.add_theme_constant_override("margin_left", 15)
	manpower_margin.add_theme_constant_override("margin_right", 15)
	manpower_margin.add_theme_constant_override("margin_top", 20)
	manpower_margin.add_theme_constant_override("margin_bottom", 20)
	manpower_panel.add_child(manpower_margin)
	manpower_margin.add_child(manpower_section)
	
	simulation_manpower_header = create_styled_label("MANPOWER", 22, UI_COLORS.manpower)
	simulation_manpower_header.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	manpower_section.add_child(simulation_manpower_header)

	# Add a header separator line
	var manpower_separator: ColorRect = ColorRect.new()
	manpower_separator.color = UI_COLORS.manpower.lightened(0.3)
	manpower_separator.custom_minimum_size = Vector2(240, 2)
	manpower_section.add_child(manpower_separator)

	# Manpower blue row with improved design
	simulation_manpower_blue_row = HBoxContainer.new()
	simulation_manpower_blue_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_manpower_blue_row.add_theme_constant_override("separation", 20)
	
	var blue_manpower_flag_container: PanelContainer = PanelContainer.new()
	blue_manpower_flag_container.add_theme_color_override("panel", UI_COLORS.accent_blue.darkened(0.3))
	var blue_manpower_nato_symbol: NATOSymbolControl = NATOSymbolControl.new(0)
	blue_manpower_flag_container.add_child(blue_manpower_nato_symbol)
	simulation_manpower_blue_row.add_child(blue_manpower_flag_container)
	
	var blue_manpower_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	blue_manpower_label.name = "value"
	blue_manpower_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	blue_manpower_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_manpower_blue_row.add_child(blue_manpower_label)
	manpower_section.add_child(simulation_manpower_blue_row)

	# Manpower red row with improved design
	simulation_manpower_red_row = HBoxContainer.new()
	simulation_manpower_red_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_manpower_red_row.add_theme_constant_override("separation", 20)
	
	var red_manpower_flag_container: PanelContainer = PanelContainer.new()
	red_manpower_flag_container.add_theme_color_override("panel", UI_COLORS.accent_red.darkened(0.3))
	var red_manpower_nato_symbol: NATOSymbolControl = NATOSymbolControl.new(1)
	red_manpower_flag_container.add_child(red_manpower_nato_symbol)
	simulation_manpower_red_row.add_child(red_manpower_flag_container)
	
	var red_manpower_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	red_manpower_label.name = "value"
	red_manpower_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	red_manpower_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_manpower_red_row.add_child(red_manpower_label)
	manpower_section.add_child(simulation_manpower_red_row)
	
	main_vbox.add_child(manpower_panel)
	
	# Casualties section with improved styling
	var casualties_panel: Panel = create_section_panel(Color(0.25, 0.08, 0.08, 0.9))
	casualties_panel.custom_minimum_size = Vector2(280, 200)
	casualties_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var casualties_section: VBoxContainer = VBoxContainer.new()
	casualties_section.add_theme_constant_override("separation", 15)
	
	var casualties_margin: MarginContainer = MarginContainer.new()
	casualties_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	casualties_margin.add_theme_constant_override("margin_left", 15)
	casualties_margin.add_theme_constant_override("margin_right", 15)
	casualties_margin.add_theme_constant_override("margin_top", 20)
	casualties_margin.add_theme_constant_override("margin_bottom", 20)
	casualties_panel.add_child(casualties_margin)
	casualties_margin.add_child(casualties_section)
	
	simulation_casualties_header = create_styled_label("CASUALTIES", 22, UI_COLORS.warning)
	simulation_casualties_header.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	casualties_section.add_child(simulation_casualties_header)

	# Add a header separator line
	var casualties_separator: ColorRect = ColorRect.new()
	casualties_separator.color = UI_COLORS.warning.lightened(0.3)
	casualties_separator.custom_minimum_size = Vector2(240, 2)
	casualties_section.add_child(casualties_separator)

	# Casualties blue row with improved design
	simulation_casualties_blue_row = HBoxContainer.new()
	simulation_casualties_blue_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_casualties_blue_row.add_theme_constant_override("separation", 20)
	
	var blue_casualties_flag_container: PanelContainer = PanelContainer.new()
	blue_casualties_flag_container.add_theme_color_override("panel", UI_COLORS.accent_blue.darkened(0.3))
	var blue_casualties_nato_symbol: NATOSymbolControl = NATOSymbolControl.new(0)
	blue_casualties_flag_container.add_child(blue_casualties_nato_symbol)
	simulation_casualties_blue_row.add_child(blue_casualties_flag_container)
	
	var blue_casualty_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	blue_casualty_label.name = "value"
	blue_casualty_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	blue_casualty_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_casualties_blue_row.add_child(blue_casualty_label)
	casualties_section.add_child(simulation_casualties_blue_row)

	# Casualties red row with improved design
	simulation_casualties_red_row = HBoxContainer.new()
	simulation_casualties_red_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_casualties_red_row.add_theme_constant_override("separation", 20)
	
	var red_casualties_flag_container: PanelContainer = PanelContainer.new()
	red_casualties_flag_container.add_theme_color_override("panel", UI_COLORS.accent_red.darkened(0.3))
	var red_casualties_nato_symbol: NATOSymbolControl = NATOSymbolControl.new(1)
	red_casualties_flag_container.add_child(red_casualties_nato_symbol)
	simulation_casualties_red_row.add_child(red_casualties_flag_container)
	
	var red_casualty_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	red_casualty_label.name = "value"
	red_casualty_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	red_casualty_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_casualties_red_row.add_child(red_casualty_label)
	casualties_section.add_child(simulation_casualties_red_row)
	
	main_vbox.add_child(casualties_panel)
	
	# Air Force section with improved styling
	var airforce_panel: Panel = create_section_panel(Color(0.08, 0.25, 0.25, 0.9))
	airforce_panel.custom_minimum_size = Vector2(280, 120)
	airforce_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var airforce_section: VBoxContainer = VBoxContainer.new()
	airforce_section.add_theme_constant_override("separation", 15)
	
	var airforce_margin: MarginContainer = MarginContainer.new()
	airforce_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	airforce_margin.add_theme_constant_override("margin_left", 15)
	airforce_margin.add_theme_constant_override("margin_right", 15)
	airforce_margin.add_theme_constant_override("margin_top", 20)
	airforce_margin.add_theme_constant_override("margin_bottom", 20)
	airforce_panel.add_child(airforce_margin)
	airforce_margin.add_child(airforce_section)
	
	simulation_airforce_header = create_styled_label("AIR FORCE", 22, UI_COLORS.airforce)
	simulation_airforce_header.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	airforce_section.add_child(simulation_airforce_header)
	
	# Air force separator
	var airforce_separator: ColorRect = ColorRect.new()
	airforce_separator.color = UI_COLORS.airforce.lightened(0.3)
	airforce_separator.custom_minimum_size = Vector2(240, 2)
	airforce_section.add_child(airforce_separator)
	
	# Air force blue row (only player has air force)
	simulation_airforce_row = HBoxContainer.new()
	simulation_airforce_row.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	simulation_airforce_row.add_theme_constant_override("separation", 20)
	
	# Create airplane icon (simplified)
	var airplane_container: PanelContainer = PanelContainer.new()
	airplane_container.add_theme_color_override("panel", UI_COLORS.accent_blue.darkened(0.3))
	var airplane_control: Control = Control.new()
	airplane_control.custom_minimum_size = Vector2(48, 48)
	airplane_control.draw.connect(func(): _draw_airplane_icon(airplane_control))
	airplane_container.add_child(airplane_control)
	simulation_airforce_row.add_child(airplane_container)
	
	var airforce_label: Label = create_styled_label("", 26, UI_COLORS.text_primary)
	airforce_label.name = "value"
	airforce_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	airforce_label.set_custom_minimum_size(Vector2(180, 50))
	simulation_airforce_row.add_child(airforce_label)
	airforce_section.add_child(simulation_airforce_row)
	
	main_vbox.add_child(airforce_panel)
	
	update_ui(current_player, game_phase, current_type, current_tank_rotation, current_vehicle_size, current_ship_direction_index)

func _on_assign_blue_pressed() -> void:
	assign_blue_pressed.emit()

func _on_assign_red_pressed() -> void:
	assign_red_pressed.emit()

func _on_type_territory_pressed() -> void:
	type_territory_pressed.emit()

func _on_type_tank_pressed() -> void:
	type_tank_pressed.emit()

func _on_type_train_pressed() -> void:
	type_train_pressed.emit()

func _on_type_ship_pressed() -> void:
	type_ship_pressed.emit()

func _on_tank_rotation_toggled() -> void:
	tank_rotation_toggled.emit()

func _on_vehicle_size_small_pressed() -> void:
	vehicle_size_small_pressed.emit()

func _on_vehicle_size_medium_pressed() -> void:
	vehicle_size_medium_pressed.emit()

func _on_vehicle_size_large_pressed() -> void:
	vehicle_size_large_pressed.emit()

func _on_vehicle_size_huge_pressed() -> void:
	vehicle_size_huge_pressed.emit()

func _on_reset_pressed() -> void:
	reset_pressed.emit()

func _on_clear_map_pressed() -> void:
	clear_map_pressed.emit()

func _on_start_new_game_pressed() -> void:
	start_new_game_pressed.emit()

func _on_ship_direction_toggled() -> void:
	ship_direction_toggled.emit()

# Update the UI to reflect the selected player, type, tank rotation, and vehicle size
func update_ui(
	current_player: int,
	game_phase,
	current_type: String,
	current_tank_rotation: int,
	current_vehicle_size: String,
	current_ship_direction_index: int = 0
) -> void:
	# Player selection with better visual feedback
	if current_player == 0:
		assign_blue_button.set_text("✦ BLUE ALLIANCE ✦")
		assign_red_button.set_text("RED COALITION")
		assign_blue_button.modulate = UI_COLORS.accent_blue.lightened(0.3)
		assign_red_button.modulate = Color.WHITE
	else:
		assign_blue_button.set_text("BLUE ALLIANCE")
		assign_red_button.set_text("✦ RED COALITION ✦")
		assign_blue_button.modulate = Color.WHITE
		assign_red_button.modulate = UI_COLORS.accent_red.lightened(0.3)
	# Type selection with military terminology
	if current_type == "territory":
		type_territory_button.set_text("◉ TERRITORY")
		type_tank_button.set_text("ARMOR")
		type_train_button.set_text("RAIL")
		type_ship_button.set_text("NAVAL")
		type_territory_button.modulate = UI_COLORS.accent_gold
		type_tank_button.modulate = Color.WHITE
		type_train_button.modulate = Color.WHITE
		type_ship_button.modulate = Color.WHITE
	elif current_type == "tank":
		type_territory_button.set_text("TERRITORY")
		type_tank_button.set_text("◉ ARMOR")
		type_train_button.set_text("RAIL")
		type_ship_button.set_text("NAVAL")
		type_territory_button.modulate = Color.WHITE
		type_tank_button.modulate = UI_COLORS.accent_gold
		type_train_button.modulate = Color.WHITE
		type_ship_button.modulate = Color.WHITE
	elif current_type == "train":
		type_territory_button.set_text("TERRITORY")
		type_tank_button.set_text("ARMOR")
		type_train_button.set_text("◉ RAIL")
		type_ship_button.set_text("NAVAL")
		type_territory_button.modulate = Color.WHITE
		type_tank_button.modulate = Color.WHITE
		type_train_button.modulate = UI_COLORS.accent_gold
		type_ship_button.modulate = Color.WHITE
	elif current_type == "ship":
		type_territory_button.set_text("TERRITORY")
		type_tank_button.set_text("ARMOR")
		type_train_button.set_text("RAIL")
		type_ship_button.set_text("◉ NAVAL")
		type_territory_button.modulate = Color.WHITE
		type_tank_button.modulate = Color.WHITE
		type_train_button.modulate = Color.WHITE
		type_ship_button.modulate = UI_COLORS.accent_gold
	# Tank rotation with military bearing terminology
	tank_rotation_button.set_text("BEARING: " + str(current_tank_rotation) + "°")
	# Vehicle size selection with military classifications
	if current_vehicle_size == "small":
		vehicle_size_small_button.set_text("◉ LIGHT")
		vehicle_size_medium_button.set_text("MEDIUM")
		vehicle_size_large_button.set_text("HEAVY")
		vehicle_size_huge_button.set_text("SUPER-HEAVY")
		vehicle_size_small_button.modulate = UI_COLORS.accent_gold
		vehicle_size_medium_button.modulate = Color.WHITE
		vehicle_size_large_button.modulate = Color.WHITE
		vehicle_size_huge_button.modulate = Color.WHITE
	elif current_vehicle_size == "medium":
		vehicle_size_small_button.set_text("LIGHT")
		vehicle_size_medium_button.set_text("◉ MEDIUM")
		vehicle_size_large_button.set_text("HEAVY")
		vehicle_size_huge_button.set_text("SUPER-HEAVY")
		vehicle_size_small_button.modulate = Color.WHITE
		vehicle_size_medium_button.modulate = UI_COLORS.accent_gold
		vehicle_size_large_button.modulate = Color.WHITE
		vehicle_size_huge_button.modulate = Color.WHITE
	elif current_vehicle_size == "large":
		vehicle_size_small_button.set_text("LIGHT")
		vehicle_size_medium_button.set_text("MEDIUM")
		vehicle_size_large_button.set_text("◉ HEAVY")
		vehicle_size_huge_button.set_text("SUPER-HEAVY")
		vehicle_size_small_button.modulate = Color.WHITE
		vehicle_size_medium_button.modulate = Color.WHITE
		vehicle_size_large_button.modulate = UI_COLORS.accent_gold
		vehicle_size_huge_button.modulate = Color.WHITE
	elif current_vehicle_size == "huge":
		vehicle_size_small_button.set_text("LIGHT")
		vehicle_size_medium_button.set_text("MEDIUM")
		vehicle_size_large_button.set_text("HEAVY")
		vehicle_size_huge_button.set_text("◉ SUPER-HEAVY")
		vehicle_size_small_button.modulate = Color.WHITE
		vehicle_size_medium_button.modulate = Color.WHITE
		vehicle_size_large_button.modulate = Color.WHITE
		vehicle_size_huge_button.modulate = UI_COLORS.accent_gold
	# Show/hide tank rotation and ship direction buttons
	if current_type == "tank":
		tank_rotation_button.show()
		ship_direction_button.hide()
		if map_mode_section_label != null:
			map_mode_section_label.hide()
		if map_mode_random_button != null:
			map_mode_random_button.hide()
		if map_mode_create_button != null:
			map_mode_create_button.hide()
		if create_terrain_section_label != null:
			create_terrain_section_label.hide()
		if create_terrain_plains_button != null:
			create_terrain_plains_button.hide()
		if create_terrain_forest_button != null:
			create_terrain_forest_button.hide()
		if create_terrain_mountains_button != null:
			create_terrain_mountains_button.hide()
		if create_terrain_lake_button != null:
			create_terrain_lake_button.hide()
		if create_mode_section_label != null:
			create_mode_section_label.hide()
		if create_mode_add_button != null:
			create_mode_add_button.hide()
		if create_mode_move_button != null:
			create_mode_move_button.hide()
		if create_mode_delete_button != null:
			create_mode_delete_button.hide()
		if create_mode_paint_button != null:
			create_mode_paint_button.hide()
		if finish_map_button != null:
			finish_map_button.hide()
		if save_map_button != null:
			save_map_button.hide()
		if load_map_button != null:
			load_map_button.hide()
	elif current_type == "ship":
		tank_rotation_button.hide()
		ship_direction_button.show()
		ship_direction_button.set_text("HEADING: " + str(current_ship_direction_index + 1))
		if map_mode_section_label != null:
			map_mode_section_label.show()
		if map_mode_random_button != null:
			map_mode_random_button.show()
		if map_mode_create_button != null:
			map_mode_create_button.show()
		if create_terrain_section_label != null:
			create_terrain_section_label.show()
		if create_terrain_plains_button != null:
			create_terrain_plains_button.show()
		if create_terrain_forest_button != null:
			create_terrain_forest_button.show()
		if create_terrain_mountains_button != null:
			create_terrain_mountains_button.show()
		if create_terrain_lake_button != null:
			create_terrain_lake_button.show()
		if create_mode_section_label != null:
			create_mode_section_label.show()
		if create_mode_add_button != null:
			create_mode_add_button.show()
		if create_mode_move_button != null:
			create_mode_move_button.show()
		if create_mode_delete_button != null:
			create_mode_delete_button.show()
		if create_mode_paint_button != null:
			create_mode_paint_button.show()
		if finish_map_button != null:
			finish_map_button.show()
		if save_map_button != null:
			save_map_button.show()
		if load_map_button != null:
			load_map_button.show()
	else:
		tank_rotation_button.hide()
		ship_direction_button.hide()

	# Hide or disable all buttons and show only 'Quit Game' in simulation phase
	if game_phase == "simulation":
		# Disable all existing buttons
		assign_blue_button.disabled = true
		assign_red_button.disabled = true
		type_territory_button.disabled = true
		type_tank_button.disabled = true
		type_train_button.disabled = true
		type_ship_button.disabled = true
		tank_rotation_button.disabled = true
		vehicle_size_small_button.disabled = true
		vehicle_size_medium_button.disabled = true
		vehicle_size_large_button.disabled = true
		vehicle_size_huge_button.disabled = true
		reset_button.disabled = true
		clear_map_button.disabled = true
		start_new_game_button.disabled = true
		ship_direction_button.disabled = true

		# Hide all except Quit Game
		assign_blue_button.hide()
		assign_red_button.hide()
		type_territory_button.hide()
		type_tank_button.hide()
		type_train_button.hide()
		type_ship_button.hide()
		tank_rotation_button.hide()
		vehicle_size_small_button.hide()
		vehicle_size_medium_button.hide()
		vehicle_size_large_button.hide()
		vehicle_size_huge_button.hide()
		reset_button.hide()
		clear_map_button.hide()
		start_new_game_button.hide()
		ship_direction_button.hide()

		# Create and show the Quit Game button if not already present
		if quit_game_button == null:
			quit_game_button = create_styled_button("⚠ ABORT MISSION ⚠", Vector2(280, 40))
			quit_game_button.set_position(Vector2(Global.world_size.x + 20, 20))
			quit_game_button.connect("pressed", Callable(self, "_on_quit_game_pressed"))
			quit_game_button.modulate = UI_COLORS.warning
			ui_layer.add_child(quit_game_button)
		quit_game_button.show()
	else:
		# Restore all buttons and hide the quit button
		assign_blue_button.show()
		assign_red_button.show()
		type_territory_button.show()
		type_tank_button.show()
		type_train_button.show()
		type_ship_button.show()
		tank_rotation_button.show()
		vehicle_size_small_button.show()
		vehicle_size_medium_button.show()
		vehicle_size_large_button.show()
		vehicle_size_huge_button.show()
		reset_button.show()
		clear_map_button.show()
		start_new_game_button.show()
		ship_direction_button.show()
		assign_blue_button.disabled = false
		assign_red_button.disabled = false
		type_territory_button.disabled = false
		type_tank_button.disabled = false
		type_train_button.disabled = false
		type_ship_button.disabled = false
		tank_rotation_button.disabled = false
		vehicle_size_small_button.disabled = false
		vehicle_size_medium_button.disabled = false
		vehicle_size_large_button.disabled = false
		vehicle_size_huge_button.disabled = false
		reset_button.disabled = false
		clear_map_button.disabled = false
		start_new_game_button.disabled = false
		ship_direction_button.disabled = false
		if quit_game_button != null:
			quit_game_button.hide()

	# At the end, ensure only one of tank_rotation_button or ship_direction_button is visible
	if current_type == "tank":
		tank_rotation_button.show()
		ship_direction_button.hide()
	elif current_type == "ship":
		tank_rotation_button.hide()
		ship_direction_button.show()
	else:
		tank_rotation_button.hide()
		ship_direction_button.hide()

	# Always hide both in simulation phase
	if game_phase == "simulation":
		tank_rotation_button.hide()
		ship_direction_button.hide()
		if simulation_panel != null:
			simulation_panel.show()
		if simulation_date_label != null:
			simulation_date_label.show()
		if simulation_strength_header != null:
			simulation_strength_header.show()
		if simulation_strength_blue_row != null:
			simulation_strength_blue_row.show()
		if simulation_strength_red_row != null:
			simulation_strength_red_row.show()
		if simulation_manpower_header != null:
			simulation_manpower_header.show()
		if simulation_manpower_blue_row != null:
			simulation_manpower_blue_row.show()
		if simulation_manpower_red_row != null:
			simulation_manpower_red_row.show()
		if simulation_casualties_header != null:
			simulation_casualties_header.show()
		if simulation_casualties_blue_row != null:
			simulation_casualties_blue_row.show()
		if simulation_casualties_red_row != null:
			simulation_casualties_red_row.show()
		if simulation_airforce_header != null:
			simulation_airforce_header.show()
		if simulation_airforce_row != null:
			simulation_airforce_row.show()
	else:
		if simulation_panel != null:
			simulation_panel.hide()
		if simulation_date_label != null:
			simulation_date_label.hide()
		if simulation_strength_header != null:
			simulation_strength_header.hide()
		if simulation_strength_blue_row != null:
			simulation_strength_blue_row.hide()
		if simulation_strength_red_row != null:
			simulation_strength_red_row.hide()
		if simulation_manpower_header != null:
			simulation_manpower_header.hide()
		if simulation_manpower_blue_row != null:
			simulation_manpower_blue_row.hide()
		if simulation_manpower_red_row != null:
			simulation_manpower_red_row.hide()
		if simulation_casualties_header != null:
			simulation_casualties_header.hide()
		if simulation_casualties_blue_row != null:
			simulation_casualties_blue_row.hide()
		if simulation_casualties_red_row != null:
			simulation_casualties_red_row.hide()
		if simulation_airforce_header != null:
			simulation_airforce_header.hide()
		if simulation_airforce_row != null:
			simulation_airforce_row.hide()
		if map_mode_section_label != null:
			map_mode_section_label.show()
		if map_mode_random_button != null:
			map_mode_random_button.show()
		if map_mode_create_button != null:
			map_mode_create_button.show()
		if create_terrain_section_label != null:
			create_terrain_section_label.show()
		if create_terrain_plains_button != null:
			create_terrain_plains_button.show()
		if create_terrain_forest_button != null:
			create_terrain_forest_button.show()
		if create_terrain_mountains_button != null:
			create_terrain_mountains_button.show()
		if create_terrain_lake_button != null:
			create_terrain_lake_button.show()
		if create_mode_section_label != null:
			create_mode_section_label.show()
		if create_mode_add_button != null:
			create_mode_add_button.show()
		if create_mode_move_button != null:
			create_mode_move_button.show()
		if create_mode_delete_button != null:
			create_mode_delete_button.show()
		if create_mode_paint_button != null:
			create_mode_paint_button.show()
		if finish_map_button != null:
			finish_map_button.show()
		if save_map_button != null:
			save_map_button.show()
		if load_map_button != null:
			load_map_button.show()

func set_map_mode_display(mode_value: int) -> void:
	if mode_value == Global.GameMode.RANDOM:
		map_mode_random_button.modulate = UI_COLORS.accent_gold
		map_mode_create_button.modulate = Color.WHITE
	elif mode_value == Global.GameMode.CREATE:
		map_mode_random_button.modulate = Color.WHITE
		map_mode_create_button.modulate = UI_COLORS.accent_gold
	else:
		map_mode_random_button.modulate = Color.WHITE
		map_mode_create_button.modulate = Color.WHITE

func set_create_terrain_display(terrain: String) -> void:
	if terrain == "plains":
		create_terrain_plains_button.modulate = UI_COLORS.accent_gold
		create_terrain_forest_button.modulate = Color.WHITE
		create_terrain_mountains_button.modulate = Color.WHITE
		create_terrain_lake_button.modulate = Color.WHITE
	else:
		if terrain == "forest":
			create_terrain_plains_button.modulate = Color.WHITE
			create_terrain_forest_button.modulate = UI_COLORS.accent_gold
			create_terrain_mountains_button.modulate = Color.WHITE
			create_terrain_lake_button.modulate = Color.WHITE
		else:
			if terrain == "mountains":
				create_terrain_plains_button.modulate = Color.WHITE
				create_terrain_forest_button.modulate = Color.WHITE
				create_terrain_mountains_button.modulate = UI_COLORS.accent_gold
				create_terrain_lake_button.modulate = Color.WHITE
			else:
				create_terrain_plains_button.modulate = Color.WHITE
				create_terrain_forest_button.modulate = Color.WHITE
				create_terrain_mountains_button.modulate = Color.WHITE
				create_terrain_lake_button.modulate = UI_COLORS.accent_gold

func clear_map_mode_highlight() -> void:
	if map_mode_random_button != null:
		map_mode_random_button.modulate = Color.WHITE
	if map_mode_create_button != null:
		map_mode_create_button.modulate = Color.WHITE

func set_create_controls_visible(visible: bool) -> void:
	var nodes: Array = [
		create_terrain_section_label,
		create_terrain_plains_button,
		create_terrain_forest_button,
		create_terrain_mountains_button,
		create_terrain_lake_button,
		create_mode_section_label,
		create_mode_add_button,
		create_mode_move_button,
		create_mode_delete_button,
		create_mode_paint_button,
		finish_map_button,
		save_map_button,
		load_map_button
	]
	for n in nodes:
		if n == null:
			continue
		if visible:
			n.show()
		else:
			n.hide()

func is_create_controls_visible() -> bool:
	if create_mode_add_button == null:
		return false
	return create_mode_add_button.visible

func set_create_mode_display(mode_value: String) -> void:
	if mode_value == "add":
		create_mode_add_button.modulate = UI_COLORS.accent_gold
		create_mode_move_button.modulate = Color.WHITE
		create_mode_delete_button.modulate = Color.WHITE
		create_mode_paint_button.modulate = Color.WHITE
	else:
		if mode_value == "move":
			create_mode_add_button.modulate = Color.WHITE
			create_mode_move_button.modulate = UI_COLORS.accent_gold
			create_mode_delete_button.modulate = Color.WHITE
			create_mode_paint_button.modulate = Color.WHITE
		else:
			if mode_value == "delete":
				create_mode_add_button.modulate = Color.WHITE
				create_mode_move_button.modulate = Color.WHITE
				create_mode_delete_button.modulate = UI_COLORS.accent_gold
				create_mode_paint_button.modulate = Color.WHITE
			else:
				create_mode_add_button.modulate = Color.WHITE
				create_mode_move_button.modulate = Color.WHITE
				create_mode_delete_button.modulate = Color.WHITE
				create_mode_paint_button.modulate = UI_COLORS.accent_gold

func _on_map_mode_random_pressed() -> void:
	map_mode_random_pressed.emit()

func _on_map_mode_create_pressed() -> void:
	map_mode_create_pressed.emit()

func _on_create_terrain_plains_pressed() -> void:
	create_terrain_plains_pressed.emit()

func _on_create_terrain_forest_pressed() -> void:
	create_terrain_forest_pressed.emit()

func _on_create_terrain_mountains_pressed() -> void:
	create_terrain_mountains_pressed.emit()

func _on_create_terrain_lake_pressed() -> void:
	create_terrain_lake_pressed.emit()

func _on_create_mode_add_pressed() -> void:
	create_mode_add_pressed.emit()

func _on_create_mode_move_pressed() -> void:
	create_mode_move_pressed.emit()

func _on_create_mode_delete_pressed() -> void:
	create_mode_delete_pressed.emit()

func _on_create_mode_paint_pressed() -> void:
	create_mode_paint_pressed.emit()

func _on_finish_map_pressed() -> void:
	finish_map_pressed.emit()

func _on_save_map_pressed() -> void:
	save_line_edit.text = ""
	save_window.popup_centered()

func _on_load_map_pressed() -> void:
	# Populate the list from res://map_saves
	load_item_list.clear()
	var dir: DirAccess = DirAccess.open("res://map_saves")
	if dir != null:
		print("[LOAD UI] Listing:", "res://map_saves", " (", ProjectSettings.globalize_path("res://map_saves"), ")")
		dir.list_dir_begin()
		while true:
			var name: String = dir.get_next()
			if name == "":
				break
			if dir.current_is_dir():
				continue
			if name.ends_with(".json"):
				load_item_list.add_item(name)
		dir.list_dir_end()
	print("[LOAD UI] Found items:", load_item_list.item_count)
	load_window.popup_centered()

func _on_save_confirm_pressed() -> void:
	var base: String = save_line_edit.text.strip_edges()
	if base == "":
		return
	save_window.hide()
	save_map_confirmed.emit(base)

func _on_save_cancel_pressed() -> void:
	save_window.hide()

func _on_load_confirm_pressed() -> void:
	var idx: int = -1 if load_item_list.get_selected_items().is_empty() else load_item_list.get_selected_items()[0]
	if idx < 0:
		return
	var name: String = load_item_list.get_item_text(idx)
	load_window.hide()
	load_map_confirmed.emit(name)

func _on_load_cancel_pressed() -> void:
	load_window.hide()

func _draw_airplane_icon(control: Control) -> void:
	var size: Vector2 = control.custom_minimum_size
	var center: Vector2 = size * 0.5
	var scale: float = 0.4
	var col: Color = UI_COLORS.airforce
	
	# Draw simple airplane shape
	var length: float = size.y * scale
	var wing_span: float = size.x * scale
	
	# Airplane body (vertical line)
	var body_start: Vector2 = center + Vector2(0, -length * 0.5)
	var body_end: Vector2 = center + Vector2(0, length * 0.3)
	control.draw_line(body_start, body_end, col, 3.0, true)
	
	# Wings (horizontal line)
	var wing_start: Vector2 = center + Vector2(-wing_span * 0.5, -length * 0.1)
	var wing_end: Vector2 = center + Vector2(wing_span * 0.5, -length * 0.1)
	control.draw_line(wing_start, wing_end, col, 2.0, true)
	
	# Tail wings (smaller horizontal line)
	var tail_span: float = wing_span * 0.4
	var tail_start: Vector2 = center + Vector2(-tail_span * 0.5, length * 0.2)
	var tail_end: Vector2 = center + Vector2(tail_span * 0.5, length * 0.2)
	control.draw_line(tail_start, tail_end, col, 2.0, true)

func update_simulation_info(date_string: String, strength0: float, strength1: float, casualties0: float, casualties1: float, manpower0: float, manpower1: float, airforce_deployed: int = 0, airforce_total: int = 500) -> void:
	if simulation_panel == null:
		return
	simulation_panel.show()
	
	# Split date and time for separate display
	var parts = date_string.split(" ")
	simulation_date_label.text = parts[0]  # Date part (YYYY/MM/DD)
	var time_label = simulation_date_label.get_parent().get_node("time_label") as Label
	time_label.text = parts[1]  # Time part (HH:MM)

	var blue_strength_label: Label = simulation_strength_blue_row.get_node("value") as Label
	var red_strength_label: Label = simulation_strength_red_row.get_node("value") as Label
	var blue_manpower_label: Label = simulation_manpower_blue_row.get_node("value") as Label
	var red_manpower_label: Label = simulation_manpower_red_row.get_node("value") as Label
	var blue_casualty_label: Label = simulation_casualties_blue_row.get_node("value") as Label
	var red_casualty_label: Label = simulation_casualties_red_row.get_node("value") as Label
	var airforce_label: Label = simulation_airforce_row.get_node("value") as Label

	blue_strength_label.text = format_number_with_commas(floor(strength0))
	red_strength_label.text = format_number_with_commas(floor(strength1))
	blue_manpower_label.text = format_number_with_commas(ceil(manpower0))
	red_manpower_label.text = format_number_with_commas(ceil(manpower1))
	blue_casualty_label.text = format_number_with_commas(floor(casualties0))
	red_casualty_label.text = format_number_with_commas(floor(casualties1))
	airforce_label.text = "%s / %s" % [format_number_with_commas(airforce_deployed), format_number_with_commas(airforce_total)]

func hide_simulation_info() -> void:
	if simulation_panel != null:
		simulation_panel.hide()

func format_number_with_commas(value: float) -> String:
	var is_negative: bool = value < 0
	var int_value: int = int(abs(value))
	var s: String = str(int_value)
	var result: String = ""
	var count: int = 0
	
	for i in range(s.length()-1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	
	if is_negative:
		result = "-" + result
	
	return result

func check_game_over(areas: Array[Area]) -> void:
	var player_a_areas = 0
	var player_b_areas = 0
	
	for area in areas:
		if area.owner_id == 0:
			player_a_areas += 1
		elif area.owner_id == 1:
			player_b_areas += 1
	
	if player_a_areas == 0 and player_b_areas > 0:
		# Player B wins
		display_game_over("Player B wins!")
	elif player_b_areas == 0 and player_a_areas > 0:
		# Player A wins
		display_game_over("Player A wins!")
	elif player_a_areas == 0 and player_b_areas == 0:
		# Draw
		display_game_over("Draw!")

func display_game_over(message: String) -> void:
	start_new_game_button.set_text("NEW CAMPAIGN")

func _on_quit_game_pressed() -> void:
	reset_pressed.emit()
