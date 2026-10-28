// Ember, closing: burns away from the bottom up.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    float nl = fbm(p * 0.9);
    float n = nl * 0.7 + fbm(p * 2.7 + 0.31) * 0.3;
    float base = (originRect.y + originRect.w - uv.y) / originRect.w;
    // the fractal channel averages 0.35, not 0.5. Nothing charred at 0, still burning at the top at 0.85, gone at 0.94
    float h = base + (n - 0.35) * 0.30;
    float level = mix(-0.21, 1.07, clamp(t / 0.94, 0.0, 1.0));
    float d = level - h;
    // the large front alone, which the flames follow
    float dl = level - (base + (nl - 0.35) * 0.21);
    // heat haze and sparks come up with the fire, so that the window is as it was at 0
    float lit = smoothstep(0.0, 0.08, t);
    float haze = smoothstep(-0.35, 0.0, d) * (1.0 - smoothstep(0.0, 0.02, d)) * lit;
    // the haze shimmers unevenly and rises (a plain sine shows as a regular wave on straight edges)
    float sh = vnoise(vec2(p.x * 4.0, p.y * 4.0 + time * 2.0)) - 0.5;
    vec2 suv = uv + vec2(sin(uv.y * 70.0 + time * 18.0 + sh * 4.0), sh) * 0.0035 * haze;
    vec4 c = src(suv);
    float charA = smoothstep(-0.07, -0.005, d);
    vec3 rgb = mix(c.rgb, tinted(vec3(0.10, 0.045, 0.02)) * c.a, charA);
    float alive = 1.0 - smoothstep(0.0, 0.012, d);
    float ed = (d - 0.004) / 0.012;
    float edge = exp(-ed * ed);
    // flames from fractal noise (value noise shows squares), only along the large front: a scrap left behind chars
    // with a glowing rim instead of filling with flame
    float fl = fbm(vec2(p.x * 2.2, p.y * 1.1 + time * 1.4));
    float fl2 = fbm(vec2(p.x * 5.0 + 0.37, p.y * 2.2 + time * 2.6));
    float flameH = 0.06 + 0.30 * fl * fl2;
    float flame = clamp(1.0 + dl / flameH, 0.0, 1.0) * step(d, 0.02) * (1.0 - smoothstep(0.0, 0.06, dl))
                  * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.85, 0.97, t));
    flame *= smoothstep(0.3, 0.65, fl * 1.1 + fl2 * 0.4);
    float heat = max(edge, flame * 0.85);
    vec3 light = fire(heat) * (edge * 1.4 + flame * 1.2) * c.a;
    // sparks rise from the front and sway
    vec2 sg = vec2(p.x * 60.0 + sin(p.y * 9.0 + time * 4.0) * 0.6, (p.y + time * 0.35) * 60.0);
    float spark = step(0.993, hash(sg)) * (1.0 - smoothstep(0.06, 0.22, length((fract(sg) - 0.5) * vec2(1.0, 0.6))))
                  * smoothstep(-0.45, -0.02, d) * (1.0 - smoothstep(-0.02, 0.03, d)) * lit;
    light += fire(0.75) * spark * 1.5;
    FRAG_COLOR = vec4(rgb * alive + light, c.a * alive) * qt_Opacity;
}
