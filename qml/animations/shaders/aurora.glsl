// Northern lights: the aurora's colours by height, and its rays
vec3 aurora(float h)
{
    vec3 c = mix(vec3(0.22, 0.98, 0.62), vec3(0.12, 0.86, 0.86), smoothstep(0.0, 0.35, h));
    c = mix(c, vec3(0.62, 0.38, 1.0), smoothstep(0.35, 0.95, h));
    vec3 a = mix(tint * 1.1, mix(tint, vec3(0.62, 0.42, 1.0), 0.55), smoothstep(0.2, 0.95, h));
    return mix(c, a, useTint);
}
float rays(vec2 p, float tt)
{
    float fold = fbm(vec2(p.x * 0.7 + tt * 0.05, tt * 0.11)) - 0.5;
    float x = p.x + fold * 0.6;
    float r = fbm(vec2(x * 5.0, p.y * 0.18 + tt * 0.04));
    float fine = vnoise(vec2(x * 21.0, tt * 0.25));
    return clamp(pow(r, 1.6) * 2.4 * (0.55 + 0.7 * fine), 0.0, 1.7);
}
