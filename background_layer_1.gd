extends Node2D
class_name BackgroundLayer1

func _draw() -> void:
	draw_texture(get_parent().background_texture_1, Vector2.ZERO)
	
