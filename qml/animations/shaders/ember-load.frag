// Ember, loading: the cover smoulders; sparks rise.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    float h = 1.0 - uv.y;
    float fl = fbm(vec2(p.x * 2.6, p.y * 1.3 + time * 1.1)) * 0.65 + vnoise(vec2(p.x * 7.0, p.y * 3.2 + time * 2.3)) * 0.35;
    float height = 0.30 + 0.06 * sin(time * 2.1) + 0.04 * sin(time * 4.7);
    float flame = clamp(1.0 - h / (height * (0.5 + fl)), 0.0, 1.0);
    flame = flame * flame;
    vec4 icon = iconAt(vec2(0.5, 0.44), 0.44 * resolution.x, vec2(sin(uv.y * 50.0 + time * 12.0) * 0.004 * flame, 0.0));
    vec3 lit = icon.rgb * (0.6 + 0.6 * flame) + fire(0.55) * 0.35 * (1.0 - uv.y) * icon.a;
    vec4 col = vec4(lit, icon.a) + vec4(vec3(0.06, 0.03, 0.02) * 0.75, 0.75) * (1.0 - icon.a);
    float coal = exp(-h * 18.0) * (0.5 + 0.8 * fbm(vec2(p.x * 3.0 + time * 0.1, time * 0.3)));
    vec2 sg = vec2(p.x * 40.0, (p.y + time * 0.3) * 40.0);
    float spark = step(0.985, hash(sg)) * (1.0 - smoothstep(0.1, 0.35, length(fract(sg) - 0.5))) * smoothstep(0.0, 0.5, uv.y);
    float heat = max(flame, coal);
    col.rgb += fire(heat) * (flame * 1.3 + coal * 0.9) + fire(0.8) * spark * 1.2;
    col.a = max(col.a, clamp(flame + coal, 0.0, 1.0));
    FRAG_COLOR = col * inside * qt_Opacity;
}
