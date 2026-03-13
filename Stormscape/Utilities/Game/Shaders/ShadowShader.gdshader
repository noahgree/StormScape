shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.35);
uniform vec2 cast_direction = vec2(1.0, 0.5);
uniform float flatten = 0.45;
uniform float shear_amount = 0.35;

void vertex() {
    VERTEX.y *= flatten;
    VERTEX.x += VERTEX.y * shear_amount * sign(cast_direction.x);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(shadow_color.rgb, tex.a * shadow_color.a);
}
