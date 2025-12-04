shader_type canvas_item;

uniform int left_value : hint_range(0, 6) = 0;
uniform int right_value : hint_range(0, 6) = 0;
uniform float border_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

float sd_circle(vec2 uv, vec2 center, float r) {
    return length(uv - center) - r;
}

float draw_dot(vec2 uv, vec2 center) {
    float d = sd_circle(uv, center, 0.08);
    return 1.0 - smoothstep(0.0, 0.02, d);
}

float draw_dots(vec2 uv, int value, vec2 c) {
	float dots = 0.0;
	if (value == 1)
	{
		// Center.
		dots += draw_dot(uv, c);
	}
    else if (value == 2) 
	{
		// Bottom left + top right.
		dots += draw_dot(uv, c + vec2(0.15, -0.15));
		dots += draw_dot(uv, c + vec2(-0.15, 0.15));
	}
    else if (value == 3) 
	{
		// Bottom left + center + top right.
		dots += draw_dot(uv, c + vec2(0.15, -0.15));
		dots += draw_dot(uv, c);
		dots += draw_dot(uv, c + vec2(-0.15, 0.15));
	}
    else if (value == 4) 
	{
		// Four corners.
		dots += draw_dot(uv, c + vec2(-0.15, 0.15));
		dots += draw_dot(uv, c + vec2(0.15, -0.15));
		dots += draw_dot(uv, c + vec2(-0.15, -0.15));
		dots += draw_dot(uv, c + vec2(0.15, 0.15));
	}
    else if (value == 5) 
	{
		// Four corners + center.
		dots += draw_dot(uv, c);
		dots += draw_dot(uv, c + vec2(-0.15, 0.15));
		dots += draw_dot(uv, c + vec2(0.15, -0.15));
		dots += draw_dot(uv, c + vec2(-0.15, -0.15));
		dots += draw_dot(uv, c + vec2(0.15, 0.15));
	}
    else if (value == 6) 
	{
		// Left + right columns.
		dots += draw_dot(uv, c + vec2(-0.15, 0.15));
		dots += draw_dot(uv, c + vec2(0.0, 0.15));
		dots += draw_dot(uv, c + vec2(0.15, -0.15));
		
		dots += draw_dot(uv, c + vec2(-0.15, -0.15));
		dots += draw_dot(uv, c + vec2(0.0, -0.15));
		dots += draw_dot(uv, c + vec2(0.15, 0.15));
	}
	return dots;
}

float draw_pips(vec2 uv, int value, int side) {
	    
    if (value == 0) return 0.0;
    
    // Left half pips
    if (side == 0 && uv.x < 0.5) {
        vec2 c = vec2(0.25, 0.5);
        return draw_dots(uv, value, c);
    }
	
    // Right half pips
    if (side == 1 && uv.x >= 0.5) {
        vec2 c = vec2(0.75, 0.5);
        return draw_dots(uv, value, c);
    }
    
    return 0.0;
}

void fragment() {
    vec2 uv = UV;
    
    // Background
    COLOR = vec4(1.0, 1.0, 1.0, 1.0);
    
    // Center line
    float center_line = step(0.49, uv.x) - step(0.51, uv.x);
    COLOR.rgb = mix(COLOR.rgb, vec3(0.0), center_line);
    
    // Dots
    float dots_left = draw_pips(uv, left_value, 0);
    float dots_right = draw_pips(uv, right_value, 1);
    float dots = max(dots_left, dots_right);
    COLOR.rgb = mix(COLOR.rgb, vec3(0.0), dots);
    
    // Rounded border around entire domino
    vec2 corner_dist = abs(uv - 0.5) * 2.0;
    float border_dist = length(max(corner_dist - vec2(1.0 - border_width * 2.0), 0.0));
    float border = 1.0 - smoothstep(border_width - 0.02, border_width, border_dist);
    COLOR.rgb = mix(border_color.rgb, COLOR.rgb, border);
}
