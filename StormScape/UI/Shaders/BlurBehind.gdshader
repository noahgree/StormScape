shader_type canvas_item;

uniform float lod : hint_range(0.0, 5) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float darken_factor : hint_range(0.0, 1.0) = 0.5; // New uniform to control darkening

void fragment() {
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV, lod);
    color.rgb *= darken_factor; // Darken the color
    COLOR = color;
}