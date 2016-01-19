#ifdef VERTEX

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    return transform_projection * vertex_position;
}
#endif
 
#ifdef PIXEL

#define PI 3.14159265

uniform float progression = 0.0;
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec2 uv = texture_coords.xy;
    vec2 v = vec2(.5) - uv;
 
    float l = length(v) * 1.025;
    float p  = progression * PI * 2. - PI;
    p += (.5-l) * ( p)*2.;
    float f = atan((v.x),-v.y);
    f = step(l,.5) * smoothstep(f,f+.05,p);
	return vec4(vec3(25. / 255.),f);
}
#endif
