shader_type canvas_item;

uniform sampler2D gradient_texture;
uniform float gradient_scale = 1.0; // Control the scale of the gradient

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // Calculate the gradient position, ensuring it covers the full vertical range
    float gradient_position = UV.y * gradient_scale;
    gradient_position = clamp(gradient_position, 0.0, 1.0);

    // Sample the gradient texture
    vec4 gradient_color = texture(gradient_texture, vec2(gradient_position, 0.0));

    if (COLOR.a > 0.0) { // Check if the text pixel is visible
        float brightness = length(COLOR.rgb);

        if (brightness < 0.1) {
            // Treat as black and keep unchanged
            COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        } else {
            // Apply the gradient color to non-black parts
            COLOR = vec4(gradient_color.rgb, tex_color.a);
        }
    } else {
        discard; // Handle transparent parts
    }
}