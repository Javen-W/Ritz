shader_type canvas_item;

// Values 0–6 for each half
uniform int dots1_value : hint_range(0, 6) = 0;
uniform int dots2_value : hint_range(0, 6) = 0;

// Rounded corner radius in aspect-corrected space (0.0 = square)
uniform float corner_radius : hint_range(0.0, 0.4) = 0.08;

// When true the domino is visually highlighted (selection indicator)
uniform bool highlighted = false;

const float DOT_RADIUS = 0.075;
const float BORDER_THICKNESS   = 0.045;   // inset from outer edge
const float DIVIDER_HALF_WIDTH = 0.028;   // half-width of centre divider
const vec4 BG_COLOR           = vec4(0.97, 0.95, 0.88, 1.0);  // ivory
const vec4 BG_HIGHLIGHT_COLOR = vec4(1.00, 0.88, 0.25, 1.0);  // golden
const vec4 DOT_COLOR          = vec4(0.12, 0.10, 0.10, 1.0);  // near-black
const vec4 BORDER_COLOR       = vec4(0.18, 0.15, 0.12, 1.0);  // dark brown
const vec4 DIVIDER_COLOR      = vec4(0.18, 0.15, 0.12, 1.0);  // same as border

// Standard rounded-rectangle SDF.
// p         – position in aspect-corrected space (x in [-1,1], y in [-0.5,0.5])
// half_size – half-extents of the box
// r         – corner radius in the same units
float sd_rounded_rect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_circle(vec2 p, vec2 center, float r) {
	return length(p - center) - r;
}

// Draw one anti-aliased pip using screen-space derivatives for AA width.
float draw_dot(vec2 uv, vec2 center) {
	float d  = sd_circle(uv, center, DOT_RADIUS);
	float aa = max(fwidth(d), 0.001);
	return 1.0 - smoothstep(-aa, aa, d);
}

// Draw all pips for a given value inside a 0..1 square UV space.
// c: centre of the arrangement (typically vec2(0.5, 0.5))
float draw_dots(vec2 uv, int value, vec2 c) {
	if (value == 0) return 0.0;
	float dots = 0.0;
	vec2 o = vec2(0.22, 0.25);  // horizontal / vertical spacing from centre

	if (value == 1) {
		dots += draw_dot(uv, c);
	} else if (value == 2) {
		dots += draw_dot(uv, c + vec2(-o.x,  o.y));
		dots += draw_dot(uv, c + vec2( o.x, -o.y));
	} else if (value == 3) {
		dots += draw_dot(uv, c + vec2( o.x, -o.y));
		dots += draw_dot(uv, c);
		dots += draw_dot(uv, c + vec2(-o.x,  o.y));
	} else if (value == 4) {
		dots += draw_dot(uv, c + vec2(-o.x, -o.y));
		dots += draw_dot(uv, c + vec2( o.x, -o.y));
		dots += draw_dot(uv, c + vec2(-o.x,  o.y));
		dots += draw_dot(uv, c + vec2( o.x,  o.y));
	} else if (value == 5) {
		dots += draw_dot(uv, c + vec2(-o.x, -o.y));
		dots += draw_dot(uv, c + vec2( o.x, -o.y));
		dots += draw_dot(uv, c);
		dots += draw_dot(uv, c + vec2(-o.x,  o.y));
		dots += draw_dot(uv, c + vec2( o.x,  o.y));
	} else if (value == 6) {
		// Two columns, three rows (standard domino layout)
		dots += draw_dot(uv, c + vec2(-o.x, -o.y));
		dots += draw_dot(uv, c + vec2(-o.x,  0.0));
		dots += draw_dot(uv, c + vec2(-o.x,  o.y));
		dots += draw_dot(uv, c + vec2( o.x, -o.y));
		dots += draw_dot(uv, c + vec2( o.x,  0.0));
		dots += draw_dot(uv, c + vec2( o.x,  o.y));
	}
	return clamp(dots, 0.0, 1.0);
}

// Draw pips for one side of the domino.
// side 0 = left half (uv.x < 0.5), side 1 = right half (uv.x >= 0.5)
float draw_pips(vec2 uv, int value, int side) {
	if (value == 0) return 0.0;
	if (side == 0 && uv.x < 0.5) {
		vec2 luv = vec2(uv.x * 2.0, uv.y);
		return draw_dots(luv, value, vec2(0.5, 0.5));
	}
	if (side == 1 && uv.x >= 0.5) {
		vec2 luv = vec2((uv.x - 0.5) * 2.0, uv.y);
		return draw_dots(luv, value, vec2(0.5, 0.5));
	}
	return 0.0;
}

void fragment() {
	vec2 uv = UV;

	// Convert to aspect-corrected centred space: x in [-1,1], y in [-0.5,0.5]
	vec2 p = (uv - 0.5) * vec2(2.0, 1.0);

	// Outer shape SDF
	float d  = sd_rounded_rect(p, vec2(1.0, 0.5), corner_radius);
	float aa = max(length(fwidth(p)), 0.001);

	// Discard fully outside pixels (fast path + transparency)
	float shape = 1.0 - smoothstep(-aa, aa, d);
	if (shape < 0.001) {
		COLOR = vec4(0.0);
	}
	else
	{
		// Background colour (highlighted = golden)
		vec4 bg = highlighted ? BG_HIGHLIGHT_COLOR : BG_COLOR;

		// Inset the bg region to leave a thin border
		float inner_mask = 1.0 - smoothstep(-aa, aa, d + BORDER_THICKNESS);
		vec4 col = mix(BORDER_COLOR, bg, inner_mask);

		// Centre divider line
		float div_d  = abs(p.x) - DIVIDER_HALF_WIDTH;
		float div_aa = max(fwidth(div_d), 0.001);
		float div    = 1.0 - smoothstep(-div_aa, div_aa, div_d);
		col = mix(col, DIVIDER_COLOR, div * inner_mask);

		// Pips
		float dots = max(draw_pips(uv, dots1_value, 0), draw_pips(uv, dots2_value, 1));
		col = mix(col, DOT_COLOR, dots * inner_mask);

		// Final colour with shape alpha for smooth outer edge
		COLOR = vec4(col.rgb, shape);
	}
}