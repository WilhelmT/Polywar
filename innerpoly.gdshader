shader_type canvas_item;

uniform int polygon_point_count = 0;
uniform vec2 polygon_points[512];
uniform bool clip_invert = false;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	if (polygon_point_count < 3) {
		// Nothing to mask; discard everything to avoid showing outside.
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
		bool cond1 = false;
		// Edge straddles horizontal ray at p.y?
		if ((a.y > p.y && b.y <= p.y) || (b.y > p.y && a.y <= p.y)) {
			cond1 = true;
		}
		if (cond1) {
			float denom = (b.y - a.y);
			// Avoid divide by zero (flat edge)
			if (abs(denom) > 0.000001) {
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
		if (inside == false) {
			discard;
		}
	}
	// Otherwise keep default color from Line2D.
}