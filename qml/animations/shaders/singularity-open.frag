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
    float gamma = mix(0.7, 1.0, smoothstep(0.0, 0.95, t));
    float rs = r * pow(max(u, 0.001), gamma - 1.0);
    vec2 dir = v / max(r, 0.0001);
    vec2 du = vec2(dir.x / aspect, dir.y);
    vec2 suv = uv + du * (rs - r);
    // the colours split only near the rim, where the lens bends most
    float ca = (1.0 - t) * (1.0 - t) * 0.004 * u * smoothstep(0.6, 1.0, u);
    vec4 cg = src(suv);
    vec4 c = vec4(src(suv + du * ca).r, cg.g, src(suv - du * ca).b, cg.a);
    float ring = exp(-pow((r - Rg) * resolution.y / 6.0, 2.0)) * (1.0 - t * 0.8);
    float core = exp(-r * r / (0.0004 + 0.02 * t)) * pow(1.0 - t, 2.0) * 2.0;
    vec3 hot = tinted(vec3(1.0, 0.92, 0.8));
    FRAG_COLOR = vec4(c.rgb * inside + hot * (ring * 1.2 + core), c.a * inside) * qt_Opacity;
}
