// Contour, opening: lines in the shape of what it opens from (a round icon, a cover) spread from it, like the depth
// lines of a chart. Between them the app comes up in steps, one band at a time, with a film of the ambience's colour
// on the bands still coming. The app can be read long before the lines leave the screen.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 hs = originRect.zw * 0.5 * resolution;
    float d = max(sdRoundRect((uv - originRect.xy - originRect.zw * 0.5) * resolution, hs, min(radiusPx, min(hs.x, hs.y))), 0.0) / resolution.y;
    float gap = 0.06;
    float steps = 4.0;
    float R = mix(t, easeOutCubic(t), 0.3) * (maxDist(origin) + gap * (steps + 1.0));
    float x = (R - d) / gap;
    // ahead of the outermost line: nothing, and no read
    if (x < -1.1) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    float band = floor(x);
    float a = clamp((band + 1.0) / steps, 0.0, 1.0) * step(0.0, x);
    float f = fract(x);
    float w = resolution.y * 0.001 + 1.0;
    float line = (1.0 - smoothstep(0.0, w, min(f, 1.0 - f) * gap * resolution.y)) * 0.9;
    line *= clamp(1.0 - band / (steps + 2.0), 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, t));
    vec4 c = src(uv);
    vec3 ink = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    vec3 rgb = mix(c.rgb, ink * c.a, a * (1.0 - a) * 0.7) * a;
    float alpha = c.a * a;
    FRAG_COLOR = vec4(rgb * (1.0 - line) + ink * line, alpha * (1.0 - line) + line) * qt_Opacity;
}
