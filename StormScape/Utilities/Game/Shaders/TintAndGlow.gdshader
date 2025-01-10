shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float final_alpha = 1.0;

void fragment() {
    vec2 uv = UV;
    vec4 base_color = texture(TEXTURE, uv);

    // Apply the tint and glow to the base color
    vec3 tinted_base_color = mix(base_color.rgb, tint_color.rgb, tint_color.a);
    base_color.rgb = tinted_base_color * glow_intensity;

    // Set the final color
    vec4 final_color = base_color;

    // Apply the glow intensity to the final color
    final_color.rgb *= glow_intensity;

    // Apply the final alpha
    final_color.a *= final_alpha;

    COLOR = final_color;
}