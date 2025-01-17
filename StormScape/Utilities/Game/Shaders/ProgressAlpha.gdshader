shader_type canvas_item;

instance uniform float progress : hint_range(0, 100);
instance uniform vec4 main_color : source_color;

void fragment() {
    vec2 uv = UV;

    // Calculate the threshold based on the progress
    float threshold = 1.0 - (progress / 100.0);

    // Sample the texture color
    vec4 tex_color = texture(TEXTURE, uv);

    // Blend the texture color with the main color
    vec4 blended_color = tex_color * main_color;

    // Check if the current pixel is above the threshold
    if (uv.y > threshold) {
        // Use the blended color
        COLOR = blended_color;
    } else {
        // Tint the blended color dark
        COLOR = vec4(blended_color.rgb * 0.25, blended_color.a); // Darken the color
    }
}