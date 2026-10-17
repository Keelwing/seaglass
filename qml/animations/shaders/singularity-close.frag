// Singularity, closing: pulled into a black hole, which then winks out.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 C = asp(originRect.xy + originRect.zw * vec2(0.5, 0.45));
    vec2 v = p - C;
    float r = length(v);
    float ang = atan(v.y, v.x);
    float k = smoothstep(0.0, 0.9, t);
    float pull = 0.5 * k * k * k;
    float rs = r + pull * (0.6 + 0.02 / (r * r + 0.004));
    float as = ang - 2.4 * k / (r * 6.0 + 0.25);
    vec2 sd = vec2(cos(as), sin(as));
    vec2 sp = C + sd * rs;
    vec2 suv = vec2(sp.x / aspect, sp.y);
    vec2 cav = vec2(sd.x / aspect, sd.y) * 0.0006 * k / (r + 0.05);
    vec4 cg = src(suv);
    vec4 c = vec4(src(suv + cav).r, cg.g, src(suv - cav).b, cg.a);
    float rh = (0.012 + 0.05 * easeInOut(clamp(t * 1.4, 0.0, 1.0))) * (1.0 - smoothstep(0.72, 0.95, t));
    float hole = (1.0 - smoothstep(rh - 0.003, rh + 0.003, r)) * step(0.0005, rh);
    vec2 dv = vec2(v.x, v.y / 0.28);
    float rd = length(dv);
    float phi = atan(dv.y, dv.x);
    float band = smoothstep(rh * 1.3, rh * 1.9, rd) * (1.0 - smoothstep(rh * 2.2, rh * 4.0, rd));
    float turb = fbm(vec2(phi * 0.5 - time * 1.1, rd * 4.0));
    float dop = 1.0 + 0.75 * dv.x / max(rd, 0.0001);
    float diskI = band * (0.35 + turb) * dop * smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.7, 0.92, t));
    diskI *= mix(1.0 - hole, 1.0, step(0.0, v.y));
    vec3 hot = tinted(vec3(1.0, 0.7, 0.4));
    float ring = exp(-pow((r - rh * 1.1) * resolution.y / 2.5, 2.0)) * step(0.0005, rh);
    float tf = smoothstep(0.9, 1.0, t);
    float flash = exp(-r * r * 3000.0) * sin(PI * tf) * 2.0 + exp(-pow((r - tf * 0.3) * 50.0, 2.0)) * (1.0 - tf) * step(0.001, tf) * 0.6;
    vec3 rgb = c.rgb * (1.0 - hole) + hot * diskI * 1.4 + vec3(1.0, 0.95, 0.9) * (ring * 0.7 * (1.0 - tf) + flash);
    FRAG_COLOR = vec4(rgb, mix(c.a, 1.0, hole)) * qt_Opacity;
}
