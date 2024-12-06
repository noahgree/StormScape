shader_type canvas_item;

uniform vec2 pixel_size = vec2(4.0, 4.0);

void fragment() {
    vec2 uv = UV;
    uv = floor(uv * pixel_size) / pixel_size;
    COLOR = texture(TEXTURE, uv);
}