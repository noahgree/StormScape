shader_type canvas_item;

instance uniform float time_factor : hint_range(0.0, 10.0) = 1.0;
instance uniform float min_alpha : hint_range(0.0, 1.0) = 0.5;
instance uniform float max_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    float pulse = min_alpha + (max_alpha - min_alpha) * (0.5 + 0.5 * sin(TIME * time_factor * 2.0 * 3.14159));
    COLOR = vec4(COLOR.rgb, COLOR.a * pulse);
}