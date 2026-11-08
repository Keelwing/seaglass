// Halftone, closing: the window breaks into a screen of dots from where the finger let go. Each dot narrows to one
// colour of the picture, takes on some of the ambience's colour, shrinks and goes out.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 px = uv * resolution;
    float cell = max(resolution.x / 22.0, 9.0);
    vec2 g = vec2(px.x + px.y, px.x - px.y) * 0.70711 / cell;
    vec2 id = floor(g);
    vec2 f = g - id - 0.5;
    vec2 mid = id + 0.5;
    vec2 cc = vec2(mid.x + mid.y, mid.x - mid.y) * 0.70711 * cell;
    float dist = length(asp(cc / resolution - origin));
    float band = 0.42;
    float R = mix(-band, maxDist(origin), mix(t, t * t, 0.35));
    float k = clamp((dist - R) / band, 0.0, 1.0);
    float a = clamp((k * 0.78 - length(f)) * cell + 0.5, 0.0, 1.0) * step(0.0001, k);
    if (a <= 0.0) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    // one read: as the dot shrinks, its picture narrows to the colour at its middle
    float one = 1.0 - smoothstep(0.35, 0.8, k);
    vec4 c = src(mix(uv, cc / resolution, one));
    vec3 ink = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    FRAG_COLOR = vec4(mix(c.rgb, ink * c.a, one * 0.45), c.a) * a * qt_Opacity;
}
