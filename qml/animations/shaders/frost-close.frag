// Frost, closing: freezes from the edges, cracks and falls as snow.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec4 W = originRect;
    vec2 wp = vec2((uv.x - W.x) * aspect, uv.y - W.y);
    vec2 ws = vec2(W.z * aspect, W.w);
    float ed = min(min(wp.x, ws.x - wp.x), min(wp.y, ws.y - wp.y));
    float n = fbm(p * 2.2) * 0.7 + fbm(p * 7.0) * 0.3;
    float grow = smoothstep(0.0, 0.5, t) * 0.62;
    float fd = ed - grow + (n - 0.5) * 0.22;
    float frozen = 1.0 - smoothstep(-0.01, 0.01, fd);
    vec4 c = src(uv);
    vec4 b = blurSrc(uv, 10.0 * resolution.y / 1000.0);
    float fr = frostPat(p);
    vec3 iceS = iced(b, fr);
    vec3 rgb = mix(c.rgb, iceS * b.a, frozen);
    float front = exp(-pow(fd * 60.0, 2.0)) * (1.0 - smoothstep(0.45, 0.55, t));
    rgb += vec3(0.85, 0.95, 1.0) * front * 0.6 * c.a;
    float ck = 1.0 - smoothstep(0.0, 0.03, cells(p * 1.3 + 0.17));
    float crackI = smoothstep(0.42, 0.52, t);
    rgb += vec3(0.9, 0.97, 1.0) * ck * crackI * (1.2 - smoothstep(0.55, 0.7, t)) * c.a;
    float k = clamp((t - 0.52) / 0.48, 0.0, 1.0);
    float gp = max(3.0, resolution.y / 180.0);
    vec4 sw = vec4(0.25, -1.0, 0.35, 0.4);
    vec3 tone = tinted(vec3(0.86, 0.94, 1.0));
    float s0 = grainStart(floor(uv * resolution / gp), gp, sw, 0.12);
    vec4 fly = grains(uv, k, gp, sw, 0.12, vec2(0.05, 1.0), vec2(0.0, 3.2), 0.36, tone, 0.75);
    float intact = k <= 0.0 ? 1.0 : step(k, s0);
    vec4 base = vec4(rgb, c.a) * intact;
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
