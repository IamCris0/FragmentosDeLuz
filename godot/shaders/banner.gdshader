shader_type spatial;
render_mode cull_disabled;
uniform vec4 dye : source_color = vec4(.10,.32,.34,1);
void vertex() {
    float free_edge = UV.y;
    VERTEX.z += (sin(TIME*2.2+UV.x*5.0+UV.y*3.0)*.11+sin(TIME*.7+UV.y*8.0)*.07)*free_edge*free_edge;
}
void fragment() {
    float border = step(UV.x,.075)+step(.925,UV.x)+step(.94,UV.y);
    vec2 p = (UV-vec2(.5,.42))*vec2(1.,.8);
    float diamond = abs(abs(p.x)+abs(p.y)-.16);
    float insignia = 1.-smoothstep(.01,.025,diamond);
    ALBEDO = mix(dye.rgb,vec3(.72,.56,.25),clamp(border+insignia,0.,1.));
    ROUGHNESS=.95;
}
