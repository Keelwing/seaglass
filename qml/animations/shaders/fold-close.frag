// Fold, closing: the window folds up into pleats from its sides, towards where the finger let go; the narrow strip
// then drops out of sight.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    float ew = easeInOut(clamp(t / 0.72, 0.0, 1.0));
    float fall = clamp((t - 0.5) / 0.5, 0.0, 1.0);
    fall = fall * fall;
    float w = mix(1.0, 0.075, ew);
    float h = mix(1.0, 0.8, ew);
    vec4 r = vec4(origin.x * (1.0 - w), (1.0 - h) * origin.y + fall * 0.9, w, h);
    vec2 local = (uv - r.xy) / max(r.zw, vec2(0.001));
    float s = sqrt(max(1.0 - w * w, 0.0));
    float x = local.x * 8.0;
    float side = mod(floor(x), 2.0) * 2.0 - 1.0;
    float tri = abs(fract(x * 0.5) * 2.0 - 1.0);
    float v = 0.5 + (local.y - 0.5) / (1.0 + 0.045 * s * (tri * 2.0 - 1.0));
    vec2 size = r.zw * resolution;
    float d = sdRoundRect((vec2(local.x, v) - 0.5) * size, size * 0.5, min(radiusPx, min(size.x, size.y) * 0.5));
    float soft = 0.02 * resolution.y;
    if (d > soft) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    float a = clamp(0.5 - d, 0.0, 1.0);
    vec4 c = src(vec2(local.x, v));
    float shade = 1.0 + s * (side * 0.34 - 0.3 * (1.0 - tri) * (1.0 - tri));
    float ridge = smoothstep(0.86, 1.0, tri) * s * 0.3;
    vec3 paper = mix(vec3(1.0), tint, 0.35 * useTint * s);
    vec3 rgb = (c.rgb * shade + paper * (ridge + max(side, 0.0) * s * 0.07) * c.a) * a;
    // nothing casts one where the swipe has wiped the window
    float shadow = (1.0 - smoothstep(0.0, soft, max(d, 0.0))) * 0.28 * smoothstep(0.0, 0.2, t);
    shadow *= clipMask(clamp(vec2(local.x, v), 0.0, 1.0));
    float fade = 1.0 - smoothstep(0.75, 1.0, t);
    FRAG_COLOR = vec4(rgb, c.a * a + shadow * (1.0 - c.a * a)) * fade * qt_Opacity;
}
