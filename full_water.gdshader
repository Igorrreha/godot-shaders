shader_type canvas_item;

group_uniforms WaterCollision;
uniform sampler2D _wave_direction_texture : repeat_enable;
uniform sampler2D _wave_force_texture : repeat_enable;
uniform sampler2D _wave_sections_texture : repeat_enable;
uniform sampler2D _wave_sections_texture_pixelized : repeat_enable, filter_nearest;
uniform sampler2D _wave_texture : repeat_enable;

uniform float _collision_wave_loop_duration : hint_range(0.0, 10.0, 0.1);
uniform float _collision_wave_delta : hint_range(0.0, 1.0, 0.001);

uniform sampler2D _front_texture : repeat_enable;
uniform float _front_texture_loop_duration : hint_range(0.0, 5.0, 0.1);

uniform float _sections_transition_zone_length : hint_range(0.0, 1.0, 0.01);

group_uniforms Water;
uniform sampler2D _wave_texture_1 : repeat_enable;
uniform sampler2D _wave_texture_2 : repeat_enable;
uniform float _wave_1_direction_degrees : hint_range(0, 360, 1);
uniform float _wave_2_direction_degrees : hint_range(0, 360, 1);
uniform float _wave_loop_duration : hint_range(0.0, 10.0, 0.1);
uniform float _wave_delta : hint_range(0.0, 1.0, 0.001);
uniform float _toplight_clip_from : hint_range(-1.0, 1.0, 0.01);
uniform float _toplight_clip_to : hint_range(-1.0, 1.0, 0.01);

uniform vec4 _tone_color: source_color;

uniform bool _top_ligth_active;


vec2 rotate(vec2 uv, vec2 pivot, float angle) {
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)), vec2(cos(angle), sin(angle)));
	uv = (uv - pivot) * rotation + pivot;
	return uv;
}


vec2 get_wave_offset(float direction_degrees, sampler2D wave_texture, vec2 uv) {
	float wave_direction = radians(direction_degrees);
	vec2 time_offset = TIME / _wave_loop_duration * vec2(0, -1);
	float offset_force = texture(wave_texture, rotate(uv, vec2(0.5, 0.5), wave_direction)
		+ time_offset).r;
	return offset_force * vec2(cos(wave_direction), sin(wave_direction));
}


vec4 screen(vec4 base, vec4 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend * blend.a);
}


vec2 get_collision_wave_section_point(vec2 uv, float wave_force) {
	float section_value = texture(_wave_sections_texture, uv).r;
	float pixelized_section_value = texture(_wave_sections_texture_pixelized, uv).r;
	
	if (pixelized_section_value > 1.0 - _sections_transition_zone_length
	|| pixelized_section_value < _sections_transition_zone_length) {
		// section-to-section transition bugfix
		return vec2(pixelized_section_value, wave_force);
	}
	else {
		return vec2(section_value, wave_force);
	}
}


vec2 get_collision_wave_offset(vec2 uv, vec2 wave_direction, vec2 section_point,
		float wave_time_offset, float wave_force) {
	// calculate distortion value for main texture
	float uv_offset_force = (texture(_wave_texture, (section_point
		+ vec2(0.0, wave_time_offset))
		.yx).r * 2.0 - 1.0) * _collision_wave_delta * wave_force;
	
	return wave_direction * uv_offset_force;
}


vec4 get_collision_wave_addition_color(vec2 uv, vec2 section_point, float wave_time_offset,
		float wave_force) {
	// get front texture color
	float front_texture_time_offset = TIME / _front_texture_loop_duration;
	float front_texture_uv_offset_force = (texture(_wave_texture,
		(section_point + vec2(0.0, wave_time_offset)).yx).r
		* 2.0 - 1.0) * _collision_wave_delta * wave_force;
	vec4 front_color = texture(_front_texture, section_point
		+ vec2(0, front_texture_time_offset)
		- front_texture_uv_offset_force) * vec4(1, 1, 1, wave_force);
	
	return front_color;
}


void fragment() {
	float main_wave_influence = 1.0;
	
	vec4 collision_wave_addition_color = vec4(0, 0, 0, 0);
	vec2 collision_wave_offset = vec2(0, 0);
	float collision_wave_force = texture(_wave_force_texture, UV).b;
	
	// collision waves
	vec4 direction_texture_point = texture(_wave_direction_texture, UV);
	if (direction_texture_point.a > 0.0) {
		vec2 wave_direction = (direction_texture_point.xy - vec2(0.5, 0.5)) * 2.0;
		vec2 collision_wave_section_point = get_collision_wave_section_point(UV, collision_wave_force);
		
		float wave_time_offset = TIME / _collision_wave_loop_duration;
		
		collision_wave_offset = get_collision_wave_offset(UV, wave_direction,
			collision_wave_section_point, wave_time_offset, collision_wave_force);
		
		collision_wave_addition_color = get_collision_wave_addition_color(UV,
			collision_wave_section_point, wave_time_offset, collision_wave_force);
		
		main_wave_influence = 1.0 - collision_wave_force;
	}
	
	// water waves
	vec2 wave_offset = (get_wave_offset(_wave_1_direction_degrees, _wave_texture_1, UV)
		+ get_wave_offset(_wave_2_direction_degrees, _wave_texture_2, UV)) / 2.0;
	
	float wave_direction = radians(_wave_1_direction_degrees + _wave_2_direction_degrees) / 2.0;
	vec2 scaled_wave_offset = wave_offset * _wave_delta - _wave_delta
		* 0.5 * vec2(cos(wave_direction), sin(wave_direction))
		* main_wave_influence;
	
	// apply deformation
	vec4 deformed_water = texture(TEXTURE, UV + scaled_wave_offset + collision_wave_offset);
	
	// apply tone
	deformed_water *= _tone_color;
	
	// apply collision waves addition texture
	vec4 waved_water = screen(deformed_water, collision_wave_addition_color);

	// apply top light
	if (_top_ligth_active) {
		float light_value = smoothstep(_toplight_clip_from, _toplight_clip_to,
			(wave_offset.x + wave_offset.y) * main_wave_influence);
		waved_water = screen(waved_water, light_value * vec4(1, 1, 1, 1));
	}

	COLOR = waved_water;
}
