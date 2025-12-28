shader_type canvas_item;

// Values 0–6 for each half
uniform int dots1_value : hint_range(0, 6) = 0;
uniform int dots2_value : hint_range(0, 6) = 0;

// Rounded corner radius (0.0 = square, 0.15 = very round)
uniform float corner_radius : hint_range(0.0, 0.25) = 0.12;

// Dot size
const float DOT_RADIUS = 0.06;

// Signed distance to circle
float sd_circle(vec2 p, vec2 center, float r) {
    return length(p - center) - r;
}

// Draw a single anti-aliased dot
float draw_dot(vec2 uv, vec2 center) {
    float d = sd_circle(uv, center, DOT_RADIUS);
    return 1.0 - smoothstep(-0.0001, 0.0001, d);
}

float draw_dots(vec2 uv, int value, vec2 c) {
	float dots = 0.0;
	vec2 o = vec2(0.15, 0.30);  // spacing from center
	
	if (value == 1)
	{
		// Center.
		dots += draw_dot(uv, c);
	}
    else if (value == 2) 
	{
		// Bottom left + top right.
		dots += draw_dot(uv, c + vec2(o.x, -o.y));
		dots += draw_dot(uv, c + vec2(-o.x, o.y));
	}
    else if (value == 3) 
	{
		// Bottom left + center + top right.
		dots += draw_dot(uv, c + vec2(o.x, -o.y));
		dots += draw_dot(uv, c);
		dots += draw_dot(uv, c + vec2(-o.x, o.y));
	}
    else if (value == 4) 
	{
		// Four corners.
		dots += draw_dot(uv, c + vec2(-o.x, o.y));
		dots += draw_dot(uv, c + vec2(o.x, -o.y));
		dots += draw_dot(uv, c + vec2(-o.x, -o.y));
		dots += draw_dot(uv, c + vec2(o.x, o.y));
	}
    else if (value == 5) 
	{
		// Four corners + center.
		dots += draw_dot(uv, c);
		dots += draw_dot(uv, c + vec2(-o.x, o.y));
		dots += draw_dot(uv, c + vec2(o.x, -o.y));
		dots += draw_dot(uv, c + vec2(-o.x, -o.y));
		dots += draw_dot(uv, c + vec2(o.x, o.y));
	}
    else if (value == 6) 
	{
		// Left + right columns.
		dots += draw_dot(uv, c + vec2(-o.x, o.y));
		dots += draw_dot(uv, c + vec2(0.0, o.y));
		dots += draw_dot(uv, c + vec2(o.x, -o.y));
		
		dots += draw_dot(uv, c + vec2(-o.x, -o.y));
		dots += draw_dot(uv, c + vec2(0.0, -o.y));
		dots += draw_dot(uv, c + vec2(o.x, o.y));
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
	
	// Rounded border around entire domino
	vec2 corner_dist = abs(uv - 0.5) * 2.0;
	float border_dist = length(max(corner_dist - vec2(1.0 - corner_radius * 2.0), 0.0));
	float border = 1.0 - smoothstep(corner_radius, corner_radius, border_dist);
	COLOR.rgba = mix(vec4(0.0, 0.0, 0.0, 0.0).rgba, COLOR.rgba, border);
    
    // Center line
	float center_line = step(0.49, uv.x) - step(0.51, uv.x);
	COLOR.rgb = mix(COLOR.rgb, vec3(0.0), center_line);
    
    // Draw pips
    float dots1 = draw_pips(uv, dots1_value, 0);
    float dots2 = draw_pips(uv, dots2_value, 1);
    float dots = max(dots1, dots2);
    COLOR.rgb = mix(COLOR.rgb, vec3(0.0), dots);
}