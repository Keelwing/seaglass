// Singularity, closing: pulled into a black hole, which then winks out.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 C = asp(origin);
    vec2 v = p - C;
    float r = length(v);
    float k = smoothstep(0.0, 0.9, t);
    float pull = 0.56 * k * k * k;
    float rs = r + pull * (0.6 + 0.02 / (r * r + 0.004));
    // the swirl turns v / r, which takes no atan
    float turn = 2.4 * k / (r * 6.0 + 0.25);
    float ct = cos(turn);
    float st = sin(turn);
    vec2 dir = r > 0.0 ? v / r : vec2(1.0, 0.0);
    vec2 sp = C + vec2(dir.x * ct + dir.y * st, dir.y * ct - dir.x * st) * rs;
    vec2 suv = vec2(sp.x / aspect, sp.y);
    vec4 c = src(suv);
    // the hole grows from nothing (no dot at progress 0) and collapses into the flash
    float rh = 0.062 * easeInOut(clamp(t * 1.4, 0.0, 1.0)) * (1.0 - smoothstep(0.7, 0.9, t));
    float hole = 0.0;
    float diskI = 0.0;
    float arcI = 0.0;
    float shade = 0.0;
    vec3 hot = vec3(0.0);
    // the hole, the heat, the disk, the arc and the shadow all end within four of its radii (disk distances are
    // never less than r)
    if (rh >= 0.0005 && r < max(rh * 4.0, rh + 0.003)) {
        hole = 1.0 - smoothstep(rh - 0.003, rh + 0.003, r);
        hot = tinted(vec3(1.0, 0.7, 0.4));
        // what falls in heats up as it reaches the disk
        float heat = (1.0 - smoothstep(rh * 1.2, rh * 3.5, r)) * k;
        c.rgb = mix(c.rgb, hot * (0.5 + luma(c.rgb)) * c.a, heat * 0.75);
        float life = smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.66, 0.86, t));
        if (life > 0.0) {
            vec2 dv = vec2(v.x, v.y / 0.28);
            float rd = length(dv);
            if (rd > rh * 1.3 && rd < rh * 4.0) {
                // three turns of the noise round the disk: it wraps without a seam, and it turns with progress
                float phi = atan(dv.y, rd > 0.0 ? dv.x : 1.0) * 0.4775;
                float band = smoothstep(rh * 1.3, rh * 1.9, rd) * (1.0 - smoothstep(rh * 2.2, rh * 4.0, rd));
                float turb = fbm(vec2(phi - t * 1.6 - time * 0.3, rd * 4.0));
                float dop = 1.0 + 0.75 * dv.x / max(rd, 0.0001);
                diskI = band * (0.35 + turb) * dop * life;
                diskI *= mix(1.0 - hole, 1.0, step(0.0, v.y));
            }
            // the far side of the disk, bent over the top of the hole (and faintly under it)
            if (r > rh * 1.04 && r < rh * 1.65) {
                float arc = smoothstep(rh * 1.04, rh * 1.18, r) * (1.0 - smoothstep(rh * 1.2, rh * 1.65, r));
                arcI = arc * (0.3 + fbm(vec2(atan(v.y, r > 0.0 ? v.x : 1.0) * 0.4775 + t * 1.2, r * 9.0)))
                     * mix(0.3, 1.0, 1.0 - smoothstep(-0.7, 0.3, v.y / max(r, 0.0001))) * life;
            }
            // a soft shadow round the hole on what is under it, so that it sits in the picture
            shade = (1.0 - smoothstep(rh, rh * 3.2, r)) * 0.5 * life;
        }
    }
    // its bright rim comes once the hole has some size, so it does not start as a small ring on the window. Measured
    // in pixels, so not part of the above; past four widths of the Gaussians it and the flash add nothing a screen
    // shows
    float rx = (r - rh * 1.1) * resolution.y / 2.5;
    float ring = abs(rx) < 4.0 ? exp(-rx * rx) * smoothstep(0.002, 0.012, rh) : 0.0;
    float tf = smoothstep(0.84, 1.0, t);
    float flash = 0.0;
    if (tf > 0.0) {
        float fx = (r - tf * 0.45) * 55.0;
        if (r < 0.14)
            flash = exp(-r * r * 900.0) * sin(PI * tf) * 1.6;
        if (abs(fx) < 4.0)
            flash += exp(-fx * fx) * (1.0 - tf) * step(0.001, tf) * 0.6;
    }
    vec3 rgb = c.rgb * (1.0 - hole) + hot * (diskI * 1.4 + arcI * 1.1)
             + vec3(1.0, 0.95, 0.9) * (ring * 0.7 * (1.0 - tf) + flash);
    FRAG_COLOR = vec4(rgb, max(mix(c.a, 1.0, hole), shade)) * qt_Opacity;
}
