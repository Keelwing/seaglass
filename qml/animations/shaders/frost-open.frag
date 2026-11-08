// Frost, opening: frost forms over the screen, and the ice melts away from the icon outward.
uniform sampler2D fieldTex;
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    float r = length(p - o);
    // read here, not baked: 8 bits of it would terrace the melting edge
    float n = fbm(p * 2.5);
    // nearly linear (the fractal channel averages 0.35), and on to the end, so that the last ice goes at about 0.92
    float tm = clamp((t - 0.1) / 0.9, 0.0, 1.0);
    float R = (0.85 * tm + 0.15 * tm * tm) * (maxDist(origin) + 0.11);
    float x = r - R + (n - 0.35) * 0.14 * smoothstep(0.0, 0.1, R);
    float melted = 1.0 - smoothstep(-0.015, 0.0, x);
    // the wet edge fades out at the end, so that the app is as it is at 1
    float fadeWet = 1.0 - smoothstep(0.9, 1.0, t);
    float xx = x * x * 500.0;
    float wet = xx < 7.5 ? exp(-xx) * fadeWet : 0.0;
    vec2 ruv = uv;
    if (wet > 0.0) {
        vec2 dir = normalize(p - o + vec2(0.0001));
        ruv = uv - vec2(dir.x / aspect, dir.y) * wet * 0.012;
    }
    // the app only where the ice has begun to go, and a little beyond: its mip level comes from neighbouring pixels,
    // and at the edge of a branch that is undefined
    vec4 clear = vec4(0.0);
    if (x < 4.0 / resolution.y)
        clear = src(ruv);
    vec3 rgb = clear.rgb;
    float a = clear.a;
    // the ice only where it has not melted yet: most of the screen, early on, and less and less of it
    if (melted < 0.999) {
        // thick along the screen's edges, as on a frozen pane
        vec2 e = min(uv, 1.0 - uv) * vec2(aspect, 1.0);
        float thick = 1.0 - smoothstep(0.0, 0.16, min(e.x, e.y) + (n - 0.35) * 0.2);
        // the ice crystallises: the drifts along the edges first, then the rest in patches (by smooth noise: a sharp
        // edge on the frost pattern itself shows its fine noise's squares)
        float order = clamp(thick * 0.6 + (n - 0.35) * 0.9 + 0.3, 0.0, 1.0);
        float formed = smoothstep(0.0, 0.35, smoothstep(0.0, 0.14, t) * 1.35 - (1.0 - order));
        vec3 ice = vec3(0.0);
        float ia = 0.0;
        // where it has not formed yet there is nothing to blur
        if (formed > 0.0) {
            vec4 b = blurSrc(uv, 14.0 * resolution.y / 1000.0);
            float fr = frostFrom(texture2D(fieldTex, uv), thick);
            ice = iced(b, fr) * b.a;
            // a sparkle in one cell in 140
            if (fr > 0.5) {
                vec2 g = floor(uv * resolution / 2.0);
                if (hash(g) >= 0.993) {
                    float sp = (0.5 + 0.5 * sin(time * 8.0 + hash(g + 5.0) * 30.0)) * smoothstep(0.5, 0.8, fr);
                    ice += tinted(vec3(0.9, 0.97, 1.0)) * sp * 0.7 * b.a;
                }
            }
            ia = b.a;
        }
        rgb = mix(ice * formed, clear.rgb, melted);
        a = mix(ia * formed, clear.a, melted);
    }
    // drops on the wet edge, here and there: one in a few cells of 12 pixels, each where it fell in its cell
    float drop = 0.0;
    if (wet > 0.0) {
        vec2 dc = uv * resolution / 12.0;
        vec2 di = floor(dc);
        vec2 dp = vec2(hash(di + 7.0), hash(di + 13.0)) * 0.6 + 0.2;
        drop = step(0.75, hash(di + 3.0)) * (1.0 - smoothstep(0.06, 0.06 + 0.12 * hash(di + 21.0), length(fract(dc) - dp))) * wet;
    }
    // a thin bright rim of wet ice on the front, below a hundred-thousandth of a level past 320 pixels
    float xp = x * resolution.y / 4.0;
    float rim = 0.0;
    if (abs(xp) < 80.0)
        rim = (exp(-xp * xp) * 0.5 + exp(-abs(xp) / 5.0) * 0.12) * fadeWet;
    rgb += vec3(0.9, 0.97, 1.0) * (rim + drop * 0.5) * a;
    FRAG_COLOR = vec4(rgb, a) * qt_Opacity;
}
