// Contour, closing: the window draws in to where the finger let go, in steps, a line on each step, and the last
// round pool goes out.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    float d = length(asp(uv) - asp(origin));
    float gap = 0.06;
    float steps = 4.0;
    float e = mix(t, easeInOut(t), 0.5);
    float R = (1.0 - e) * (maxDist(origin) + gap * steps) - gap;
    float x = (R - d) / gap;
    if (x < -1.1) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    float band = floor(x);
    float a = clamp((band + 1.0) / steps, 0.0, 1.0) * step(0.0, x);
    float f = fract(x);
    float w = resolution.y * 0.001 + 1.0;
    float line = (1.0 - smoothstep(0.0, w, min(f, 1.0 - f) * gap * resolution.y)) * 0.9;
    line *= clamp(1.0 - band / (steps + 2.0), 0.0, 1.0) * smoothstep(0.0, 0.1, t);
    vec4 c = src(uv);
    vec3 ink = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    vec3 rgb = mix(c.rgb, ink * c.a, a * (1.0 - a) * 0.7) * a;
    float alpha = c.a * a;
    float fade = 1.0 - smoothstep(0.86, 1.0, t);
    FRAG_COLOR = vec4(rgb * (1.0 - line) + ink * line, alpha * (1.0 - line) + line) * fade * qt_Opacity;
}
