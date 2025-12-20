shader_type canvas_item;

void fragment() {
    if (COLOR.a > 0.0) { // Check if the texture pixel is visible
        // Use a simple check to determine if the pixel is black
        if (COLOR.rgb == vec3(0.0)) {
            // Keep black parts unchanged
            COLOR = vec4(0.0, 0.0, 0.0, COLOR.a);
        } else {
            // Make non-black parts transparent
            COLOR = vec4(0.0, 0.0, 0.0, 0.0);
        }
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}