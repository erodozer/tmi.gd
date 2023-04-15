shader_type canvas_item;
render_mode blend_mul;

uniform int size = 64; // amount of dots
uniform float dot_size = 2.0; // dots are multiplied by dot_size
uniform float value_multiplier = 1.0; // reduce or increase value, useful when its too bright
uniform bool invert = false;

vec3 rgb2hsv(vec3 tex) {
	vec3 hsv;
	{
		vec3 c = tex;
		vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
		vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
		vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
		float d = q.x - min(q.w, q.y);
		float e = 1.0e-10;
		return tex = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
	}
}

float luminance(vec4 sample) {
	return 0.21 * sample.r + 0.71 * sample.g + 0.07 * sample.b + (1.0 - sample.a);
}

void fragment() {
	float fSize = float(size); // float version of "size"
	vec2 ratio = vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y); // make sure the dots are going to be 1:1
	vec2 pixelated_uv = floor(UV * fSize * ratio) / (fSize * ratio); // pixelates the UV, first multiply with size so it can be rounded to integer then divide it with the same value so your computer can see it and multiply with ratio to fix stretching
	float dots = length(fract(UV * fSize * ratio) - vec2(0.5)) * dot_size; // fracts the UV to make it loop, substract it by half then turn it into circle (using length) and finally multiply with 2 for smaller circle
	float value = luminance(texture(TEXTURE, pixelated_uv)); // get pixel value (brightness) from hsv; "v" means value
	
	// remove completely transparent parts
	if (texture(TEXTURE, pixelated_uv).a == 0.0) {
		discard;
	}
		
	dots = mix(dots, 1.0 - dots, float(invert)); // choose between original dots and inverted dots using "invert" since bool are only 0 (false) and 1 (true)
	dots += value * value_multiplier; // add dots with pixels value which will shrink them. Also multiply with value mutliplier because sometimes its too bright
	dots = pow(dots, 5.0); // make the dots harder but with anti-aliasing (you can use floor function but the edge will be hard)
	dots = clamp(dots, 0.0, 1.0); // clamp result value to avoid artifacts when blended with other objects
	COLOR.rgb = vec3(dots);
	COLOR.a = texture(TEXTURE, pixelated_uv).a; // the alpha shouldnt be affected too so use original texture instead
}