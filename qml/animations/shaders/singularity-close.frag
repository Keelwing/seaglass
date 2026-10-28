// Singularity, closing: pulled into a black hole, which then winks out.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 C = asp(origin);
    vec2 v = p - C;
    float r = length(v);
    float ang = atan(v.y, v.x);
    float k = smoothstep(0.0, 0.9, t);
    float pull = 0.56 * k * k * k;
    float rs = r + pull * (0.6 + 0.02 / (r * r + 0.004));
    float as = ang - 2.4 * k / (r * 6.0 + 0.25);
    vec2 sd = vec2(cos(as), sin(as));
    vec2 sp = C + sd * rs;
    vec2 suv = vec2(sp.x / aspect, sp.y);
    vec4 c = src(suv);
    // the hole grows from nothing (no dot at progress 0) and collapses into the flash
    float rh = 0.062 * easeInOut(clamp(t * 1.4, 0.0, 1.0)) * (1.0 - smoothstep(0.7, 0.9, t));
    float hole = (1.0 - smoothstep(rh - 0.003, rh + 0.003, r)) * step(0.0005, rh);
    vec3 hot = tinted(vec3(1.0, 0.7, 0.4));
    // what falls in heats up as it reaches the disk
    float heat = smoothstep(rh * 3.5, rh * 1.2, r) * k * step(0.0005, rh);
    c.rgb = mix(c.rgb, hot * (0.5 + luma(c.rgb)) * c.a, heat * 0.75);
    vec2 dv = vec2(v.x, v.y / 0.28);
    float rd = length(dv);
    // three turns of the noise round the disk: it wraps without a seam, and it turns with progress
    float phi = atan(dv.y, dv.x) * 0.4775;
    float band = smoothstep(rh * 1.3, rh * 1.9, rd) * (1.0 - smoothstep(rh * 2.2, rh * 4.0, rd));
    float turb = fbm(vec2(phi - t * 1.6 - time * 0.3, rd * 4.0));
    float dop = 1.0 + 0.75 * dv.x / max(rd, 0.0001);
    float life = smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.66, 0.86, t));
    float diskI = band * (0.35 + turb) * dop * life;
    diskI *= mix(1.0 - hole, 1.0, step(0.0, v.y));
    // the far side of the disk, bent over the top of the hole (and faintly under it)
    float arc = smoothstep(rh * 1.04, rh * 1.18, r) * (1.0 - smoothstep(rh * 1.2, rh * 1.65, r));
    float arcI = arc * (0.3 + fbm(vec2(ang * 0.4775 + t * 1.2, r * 9.0)))
               * mix(0.3, 1.0, smoothstep(0.3, -0.7, v.y / max(r, 0.0001))) * life;
    // its bright rim comes once the hole has some size, so it does not start as a small ring on the window
    float ring = exp(-pow((r - rh * 1.1) * resolution.y / 2.5, 2.0)) * smoothstep(0.002, 0.012, rh);
    float tf = smoothstep(0.84, 1.0, t);
    float flash = exp(-r * r * 900.0) * sin(PI * tf) * 1.6
                + exp(-pow((r - tf * 0.45) * 55.0, 2.0)) * (1.0 - tf) * step(0.001, tf) * 0.6;
    vec3 rgb = c.rgb * (1.0 - hole) + hot * (diskI * 1.4 + arcI * 1.1)
             + vec3(1.0, 0.95, 0.9) * (ring * 0.7 * (1.0 - tf) + flash);
    // a soft shadow round the hole on what is under it, so that it sits in the picture
    float shade = (1.0 - smoothstep(rh, rh * 3.2, r)) * 0.5 * life;
    FRAG_COLOR = vec4(rgb, max(mix(c.a, 1.0, hole), shade)) * qt_Opacity;
}
