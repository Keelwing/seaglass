// Frost: the frost pattern, and a picture turned to ice
float frostPat(vec2 p)
{
    float f = fbm(p * 2.3) * 0.5 + fbm(p * 7.1 + 0.37) * 0.3 + fbm(p * 15.0 + 0.71) * 0.2;
    float e = (1.0 - smoothstep(0.0, 0.04, cells(p * 2.9 + 0.11))) * smoothstep(0.45, 0.7, fbm(p * 3.3 + 0.5));
    float fine = vnoise(p * 31.0);
    return clamp(f + e * 0.3 + fine * 0.15 - 0.1, 0.0, 1.0);
}
vec3 iced(vec4 b, float fr)
{
    vec3 c = b.rgb / max(b.a, 0.001);
    vec3 base = mix(vec3(luma(c)), c, 0.3) * vec3(0.8, 0.92, 1.08) + vec3(0.12, 0.17, 0.24);
    return mix(base, tinted(vec3(0.88, 0.95, 1.0)), fr * 0.7);
}
