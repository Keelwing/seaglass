// Volt, opening: lightning strikes the icon and lights up the screen around it; an electric ring opens the app.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    // the bolt's shape follows where it strikes, not the clock (it would change every frame)
    float seed = fract(origin.x * 97.0 + origin.y * 13.0);
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    vec3 light = vec3(0.0);
    if (t < 0.42) {
        // the leader runs down from the top edge, the branches leaving it as it passes; then the bolt flickers and
        // fades
        vec2 top = vec2(o.x + (hash(vec2(seed * 256.0, 9.0)) - 0.5) * 0.25, 0.0);
        float lead = min(1.0, t / 0.16);
        float flick = 0.75 + 0.25 * hash(vec2(floor(time * 30.0), 2.0));
        float boltI = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.24, 0.42, t)) * flick;
        float side = sign(hash(vec2(seed * 256.0, 1.0)) - 0.5);
        vec2 m1 = boltAt(top, o, seed, 1.0, 0.38);
        vec2 m2 = boltAt(top, o, seed, 1.0, 0.64);
        vec2 e1 = m1 + vec2(0.11 * side, 0.15);
        vec2 e2 = m2 + vec2(-0.06 * side, 0.08);
        float core, c1, c2;
        float g = bolt(p, top, o, seed, lead, 1.0, core);
        float g1 = bolt(p, m1, e1, fract(seed + 0.21), clamp((lead - 0.38) / 0.3, 0.0, 1.0), 0.6, c1);
        float g2 = bolt(p, m2, e2, fract(seed + 0.43), clamp((lead - 0.64) / 0.2, 0.0, 1.0), 0.4, c2);
        // the branches fade towards their ends
        float f1 = 1.0 - clamp(dot(p - m1, e1 - m1) / dot(e1 - m1, e1 - m1), 0.0, 1.0);
        float f2 = 1.0 - clamp(dot(p - m2, e2 - m2) / dot(e2 - m2, e2 - m2), 0.0, 1.0);
        light = (elec * (g + g1 * f1 * 0.7 + g2 * f2 * 0.5) * 1.4 + vec3(1.0) * (core + c1 * f1 * 0.6 + c2 * f2 * 0.4) * 1.5) * boltI;
    }
    vec2 v = p - o;
    float r = length(v);
    // the strike lights the screen a little, most of all around the icon (a full-screen white is too much)
    float ft = (t - 0.16) / 0.035;
    float flash = exp(-ft * ft);
    float tb = clamp((t - 0.14) / 0.86, 0.0, 1.0);
    // nearly linear, so that the front leaves the farthest corner at about 0.92, not at 0.6
    float R = mix(tb, easeOutCubic(tb), 0.35) * (maxDist(origin) + 0.06);
    float a01 = atan(v.y, v.x) / (2.0 * PI) + 0.5;
    // the front is jagged, its fine jags crackling with the clock. They grow with the ring up to a point (a small ring
    // as jagged as a large one is a star); a few coarse ones keep even a small ring from being a circle
    float jagged = (ringJag(a01, 64.0, seed) * 0.7 + ringJag(a01, 181.0, fract(seed + 0.3 + floor(time * 20.0) * 0.137)) * 0.3)
                   * min(R / 0.45, 1.0) + ringJag(a01, 11.0, fract(seed + 0.6)) * 0.5 * smoothstep(0.0, 0.1, R);
    float x = r - R + jagged * 0.022;
    float inside = 1.0 - smoothstep(-0.003, 0.003, x);
    // faint colour fringes only just behind the front (wider ones look like a broken display)
    float ca = exp(min(x, 0.0) * 60.0) * 0.002 * (1.0 - tb);
    vec2 dir = v / max(r, 0.0001);
    vec2 duv = vec2(dir.x / aspect, dir.y) * ca;
    vec4 cg = src(uv);
    vec4 c = vec4(src(uv + duv).r, cg.g, src(uv - duv).b, cg.a);
    // the front as a discharge: a thin core and glow like the bolts, broken into arcs. The wide glow follows the ring
    // without its jags, which would draw it out into rays
    float xp = x * resolution.y;
    float xr = (r - R) * resolution.y;
    float brk = smoothstep(0.2, 0.45, fbm(vec2(a01 * 3.0 + seed * 7.0, tb * 0.7)));
    float front = (exp(-xp * xp / 2.2) * 1.2 + exp(-abs(xp) / 10.0) * 0.55 + exp(-abs(xr) / 45.0) * 0.2) * (0.35 + 0.65 * brk);
    light += elec * front * 1.4 * (1.0 - smoothstep(0.85, 1.0, tb)) * step(0.001, tb)
             + vec3(0.85, 0.92, 1.0) * flash * (0.04 + 0.4 * exp(-r * 4.5));
    FRAG_COLOR = vec4(c.rgb * inside + light, c.a * inside) * qt_Opacity;
}
