shader_type canvas_item;

// Colours a sprite by team: the sprite's own shading is re-coloured with the
// team colour, and a solid outline in the same colour is drawn around it, so
// the same model reads clearly as a different side.

uniform vec4 tint : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.7;
uniform float outline_width : hint_range(0.0, 3.0) = 1.0; // in texture pixels, 0 = off

varying float modulate_alpha; // lets the outline fade with the sprite (death fade, dash)

void vertex() {
	modulate_alpha = COLOR.a;
}

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shifted = tint.rgb * (lum * 1.4 + 0.1);
	vec4 result = COLOR;
	result.rgb = mix(COLOR.rgb, shifted, amount);

	if (outline_width > 0.0 && texture(TEXTURE, UV).a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float near = 0.0;
		near = max(near, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		near = max(near, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		near = max(near, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		near = max(near, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		if (near > 0.1) {
			result = vec4(tint.rgb, modulate_alpha);
		}
	}
	COLOR = result;
}
