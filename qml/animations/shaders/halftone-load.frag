// Halftone, loading: the icon on a screen of dots, its colours read at each dot's middle, and rings of larger dots
// spreading from it.
void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    vec2 px = uv * resolution;
    float cell = max(resolution.x / 18.0, 8.0);
    vec2 g = vec2(px.x + px.y, px.x - px.y) * 0.70711 / cell;
    vec2 id = floor(g);
    vec2 f = g - id - 0.5;
    vec2 mid = id + 0.5;
    vec2 cc = vec2(mid.x + mid.y, mid.x - mid.y) * 0.70711 * cell;
    vec2 ip = (cc - vec2(0.5, 0.46) * resolution) / (0.58 * resolution.x) + 0.5;
    vec4 icon = texture2D(source, clamp(ip, 0.0, 1.0)) * boxMask(ip);
    float r = length(asp(cc / resolution - vec2(0.5, 0.46)));
    float wave = fract(r * 2.4 - time * 0.55);
    wave = wave * wave * wave;
    float fall = 1.0 - smoothstep(0.1, 0.62, r);
    float small = 0.13 + 0.26 * wave * fall;
    float rd = mix(small, 0.47 + 0.1 * wave, icon.a);
    float dot0 = clamp((rd - length(f)) * cell + 0.5, 0.0, 1.0);
    vec3 base = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    vec3 ink = base * (0.3 + 0.75 * wave * fall) + 0.04;
    vec3 rgb = mix(ink, icon.rgb / max(icon.a, 0.001), icon.a);
    float back = 0.62;
    FRAG_COLOR = vec4(mix(vec3(0.045, 0.05, 0.065) * back, rgb, dot0), mix(back, 1.0, dot0)) * inside * qt_Opacity;
}
