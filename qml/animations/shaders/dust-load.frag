// Dust, loading: sand pours through the cover.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    float d;
    float inside = cardInside(d);
    vec3 sand = tinted(vec3(0.88, 0.72, 0.48));
    vec4 icon = iconAt(vec2(0.5, 0.30), 0.36 * resolution.x, vec2(0.0));
    vec4 col = icon + vec4(vec3(0.07, 0.05, 0.035) * 0.72, 0.72) * (1.0 - icon.a);
    float cyc = 4.0;
    float ph = fract(time / cyc);
    // the heap grows as the sand comes (its height as the root of what has fallen), then sinks away into the floor
    // before the next round: no jump where the loop starts again
    float H = 0.36 * sqrt(clamp(ph / 0.9, 0.0, 1.0)) * (1.0 - smoothstep(0.9, 1.0, ph));
    float x = (uv.x - 0.5) * 2.0;
    float heapTop = 1.0 - H * (1.0 - pow(abs(x), 1.5));
    float gpx = max(1.5, resolution.x / 90.0);
    float gr = hash(floor(px / gpx));
    float heap = step(heapTop, uv.y) * (0.75 + 0.25 * gr);
    float sx = abs(uv.x - 0.5);
    float stream = (1.0 - smoothstep(0.012, 0.022, sx)) * step(0.46, uv.y) * step(uv.y, heapTop + 0.01);
    float sgr = step(0.45, hash(floor(vec2(px.x / gpx, px.y / gpx - time * 45.0)))) * stream;
    float fall = step(0.993, hash(floor(vec2(px.x / gpx, px.y / gpx - time * 30.0)) + 3.0)) * step(0.46, uv.y) * (1.0 - smoothstep(0.05, 0.3, sx));
    float s = max(heap, max(sgr, fall));
    col.rgb = mix(col.rgb, sand * (0.7 + 0.3 * gr), s);
    col.a = max(col.a, s);
    FRAG_COLOR = col * inside * qt_Opacity;
}
