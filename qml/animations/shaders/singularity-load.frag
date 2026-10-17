// Singularity, loading: a small black hole spins in the cover.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    float d;
    float inside = cardInside(d);
    vec2 v = (px - resolution * vec2(0.5, 0.48)) / resolution.x;
    float r = length(v);
    float ang = atan(v.y, v.x);
    float rs = r + 0.012 / (r + 0.02);
    float as = ang + 0.9 / (r * 9.0 + 0.35) + time * 0.4 * (0.15 / (r + 0.15));
    vec2 ip = vec2(cos(as), sin(as)) * rs / 0.44 + 0.5;
    vec4 icon = texture2D(source, clamp(ip, 0.0, 1.0)) * boxMask(ip);
    vec4 col = icon * 0.85 + vec4(vec3(0.01, 0.01, 0.03) * 0.85, 0.85) * (1.0 - icon.a * 0.85);
    vec2 sg = vec2(ang * 8.0, log(r + 0.02) * 14.0 + time * 1.5);
    float st = step(0.97, hash(sg)) * (1.0 - smoothstep(0.1, 0.4, length(fract(sg) - 0.5)));
    col.rgb += vec3(0.8, 0.85, 1.0) * st * 0.6;
    float rh = 0.075;
    float hole = 1.0 - smoothstep(rh - 0.004, rh + 0.004, r);
    col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), hole);
    float ring = exp(-pow((r - rh * 1.08) * resolution.x / 1.5, 2.0));
    vec2 dv = vec2(v.x, v.y / 0.3);
    float rd = length(dv);
    float band = smoothstep(rh * 1.2, rh * 1.7, rd) * (1.0 - smoothstep(rh * 2.0, rh * 3.8, rd));
    float turb = fbm(vec2(atan(dv.y, dv.x) * 0.5 - time * 0.6, rd * 5.0));
    float dop = 1.0 + 0.7 * (dv.x / max(rd, 0.0001));
    float disk = band * (0.4 + turb) * dop * mix(1.0 - hole, 1.0, step(0.0, v.y));
    col.rgb += tinted(vec3(1.0, 0.72, 0.42)) * disk * 1.3 + vec3(1.0, 0.95, 0.9) * ring * 0.8;
    col.a = max(col.a, clamp(disk, 0.0, 1.0));
    FRAG_COLOR = col * inside * qt_Opacity;
}
