// Shatter, loading: the cover cracks from a point on the icon, the cracks fill with gold and heal.
// a crack w pixels wide, d pixels away, with a pixel of soft edge
float crackAt(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d); }
void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    float cyc = 2.6;
    float ph = fract(time / cyc);
    float sd = floor(time / cyc);
    float unit = resolution.x;
    vec2 o = resolution * vec2(0.5, 0.46) + (vec2(hash(vec2(sd, 1.0)), hash(vec2(sd, 2.0))) - 0.5) * 0.16 * unit;
    vec2 v = (uv * resolution - o) / unit;
    float r = length(v);
    float N = 9.0;
    float s = atan(v.y, r > 0.0 ? v.x : 1.0) * N / (2.0 * PI) + hash(vec2(sd, 3.0));
    float grow = easeOutCubic(clamp(ph / 0.3, 0.0, 1.0));
    float fillR = 1.1 * smoothstep(0.18, 0.62, ph);
    float isGold = step(r, fillR);
    float w = mix(1.3, 2.6, isGold);
    // the rays: nearly straight lines with a slight kink every 1/9 of the width (white noise), straight at the point
    // of impact. A ray's and a sector's numbers wrap round (mod N): s jumps by N where atan does, to the left of the
    // point, and a ray or arc there would change halfway
    float k = mod(floor(s + 0.5), N);
    float ray = 0.0;
    float glow = 0.0;
    if (r <= (0.35 + 0.6 * hash(vec2(k, sd + 5.0))) * grow) {
        // the kink moves a ray by at most 0.08 of a sector: past that and the 22 pixels the glow reaches, no ray here
        float fs = s - floor(s + 0.5);
        if ((abs(fs) - 0.08 * min(1.0, r * 5.0)) * 2.0 * PI / N * r * unit < 22.0) {
            float seg = r * 9.0;
            float i0 = floor(seg);
            float wob = mix(hash(vec2(i0, k + sd * 13.0)), hash(vec2(i0 + 1.0, k + sd * 13.0)), fract(seg)) - 0.5;
            float dRay = abs(fs + wob * 0.16 * min(1.0, r * 5.0)) * 2.0 * PI / N * r * unit;
            // the rays start a little way out, round a small crushed spot, so they do not run together at the point
            ray = crackAt(dRay, w) * smoothstep(0.012, 0.025, r);
            if (isGold > 0.0)
                glow = exp(-dRay * dRay / 30.0) * (1.0 - smoothstep(0.7, 1.0, ph)) * 0.18;
        }
    }
    // a few arcs between the rays
    float j = mod(floor(s), N);
    float arc = 0.0;
    if (r <= 0.4 * grow) {
        float q = r / 0.12 + (hash(vec2(j, sd + 9.0)) - 0.5) * 0.4;
        float n = floor(q + 0.5);
        if (n >= 0.5 && n <= 3.5 && hash(vec2(j * 7.0 + n, sd + 11.0)) >= 0.6)
            arc = crackAt(abs(q - n) * 0.12 * unit, w * 0.8);
    }
    float spot = (1.0 - smoothstep(0.008, 0.016, r)) * grow;
    float crack = max(max(ray, arc), spot) * (1.0 - smoothstep(0.78, 1.0, ph));
    // the pieces of the icon shift apart while it is cracked, and close as the gold sets: by at most 0.0175 of its
    // width, so only that far round it is there anything to read
    vec4 icon = vec4(0.0);
    vec2 fromIcon = abs(uv - vec2(0.5, 0.46)) * resolution / (0.46 * resolution.x);
    if (max(fromIcon.x, fromIcon.y) <= 0.5175) {
        float split = grow * (1.0 - smoothstep(0.5, 0.75, ph)) * step(0.03, r);
        vec2 off = vec2(0.0);
        if (split > 0.0)
            off = (vec2(hash(vec2(j, sd + 20.0)), hash(vec2(j, sd + 21.0))) - 0.5) * 0.035 * split;
        icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x, off);
    }
    vec4 col = icon + vec4(vec3(0.04, 0.05, 0.07) * 0.7, 0.7) * (1.0 - icon.a);
    vec3 gold = mix(vec3(1.0, 0.78, 0.36), tint, 0.25 + 0.5 * useTint);
    if (crack > 0.0) {
        float shimmer = 0.8 + 0.35 * sin(time * 5.0 - r * 30.0);
        vec3 line = mix(vec3(0.75, 0.82, 0.9), gold * shimmer, isGold);
        col = mix(col, vec4(mix(line, line * 0.45, icon.a), 1.0), crack);
    }
    col.rgb += gold * glow * col.a;
    // the blow: a flash at the point as the round starts
    if (ph < 0.1 && r * r < 0.03) {
        float flash = exp(-r * r / 0.0012) * sin(PI * (ph / 0.1));
        col.rgb += vec3(1.0, 0.97, 0.92) * flash * 0.8;
        col.a = max(col.a, flash * 0.8);
    }
    FRAG_COLOR = col * inside * qt_Opacity;
}
