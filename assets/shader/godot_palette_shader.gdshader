shader_type canvas_item;

uniform sampler2D palette : hint_default_transparent;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment(){
  int palette_size = textureSize(palette, 0).x;
  vec4 color = texture(screen_texture, SCREEN_UV);
  vec4 new_color = vec4(.0);

  for (int i = 0; i < palette_size; i++) {
    float color_uv_width = 1.0 / float(palette_size);
    float palette_uv_x = color_uv_width * (float(i) + 0.5);
    float palette_uv_y = 0.5;
    
    vec4 palette_color = texture(palette, vec2(palette_uv_x, palette_uv_y));
    if (distance(palette_color, color) < distance(new_color, color)) {
      new_color = palette_color;
    }
  }

  COLOR = new_color;
}
