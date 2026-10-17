// Northern lights, closing: turns into rays of light that rise and fade.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    float hw = clamp((originRect.y + originRect.w - uv.y) / originRect.w, 0.0, 1.0);
    float n = fbm(vec2(p.x * 2.0, p.y * 0.6));
    float colr = vnoise(vec2(p.x * 3.0, 0.37));
    float d = clamp(t * 2.0 - hw * 0.8 - n * 0.35, 0.0, 1.0);
    float lift = d * d * (0.18 + 0.22 * colr);
    vec4 c = src(uv + vec2(0.0, lift));
    vec3 s = c.rgb / max(c.a, 0.001);
    float streak = pow(fbm(vec2(p.x * 14.0, p.y * 0.9 + t * 0.8)), 1.5) * 1.6;
    vec3 aur = aurora(clamp(0.2 + lift * 2.0 + (1.0 - uv.y) * 0.3, 0.0, 1.0));
    float conv = smoothstep(0.1, 0.55, d);
    vec3 rgb = mix(s, aur * (0.4 + luma(s)), conv);
    float a = c.a * (1.0 - smoothstep(0.35, 0.95, d)) * mix(1.0, clamp(streak, 0.0, 1.0), conv);
    vec3 glow = aur * streak * smoothstep(0.25, 0.6, d) * (1.0 - smoothstep(0.7, 1.0, d)) * 0.7 * c.a;
    float fade = 1.0 - smoothstep(0.8, 1.0, t);
    FRAG_COLOR = vec4(rgb * a + glow, a) * fade * qt_Opacity;
}
