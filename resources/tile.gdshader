shader_type canvas_item;

uniform float border_width : hint_range(0.0, 0.2) = 0.06;
uniform vec4 border_color : source_color = vec4(0,0,0,1);
uniform vec4 fill_color : source_color = vec4(0.95,0.95,0.95,1);

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(max(abs(uv) - (0.5 - border_width), 0.0));
    float edge = 1.0 - smoothstep(0.0, 0.01, dist);
    COLOR = mix(border_color, fill_color, edge);
}