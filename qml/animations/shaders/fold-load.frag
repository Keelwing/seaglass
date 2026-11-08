// Fold, loading: the cover is a paper screen with the icon printed on it. Its pleats lean a little all the time, and
// a fold runs across and back, tilting them in turn so that the light catches them; the top and bottom edges zigzag
// with it.
void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    float x = uv.x * 6.0;
    float side = mod(floor(x), 2.0) * 2.0 - 1.0;
    float tri = abs(fract(x * 0.5) * 2.0 - 1.0);
    float h = sin(uv.x * 2.4 - time * 2.1);
    float s = 0.34 + 0.5 * h * h * step(0.0, h);
    float v = 0.5 + (uv.y - 0.5) / (0.96 + 0.05 * s * (tri * 2.0 - 1.0));
    float mask = clamp(0.5 - (abs(v - 0.5) - 0.5) * resolution.y, 0.0, 1.0);
    vec3 base = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    vec3 paper = mix(base * 0.4 + 0.06, base * 0.26 + 0.05, uv.y);
    vec2 ip = (vec2(uv.x, v) * resolution - vec2(0.5, 0.46) * resolution) / (0.46 * resolution.x) + 0.5;
    vec4 icon = texture2D(source, clamp(ip, 0.0, 1.0)) * boxMask(ip);
    vec3 rgb = icon.rgb + paper * (1.0 - icon.a);
    float shade = 1.0 + s * (side * 0.42 - 0.34 * (1.0 - tri) * (1.0 - tri));
    float ridge = smoothstep(0.84, 1.0, tri) * s * 0.34;
    FRAG_COLOR = vec4(rgb * shade + ridge, 1.0) * mask * inside * qt_Opacity;
}
