shader_type canvas_item;

uniform bool whitener_enabled = false;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 0.15;
uniform vec4 tint_color: source_color =  vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
	float new_alpha = base_color.a * alpha_multiplier;

    if (whitener_enabled) {
        COLOR = vec4(1.0, 1.0, 1.0, new_alpha);
    } else {
        COLOR = vec4(base_color.rgb, new_alpha);
		COLOR *= tint_color;
    }
}