// Volt, loading: arcs run around the cover; now and then a bolt strikes the icon.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    vec2 v = px - resolution * 0.5;
    // the jags crackle: a new fine shape 24 times a second, the coarse one turning into the next one
    float tick = floor(time * 24.0);
    float glow = 0.0;
    float core = 0.0;
    // an arc stays within 33 pixels of the edge and a branch within 78: past 150 their glows are below half a level
    if (-d < 150.0) {
        // around the cover, 0 to 1 (by the angle in the cover's own proportions, so that the sides are not squeezed)
        float a01 = atan(v.y / resolution.y, v != vec2(0.0) ? v.x / resolution.x : 1.0) / (2.0 * PI) + 0.5;
        float morph = fract(time * 5.0);
        float sA = floor(time * 5.0) * 0.137;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            // three arcs, each a leap between two points of the edge that travels around it, the middle one the other
            // way
            float dirn = 1.0 - 2.0 * step(0.5, fi) * step(fi, 1.5);
            float head = fract(dirn * time * (0.2 + 0.06 * fi) + fi * 0.33);
            float len = 0.045 + 0.02 * fi;
            float u = (fract(a01 - head + 0.5) - 0.5) * dirn / len + 1.0;
            if (u >= 0.0 && u <= 1.0) {
                float env = max(sin(PI * u), 0.0);
                float coarse = mix(ringJag(a01, 48.0, fract(sA + fi * 0.31)), ringJag(a01, 48.0, fract(sA + 0.137 + fi * 0.31)),
                                   smoothstep(0.0, 1.0, morph));
                float fine = ringJag(a01, 160.0, fract(tick * 0.017 + fi * 0.29));
                float path = 4.0 + env * (16.0 + coarse * 20.0) + fine * 5.0 * pow(env, 0.6);
                float w = abs(-d - path);
                core += exp(-w * w / 1.6) * env;
                glow += (exp(-w / 4.0) * 0.6 + exp(-w / 16.0) * 0.25) * env;
                // a branch forks off it towards the middle, thinning out to its tip
                float bu = (u - 0.3 - 0.1 * fi) / 0.4;
                if (bu >= 0.0 && bu < 1.0) {
                    float bpath = path + bu * (22.0 + 10.0 * fi) + ringJag(a01, 160.0, fract(tick * 0.023 + fi * 0.41)) * 6.0 * bu;
                    float wb = abs(-d - bpath);
                    core += exp(-wb * wb / 1.2) * (1.0 - bu) * 0.8;
                    glow += exp(-wb / 4.0) * 0.4 * (1.0 - bu);
                }
            }
        }
    }
    // a strike every 1.1 s, at a different moment of each: the bolt, a flash as it reaches the icon and a second one
    // after it, an afterglow
    float cyc = 1.1;
    float n = floor(time / cyc);
    float ds = time - n * cyc - (0.1 + 0.55 * hash(vec2(n, 3.0)));
    float s1 = (ds - 0.03) / 0.025;
    float s2 = (ds - 0.16) / 0.035;
    float strike = exp(-s1 * s1) + 0.6 * exp(-s2 * s2);
    float shown = smoothstep(-0.02, 0.0, ds) * (1.0 - smoothstep(0.18, 0.34, ds));
    vec2 ic = vec2(0.5 * aspect, 0.5);
    vec3 bolts = vec3(0.0);
    if (shown > 0.0) {
        // from a point of the edge to the icon's rim, with a branch
        float ang = hash(vec2(n, 5.0)) * 2.0 * PI;
        vec2 dn = vec2(cos(ang), sin(ang));
        vec2 a = vec2(0.5) + dn * 0.47 / max(abs(dn.x), abs(dn.y));
        a = asp(a);
        vec2 b = ic + normalize(a - ic) * 0.19 * aspect;
        float seed = fract(n * 0.0731 + 0.4);
        float c0, c1;
        // it runs from the edge in 30 ms
        float g0 = bolt(p, a, b, seed, clamp(ds / 0.03, 0.0, 1.0), 1.0, c0);
        vec2 m = boltAt(a, b, seed, 1.0, 0.45);
        vec2 e = m + (b - a) * 0.3 + vec2(-(b - a).y, (b - a).x) * 0.35 * sign(hash(vec2(n, 6.0)) - 0.5);
        float g1 = bolt(p, m, e, fract(seed + 0.21), clamp((ds - 0.012) / 0.03, 0.0, 1.0), 0.6, c1)
                   * (1.0 - clamp(length(p - m) / length(e - m), 0.0, 1.0));
        float flick = 0.6 + 0.4 * hash(vec2(tick, 4.0));
        float boltI = shown * flick * (0.5 + strike);
        bolts = elec * (g0 + g1 * 0.6) * 1.3 * boltI + vec3(1.0) * (c0 + c1 * 0.5) * boltI;
    }
    vec4 icon = vec4(0.0);
    vec2 box = abs(v) / (0.44 * resolution.x);
    if (box.x <= 0.5 && box.y <= 0.5) {
        icon = iconAt(vec2(0.5, 0.5), 0.44 * resolution.x, vec2(0.0));
        // a cool light on the icon, brighter at a strike (not so bright that it turns white)
        icon.rgb = icon.rgb * (0.8 + 0.2 * strike) + elec * icon.a * (0.08 + 0.3 * strike);
    }
    vec3 bg = vec3(0.04, 0.06, 0.12) + elec * (0.06 * exp(-length(v) / (0.35 * resolution.x)) + 0.05 * strike);
    vec4 col = icon + vec4(bg * 0.8, 0.8) * (1.0 - icon.a);
    col.rgb += elec * (glow * 1.3 + 0.2 * strike * glow) + vec3(1.0) * core * 0.9 + bolts;
    col.a = max(col.a, clamp(glow, 0.0, 1.0));
    FRAG_COLOR = col * inside * qt_Opacity;
}
