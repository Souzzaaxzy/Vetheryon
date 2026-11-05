shader_type sky;

// Céu do Vetheryon: dia azul com sol, noite azul-escura com estrelas e lua.
// O `day` (0 noite .. 1 dia) e as direções do sol/lua vêm do script day_night.gd.

uniform vec3 sun_dir = vec3(0.0, 0.6, 0.8);
uniform vec3 moon_dir = vec3(0.0, -0.6, -0.8);
uniform float day = 1.0;

uniform vec3 day_zenith : source_color = vec3(0.16, 0.40, 0.88);
uniform vec3 day_horizon : source_color = vec3(0.60, 0.78, 0.98);
uniform vec3 night_zenith : source_color = vec3(0.01, 0.02, 0.07);
uniform vec3 night_horizon : source_color = vec3(0.04, 0.06, 0.14);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.80);
uniform vec3 moon_color : source_color = vec3(0.85, 0.88, 0.98);
uniform float star_amount = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);

	vec3 day_col = mix(day_horizon, day_zenith, smoothstep(0.42, 0.92, h));
	vec3 night_col = mix(night_horizon, night_zenith, smoothstep(0.42, 0.92, h));
	vec3 col = mix(night_col, day_col, day);

	// Estrelas: só à noite e acima do horizonte.
	float night = 1.0 - day;
	if (night > 0.01 && dir.y > 0.0) {
		vec3 cell = floor(dir * 260.0);
		float s = hash13(cell);
		float star = smoothstep(0.9970, 1.0, s);
		// brilho com um leve cintilar
		float tw = 0.7 + 0.3 * hash13(cell + vec3(7.0, 3.0, 1.0));
		col += vec3(0.9, 0.93, 1.0) * star * tw * night * star_amount * smoothstep(0.0, 0.25, dir.y);
	}

	// Sol: disco + brilho.
	float sd = dot(dir, normalize(sun_dir));
	float sun_disk = smoothstep(0.9993, 0.99985, sd);
	float sun_glow = pow(max(sd, 0.0), 350.0) * 0.6;
	col += sun_color * (sun_disk * 3.0 + sun_glow) * day;

	// Lua: disco mais suave.
	float md = dot(dir, normalize(moon_dir));
	float moon_disk = smoothstep(0.9991, 0.99975, md);
	float moon_glow = pow(max(md, 0.0), 600.0) * 0.25;
	col += moon_color * (moon_disk * 1.6 + moon_glow) * night;

	COLOR = col;
}
