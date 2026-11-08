// Fold, opening: the window comes out of the icon folded like a paper screen, a narrow pleated strip that stands up
// and opens sideways. Its pleats catch the light on one side, and their ridges stand nearer than their valleys, so
// its top and bottom edges zigzag until it lies flat.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    float eh = easeOutCubic(clamp(t / 0.55, 0.0, 1.0));
    float xw = clamp((t - 0.04) / 0.96, 0.0, 1.0);
    float ew = mix(easeInOut(xw), xw, 0.35);
    vec4 r = vec4(mix(originRect.x, 0.0, ew), mix(originRect.y, 0.0, eh), mix(originRect.z, 1.0, ew), mix(originRect.w, 1.0, eh));
    vec2 local = (uv - r.xy) / max(r.zw, vec2(0.001));
    // the sine of the faces' tilt, from how far the width has opened
    float s = sqrt(max(1.0 - r.z * r.z, 0.0));
    float x = local.x * 8.0;
    float side = mod(floor(x), 2.0) * 2.0 - 1.0;
    float tri = abs(fract(x * 0.5) * 2.0 - 1.0);
    float v = 0.5 + (local.y - 0.5) / (1.0 + 0.045 * s * (tri * 2.0 - 1.0));
    vec2 size = r.zw * resolution;
    float rad = min(radiusPx * (1.0 - smoothstep(0.0, 0.5, t)), min(size.x, size.y) * 0.5);
    float d = sdRoundRect((vec2(local.x, v) - 0.5) * size, size * 0.5, rad);
    float soft = 0.02 * resolution.y;
    // past the shadow: nothing, and no read
    if (d > soft) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    float a = clamp(0.5 - d, 0.0, 1.0);
    vec4 c = texture2D(source, clamp(vec2(local.x, v), 0.0, 1.0));
    float shade = 1.0 + s * (side * 0.34 - 0.3 * (1.0 - tri) * (1.0 - tri));
    float ridge = smoothstep(0.86, 1.0, tri) * s * 0.3;
    vec3 paper = mix(vec3(1.0), tint, 0.35 * useTint * s);
    vec3 rgb = (c.rgb * shade + paper * (ridge + max(side, 0.0) * s * 0.07) * c.a) * a;
    float shadow = (1.0 - smoothstep(0.0, soft, max(d, 0.0))) * 0.28 * (1.0 - smoothstep(0.7, 1.0, t));
    FRAG_COLOR = vec4(rgb, c.a * a + shadow * (1.0 - c.a * a)) * smoothstep(0.0, 0.06, t) * qt_Opacity;
}
