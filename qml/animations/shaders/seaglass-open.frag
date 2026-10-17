// Seaglass, opening: the window rises from the icon or cover as frosted glass in the ambience's colour, settles a
// little past full size, and clears as it lands.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    float c1 = 0.9;
    float tm = t - 1.0;
    float e = 1.0 + (c1 + 1.0) * tm * tm * tm + c1 * tm * tm;
    vec4 r = mix(originRect, vec4(0.0, 0.0, 1.0, 1.0), e);
    vec2 px = uv * resolution;
    vec2 centre = (r.xy + r.zw * 0.5) * resolution;
    vec2 halfSize = max(r.zw * 0.5 * resolution, vec2(1.0));
    float r0 = min(originRect.z * resolution.x, originRect.w * resolution.y) * 0.12 + 4.0;
    float rad = mix(r0, 0.0, smoothstep(0.55, 1.0, t));
    float d = sdRoundRect(px - centre, halfSize, rad);
    float inside = clamp(0.5 - d, 0.0, 1.0);
    vec2 local = (uv - r.xy) / max(r.zw, vec2(0.001));
    float frost = 1.0 - smoothstep(0.25, 0.9, t);
    vec4 b = blurSrc(local, 20.0 * frost * resolution.y / 1000.0);
    vec3 s = b.rgb / max(b.a, 0.001);
    vec3 glass = mix(s, mix(s, tint, 0.38) + 0.10, frost);
    float band = (local.x + local.y) * 0.5 - mix(-0.3, 1.3, t);
    float glint = exp(-band * band * 90.0) * 0.32 * (1.0 - t);
    float rim = (1.0 - smoothstep(0.0, 2.5, abs(d + 1.0))) * (0.2 + 0.6 * frost);
    float a = inside * b.a * smoothstep(0.0, 0.1, t);
    float shadow = (1.0 - smoothstep(0.0, 26.0, d)) * step(0.0, d) * 0.35 * (1.0 - smoothstep(0.6, 1.0, t));
    vec3 rgb = (glass + glint) * a + tint * rim * smoothstep(0.0, 0.1, t);
    FRAG_COLOR = vec4(rgb, a + shadow * (1.0 - a)) * qt_Opacity;
}
