shader_type canvas_item;

uniform float amplitude = 5000.0;
uniform float frequency = 100.0;
uniform float speed = 100.0;

varying float wave_offset;

void vertex() {
    // Calculate Y offset using sine wave
    float offset = sin(VERTEX.x * frequency * 0.01 + TIME * speed) * amplitude;
    VERTEX.y += offset;

    // Pass the offset to fragment shader
    wave_offset = offset;
}

void fragment() {
    // Use wave_offset to adjust UV mapping
    vec2 uv = UV;
    uv.y += wave_offset / 100.0; // Scale offset to match texture space

    COLOR = texture(TEXTURE, uv); // ✅ THIS LINE IS MANDATORY
}
