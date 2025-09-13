shader_type canvas_item;

/* 0 → 1 driven each frame from GDScript */
uniform float progress : hint_range(0.0, 1.0) = 0.0;

/* click position in LOCAL space of this Polygon2D */
uniform vec2  centre = vec2(0.0);

/* visual parameters */
uniform vec4  base_colour = vec4(0.25, 0.25, 0.25, 0.2);
uniform float max_radius  = 250.0;
uniform float ring_width  = 18.0;
uniform float wave_count  = 3.0;

/* --- independent timing points ---------------------------------- */
uniform float ease_in_end     = 0.5;   // 25 % → crest fully out
uniform float ease_out_start  = 0.0;   // 75 % → centre erase begins


uniform float hole_speed_power = 1.0;   // set from GDScript



/* NB:           0  <  ease_in_end  ≤ 1
                 0 ≤  ease_out_start < 1      */

/* (you can set ease_out_start < ease_in_end for overlap) */

void fragment ()
{
	float t = clamp(progress, 0.0, 1.0);

	/* -------- outward growth (ease-in) ---------------------------- */
	float grow_t = (ease_in_end > 0.0)
		? clamp(t / ease_in_end, 0.0, 1.0)
		: 1.0;                         // safety if user sets 0

	/* -------- inward erase (ease-out) ----------------------------- */
	float shrink_t = (t < ease_out_start)
		? 0.0
		: clamp((t - ease_out_start) / (1.0 - ease_out_start), 0.0, 1.0);

	/* -------- radii ---------------------------------------------- */
	float d          = distance(FRAGCOORD.xy, centre);
	float head       = grow_t   * max_radius;   // travelling crest
	// easeOutQuad on shrink_t
	float shrink_eased = 1.0 - pow(1.0 - shrink_t, hole_speed_power);
	float inner_hole   = shrink_eased * max_radius;

	/* -------- crest & trailing ripples --------------------------- */
	float head_alpha = 1.0 - smoothstep(head - ring_width, head, d);
	float alpha = clamp(head_alpha, 0.0, 1.0);

	/* -------- erase from the centre ------------------------------ */
	float erase = smoothstep(inner_hole - ring_width, inner_hole, d);
	alpha *= erase;

	COLOR = vec4(base_colour.rgb, base_colour.a * alpha);
}
