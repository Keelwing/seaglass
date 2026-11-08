// Frost: the frost pattern, a picture turned to ice, and the snow it falls apart into
// frosted glass: an even, fine haze (centred: the fractal channel averages 0.35) with thin crystal veins at two
// scales, broken up so that they do not join into cells. Where the frost is thick (thick 1: along the edges it grew
// from) it is dense and white, in ragged drifts of fine crystals. A rime of tiny crystals where it is dense
float frostPat(vec2 p, float thick)
{
    float haze = 0.24 + (fbm(p * 5.3) - 0.35) * 0.3 + (fbm(p * 11.0 + 0.37) - 0.35) * 0.15;
    float vein = (1.0 - smoothstep(0.0, 0.04, cells(p * 3.1 + 0.11))) * smoothstep(0.35, 0.6, vnoise(p * 9.0 + 0.5))
                 + (1.0 - smoothstep(0.0, 0.055, cells(p * 7.3 + 0.41))) * smoothstep(0.45, 0.7, vnoise(p * 13.0 + 0.2)) * 0.6;
    float drift = 0.0;
    if (thick > 0.0) {
        float fine = (1.0 - smoothstep(0.0, 0.1, cells(p * 13.7 + 0.29))) * smoothstep(0.3, 0.6, vnoise(p * 21.0 + 0.7));
        drift = thick * (0.3 + (fbm(p * 3.7 + 0.6) - 0.35) * 0.7 + fine * 0.35);
    }
    float f = clamp(haze + vein * (0.3 + 0.25 * thick) + drift, 0.0, 1.0);
    float rime = step(1.0 - 0.12 * f, hash(floor(gl_FragCoord.xy / 1.5)));
    return clamp(f + rime * 0.3, 0.0, 1.0);
}
// the same from what frost-field.frag baked: f = A + thick * B, and a rime dot from the thickness kept for its pixel
float frostFrom(vec4 field, float thick)
{
    float f = clamp(field.r + thick * field.g * 1.5, 0.0, 1.0);
    return clamp(f + step(field.a * 1.01, thick) * 0.3, 0.0, 1.0);
}
// the source at its full size, on a source with mipmaps: read inside a branch or a loop, or at a coordinate that jumps
// from cell to cell, a mip level worked out from the neighbouring pixels would be undefined
vec4 srcFull(vec2 uv)
{
#ifdef ES3
    return textureLod(source, clamp(uv, 0.0, 1.0), 0.0) * clipMask(clamp(uv, 0.0, 1.0)) * inRect(uv);
#else
    return srcClamp(uv) * inRect(uv);
#endif
}
// the picture (blurred, premultiplied) behind frosted glass: darker and cooler, white where the frost is dense.
// Only the frost takes the ambience's colour, and only half of it: a frost all in the colour looks like mould
vec3 icedBase(vec3 c)
{
    return mix(vec3(luma(c)), c, 0.4) * vec3(0.8, 0.92, 1.06) * 0.9 + vec3(0.05, 0.08, 0.12);
}
vec3 iced(vec4 b, float fr)
{
    vec3 white = vec3(0.88, 0.95, 1.0);
    return mix(icedBase(b.rgb / max(b.a, 0.001)), mix(white, tinted(white), 0.5), fr * fr * 0.75);
}
// Snow: the ice falls apart into round flakes that drift down and sway. As with grains.glsl, each pixel steps back
// along the paths of four speed classes to find the flake that covers it now. A flake leaves when the break that
// spreads from o (field) reaches its cell, a little before the ice there goes. Its sway depends only on its age and
// class, and neighbours leave at nearly the same time, so that the way back finds the right cell (with a wider
// spread of start times it misses, and the flakes come out cut)
float snowField(vec2 cp, vec2 o, float spread)
{
    return length(cp - o) * spread + (fbm(cp * 1.7) - 0.35) * 0.18 + 0.07;
}
float flakeStart(vec2 C, float gp, vec2 o, float spread)
{
    return max(0.0, snowField(asp((C + 0.5) * gp / resolution), o, spread) - hash(C) * 0.02);
}
vec2 flakeDisp(float a, float v, float j)
{
    return vec2(0.06 * v * a + (sin(a * 14.0 + j * 1.7) - sin(j * 1.7)) * 0.012, 0.18 * v * a + 0.45 * a * a) * resolution.y;
}
vec4 snow(vec2 uv, float k, float gp, vec2 o, float spread, float life, vec3 tone)
{
    vec2 P = uv * resolution;
    float a0 = k - flakeStart(floor(P / gp), gp, o, spread);
    for (int j = 0; j < 4; j++) {
        float fj = float(j);
        float v = 0.5 + fj * 0.4;
        vec2 C = floor((P - flakeDisp(max(a0, 0.0), v, fj)) / gp);
        float a = max(0.0, k - flakeStart(C, gp, o, spread));
        C = floor((P - flakeDisp(a, v, fj)) / gp);
        a = max(0.0, k - flakeStart(C, gp, o, spread));
        C = floor((P - flakeDisp(a, v, fj)) / gp);
        if (floor(hash(C + vec2(31.0, 17.0)) * 4.0) != fj) continue;
        a = k - flakeStart(C, gp, o, spread);
        if (a <= 0.0) continue;
        vec2 pos = (C + 0.5) * gp + flakeDisp(a, v, fj);
        // flakes of different sizes, and about half the cells only melt: a snowfall, not a cloud of dots
        float h = hash(C + vec2(5.0, 11.0));
        if (h > 0.5) continue;
        float hs = gp * (0.42 - 0.12 * clamp(a / life, 0.0, 1.0)) * (0.55 + 0.9 * h);
        float flake = 1.0 - smoothstep(hs * 0.5, hs, length(P - pos));
        if (flake > 0.0) {
            // from the ice it was to white
            vec2 cu = (C + 0.5) * gp / resolution;
            vec4 c = srcFull(cu);
            vec3 col = mix(icedBase(c.rgb / max(c.a, 0.001)), tone, 0.5 + 0.5 * clamp(a / (life * 0.4), 0.0, 1.0));
            return vec4(col, 1.0) * c.a * flake * (1.0 - smoothstep(life * 0.5, life, a));
        }
    }
    return vec4(0.0);
}
