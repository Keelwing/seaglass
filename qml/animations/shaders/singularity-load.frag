// Singularity, loading: a small black hole spins in the cover, beside the icon, and bends it.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    float d;
    float inside = cardInside(d);
    // the hole sits below and right of the icon's middle (width units), so the icon still shows, bent round it
    vec2 off = vec2(0.075, 0.07);
    vec2 v = (px - resolution * vec2(0.5, 0.46)) / resolution.x - off;
    float r = length(v);
    float ang = atan(v.y, v.x);
    // a lens: the light seen at r comes from nearer the hole (r - 0.0048 / r), so what is right behind it shows as
    // a ring round it; and a little twist, as the hole drags space round with it
    float rs = max(r - 0.0048 / max(r, 0.001), 0.0);
    float as = ang + 0.3 / (r * 9.0 + 0.35);
    vec2 ip = (vec2(cos(as), sin(as)) * rs + off) / 0.4 + 0.5;
    vec4 icon = texture2D(source, clamp(ip, 0.0, 1.0)) * boxMask(ip);
    vec4 col = icon * 0.85 + vec4(vec3(0.01, 0.01, 0.03) * 0.85, 0.85) * (1.0 - icon.a * 0.85);
    // stars falling in, behind the icon: points in cells of a turn and the log of the radius, nearly square at
    // every radius
    vec2 sg = vec2((ang / (2.0 * PI) + 0.5) * 88.0, log(r + 0.02) * 14.0 + time * 2.0);
    float st = step(0.97, hash(sg)) * (1.0 - smoothstep(0.12, 0.3, length(fract(sg) - 0.5)))
             * smoothstep(0.08, 0.16, r);
    col.rgb += vec3(0.8, 0.85, 1.0) * st * 0.7 * (1.0 - icon.a);
    float rh = 0.06;
    float hole = 1.0 - smoothstep(rh - 0.004, rh + 0.004, r);
    col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), hole);
    float ring = exp(-pow((r - rh * 1.08) * resolution.x / 1.5, 2.0));
    vec2 dv = vec2(v.x, v.y / 0.3);
    float rd = length(dv);
    float band = smoothstep(rh * 1.2, rh * 1.7, rd) * (1.0 - smoothstep(rh * 2.0, rh * 3.8, rd));
    // three turns of the noise round the disk: it wraps without a seam
    float turb = fbm(vec2(atan(dv.y, dv.x) * 0.4775 - time * 1.2, rd * 5.0));
    float dop = 1.0 + 0.7 * (dv.x / max(rd, 0.0001));
    float disk = band * (0.4 + turb) * dop * mix(1.0 - hole, 1.0, step(0.0, v.y));
    // the far side of the disk, bent over the top of the hole (and faintly under it)
    float arc = smoothstep(rh * 1.04, rh * 1.18, r) * (1.0 - smoothstep(rh * 1.2, rh * 1.6, r));
    float arcI = arc * (0.3 + fbm(vec2(ang * 0.4775 + time * 0.8, r * 9.0)))
               * mix(0.3, 1.0, smoothstep(0.3, -0.7, v.y / max(r, 0.0001)));
    col.rgb += tinted(vec3(1.0, 0.72, 0.42)) * (disk * 1.3 + arcI) + vec3(1.0, 0.95, 0.9) * ring * 0.8;
    col.a = max(col.a, clamp(disk + arcI, 0.0, 1.0));
    FRAG_COLOR = col * inside * qt_Opacity;
}
