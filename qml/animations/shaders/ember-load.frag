// Ember, loading: the cover smoulders: coals glow under the icon, low flames lick up, sparks rise.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    // the height above the bottom; along the lower sides it is lower, so that the flames climb them a little
    float h = min(1.0 - uv.y, 0.03 + (-d) / resolution.y * 2.5 + (1.0 - uv.y) * 0.4);
    // tongues: fractal noise, warped sideways by a slower one, and a height that travels along the bottom
    float w = (fbm(vec2(p.x * 1.7, p.y * 0.9 + time * 0.9)) - 0.35) * 0.25;
    float fl = fbm(vec2((p.x + w) * 2.6, p.y * 1.3 + time * 1.1)) * 0.65
               + fbm(vec2((p.x - w) * 6.0 + 0.37, p.y * 2.8 + time * 2.3)) * 0.35;
    float height = 0.2 + 0.2 * vnoise(vec2(p.x * 2.0, time * 0.35)) + 0.03 * sin(time * 2.1);
    float flame = clamp(1.0 - h / (height * (0.45 + fl)), 0.0, 1.0);
    // thinner over the coals, which show through
    flame = flame * flame * (0.55 + 0.45 * smoothstep(0.02, 0.09, h));
    // a bed of coals: hot and dark patches that flare and fade, and here and there a thin dark crack
    float bed = 1.0 - smoothstep(0.03, 0.08, h + (vnoise(vec2(p.x * 5.0, 0.3)) - 0.5) * 0.05);
    float crack = mix(1.0, smoothstep(0.0, 0.12, cells(p * 5.0 + 0.23)), 0.8 * smoothstep(0.25, 0.5, fbm(p * 3.0 + 0.7)));
    float glowing = smoothstep(0.1, 0.65, fbm(p * 4.5 + vec2(time * 0.12, time * 0.05)));
    float coal = bed * crack * (0.2 + 0.8 * glowing);
    float pulse = 0.6 + 0.4 * sin(time * 1.7);
    vec4 icon = iconAt(vec2(0.5, 0.44), 0.44 * resolution.x, vec2(sin(uv.y * 50.0 + time * 12.0) * 0.004 * flame, 0.0));
    // the icon is lit from below, most of all along its lower rim, more as the coals flare (light on its colours,
    // not added to them, which would turn it muddy in an ambience's colour)
    float below = iconAt(vec2(0.5, 0.44), 0.44 * resolution.x, vec2(0.0, 0.025)).a;
    float under = (smoothstep(0.36, 0.6, uv.y) * 0.5 + icon.a * (1.0 - below) * 0.8) * (0.7 + 0.3 * pulse);
    vec3 lit = icon.rgb * (0.7 + 0.5 * flame + fire(0.55) * under);
    // the fire's glow on the cover, and a faint smoke drifting up
    float smoke = fbm(vec2(p.x * 1.8, p.y * 1.2 + time * 0.25));
    vec3 bg = vec3(0.03, 0.025, 0.03) + fire(0.3) * (0.3 * exp(-h * 3.0) * pulse + 0.06 * smoke * smoothstep(0.1, 0.6, h));
    vec4 col = vec4(lit, icon.a) + vec4(bg * 0.8, 0.8) * (1.0 - icon.a);
    // sparks in two sizes rise from the fire, sway, and burn out on the way up
    float spark = 0.0;
    for (int i = 0; i < 2; i++) {
        float k = 34.0 + float(i) * 22.0;
        vec2 sg = vec2(p.x * k, (p.y + time * (0.24 + float(i) * 0.1)) * k);
        vec2 id = floor(sg) + float(i) * 57.0;
        vec2 sc = vec2(0.5 + sin(time * 2.0 + hash(id + 3.0) * 6.28) * 0.25, 0.5);
        float s = step(0.982, hash(id)) * (1.0 - smoothstep(0.08, 0.2, length((fract(sg) - sc) * vec2(1.0, 0.5))));
        // each burns out at a height of its own
        spark += s * smoothstep(0.25 + 0.5 * hash(id + 9.0), 0.9, uv.y);
    }
    col.rgb += fire(flame) * flame * 1.3 + fire(0.25 + 0.4 * coal) * coal * 1.1 + fire(0.8) * spark * 1.3;
    col.a = max(col.a, clamp(flame + coal, 0.0, 1.0));
    FRAG_COLOR = col * inside * qt_Opacity;
}
