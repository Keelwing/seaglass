// Ember's fire: a heat (0 to 1) as a colour, natural or in the ambience's colour
vec3 fire(float h)
{
    vec3 c = mix(vec3(0.0), vec3(0.55, 0.06, 0.0), smoothstep(0.0, 0.25, h));
    c = mix(c, vec3(1.0, 0.42, 0.05), smoothstep(0.2, 0.55, h));
    c = mix(c, vec3(1.0, 0.82, 0.32), smoothstep(0.5, 0.8, h));
    c = mix(c, vec3(1.0, 0.98, 0.88), smoothstep(0.8, 1.0, h));
    vec3 a = mix(vec3(0.0), tint * 0.55, smoothstep(0.0, 0.35, h));
    a = mix(a, tint * 1.05, smoothstep(0.3, 0.7, h));
    a = mix(a, vec3(1.0), smoothstep(0.78, 1.0, h));
    return mix(c, a, useTint);
}
