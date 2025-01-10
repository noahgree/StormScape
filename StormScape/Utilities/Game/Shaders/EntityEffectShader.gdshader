shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_thickness = 0.0;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float final_alpha = 1.0;

uniform vec4 override_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform bool use_override_color = false;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (tex_color.a > 0.1) {
        bool is_edge = false;
        float max_pixel_size = max(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y);

        for (float x = -outline_thickness; x <= outline_thickness; x++) {
            for (float y = -outline_thickness; y <= outline_thickness; y++) {
                if (abs(x) < 0.0001 && abs(y) < 0.0001) continue;

                vec2 offset = vec2(x, y) * max_pixel_size;
                vec4 sample = texture(TEXTURE, UV + offset);

                if (sample.a < 0.1) {
                    is_edge = true;
                    break;
                }
            }
            if (is_edge) break;
        }

        if (is_edge) {
            COLOR = outline_color;
        } else {
            if (use_override_color) {
                vec3 blended_rgb = mix(tex_color.rgb, override_color.rgb, override_color.a);
                COLOR = vec4(blended_rgb, tex_color.a);
            } else {
                vec3 tinted_rgb = mix(tex_color.rgb, tint_color.rgb, tint_color.a);
                COLOR = vec4(tinted_rgb, tex_color.a);
            }
        }
    } else {
        discard;
    }

    COLOR.a *= final_alpha;
}