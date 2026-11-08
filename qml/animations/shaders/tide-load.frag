// Tide, loading: water rises in the cover over the icon, lighter under the surface and deeper below, with light
// shafts, soft caustics and bubbles that wobble up at their own pace.
// a lane of bubbles, one per column at a time: how much of a bubble is at px
float bubbles(vec2 px, float lane, float cols, float surfPx)
{
    float colW = resolution.x / cols;
    float ci = floor(px.x / colW);
    float h1 = hash(vec2(ci, lane * 7.0 + 1.0));
    float h2 = hash(vec2(ci, lane * 7.0 + 2.0));
    float run = time * mix(0.16, 0.30, h1) + h2;
    // some rises are left out; the choice changes only while the bubble is faded out
    if (hash(vec2(ci, lane * 5.0 + floor(run))) < 0.35)
        return 0.0;
    float ph = fract(run);
    float h3 = hash(vec2(ci, lane * 7.0 + 3.0));
    float r = mix(2.0, 5.0, h3) * resolution.x / 351.0;
    vec2 c = px - vec2((ci + 0.5 + (h1 - 0.5) * 0.4) * colW + sin(time * 2.5 + h2 * 6.28) * 2.5,
                       mix(resolution.y + r, surfPx + r, ph));
    float d = length(c);
    // past its ring; its highlight is inside it
    if (d >= r + 0.6)
        return 0.0;
    float ring = smoothstep(r - 1.6, r - 0.6, d) * (1.0 - smoothstep(r - 0.4, r + 0.6, d));
    float spec = 1.0 - smoothstep(0.0, r * 0.4, length(c + r * 0.35));
    float fade = smoothstep(0.0, 0.15, ph) * (1.0 - smoothstep(0.85, 1.0, ph));
    return (ring * 0.7 + spec * 0.6) * fade;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    if (inside <= 0.0) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    vec2 px = uv * resolution;
    float level = 0.18 + 0.62 * (1.0 - exp(-time / 1.8));
    float surf = 1.0 - level + 0.014 * sin(uv.x * 9.0 + time * 2.6) + 0.008 * sin(uv.x * 21.0 - time * 3.9)
               + (fbm(vec2(uv.x * 0.6 + time * 0.05, time * 0.08)) - 0.5) * 0.02;
    float dy = uv.y - surf;
    float under = smoothstep(-0.003, 0.003, dy);
    // the icon: under the surface lifted a little, as seen through water, and wobbling
    vec2 off = vec2(0.0);
    if (under > 0.0)
        off = under * (vec2(sin(uv.y * 38.0 + time * 2.4), cos(uv.x * 31.0 + time * 1.9)) * 0.010 + vec2(0.0, 0.025));
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x, off);
    // the air: dark glass, a little lighter at the top left
    vec3 air = mix(vec3(0.07, 0.10, 0.13), vec3(0.03, 0.05, 0.07), uv.y)
             + 0.05 * (1.0 - smoothstep(0.0, 0.7, length(uv - vec2(0.15, 0.05))));
    vec4 col = vec4(air * 0.6, 0.6);
    col = icon + col * (1.0 - icon.a);
    float rising = 0.0;
    if (under > 0.0) {
        // the water keeps its own deep colour, as in tide-close; its shafts and caustics take the ambience's
        vec3 tone = vec3(0.10, 0.50, 0.70);
        float depth = clamp(dy / max(level, 0.05), 0.0, 1.0);
        vec3 w = tone * mix(1.1, 0.5, depth);
        // the caustics: wide cells, bent round by smooth noise, brightest under the surface
        vec2 cq = asp(uv) * 0.9 + vec2(time * 0.025, -time * 0.05)
                + (vec2(vnoise(uv * 0.3 + time * 0.01), vnoise(uv * 0.3 + 0.5 - time * 0.01)) - 0.5) * 0.4;
        float caust = 1.0 - smoothstep(0.0, 0.16, cells(cq));
        caust *= caust * smoothstep(0.3, 0.6, fbm(cq * 1.3 + 2.3)) * exp(-max(dy, 0.0) * 3.0);
        float shafts = smoothstep(0.5, 0.85, fbm(vec2(uv.x * 1.6 + dy * 0.5 + time * 0.02, time * 0.03)))
                     * exp(-max(dy, 0.0) * 4.0);
        w += tinted(vec3(0.75, 0.95, 1.0)) * (caust * 0.3 + shafts * 0.2);
        float wa = under * 0.62;
        col.rgb = col.rgb * (1.0 - wa) + w * wa;
        col.a = col.a + wa * (1.0 - col.a);
        float surfPx = surf * resolution.y;
        rising = (bubbles(px, 0.0, 9.0, surfPx) + bubbles(px, 1.0, 9.0, surfPx)) * under * 0.7;
    }
    // the surface: a bright meniscus, a darker band just under it
    float spx = dy * resolution.y;
    col.rgb += vec3(0.85, 0.97, 1.0) * exp(-spx * spx * 0.3) * 0.65;
    col.rgb *= 1.0 - 0.18 * exp(-max(spx - 2.0, 0.0) * 0.25) * step(0.0, spx);
    col.rgb += vec3(0.85, 0.95, 1.0) * rising;
    FRAG_COLOR = col * inside * qt_Opacity;
}
