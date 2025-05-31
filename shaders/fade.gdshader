// fade_transition.gdshader
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
//uniform int transition_phase : hint_range(0, 1); // 0 = fade out, 1 = fade in
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D screen_texture : source_color;

void fragment() {
    vec4 scene_color = texture(screen_texture, UV);
    COLOR = mix(scene_color, fade_color, progress);
}