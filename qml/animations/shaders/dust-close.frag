// Dust, closing: crumbles from the top down into dust that the wind takes.
void main()
{
    vec2 uv = qt_TexCoord0;
    float k = progress;
    float gp = max(2.0, resolution.y / 300.0);
    // from the top down, the way the swipe went, at an even pace; starts from 0 (whole at progress 0) to at most 0.8
    // with the noise, so the last grain is gone at progress 1 (life 0.2)
    vec4 sw = vec4(0.12, 1.0, 0.68, 0.005);
    vec3 tone = tinted(vec3(0.86, 0.72, 0.52));
    vec4 fly = vec4(0.0);
    if (part != 1.0) {
        // the dust rises more than it drifts, and the grains fade late in their flight: the last of it, from the
        // bottom, is still in the air near the end
        fly = grains(uv, k, gp, sw, 0.04, vec2(0.6, -1.2), vec2(0.0, -0.6), 0.2, tone, 0.5, 0.6);
        fly.rgb *= 1.15;
    }
    vec4 base = part != 2.0 && k < grainStart(floor(uv * resolution / gp), gp, sw, 0.04) ? src(uv) : vec4(0.0);
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
