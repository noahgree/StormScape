shader_type canvas_item;
render_mode unshaded;

// Screen texture with linear filtering.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
// Controls how far the texture samples offset for blurring.
uniform float blur_radius : hint_range(0.0, 10.0) = 1.0;
// Darken factor applied after blur.
uniform float darken_factor : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 texel_size = vec2(1.0) / vec2(textureSize(SCREEN_TEXTURE, 0));

    // 3x3 Gaussian-like weights.
    float weights[9] = float[](1.0, 2.0, 1.0,
                               2.0, 4.0, 2.0,
                               1.0, 2.0, 1.0);
    float weight_sum = 16.0; // total weight

    vec4 color_sum = vec4(0.0);
    int index = 0;

    // Loop through a 3x3 grid around the current pixel.
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 offset = vec2(float(i), float(j)) * blur_radius * texel_size;
            color_sum += texture(SCREEN_TEXTURE, uv + offset) * weights[index];
            index++;
        }
    }

    // Calculate the average then apply darken factor.
    vec4 blurred_color = color_sum / weight_sum;
    blurred_color.rgb *= darken_factor;

    COLOR = blurred_color;
}