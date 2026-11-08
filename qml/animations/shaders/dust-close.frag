// Dust, closing: crumbles from the top down into dust that the wind takes.
void main()
{
    vec2 uv = qt_TexCoord0;
    float k = progress;
    float gp = max(2.0, resolution.y / 300.0);
    // from the top down, the way the swipe went, at an even pace; starts from 0 (whole at progress 0) to at most 0.8
    // with the noise, so the last grain is gone at progress 1 (life 0.2)
    vec4 sw = vec4(0.12, 1.0, 0.68, 0.005);
    // how long ago the sweep passed this pixel, before the noise, which moves a start by -0.036 to 0.075 (the tile's
    // fractal channel ends at 248 of 255). A grain's cell is at most slack from where it covers
    float past = k - dot(asp(uv), sw.xy) * sw.z - sw.w;
    float slack = 0.381 * gp / resolution.y;
    vec4 fly = vec4(0.0);
    // no grain has come here yet, or the last has gone: its flight of 0.2 takes it 0.085 back up the sweep, on top of
    // the noise
    if (part != 1.0 && past > -0.037 - slack && past < 0.36 + slack) {
        // the dust rises more than it drifts, and the grains fade late in their flight: the last of it, from the
        // bottom, is still in the air near the end
        vec3 tone = tinted(vec3(0.86, 0.72, 0.52));
        fly = grains(uv, k, gp, sw, 0.04, vec2(0.6, -1.2), vec2(0.0, -0.6), 0.2, tone, 0.5, 0.6);
        fly.rgb *= 1.15;
    }
    // the noise decides only within its own reach of the sweep
    vec4 base = vec4(0.0);
    if (part != 2.0 && past < 0.075 + slack) {
        if (past < -0.037 - slack || k < grainStart(floor(uv * resolution / gp), gp, sw, 0.04))
            base = src(uv);
    }
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
