extends RefCounted
class_name Base

var polygon			: PackedVector2Array		# The offset polygon
var owner_id		: int						# Current owner
var original_id		: int						# Original area’s polygon_id
var under_attack	: bool = false				# Updated every tick
var conquest_animation_time: float = 0.0
var conquest_animation_duration: float = 1.0
var conquest_from_color: Color
var conquest_to_color: Color  
var is_being_conquered: bool = false

func centroid() -> Vector2:
	var c : Vector2 = GeometryUtils.calculate_centroid(polygon)
	return c
