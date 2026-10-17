// Grains (Dust, Frost): a picture falling apart into grains that fly off. Each pixel steps back along the
// paths of four speed classes to find the grain that covers it now
float grainStart(vec2 C, float gp, vec4 sw, float jit)
{
    vec2 cp = asp((C + 0.5) * gp / resolution);
    return dot(cp, sw.xy) * sw.z + sw.w + (fbm(cp * 1.3) - 0.5) * 0.22 + hash(C) * jit;
}
vec2 grainDisp(float a, float v, vec2 drift, vec2 grav){ return (drift * v * a * 0.35 + 0.5 * grav * a * a) * resolution.y; }
vec4 grains(vec2 uv, float k, float gp, vec4 sw, float jit, vec2 drift, vec2 grav, float life, vec3 tone, float toneMin)
{
    vec2 P = uv * resolution;
    float a0 = max(0.0, k - grainStart(floor(P / gp), gp, sw, jit));
    for (int j = 0; j < 4; j++) {
        float fj = float(j);
        float v = 0.5 + fj * 0.4;
        float ang = (fj - 1.5) * 0.14;
        vec2 dj = vec2(drift.x * cos(ang) - drift.y * sin(ang), drift.x * sin(ang) + drift.y * cos(ang));
        vec2 C = floor((P - grainDisp(a0, v, dj, grav)) / gp);
        float a = max(0.0, k - grainStart(C, gp, sw, jit));
        C = floor((P - grainDisp(a, v, dj, grav)) / gp);
        a = max(0.0, k - grainStart(C, gp, sw, jit));
        C = floor((P - grainDisp(a, v, dj, grav)) / gp);
        if (floor(hash(C + vec2(31.0, 17.0)) * 4.0) != fj) continue;
        a = k - grainStart(C, gp, sw, jit);
        if (a <= 0.0) continue;
        vec2 pos = (C + 0.5) * gp + grainDisp(a, v, dj, grav);
        float hs = gp * 0.5 * (1.0 - 0.4 * clamp(a / life, 0.0, 1.0));
        vec2 dd = abs(P - pos);
        if (max(dd.x, dd.y) < hs) {
            vec2 cu = (C + 0.5) * gp / resolution;
            vec4 c = srcClamp(cu) * inRect(cu);
            c.rgb = mix(c.rgb, tone * c.a, mix(toneMin, 1.0, clamp(a / life, 0.0, 1.0)) * 0.6);
            return c * (1.0 - smoothstep(life * 0.45, life, a));
        }
    }
    return vec4(0.0);
}
