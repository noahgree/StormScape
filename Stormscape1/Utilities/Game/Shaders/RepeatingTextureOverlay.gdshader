shader_type canvas_item;

uniform sampler2D overlay_tex: source_color, repeat_enable, filter_nearest;
uniform float scale = 0.0078125; // calculated by 1/texture size e.g. 1/144
varying vec2 world_position;

void vertex(){
	// calculate the world position for use in the fragment shader
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // Calculate mix amount, ensuring it's within the range
    float mix_amount = COLOR.r > 0.99 ? 1.0 : 0.0;

    // Sample the overlay texture
    vec4 overlay_color = texture(overlay_tex, world_position * scale);

    // Mix the original color with the overlay color
    vec4 final_color = mix(COLOR, overlay_color, mix_amount);

    // Clamp the final color to ensure it doesn't exceed the expected range
    COLOR = clamp(final_color, 0.0, 1.0);
}