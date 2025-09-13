extends Node2D
class_name TrailManager

const MAX_TRAIL_SEGMENTS_PER_UNIT: int = 10
const TRAIL_FADE_TIME: float = 0.5  # How long trails last
const TRAIL_WIDTH: float = 0.5     # Width of trail lines
const MIN_SEGMENT_LENGTH: float = 1.0  # Minimum distance for a trail segment
const MAX_ALPHA: float = 1.0

# Trail segment data structure
class TrailSegment:
	var start_pos: Vector2
	var end_pos: Vector2
	var color: Color
	var life_left: float
	var life_max: float
	var owner_id: int
	
	func _init(pos1: Vector2, pos2: Vector2, col: Color, duration: float, owner: int):
		start_pos = pos1
		end_pos = pos2
		color = col
		life_left = duration
		life_max = duration
		owner_id = owner

var trail_segments: Array[TrailSegment] = []
var previous_positions: Dictionary = {}  # Agent -> Vector2

func _process(delta: float) -> void:
	# Update trail segment lifetimes
	var i: int = 0
	while i < trail_segments.size():
		var segment: TrailSegment = trail_segments[i]
		segment.life_left -= delta
		
		if segment.life_left <= 0.0:
			trail_segments.remove_at(i)
		else:
			i += 1
	
	# Force redraw
	queue_redraw()

func _draw() -> void:
	# Draw all trail segments
	for segment: TrailSegment in trail_segments:
		var alpha: float = pow(segment.life_left / segment.life_max, 2.0)
		var trail_color: Color = segment.color
		trail_color.a = alpha * MAX_ALPHA  # Start with 60% opacity and fade
		trail_color = trail_color.darkened(0.5*(1-alpha))
		# Draw the trail segment as a line
		draw_line(segment.start_pos, segment.end_pos, trail_color, TRAIL_WIDTH, true)

func add_trail_segment(agent_pos: Vector2, agent_id: int, owner_id: int) -> void:
	# Check if we have a previous position for this agent
	if previous_positions.has(agent_id):
		var prev_pos: Vector2 = previous_positions[agent_id]
		var distance: float = prev_pos.distance_to(agent_pos)
		
		# Only create trail segment if agent moved enough
		if distance >= MIN_SEGMENT_LENGTH:
			var agent_color: Color = Global.get_player_color(owner_id)
			# Make the trail color lighter and more transparent
			var trail_color: Color = agent_color.lightened(0.25)
			trail_color.a = MAX_ALPHA
			
			var segment: TrailSegment = TrailSegment.new(
				prev_pos,
				agent_pos,
				trail_color,
				TRAIL_FADE_TIME,
				owner_id
			)
			
			trail_segments.append(segment)
			
			# Limit the number of trail segments to prevent memory issues
			if trail_segments.size() > MAX_TRAIL_SEGMENTS_PER_UNIT*UnitLayer.MAX_UNITS:
				trail_segments.remove_at(0)
	
	# Update the previous position
	previous_positions[agent_id] = agent_pos

func add_trail_segment_custom(agent_pos: Vector2, agent_id: int, owner_id: int, fade_time: float) -> void:
	# Check if we have a previous position for this agent
	if previous_positions.has(agent_id):
		var prev_pos: Vector2 = previous_positions[agent_id]
		var distance: float = prev_pos.distance_to(agent_pos)
		if distance >= MIN_SEGMENT_LENGTH:
			var agent_color: Color = Global.get_player_color(owner_id)
			var trail_color: Color = agent_color.lightened(0.25)
			trail_color.a = MAX_ALPHA
			var segment: TrailSegment = TrailSegment.new(
				prev_pos,
				agent_pos,
				trail_color,
				fade_time,
				owner_id
			)
			trail_segments.append(segment)
			if trail_segments.size() > MAX_TRAIL_SEGMENTS_PER_UNIT*UnitLayer.MAX_UNITS:
				trail_segments.remove_at(0)
	previous_positions[agent_id] = agent_pos

func remove_trails(agent_id: int) -> void:
	previous_positions.erase(agent_id) 
