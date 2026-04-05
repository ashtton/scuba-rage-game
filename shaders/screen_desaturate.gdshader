shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float darken : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	float gray = dot(screen.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(screen.rgb, vec3(gray), strength);
	desaturated *= 1.0 - (darken * strength);
	COLOR = vec4(desaturated, 1.0);
}
