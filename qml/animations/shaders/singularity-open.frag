// Singularity, opening: bursts out of a white hole.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    vec2 v = p - o;
    float r = length(v);
    float M = maxDist(origin);
    // the edge leaves the farthest corner at 0.92, nearly linear: an ease-out finishes the reveal at half time
    float s = clamp(t / 0.92, 0.0, 1.0);
    float e = 1.0 - pow(1.0 - s, 1.6);
    float Rg = e * (M + 0.02);
    float u = r / max(Rg, 0.0001);
    float inside = 1.0 - smoothstep(0.985, 1.0, u);
    vec4 c = vec4(0.0);
    // past the edge there is no app to read. Read a little further all the same: a read beside pixels that skip it
    // takes no proper level from a mipmapped app (a still's), which would show as a line along the tier's edge
    if (r < Rg + 3.0 / resolution.y) {
        float gamma = mix(0.7, 1.0, smoothstep(0.0, 0.95, t));
        float rs = r * pow(max(u, 0.001), gamma - 1.0);
        vec2 dir = v / max(r, 0.0001);
        vec2 du = vec2(dir.x / aspect, dir.y);
        vec2 suv = uv + du * (rs - r);
        // the colours split only near the rim, where the lens bends most, and they are read from a little before that,
        // for the same reason
        float ca = (1.0 - t) * (1.0 - t) * 0.004 * u * smoothstep(0.6, 1.0, u);
        c = src(suv);
        if (r > 0.6 * Rg - 3.0 / resolution.y) {
            float cr = src(suv + du * ca).r;
            float cb = src(suv - du * ca).b;
            if (ca > 0.0) {
                c.r = cr;
                c.b = cb;
            }
        }
    }
    // the rim and the core: past these widths of their Gaussians they add nothing a screen shows
    float x = (r - Rg) * resolution.y / 6.0;
    float ring = abs(x) < 4.0 ? exp(-x * x) * (1.0 - t * 0.8) : 0.0;
    float cw = 0.0004 + 0.02 * t;
    float core = r * r < 25.0 * cw ? exp(-r * r / cw) * (1.0 - t) * (1.0 - t) * 2.0 : 0.0;
    vec3 rgb = c.rgb * inside;
    float light = ring * 1.2 + core;
    if (light > 0.0)
        rgb += tinted(vec3(1.0, 0.92, 0.8)) * light;
    FRAG_COLOR = vec4(rgb, c.a * inside) * qt_Opacity;
}
