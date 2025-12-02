shader_type canvas_item;

void fragment() {
    vec2 uv = UV;
    float line = step(0.49, uv.x) - step(0.51, uv.x);
    COLOR = vec4(1.0, 1.0, 1.0, 1.0);
    COLOR.rgb = mix(COLOR.rgb, vec3(0.0), line);
}
