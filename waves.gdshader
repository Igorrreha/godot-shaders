shader_type canvas_item;

uniform sampler2D _wave_direction_texture : repeat_enable;
uniform sampler2D _wave_force_texture : repeat_enable;
uniform sampler2D _wave_sections_texture : repeat_enable;
uniform sampler2D _wave_sections_texture_pixelized : repeat_enable, filter_nearest;
uniform sampler2D _wave_texture : repeat_enable;

uniform float _wave_loop_duration : hint_range(0.0, 5.0, 0.1);
uniform float _wave_delta : hint_range(0.0, 1.0, 0.001);

uniform sampler2D _front_texture : repeat_enable;
uniform float _front_texture_loop_duration : hint_range(0.0, 5.0, 0.1);

uniform float _sections_transition_zone_length : hint_range(0.0, 1.0, 0.01);


vec4 screen(vec4 base, vec4 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend * blend.a);
}


void fragment() {
	vec4 direction_texture_point = texture(_wave_direction_texture, UV);
	if (direction_texture_point.a > 0.0) {
		// get textures data
		vec2 wave_direction = (direction_texture_point.xy - vec2(0.5, 0.5)) * 2.0;
		float wave_force = texture(_wave_force_texture, UV).b;
		
		float section_value = texture(_wave_sections_texture, UV).r;
		float pixelized_section_value = texture(_wave_sections_texture_pixelized, UV).r;
		vec2 section_point;
		if (pixelized_section_value > 1.0 - _sections_transition_zone_length
		|| pixelized_section_value < _sections_transition_zone_length) {
			// section-to-section transition bugfix
			section_point = vec2(pixelized_section_value, wave_force);
		}
		else {
			section_point = vec2(section_value, wave_force);
		}
		
		// calculate distortion value for main texture
		float wave_time_offset = TIME / _wave_loop_duration;
		float uv_offset_force = (texture(_wave_texture, (section_point
			+ vec2(0.0, wave_time_offset))
			.yx).r * 2.0 - 1.0) * _wave_delta * wave_force;
		
		// get front texture color
		float front_texture_time_offset = TIME / _front_texture_loop_duration;
		float front_texture_uv_offset_force = (texture(_wave_texture,
			(section_point + vec2(0.0, wave_time_offset)).yx).r
			* 2.0 - 1.0) * _wave_delta * wave_force;
		vec4 front_color = texture(_front_texture, section_point
			+ vec2(0, front_texture_time_offset)
			- front_texture_uv_offset_force) * vec4(1, 1, 1, wave_force);
		
		// apply color
		COLOR = screen(texture(TEXTURE, UV + wave_direction * uv_offset_force), front_color);
	}
}
