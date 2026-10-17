// Volt, opening: lightning strikes the icon; the app lights up.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    float seed = floor(time * 22.0) * 0.0391;
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    float ta = clamp(t / 0.22, 0.0, 1.0);
    vec2 top = vec2(o.x + (hash(vec2(3.0, 9.0)) - 0.5) * 0.25, 0.0);
    float leadY = o.y * min(1.0, ta * 1.4);
    float core;
    float g = boltGlow(p, top, o, seed, core);
    float s1 = 0.38;
    vec2 m1 = vec2(mix(top.x, o.x, s1) + boltX(o.y * s1, seed) * pow(sin(PI * s1), 0.6), o.y * s1);
    vec2 e1 = m1 + vec2(0.11 * sign(hash(vec2(floor(time * 22.0), 1.0)) - 0.5), 0.15);
    float c1;
    float g1 = boltGlow(p, m1, e1, seed + 0.21, c1);
    float f1 = 1.0 - clamp((p.y - m1.y) / (e1.y - m1.y), 0.0, 1.0);
    float vis = step(p.y, leadY + 0.002);
    float boltI = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.24, 0.42, t)) * vis * (0.75 + 0.25 * hash(vec2(floor(time * 30.0), 2.0)));
    float flash = exp(-pow((t - 0.17) / 0.05, 2.0)) * 0.5;
    float tb = clamp((t - 0.14) / 0.86, 0.0, 1.0);
    vec2 v = p - o;
    float r = length(v);
    float R = easeOutCubic(tb) * (maxDist(origin) + 0.05);
    float x = r - R;
    float inside = 1.0 - smoothstep(-0.004, 0.004, x);
    float ca = exp(min(x, 0.0) * 10.0) * 0.012 * (1.0 - tb);
    vec2 dir = v / max(r, 0.0001);
    vec2 duv = vec2(dir.x / aspect, dir.y) * ca;
    vec4 cg = src(uv);
    vec4 c = vec4(src(uv + duv).r, cg.g, src(uv - duv).b, cg.a);
    float ang = atan(v.y, v.x);
    float web = 1.0 - abs(fbm(vec2(ang * 0.8 + seed, r * 2.0)) - 0.5) * 2.0;
    float arcs = smoothstep(0.93, 1.0, web) * exp(-x * x * 900.0) + exp(-x * x * 20000.0) * 0.8;
    vec3 light = elec * ((g + g1 * f1 * 0.7) * boltI * 1.4) + vec3(1.0) * (core + c1 * f1 * 0.6) * boltI * 1.5
                          + elec * arcs * 1.6 * (1.0 - smoothstep(0.85, 1.0, tb)) * step(0.001, tb) + vec3(0.85, 0.92, 1.0) * flash;
    FRAG_COLOR = vec4(c.rgb * inside + light, c.a * inside) * qt_Opacity;
}
