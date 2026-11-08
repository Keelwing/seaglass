// Halftone, opening: a screen of dots spreads out of the icon. Each dot grows as the wave passes, in the ambience's
// colour at first and then showing the app, until the dots run together.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 px = uv * resolution;
    float cell = max(resolution.x / 22.0, 9.0);
    // a grid at 45 degrees, in cells, and the middle of this pixel's cell in pixels
    vec2 g = vec2(px.x + px.y, px.x - px.y) * 0.70711 / cell;
    vec2 id = floor(g);
    vec2 f = g - id - 0.5;
    vec2 mid = id + 0.5;
    vec2 cc = vec2(mid.x + mid.y, mid.x - mid.y) * 0.70711 * cell;
    vec2 hs = originRect.zw * 0.5 * resolution;
    float dist = max(sdRoundRect(cc - (originRect.xy + originRect.zw * 0.5) * resolution, hs, min(radiusPx, min(hs.x, hs.y))), 0.0) / resolution.y;
    float band = 0.4;
    float R = mix(t, easeOutCubic(t), 0.2) * (maxDist(origin) + band);
    float k = clamp((R - dist) / band, 0.0, 1.0);
    float a = clamp((k * 0.78 - length(f)) * cell + 0.5, 0.0, 1.0) * step(0.0001, k);
    // no dot here: nothing, and no read
    if (a <= 0.0) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    vec4 c = src(uv);
    vec3 ink = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    float inky = 1.0 - smoothstep(0.08, 0.42, k);
    FRAG_COLOR = vec4(mix(c.rgb, ink * c.a, inky) * a, c.a * a) * qt_Opacity;
}
