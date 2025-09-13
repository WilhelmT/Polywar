shader_type canvas_item;

/* ─── tunables you can override from GDScript ───────────────────────── */
uniform vec2  LIGHT_DIR      = vec2(0.0, -1.0);
uniform float FACET_DARK     = 0.2;
uniform float FACET_BRIGHT   = 1.0;

uniform int   TRACK_SEGMENTS = 16;
uniform float TRACK_PERIOD   = 0.20;

/* varyings */
varying vec2  v_uv;          /* original UV  (x=±2 on tracks, xy=fake normal) */
varying vec2  v_nrm_world;   /* fake normal rotated into world space         */
varying float v_base;        /* per-facet brightness (0.30–1.0)              */

void vertex()
{
	/* pass through UV for track detection & normals */
	v_uv = UV;

	/* each vertex has colour.rgb = baseBrightness (same value in all channels) */
	v_base = COLOR.r;         /* = g = b because we wrote them identical */

	/* rotate fake normal into world space using per-instance forward vector */
	vec2 fwd   = normalize(INSTANCE_CUSTOM.xy);
	vec2 right = vec2(-fwd.y,  fwd.x);

	vec2 local = UV;
	v_nrm_world = normalize(vec2(
		right.x * local.x - fwd.x * local.y,
		right.y * local.x - fwd.y * local.y));
}

void fragment()
{
	/* 1. basic Lambert */
	float d = clamp(dot(v_nrm_world, normalize(LIGHT_DIR)), -1.0, 1.0);
	float lambert = mix(FACET_DARK, FACET_BRIGHT, (d + 1.0) * 0.5);

	/* 3. marching-ants + end fade for tracks */
	float ant = 1.0;
	if (abs(v_uv.x) > 1.5) {                       /* track quad */
		float stripe = floor(v_uv.y * float(TRACK_SEGMENTS))
		             + floor(TIME / TRACK_PERIOD);
		float step   = mod(stripe, 2.0) < 1.0 ? 0.85 : 0.70;

		float fade_t = abs(v_uv.y * 2.0 - 1.0);     /* 0 centre → 1 ends */
		float edge   = mix(1.0, 0.5, fade_t);       /* darker at ends    */

		ant = step * edge;
	}

	/* 4. remove base brightness from tint, then re-apply it once */
	vec3 tint_rgb      = COLOR.rgb;        /* already includes base brightness */
	float base         = v_base;           /* same for all channels            */
	vec3 clean_tint    = tint_rgb / base;  /* divide it back out               */

	COLOR = vec4(clean_tint * base         /* base brightness once             */
	                       * lambert
	                       * ant,
	             COLOR.a);                 /* instance alpha (always 1)        */
}
