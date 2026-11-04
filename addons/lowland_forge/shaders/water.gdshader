// Stylised lake / sea water. One shader for the whole global water plane (y = 0).
//  * Vertex waves on a dense grid near the player; flat-shaded facets via screen derivatives.
//  * Colour + opacity from real water depth (scene depth vs the water surface).
//  * Shoreline foam band + two animated foam lines that roll towards the shore ("lapping").
// All lighting is left to the engine (no emission), so it follows day/night automatically.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_schlick_ggx;

global uniform vec4 wind;     // dir.x, dir.z, strength 0..1, gust 0..1
global uniform vec4 weather;  // cloud, rain, wetness, fog
// Accumulated on the CPU (LFWaterWaves) so wind changes never jump the phase: never use TIME * wind.
global uniform vec4 water_wave; // swell phase (rad), lapping phase, fleck drift x, z
global uniform vec4 water_dir;  // old swell angle, new swell angle, blend 0..1 (fixed directions, cross-faded)

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform vec3 shallow_color : source_color = vec3(0.16, 0.56, 0.58);
uniform vec3 deep_color : source_color = vec3(0.04, 0.20, 0.30);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float depth_falloff = 0.55;     // bigger = colour reaches "deep" in fewer metres
uniform float min_alpha = 0.35;         // opacity in very shallow water
uniform float max_alpha = 0.90;         // opacity in deep water
uniform float wave_amp = 1.0;           // overall vertex-wave multiplier
uniform float facet_tilt = 1.6;         // exaggerates facet slope so lighting reads (1 = geometric)
uniform float fade_start = 50.0;        // waves fade to flat between these distances from the mesh centre
uniform float fade_end = 78.0;
uniform float lap_speed = 1.0;          // lapping animation speed multiplier
uniform float lap_range = 1.0;          // how far from shore (water depth) lapping lines start
uniform float darken = 1.0;             // colour multiplier (rain_fx lowers it in rain)

varying vec3 wpos;
varying float v_fade;
varying float v_river;   // 1 on a river (the mesh's COLOR.a = 1 - river; no colours: none)

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth value noise, 0..1.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
			mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

// One wave set travelling along angle `a` (rad, world XZ) at accumulated phase `ph`.
float wave_set(vec2 p, float a, float ph, float ws) {
	vec2 wd = vec2(cos(a), sin(a));
	vec2 pd = vec2(-wd.y, wd.x);
	// swell travels with the wind, two cross waves add chop
	float h = sin(dot(p, wd) * 0.70 - ph) * 0.55;
	h += sin(dot(p, wd * 0.6 + pd * 0.6) * 1.05 - ph * 1.25 + 1.7) * 0.30;
	h += sin(dot(p, wd * 0.5 - pd * 0.9) * 1.45 - ph * 1.6 + 4.1) * 0.15 * (0.4 + ws);
	return h;
}

float wave_height(vec2 p) {
	float ws = clamp(wind.z, 0.0, 1.0);
	float ph = water_wave.x;
	float h = wave_set(p, water_dir.y, ph, ws);
	if (water_dir.z < 0.999) { // wind turned: the old direction fades out, the new one fades in
		h = mix(wave_set(p, water_dir.x, ph, ws), h, smoothstep(0.0, 1.0, water_dir.z));
	}
	float amp = 0.015 + 0.09 * ws + 0.03 * weather.y; // calm lake -> windy chop; rain adds a little
	return h * amp * wave_amp;
}

