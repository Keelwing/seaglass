// Frost, closing: freezes from the edges, cracks from where the finger let go, and falls apart as snow.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    float M = maxDist(origin);
    vec3 white = tinted(vec3(0.9, 0.97, 1.0));
    // the break spreads from the finger from 0.5 on and reaches the farthest corner at about 0.9; the snow still
    // falling then fades out by the end
    float k = clamp((t - 0.5) / 0.5, 0.0, 1.0);
    float spread = 0.6 / M;
    float life = 0.4;
    vec4 base = vec4(0.0);
    if (part != 2.0) {
        // what is left of the ice: the flakes leave a little before it goes
        float left = 1.0;
        if (k > 0.0)
            left = snowField(p, o, spread) - k;
        float intact = smoothstep(-0.006, 0.006, left);
        vec4 c = src(uv);
        vec3 rgb = c.rgb;
        // the frost grows in from the window's edges: nothing at 0 (centred: the fractal channel averages 0.35),
        // all of it frozen by 0.42 and still moving when the cracks come
        vec4 W = originRect;
        vec2 wp = vec2((uv.x - W.x) * aspect, uv.y - W.y);
        vec2 ws = vec2(W.z * aspect, W.w);
        float ed = min(min(wp.x, ws.x - wp.x), min(wp.y, ws.y - wp.y));
        float n = fbm(p * 2.2) * 0.7 + fbm(p * 7.0) * 0.3;
        float grow = mix(-0.08, 0.4, clamp(t / 0.42, 0.0, 1.0));
        float fd = ed - grow + (n - 0.35) * 0.22 * smoothstep(0.0, 0.1, t);
        float frozen = 1.0 - smoothstep(-0.004, 0.004, fd);
        if (frozen > 0.0 && intact > 0.0) {
            vec4 b = blurSrc(uv, 10.0 * resolution.y / 1000.0);
            // thick along the edges it grew from, thin at the front, and thicker as it sets
            float thick = (1.0 - smoothstep(0.0, 0.16, ed + (n - 0.35) * 0.2)) * smoothstep(0.0, 0.06, -fd);
            float fr = frostPat(p, thick) * mix(0.6, 1.0, smoothstep(0.1, 0.5, t));
            rgb = mix(rgb, iced(b, fr) * b.a, frozen);
        }
        // a bright rime on the front while it grows
        float fdp = fd * resolution.y / 4.0;
        rgb += white * (exp(-fdp * fdp) * 0.6 + exp(-abs(fdp) / 5.0) * 0.15) * smoothstep(0.0, 0.05, t)
               * (1.0 - smoothstep(0.4, 0.5, t)) * c.a;
        if (t > 0.3) {
            // cracks run out from the finger: seven jagged rays, and between them a few thinner ones, broken up
            vec2 v = p - o;
            float r = length(v);
            float crackR = smoothstep(0.3, 0.48, t) * (M + 0.05);
            float a01 = atan(v.y, v.x) / (2.0 * PI) + 0.5;
            float sec = floor(a01 * 7.0);
            float rayA = (sec + 0.25 + 0.5 * hash(vec2(sec, 3.0))) / 7.0;
            float jr = r * 30.0;
            float wig = mix(hash(vec2(floor(jr), sec)), hash(vec2(floor(jr) + 1.0, sec)), fract(jr)) - 0.5;
            float dRay = abs((a01 - rayA) * 2.0 * PI * r - wig * 0.03 * min(r * 5.0, 1.0)) * resolution.y;
            float ray = (exp(-dRay * dRay / 1.5) + exp(-dRay / 4.0) * 0.3) * (1.0 - smoothstep(crackR - 0.03, crackR, r));
            float thin = (1.0 - smoothstep(0.0, 0.03, cells(p * 2.6 + 0.17))) * smoothstep(0.42, 0.62, fbm(p * 4.0 + 0.3))
                         * (1.0 - smoothstep(crackR * 0.7, crackR * 0.85, r));
            rgb += white * max(ray, thin * 0.7) * c.a;
        }
        // the edge where the ice crumbles shines a little
        rgb += white * exp(-left * left / 0.00006) * step(0.0, k - 0.001) * 0.5 * c.a;
        base = vec4(rgb, c.a) * intact;
    }
    vec4 fly = vec4(0.0);
    if (part != 1.0 && k > 0.0)
        fly = snow(uv, k, resolution.y / 140.0, o, spread, life, tinted(vec3(0.9, 0.96, 1.0)))
              * (1.0 - smoothstep(0.9, 1.0, t));
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
