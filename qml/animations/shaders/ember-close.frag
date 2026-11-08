// Ember, closing: burns away from the bottom up.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    float base = (originRect.y + originRect.w - uv.y) / originRect.w;
    float level = mix(-0.21, 1.07, clamp(t / 0.94, 0.0, 1.0));
    float d0 = level - base;
    // the noise moves the front by -0.105 to 0.195: past these a pixel is burnt or untouched, whatever the noise
    if (d0 > 0.245) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    vec2 p = asp(uv);
    float d = 0.0;
    float dl = 0.0;
    // heat haze and sparks come up with the fire, so that the window is as it was at 0
    float lit = smoothstep(0.0, 0.08, t);
    vec2 suv = uv;
    if (d0 >= -0.555) {
        float nl = fbm(p * 0.9);
        float n = nl * 0.7 + fbm(p * 2.7 + 0.31) * 0.3;
        // the fractal channel averages 0.35, not 0.5. Nothing charred at 0, still burning at the top at 0.85, gone at
        // 0.94
        d = d0 - (n - 0.35) * 0.30;
        if (d > 0.05) {
            FRAG_COLOR = vec4(0.0);
            return;
        }
        // the large front alone, which the flames follow
        dl = d0 - (nl - 0.35) * 0.21;
        if (d > -0.35 && d < 0.02) {
            float haze = smoothstep(-0.35, 0.0, d) * (1.0 - smoothstep(0.0, 0.02, d)) * lit;
            // the haze shimmers unevenly and rises (a plain sine shows as a regular wave on straight edges)
            float sh = vnoise(vec2(p.x * 4.0, p.y * 4.0 + time * 2.0)) - 0.5;
            suv = uv + vec2(sin(uv.y * 70.0 + time * 18.0 + sh * 4.0), sh) * 0.0035 * haze;
        }
    }
    // one read for the untouched pixels and the rest: a read beside pixels that skip it takes no proper level from a
    // mipmapped window (a still's), which would show as a line along the tier's edge
    vec4 c = src(suv);
    if (d0 < -0.555) {
        FRAG_COLOR = c * qt_Opacity;
        return;
    }
    vec3 rgb = c.rgb;
    if (d > -0.07)
        rgb = mix(rgb, tinted(vec3(0.10, 0.045, 0.02)) * c.a, smoothstep(-0.07, -0.005, d));
    float alive = 1.0 - smoothstep(0.0, 0.012, d);
    float ed = (d - 0.004) / 0.012;
    float edge = abs(ed) < 2.6 ? exp(-ed * ed) : 0.0;
    // flames from fractal noise (value noise shows squares), only along the large front: a scrap left behind chars
    // with a glowing rim instead of filling with flame. The tallest flame the noise tile can make is 0.344 high
    float flame = 0.0;
    if (d <= 0.02 && dl < 0.06 && dl > -0.344 && t > 0.0 && t < 0.97) {
        float fl = fbm(vec2(p.x * 2.2, p.y * 1.1 + time * 1.4));
        float fl2 = fbm(vec2(p.x * 5.0 + 0.37, p.y * 2.2 + time * 2.6));
        float flameH = 0.06 + 0.30 * fl * fl2;
        flame = clamp(1.0 + dl / flameH, 0.0, 1.0) * (1.0 - smoothstep(0.0, 0.06, dl))
                * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.85, 0.97, t))
                * smoothstep(0.3, 0.65, fl * 1.1 + fl2 * 0.4);
    }
    vec3 light = vec3(0.0);
    if (edge + flame > 0.0)
        light = fire(max(edge, flame * 0.85)) * (edge * 1.4 + flame * 1.2) * c.a;
    // sparks rise from the front and sway
    if (d > -0.45 && d < 0.03) {
        vec2 sg = vec2(p.x * 60.0 + sin(p.y * 9.0 + time * 4.0) * 0.6, (p.y + time * 0.35) * 60.0);
        if (hash(sg) >= 0.993)
            light += fire(0.75) * 1.5 * (1.0 - smoothstep(0.06, 0.22, length((fract(sg) - 0.5) * vec2(1.0, 0.6))))
                     * smoothstep(-0.45, -0.02, d) * (1.0 - smoothstep(-0.02, 0.03, d)) * lit;
    }
    FRAG_COLOR = vec4(rgb * alive + light, c.a * alive) * qt_Opacity;
}
