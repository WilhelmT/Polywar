shader_type canvas_item;

uniform sampler2D mask_tex;
uniform float darkness : hint_range(0.0,1.0) = 0.65;

void fragment(){
	vec2 px = vec2(1.0) / vec2(textureSize(mask_tex,0));
	float m = (
		texture(mask_tex, SCREEN_UV).a +
		texture(mask_tex, SCREEN_UV + vec2( px.x, 0)).a +
		texture(mask_tex, SCREEN_UV + vec2(-px.x, 0)).a +
		texture(mask_tex, SCREEN_UV + vec2(0,  px.y)).a +
		texture(mask_tex, SCREEN_UV + vec2(0, -px.y)).a ) * 0.2;
	if (m < 0.01){
		COLOR = vec4(0.0,0.0,0.0, darkness);    // dim world
	}else{
		COLOR = vec4(0.0);                      // fully clear inside
	}
}