extends Node
class_name DotPlusCursorManager

# Animation properties
const ANIMATION_DURATION: float = 0.5
const SHRINK_PORTION: float = 0.15    # 5% of time spent shrinking

# Animation variables
var is_animating: bool = false
var animation_time: float = 0.0
var is_expanding: bool = false

# Cursor size properties
const DEFAULT_SIZE: float = 8.0    # Length of each line segment
const CLICKED_SIZE: float = 1.0    # Size when clicked
const GAP_SIZE: float = 8.0        # Gap between center dot and line segments
const LINE_THICKNESS: float = 1.0  # Thickness of lines
const DOT_RADIUS: float = 1.0      # Size of center dot
const OUTLINE_WIDTH: float = 2.0   # Width of the outline
const HOTSPOT: Vector2 = Vector2(DEFAULT_SIZE*2, DEFAULT_SIZE*2)  # Center of the cursor

# Cursor appearance
const FILL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.75)  # Light gray/white fill
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0)  # Dark outline


func _ready() -> void:
	var default_cursor: Texture2D = create_cursor(DEFAULT_SIZE, FILL_COLOR.a)
	Input.set_custom_mouse_cursor(default_cursor, Input.CURSOR_ARROW, HOTSPOT)
	set_process_input(true)
	set_process(true)

func _process(delta: float) -> void:
	if is_animating:
		# Update animation time
		animation_time += delta
		
		if animation_time >= ANIMATION_DURATION:
			animation_time = ANIMATION_DURATION
			is_animating = false
			
			# Set back to normal cursor
			var default_cursor: Texture2D = create_cursor(DEFAULT_SIZE, FILL_COLOR.a)
			Input.set_custom_mouse_cursor(default_cursor, Input.CURSOR_ARROW, HOTSPOT)
			return
		
		# Calculate current size
		var current_size: float
		var normalized_time: float = animation_time / ANIMATION_DURATION

		if normalized_time < SHRINK_PORTION:
			# ─ Shrink phase ───────────
			var t := normalized_time / SHRINK_PORTION          # 0 → 1
			current_size  = DEFAULT_SIZE - (DEFAULT_SIZE - CLICKED_SIZE) * ease_in_quad(t)
		else:
			# ─ Recovery phase ────────
			var t := (normalized_time - SHRINK_PORTION) / (1.0 - SHRINK_PORTION)
			current_size  = CLICKED_SIZE + (DEFAULT_SIZE - CLICKED_SIZE) * ease_out_cubic(t)

		# Create and set animated cursor
		var animated_cursor: Texture2D = create_cursor(current_size, FILL_COLOR.a)
		Input.set_custom_mouse_cursor(animated_cursor, Input.CURSOR_ARROW, HOTSPOT)

func _input(event: InputEvent) -> void:
	if get_parent().game_simulation_component == null:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				start_animation()

func create_cursor(size: float, alpha: float) -> Texture2D:
	var img := Image.create(HOTSPOT.x * 2, HOTSPOT.y * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))   # Transparent BG

	# Derive colours for this frame
	var fill_color    := FILL_COLOR
	fill_color.a      = alpha
	var outline_color := OUTLINE_COLOR
	outline_color.a   = alpha

	# Draw the four line segments with proper outlines to form a cross
	# Top line (vertical, pointing up)
	draw_rect_line(img, Vector2(HOTSPOT.x - LINE_THICKNESS/2, HOTSPOT.y - GAP_SIZE - size), 
				   Vector2(HOTSPOT.x + LINE_THICKNESS/2, HOTSPOT.y - GAP_SIZE), 
				   LINE_THICKNESS, fill_color, outline_color)
	
	# Bottom line (vertical, pointing down)
	draw_rect_line(img, Vector2(HOTSPOT.x - LINE_THICKNESS/2, HOTSPOT.y + GAP_SIZE), 
				   Vector2(HOTSPOT.x + LINE_THICKNESS/2, HOTSPOT.y + GAP_SIZE + size), 
				   LINE_THICKNESS, fill_color, outline_color)
	
	# Left line (horizontal, pointing left)
	draw_rect_line(img, Vector2(HOTSPOT.x - GAP_SIZE - size, HOTSPOT.y - LINE_THICKNESS/2), 
				   Vector2(HOTSPOT.x - GAP_SIZE, HOTSPOT.y + LINE_THICKNESS/2), 
				   LINE_THICKNESS, fill_color, outline_color)
	
	# Right line (horizontal, pointing right)
	draw_rect_line(img, Vector2(HOTSPOT.x + GAP_SIZE, HOTSPOT.y - LINE_THICKNESS/2), 
				   Vector2(HOTSPOT.x + GAP_SIZE + size, HOTSPOT.y + LINE_THICKNESS/2), 
				   LINE_THICKNESS, fill_color, outline_color)

	# Draw center dot with outline
	draw_circle_with_outline(img, HOTSPOT, DOT_RADIUS, fill_color, outline_color)

	return ImageTexture.create_from_image(img)

func draw_rect_line(img: Image, start: Vector2, end: Vector2, thickness: float, fill_color: Color, outline_color: Color) -> void:
	# Calculate the rectangle bounds
	var min_x = min(start.x, end.x)
	var max_x = max(start.x, end.x)
	var min_y = min(start.y, end.y)
	var max_y = max(start.y, end.y)
	
	# Draw outline first (slightly larger)
	var outline_thickness = thickness + OUTLINE_WIDTH * 2
	var outline_min_x = min_x - OUTLINE_WIDTH
	var outline_max_x = max_x + OUTLINE_WIDTH
	var outline_min_y = min_y - OUTLINE_WIDTH
	var outline_max_y = max_y + OUTLINE_WIDTH
	
	# Fill outline area
	for y in range(int(outline_min_y), int(outline_max_y + 1)):
		for x in range(int(outline_min_x), int(outline_max_x + 1)):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, outline_color)
	
	# Fill inner area
	for y in range(int(min_y), int(max_y + 1)):
		for x in range(int(min_x), int(max_x + 1)):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, fill_color)

func draw_circle_with_outline(img: Image, center: Vector2, radius: float, fill_color: Color, outline_color: Color) -> void:
	var total_radius = radius + OUTLINE_WIDTH
	
	# Draw outline first
	for y in range(int(center.y - total_radius), int(center.y + total_radius + 1)):
		for x in range(int(center.x - total_radius), int(center.x + total_radius + 1)):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				var dist = sqrt((x - center.x) * (x - center.x) + (y - center.y) * (y - center.y))
				if dist <= total_radius:
					img.set_pixel(x, y, outline_color)
	
	# Draw fill
	for y in range(int(center.y - radius), int(center.y + radius + 1)):
		for x in range(int(center.x - radius), int(center.x + radius + 1)):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				var dist = sqrt((x - center.x) * (x - center.x) + (y - center.y) * (y - center.y))
				if dist <= radius:
					img.set_pixel(x, y, fill_color)

func start_animation() -> void:
	is_animating = true
	animation_time = 0.0

# Easing functions
func ease_in_quad(x: float) -> float:
	return x * x

func ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)
