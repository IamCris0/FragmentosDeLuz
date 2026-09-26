shader_type spatial;
render_mode unshaded, cull_disabled;

uniform bool active = false;

void fragment() {
	vec2 p=(UV-.5)*2.;
	float r=length(p);
	if(r>1.)discard;
	float a=atan(p.y,p.x);
	float swirl=sin(a*4.-r*15.+TIME*(active?1.6:.45));
	float threads=pow(max(0.,sin(a*7.-r*24.+sin(r*17.+TIME)*.6+TIME)),12.);
	float rim=exp(-pow((r-.91)*22.,2.));
	float core=smoothstep(.1,.8,r);
	vec3 nebula=mix(vec3(.17,.06,.32),vec3(.015,.26,.30),swirl*.5+.5);
	vec3 color=vec3(.012,.026,.075)+nebula*core*.7+vec3(.14,.87,.79)*(rim+threads*core*.4);
	if(!active)color*=.24;
	ALBEDO=color;
	EMISSION=color*(active?2.2:.5);
}
