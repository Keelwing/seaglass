// Northern lights, closing: turns into rays of light that rise and fade.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    float hw = clamp((originRect.y + originRect.w - uv.y) / originRect.w, 0.0, 1.0);
    // how far it has gone here, before the noise takes off up to 0.35. All gone, whatever the noise: nothing
    float d0 = t * 2.0 - hw * 0.8;
    if (d0 >= 1.35) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    // not begun (d 0): the app as it is, with no noise. A still's app has mipmaps and a read's level comes from the
    // pixels around it, so one read for this and for the lifted app, not one in each branch
    vec2 p = asp(uv);
    float d = 0.0;
    float lift = 0.0;
    if (d0 > 0.0) {
        d = clamp(d0 - fbm(vec2(p.x * 2.0, p.y * 0.6)) * 0.35, 0.0, 1.0);
        if (d >= 1.0) {
            FRAG_COLOR = vec4(0.0);
            return;
        }
        if (d > 0.0)
            lift = d * d * (0.18 + 0.22 * vnoise(vec2(p.x * 3.0, 0.37)));
    }
    vec4 c = src(uv + vec2(0.0, lift));
    float fade = 1.0 - smoothstep(0.8, 1.0, t);
    // only lifted so far, its colours still its own
    if (d <= 0.1) {
        FRAG_COLOR = c * fade * qt_Opacity;
        return;
    }
    vec3 s = c.rgb / max(c.a, 0.001);
    float f = fbm(vec2(p.x * 14.0, p.y * 0.9 + t * 0.8));
    float streak = f * sqrt(f) * 1.6;
    vec3 aur = aurora(clamp(0.2 + lift * 2.0 + (1.0 - uv.y) * 0.3, 0.0, 1.0));
    float conv = smoothstep(0.1, 0.55, d);
    vec3 rgb = mix(s, aur * (0.4 + luma(s)), conv);
    float a = c.a * (1.0 - smoothstep(0.35, 0.95, d)) * mix(1.0, clamp(streak, 0.0, 1.0), conv);
    vec3 glow = aur * streak * smoothstep(0.25, 0.6, d) * (1.0 - smoothstep(0.7, 1.0, d)) * 0.7 * c.a;
    FRAG_COLOR = vec4(rgb * a + glow, a) * fade * qt_Opacity;
}