void vertex() {
	v_river = 1.0 - COLOR.a;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 c = MODEL_MATRIX[3].xyz;
	float d = max(abs(w.x - c.x), abs(w.z - c.z));
	v_fade = 1.0 - smoothstep(fade_start, fade_end, d);
	w.y += wave_height(w.xz) * v_fade;
	wpos = w;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	float ws = clamp(wind.z, 0.0, 1.0);
	float calm = 1.0 - ws;

	// --- faceted normal: geometric triangle normal with exaggerated tilt ---
	vec3 gn = cross(dFdx(wpos), dFdy(wpos));
	gn = length(gn) > 1e-9 ? normalize(gn) : vec3(0, 1, 0);
	if (gn.y < 0.0) gn = -gn;
	vec3 wn = normalize(vec3(gn.x * facet_tilt, gn.y, gn.z * facet_tilt));
	// rain: tiny quantised ripple cells
	float rr = weather.y;
	if (rr > 0.02) {
		vec2 rc = floor(wpos.xz * 1.3);
		float ph = fract(t * 1.7 + hash21(rc));
		float ring = abs(length(fract(wpos.xz * 1.3) - 0.5) - ph * 0.5);
		float drop = (1.0 - smoothstep(0.0, 0.07, ring)) * (1.0 - ph) * step(0.6, hash21(rc + 7.0)) * rr;
		wn = normalize(wn + vec3(drop * 0.6, 0.0, drop * 0.3));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// --- water depth below this fragment (vertical metres) ---
	float sd = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	float vdepth = 50.0;
	if (sd > 0.00001) {
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, sd, 1.0);
		v.xyz /= v.w;
		float sy = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).y;
		vdepth = max(wpos.y - sy, 0.0);
	}

	float dk = clamp(1.0 - exp(-vdepth * depth_falloff), 0.0, 1.0);
	// quantise colour steps slightly for the stylised banded look
	// anti-aliased over how fast the depth changes here: a hard step flickered into hatching along the
	// contours where the depth buffer's precision wobbles across a band's edge
	float dk6 = dk * 6.0;
	float aa = clamp(fwidth(dk6), 0.02, 0.5);
	dk = (floor(dk6) + smoothstep(0.5 - aa, 0.5 + aa, fract(dk6))) / 6.0;
	vec3 col = mix(shallow_color, deep_color, dk) * darken;
	float alpha = mix(min_alpha, max_alpha, dk);

	// fresnel: more opaque / reflective at grazing angles
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	alpha = clamp(alpha + fres * 0.25, 0.0, 1.0);

	// --- shoreline foam ---
	float fw = clamp(fwidth(vdepth), 0.02, 0.6);
	float edge_noise = vnoise(wpos.xz * 0.9 + vec2(t * 0.05, 0.0));
	// Thresholds are water DEPTH (m). Shores are gentle, so keep these small: a few cm of depth
	// is already ~0.5-1 m of horizontal distance from the waterline.
	float shore_w = 0.035 + 0.04 * edge_noise + 0.03 * ws;
	float foam = step(vdepth, max(shore_w, fw * 0.8)) * 0.85;

	// --- lapping lines: roll towards the shore, then fade ---
	float lap = water_wave.y * lap_speed;   // accumulated: (0.10 + 0.16 * wind + 0.05 * gust) cycles/s
	float range = (0.18 + 0.22 * ws) * lap_range;
	float wob = vnoise(wpos.xz * 0.12) * 0.5;       // bends the lines so they aren't parallel stripes
	float line_w = max(0.012 + 0.01 * ws, fw * 0.7);
	for (int i = 0; i < 2; i++) {
		float ph = fract(lap + float(i) * 0.5 + wob);
		float dl = 0.04 + range * (1.0 - ph);        // line depth shrinks -> moves to shore
		float env = smoothstep(0.0, 0.15, ph) * (1.0 - smoothstep(0.7, 1.0, ph));
		float segs = step(0.38 - 0.2 * ws, vnoise(wpos.xz * 0.30 + float(i) * 11.0 + vec2(0.0, wob * 3.0)));
		float line = step(abs(vdepth - dl), line_w) * env * segs * (0.45 + 0.35 * ws) * (1.0 - v_river);   // a lake's, not a river's
		foam = max(foam, line);
	}
	// light foam flecks on windy open water
	float fleck = step(0.86 - 0.08 * ws, vnoise(wpos.xz * 1.4 + water_wave.zw)) * step(0.5, ws) * (ws - 0.5) * 1.2;
	foam = clamp(max(foam, fleck * dk), 0.0, 1.0);

	ALBEDO = mix(col, foam_color, foam);
	ALPHA = mix(alpha, 1.0, foam * 0.9);
	ROUGHNESS = mix(0.10 + 0.25 * weather.y, 1.0, foam);
	SPECULAR = mix(0.9, 0.0, foam);
	METALLIC = 0.0;
	if (!FRONT_FACING) { // seen from below: flat murky colour, no foam
		ALBEDO = deep_color * darken;
		ALPHA = 0.55;
		ROUGHNESS = 0.3;
	}
}
