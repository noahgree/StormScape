shader_type canvas_item;

// ─── Original Parameters ──────────────────────────────────────────────

instance uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float outline_thickness = 0.0;

instance uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform float final_alpha = 1.0;

instance uniform vec4 override_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform bool use_override_color = false;
instance uniform float brightness_mult = 1.0;

// ─── Crack Generation Parameters ─────────────────────────────────────────
instance uniform float crack_depth : hint_range(0.0, 10.0) = 0.4;
instance uniform float crack_scale : hint_range(1.0, 25.0) = 3.838;
instance uniform float crack_zebra_scale : hint_range(0.0, 10.0) = 0.841;
const float crack_zebra_amp = 1.183;
instance uniform float crack_profile : hint_range(0.0, 10.0) = 2.11;
instance uniform float crack_slope : hint_range(0.0, 250.0) = 86.2;
instance uniform float crack_width : hint_range(0.0, 1.0) = 0.036;
instance uniform vec4 crack_color : source_color = vec4(0.246, 0.109, 0.01, 0.85);
instance uniform float crack_intensity : hint_range(0.0, 1.0) = 0.0;
instance uniform vec2 crack_pixelate = vec2(16.0, 16.0);
const float crack_darkness = 1.0;

const vec4 background_color = vec4(0.0, 0.0, 0.0, 0.0);

// ─── Helper Functions ────────────────────────────────────────────────────

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
            dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), f.x),
        mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
            dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), f.x),
        f.y);
}

vec3 voronoiB(vec2 u) {
    vec2 p = floor(u);
    vec2 f = fract(u);
    float res = 8.0;
    vec2 C = vec2(0.0);
    vec2 P = vec2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash(p + g);
            vec2 r = g - f + o;
            float d = dot(r, r);
            if (d < res) {
                res = d;
                C = g;
                P = r;
            }
        }
    }
    res = 8.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g = C + vec2(float(i), float(j));
            vec2 o = hash(p + g);
            vec2 r = g - f + o;
            if (dot(P - r, P - r) > 1e-5) {
                res = min(res, 0.5 * dot((P + r), normalize(r - P)));
            }
        }
    }
    return vec3(res, P + f);
}

float fbm(vec2 n) {
    float total = 0.0, amp = 1.0;
    for (int i = 0; i < 7; i++) {
        total += noise(n) * amp;
        n *= 2.0;
        amp *= 0.5;
    }
    return total;
}

/// Generates a multi-depth crack mask. The returned vec4’s .a holds the crack mask.
vec4 generate_cracks(vec2 uv) {
    vec2 U = uv * crack_scale;
    vec4 colorAccum = background_color;
    for (float i = 0.0; i < crack_depth; i++) {
        vec2 D = vec2(crack_zebra_amp * fbm(U / crack_zebra_scale) * crack_zebra_scale);
        vec3 H = voronoiB(U + D);
        float d = H.x; // distance to cell boundary
        d = min(1.0, crack_slope * pow(max(0.0, d - crack_width), crack_profile));
        colorAccum += vec4(1.0 - d) / exp2(i);
        U *= 1.5;
    }
    colorAccum *= crack_color; // mix in the crack base color
    return colorAccum;
}

// ─── Fragment Shader ─────────────────────────────────────────────────────

void fragment() {
    // Sample the base texture.
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a <= 0.1) {
        discard;
    }

    // Outline detection
    bool is_edge = false;
    float max_pixel_size = max(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y);
    for (float x = -outline_thickness; x <= outline_thickness; x++) {
        for (float y = -outline_thickness; y <= outline_thickness; y++) {
            if (abs(x) < 0.0001 && abs(y) < 0.0001)
                continue;
            vec2 offset = vec2(x, y) * max_pixel_size;
            vec4 sample = texture(TEXTURE, UV + offset);
            if (sample.a < 0.1) {
                is_edge = true;
                break;
            }
        }
        if (is_edge)
            break;
    }

    // Compute base color from texture and tint/override values.
    vec4 base_color;
    if (is_edge) {
        base_color = outline_color;
    } else {
        if (use_override_color) {
            base_color = vec4(mix(tex_color.rgb, override_color.rgb, override_color.a), tex_color.a);
        } else {
            base_color = vec4(mix(tex_color.rgb, tint_color.rgb, tint_color.a), tex_color.a);
        }
    }
    // Optionally mix in some original texture detail.
    base_color.rgb = mix(tex_color.rgb, base_color.rgb, base_color.a);
    COLOR = base_color;

    // Apply the crack effect only if:
    //   - crack_intensity > 0,
    //   - the pixel is not pure black,
    //   - and it isn't an edge.
    if (crack_intensity > 0.0 && !is_edge && (tex_color.r > 0.01 || tex_color.g > 0.01 || tex_color.b > 0.01)) {
        // Quantize UV using separate X/Y pixelate values if enabled.
        vec2 effectiveUV = UV;
        if (crack_pixelate.x > 0.0)
            effectiveUV.x = floor(UV.x * crack_pixelate.x) / crack_pixelate.x;
        if (crack_pixelate.y > 0.0)
            effectiveUV.y = floor(UV.y * crack_pixelate.y) / crack_pixelate.y;

        vec4 crack_effect = generate_cracks(effectiveUV);
        float mask = clamp(crack_effect.a * crack_intensity, 0.0, 1.0);

        // Determine the effective crack color.
        // If override is active, mix in the override color at half strength.
        vec3 effective_crack = crack_color.rgb;
        if (use_override_color && override_color.a > 0.0) {
            effective_crack = mix(effective_crack, override_color.rgb, override_color.a * 0.5);
        }

        // Blend the underlying color with a darker version based on the effective crack color.
        COLOR.rgb = mix(COLOR.rgb, mix(COLOR.rgb, effective_crack, crack_darkness), mask);
    }

    COLOR.a *= final_alpha;
	COLOR.rgb *= brightness_mult;
}