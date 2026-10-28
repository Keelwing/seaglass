// Seaglass, closing: the window is lifted as a pane of frosted sea glass, tips back and rounds into a pebble as it
// falls, thick at its edges and lit from the top left, and drops into the water: rings and a few droplets where it
// goes in. originRect is the window as it was let go.
float pebble(vec2 p, vec2 halfSize, float tilt, float rad, float wob)
{
    float y01 = clamp(p.y / max(halfSize.y, 1.0) * 0.5 + 0.5, 0.0, 1.0);
    float k = 1.0 - tilt * (1.0 - y01);
    // an uneven outline: noise read round a circle, so that it closes on itself
    vec2 n = normalize(p + vec2(0.0001)) * 0.07 + vec2(0.31, 0.62);
    return sdRoundRect(vec2(p.x / k, p.y), halfSize, rad) + (vnoise(n) - 0.5) * wob;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec4 w = originRect;
    vec2 px = uv * resolution;
    vec2 target = vec2(0.5, 0.78) * resolution;
    float start = smoothstep(0.0, 0.2, t);

    // a small lift, then faster and faster down to the water, which it reaches at 0.8
    float lift = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.14, 0.42, t));
    float fall = clamp((t - 0.06) / 0.74, 0.0, 1.0);
    float e = fall * fall * (1.6 - 0.6 * fall);
    float sink = 1.0 - smoothstep(0.78, 0.9, t);
    vec2 startHalf = w.zw * 0.5 * resolution;
    vec2 endHalf = vec2(0.12, 0.085) * resolution.x;
    vec2 centre = mix((w.xy + w.zw * 0.5) * resolution, target, e) - vec2(0.0, lift * 0.02 * resolution.y);
    // the height goes first: an oval stone rather than a pill
    vec2 halfSize = mix(startHalf * (1.0 + 0.03 * lift), endHalf, vec2(e, 1.0 - (1.0 - e) * (1.0 - e)))
                  * (0.25 + 0.75 * sink);
    float tilt = 0.2 * sin(PI * fall) * start;
    float rad = min(halfSize.x, halfSize.y) * 0.92 * smoothstep(0.04, 0.6, fall);
    float wob = min(halfSize.x, halfSize.y) * 0.25 * smoothstep(0.1, 0.5, fall);

    vec2 p = px - centre;
    float d = pebble(p, halfSize, tilt, rad, wob);
    float inside = clamp(0.5 - d, 0.0, 1.0) * step(0.001, sink);
    float y01 = clamp(p.y / max(halfSize.y, 1.0) * 0.5 + 0.5, 0.0, 1.0);
    float k = 1.0 - tilt * (1.0 - y01);
    vec2 local = vec2(p.x / k, p.y) / (2.0 * halfSize) + 0.5;

    // thick glass: the rim bends the picture inwards and catches the light
    float rimWidth = max(6.0, min(halfSize.x, halfSize.y) * 0.16);
    float lens = (1.0 - smoothstep(0.0, rimWidth, -d)) * start;
    vec2 bent = 0.5 + (local - 0.5) * (1.0 - 0.1 * lens * lens);
    vec2 h = vec2(1.5, 0.0);
    vec2 slope = vec2(pebble(p + h.xy, halfSize, tilt, rad, wob) - pebble(p - h.xy, halfSize, tilt, rad, wob),
                      pebble(p + h.yx, halfSize, tilt, rad, wob) - pebble(p - h.yx, halfSize, tilt, rad, wob));
    vec3 normal = normalize(vec3(normalize(slope + vec2(0.0001)) * lens * 1.1, 1.0));
    vec3 light = normalize(vec3(-0.5, -0.7, 0.6));
    float shade = dot(normal, light);
    float spec = pow(max(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0), 18.0) * lens;

    float frost = smoothstep(0.0, 0.35, t);
    vec4 b = blurSrc(w.xy + bent * w.zw, 16.0 * frost * resolution.y / 1000.0);
    vec3 s = b.rgb / max(b.a, 0.001);
    float grain = fbm(px / 190.0) * 0.6 + vnoise(px / 37.0) * 0.4;
    vec3 glass = mix(s, mix(s, tint, 0.25) + 0.05, frost) * (1.0 + (grain - 0.5) * 0.08 * frost);
    glass *= 1.0 + 0.3 * (shade - 0.57) * lens;
    float gloss = exp(-dot(local - vec2(0.3, 0.24), local - vec2(0.3, 0.24)) * 28.0) * 0.22 * frost;
    // frosted, it is nearly opaque: the app grid does not show through the app. What the swipe wiped stays empty.
    float a = inside * mix(b.a, max(b.a, 0.82 * clipMask(clamp(w.xy + bent * w.zw, 0.0, 1.0))), frost);
    vec3 rgb = (glass + gloss) * a + vec3(1.0) * spec * 0.8 * inside;

    // its shadow on the water, softer the higher it is
    float height = 1.0 - e;
    vec2 drop = vec2(0.0, 8.0 + height * 0.03 * resolution.y);
    float blur = mix(10.0, 46.0, height);
    float sd = pebble(p - drop, halfSize, tilt, rad, wob);
    float shadow = (1.0 - smoothstep(-blur * 0.3, blur, sd)) * 0.32 * start * sink * (1.0 - inside);

    // where it goes in: two rings, a flash and a few droplets, flattened as if seen across the water
    float ta = clamp((t - 0.74) / 0.26, 0.0, 1.0);
    if (ta > 0.0) {
        vec2 q = (px - target) / resolution.x;
        float rr = length(q * vec2(1.0, 1.8));
        float pxu = 1.0 / resolution.x;
        float ring = exp(-pow((rr - ta * 0.26) / (pxu * 3.5), 2.0)) * (1.0 - ta)
                   + exp(-pow((rr - max(ta - 0.3, 0.0) * 0.22) / (pxu * 3.0), 2.0)) * (1.0 - ta) * step(0.3, ta) * 0.7;
        float flash = exp(-rr * rr * 900.0) * (1.0 - smoothstep(0.0, 0.35, ta));
        float drops = 0.0;
        for (int i = 0; i < 8; i++) {
            float fi = float(i);
            float angle = mix(0.45, 2.7, (fi + 0.5) / 8.0) + (hash(vec2(fi, 3.0)) - 0.5) * 0.3;
            float speed = 0.16 + 0.12 * hash(vec2(fi, 7.0));
            vec2 at = vec2(cos(angle), -sin(angle)) * speed * ta + vec2(0.0, 0.5 * ta * ta);
            float size = pxu * (3.5 - 1.5 * ta);
            drops += 1.0 - smoothstep(size * 0.4, size, length(q - at));
        }
        // around the pebble while it sinks, not over it
        vec3 water = mix(tint, vec3(1.0), 0.35);
        rgb += water * (ring * 0.9 + flash * 0.8 + drops * (1.0 - ta) * 0.9) * (1.0 - a);
    }

    FRAG_COLOR = vec4(rgb, a + shadow) * qt_Opacity;
}
