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
    // a lens: the light seen at r comes from nearer the hole (r - 0.0048 / r), so what is right behind it shows as
    // a ring round it; and a little twist, as the hole drags space round with it, which turns v / r and takes no atan
    float rs = max(r - 0.0048 / max(r, 0.001), 0.0);
    float turn = 0.3 / (r * 9.0 + 0.35);
    float ct = cos(turn);
    float st = sin(turn);
    vec2 dir = v / max(r, 0.0001);
    vec2 ip = (vec2(dir.x * ct - dir.y * st, dir.x * st + dir.y * ct) * rs + off) / 0.4 + 0.5;
    vec4 icon = boxMask(ip) > 0.0 ? texture2D(source, ip) : vec4(0.0);
    vec4 col = icon * 0.85 + vec4(vec3(0.01, 0.01, 0.03) * 0.85, 0.85) * (1.0 - icon.a * 0.85);
    // stars falling in, behind the icon: points in cells of a turn and the log of the radius, nearly square at
    // every radius
    if (r > 0.08 && icon.a < 1.0) {
        vec2 sg = vec2((atan(v.y, r > 0.0 ? v.x : 1.0) / (2.0 * PI) + 0.5) * 88.0, log(r + 0.02) * 14.0 + time * 2.0);
        if (hash(sg) >= 0.97) {
            float star = (1.0 - smoothstep(0.12, 0.3, length(fract(sg) - 0.5))) * smoothstep(0.08, 0.16, r);
            col.rgb += vec3(0.8, 0.85, 1.0) * star * 0.7 * (1.0 - icon.a);
        }
    }
    float rh = 0.06;
    float hole = 1.0 - smoothstep(rh - 0.004, rh + 0.004, r);
    col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), hole);
    float disk = 0.0;
    float arcI = 0.0;
    // the disk and the arc end within 3.8 of the hole's radii (disk distances are never less than r)
    if (r < rh * 3.8) {
        vec2 dv = vec2(v.x, v.y / 0.3);
        float rd = length(dv);
        if (rd > rh * 1.2 && rd < rh * 3.8) {
            float band = smoothstep(rh * 1.2, rh * 1.7, rd) * (1.0 - smoothstep(rh * 2.0, rh * 3.8, rd));
            // three turns of the noise round the disk: it wraps without a seam
            float turb = fbm(vec2(atan(dv.y, rd > 0.0 ? dv.x : 1.0) * 0.4775 - time * 1.2, rd * 5.0));
            float dop = 1.0 + 0.7 * (dv.x / max(rd, 0.0001));
            disk = band * (0.4 + turb) * dop * mix(1.0 - hole, 1.0, step(0.0, v.y));
        }
        // the far side of the disk, bent over the top of the hole (and faintly under it)
        if (r > rh * 1.04 && r < rh * 1.6) {
            float arc = smoothstep(rh * 1.04, rh * 1.18, r) * (1.0 - smoothstep(rh * 1.2, rh * 1.6, r));
            arcI = arc * (0.3 + fbm(vec2(atan(v.y, r > 0.0 ? v.x : 1.0) * 0.4775 + time * 0.8, r * 9.0)))
                 * mix(0.3, 1.0, 1.0 - smoothstep(-0.7, 0.3, v.y / max(r, 0.0001)));
        }
        if (disk + arcI > 0.0) {
            col.rgb += tinted(vec3(1.0, 0.72, 0.42)) * (disk * 1.3 + arcI);
            col.a = max(col.a, clamp(disk + arcI, 0.0, 1.0));
        }
    }
    // the rim is measured in pixels, so not part of the above; past four widths of its Gaussian it adds nothing a
    // screen shows
    float rx = (r - rh * 1.08) * resolution.x / 1.5;
    if (abs(rx) < 4.0)
        col.rgb += vec3(1.0, 0.95, 0.9) * exp(-rx * rx) * 0.8;
    FRAG_COLOR = col * inside * qt_Opacity;
}
