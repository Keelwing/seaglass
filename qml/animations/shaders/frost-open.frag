// Frost, opening: the ice melts from the icon outward.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    float appear = smoothstep(0.0, 0.14, t);
    float tm = clamp((t - 0.12) / 0.88, 0.0, 1.0);
    float r = length(p - o);
    float n = fbm(p * 2.5);
    float R = easeInOut(tm) * (maxDist(origin) + 0.15);
    float x = r - R + (n - 0.5) * 0.14;
    float melted = 1.0 - smoothstep(-0.015, 0.0, x);
    float wet = exp(-x * x * 500.0);
    vec2 dir = normalize(p - o + vec2(0.0001));
    vec4 clear = src(uv - vec2(dir.x / aspect, dir.y) * wet * 0.012);
    vec4 b = blurSrc(uv, 14.0 * resolution.y / 1000.0);
    float fr = frostPat(p);
    vec3 ice = iced(b, fr) * b.a;
    float drop = smoothstep(0.72, 0.9, vnoise(p * 30.0)) * wet;
    vec2 g = floor(uv * resolution / 2.0);
    float sp = step(0.993, hash(g)) * (0.5 + 0.5 * sin(time * 8.0 + hash(g + 5.0) * 30.0)) * (1.0 - melted);
    vec3 rgb = mix(ice, clear.rgb, melted) + vec3(0.9, 0.97, 1.0) * (exp(-x * x * 8000.0) * 0.6 + drop * 0.5 + sp * 0.7);
    float a = mix(b.a, clear.a, melted);
    FRAG_COLOR = vec4(rgb, a) * appear * qt_Opacity;
}
