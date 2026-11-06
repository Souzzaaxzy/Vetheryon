// Terreno do Vetheryon: mesma base do shader do LowLand Forge (cor por célula de
// 2 m, lida do atlas `facets`), com dois acréscimos para tirar a "cara de desenho":
//   * encostas viram rocha em vez de grama;
//   * um ruído fino quebra a cor chapada de cada célula.
// Mantido em `src/` para não alterar o addon de terceiros.
shader_type spatial;

uniform sampler2D facets : source_color, filter_nearest, repeat_disable;
uniform float cell = 2.0;
uniform sampler2D noise_tex : hint_default_white, filter_linear, repeat_enable;
uniform float detail_strength = 0.16;
uniform float detail_scale = 0.22;
uniform float rock_slope = 0.55;
uniform vec3 rock_color : source_color = vec3(0.30, 0.29, 0.27);

varying vec3 local_pos;
varying vec3 world_pos;


void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 c = local_pos.xz / cell;
	vec2 ci = floor(c);
	vec2 f = c - ci;
	int t = f.x + f.y > 1.0 ? 1 : 0;
	ivec2 size = textureSize(facets, 0);
	ivec2 px = clamp(ivec2(int(ci.x) * 2 + t, int(ci.y)), ivec2(0), size - 1);
	vec3 ground = texelFetch(facets, px, 0).rgb;

	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VERTEX) > 0.0 ? -n : n;

	// Faces inclinadas (falésias) leem como rocha.
	float slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	float rock = smoothstep(rock_slope, rock_slope + 0.25, slope);
	// Ruído fino quebra a cor chapada de cada célula.
	float d = texture(noise_tex, world_pos.xz * detail_scale).r - 0.5;
	vec3 col = mix(ground, rock_color, rock);
	col *= 1.0 + d * detail_strength;

	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.85, rock);
}
