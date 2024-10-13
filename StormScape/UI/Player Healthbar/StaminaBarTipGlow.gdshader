shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
uniform float tip_size : hint_range(0.0, 0.5);
uniform float opacity : hint_range(0.0, 1.0);

const float initial_angle = radians(159.0 + 110.0);
const float fill_range = radians(157.0);

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float angle = atan(uv.y, uv.x);
    float progress_angle = initial_angle + progress * fill_range;

    float distance_to_tip = abs(angle - progress_angle);
    distance_to_tip = min(distance_to_tip, 2.0 * PI - distance_to_tip);

    vec4 base_color = texture(TEXTURE, UV);

    if (distance_to_tip < tip_size) {
		base_color.rgb = mix(base_color.rgb, vec3(1.0), opacity);
    }

    // Ensure the color is bright enough for glow
    base_color.rgb *= 2.8; // Increase intensity for glow effect

    COLOR = base_color;
}