// Tide, opening: a drop falls on the icon; the app spreads in its ripple.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    vec2 v = p - o;
    float r = length(v);
    vec2 dir = v / max(r, 0.0001);
    float M = maxDist(origin) + 0.06;
    float R = mix(t, easeOutCubic(t), 0.35) * M;
    float x = r - R;
    float env = exp(-x * x * 140.0);
    float inner = x < 0.0 ? exp(x * 7.0) : 0.0;
    float amp = 0.013 * (1.0 - t * 0.85);
    float wave = sin(x * 75.0) * amp * (env + inner * 0.6);
    vec2 suv = uv - vec2(dir.x / aspect, dir.y) * wave;
    vec4 c = src(suv);
    float alpha = 1.0 - smoothstep(-0.008, 0.008, x);
    vec3 water = tinted(vec3(0.55, 0.9, 1.0));
    float crest = pow(max(0.0, cos(x * 75.0)), 6.0) * (env + inner * 0.4);
    float rim = exp(-x * x * 9000.0);
    float drop = exp(-r * r * 2500.0) * (1.0 - smoothstep(0.0, 0.16, t));
    vec3 col = (c.rgb + water * crest * 0.45 * (1.0 - t)) * alpha + water * (rim * 0.6 + drop * 1.2) * (1.0 - smoothstep(0.85, 1.0, t));
    FRAG_COLOR = vec4(col, c.a * alpha) * qt_Opacity;
}
