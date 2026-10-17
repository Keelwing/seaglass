// Dust, closing: crumbles into dust that the wind takes.
void main()
{
    vec2 uv = qt_TexCoord0;
    float k = progress;
    float gp = max(2.0, resolution.y / 300.0);
    vec4 sw = vec4(1.0, -0.15, 0.62 / aspect, 0.04);
    vec3 tone = tinted(vec3(0.86, 0.72, 0.52));
    float s0 = grainStart(floor(uv * resolution / gp), gp, sw, 0.12);
    vec4 fly = grains(uv, k, gp, sw, 0.1, normalize(vec2(1.0, -0.6)), vec2(0.0, -0.6), 0.3, tone, 0.0);
    vec4 base = k < s0 ? src(uv) : vec4(0.0);
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
