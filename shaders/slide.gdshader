// slide_transition.gdshader
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
uniform int transition_phase : hint_range(0, 1);
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec4 slide_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D screen_texture : source_color;

void fragment() {
    vec2 dir = normalize(direction);
    float slide_pos;

    if (abs(dir.x) > abs(dir.y)) {
        slide_pos = UV.x;
        if (dir.x < 0.0) slide_pos = 1.0 - UV.x;
    } else {
        slide_pos = UV.y;
        if (dir.y < 0.0) slide_pos = 1.0 - UV.y;
    }

    vec4 scene_color = texture(screen_texture, UV);

    if (transition_phase == 0) {
        // Slide out - da cena para preto
        if (slide_pos > progress) {
            COLOR = scene_color;
        } else {
            COLOR = slide_color;
        }
    } else {
        // Slide in - do preto para cena
        if (slide_pos > progress) {
            COLOR = slide_color;
        } else {
            COLOR = scene_color;
        }
    }
}