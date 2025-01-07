shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_size = 4.5;
uniform float glow_strength = 9.0;
uniform bool enable_fade = false;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float final_alpha = 1.0;

uniform vec2 frame_uv_min;
uniform vec2 frame_uv_max;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (tex_color.a < 0.1) {
        float glow = 0.0;
        int samples = 0;

        for (float x = -glow_size; x <= glow_size; x++) {
            for (float y = -glow_size; y <= glow_size; y++) {
                vec2 offset = vec2(x, y) * SCREEN_PIXEL_SIZE;
                vec2 sample_uv = UV + offset;

                // Ensure sample_uv stays within frame bounds
                if (sample_uv.x < frame_uv_min.x || sample_uv.x > frame_uv_max.x ||
                    sample_uv.y < frame_uv_min.y || sample_uv.y > frame_uv_max.y) {
                    continue;
                }

                vec4 sample = texture(TEXTURE, sample_uv);

                float fade_factor = 1.0;
                if (enable_fade) {
                    // Normalize UV within the frame
                    vec2 normalized_uv = (sample_uv - frame_uv_min) / (frame_uv_max - frame_uv_min);

                    float dist_to_edge_x = min(normalized_uv.x, 1.0 - normalized_uv.x);
                    float dist_to_edge_y = min(normalized_uv.y, 1.0 - normalized_uv.y);
                    float min_dist_to_edge = min(dist_to_edge_x, dist_to_edge_y);

                    float fade_start = glow_size * SCREEN_PIXEL_SIZE.x; // Adjust as needed
                    fade_factor = smoothstep(0.0, fade_start, min_dist_to_edge);
                }

                glow += sample.a * fade_factor;
                samples++;
            }
        }

        glow = glow / float(samples) * glow_strength;

        if (glow > 0.0) {
            COLOR = glow_color * glow;
        } else {
            discard;
        }
    } else {
        vec3 tinted_rgb = mix(tex_color.rgb, tint_color.rgb, tint_color.a);
		COLOR = vec4(tinted_rgb, tex_color.a);
    }
	
	COLOR.a *= final_alpha;
}