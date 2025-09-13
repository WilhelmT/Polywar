extends Polygon2D
class_name RipplePolygon

const life_time : float = 0.3
var ease      : Tween.EaseType = Tween.EASE_IN_OUT
var trans     : Tween.TransitionType = Tween.TRANS_CUBIC
var ease_in_end_absolute: float = 0.125

var _tween : Tween
var shader: Shader = preload("res://ripple.gdshader")

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("progress", 0.0)
	#
	#material.set_shader_parameter("ring_count",   5)
	#material.set_shader_parameter("ring_spacing", 1.4)
	#material.set_shader_parameter("ring_falloff", 0.5)
	#material.set_shader_parameter("ring_width",   22.0)
	
	material.set_shader_parameter("ease_in_end", ease_in_end_absolute/life_time)

	_tween = create_tween()
	_tween.tween_property(
		material, "shader_parameter/progress", 1.0, life_time
	)#.set_ease(ease).set_trans(trans)

	_tween.finished.connect(queue_free)    # auto-cleanup
