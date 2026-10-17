// Tide, closing: a wave washes it away from the bottom.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    float base = originRect.y + originRect.w * (1.1 - t * 1.38);
    float w = 0.022 * sin(p.x * 16.0 + t * 9.0) + 0.012 * sin(p.x * 37.0 - t * 14.0) + (fbm(vec2(p.x * 1.3, t * 0.6)) - 0.5) * 0.07;
    float dy = uv.y - (base + w);
    float near = exp(min(dy, 0.0) * 18.0);
    vec2 suv = uv + vec2(sin(uv.y * 90.0 + t * 20.0) * 0.003, -0.022 * near) * near;
    vec4 app = src(suv);
    float keep = 1.0 - smoothstep(-0.004, 0.004, dy);
    float body = smoothstep(0.0, 0.01, dy) * (1.0 - smoothstep(0.02, 0.3, dy));
    vec3 tone = tinted(vec3(0.08, 0.42, 0.58));
    vec2 cq = p * 2.4 + vec2(t * 0.3, -t * 0.8) + (vec2(fbm(p * 1.5 + t * 0.2), fbm(p * 1.5 + 0.5 - t * 0.2)) - 0.5) * 0.25;
    float caust = (1.0 - smoothstep(0.0, 0.06, cells(cq))) * (0.4 + 0.6 * fbm(p * 2.0 + t));
    vec3 water = tone + caust * 0.3;
    float endFade = 1.0 - smoothstep(0.78, 1.0, t);
    float wa = body * 0.62 * endFade;
    float foamN = fbm(p * 5.0 + vec2(t * 1.5, 0.0));
    float foam = (exp(-dy * dy * 6000.0) * smoothstep(0.35, 0.7, foamN) + exp(-dy * dy * 20000.0) * 0.6) * endFade;
    vec2 g = floor(uv * resolution / 3.0);
    float sp = step(0.985, hash(g + floor(t * 12.0) * 7.0)) * smoothstep(-0.12, -0.01, dy) * (1.0 - smoothstep(-0.01, 0.0, dy));
    vec3 col = app.rgb * keep;
    float a = app.a * keep;
    col = col + water * wa * (1.0 - a);
    a = a + wa * (1.0 - a);
    col += vec3(0.9, 0.97, 1.0) * (foam + sp);
    a = max(a, clamp(foam + sp, 0.0, 1.0) * 0.8);
    FRAG_COLOR = vec4(col, a) * qt_Opacity;
}
