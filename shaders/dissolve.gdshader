// dissolve_transition.gdshader
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
uniform int transition_phase : hint_range(0, 1);
uniform float noise_scale : hint_range(1.0, 50.0) = 10.0;
uniform vec4 dissolve_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D screen_texture : source_color;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 scene_color = texture(screen_texture, UV);
    float noise_value = rand(UV * noise_scale);

    if (transition_phase == 0) {
        // Dissolve out - da cena para preto
        if (noise_value > progress) {
            COLOR = scene_color;
        } else {
            COLOR = dissolve_color;
        }
    } else {
        // Dissolve in - do preto para cena
        if (noise_value > progress) {
            COLOR = dissolve_color;
        } else {
            COLOR = scene_color;
        }
    }
}