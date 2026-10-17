// Ember, closing: burns away from the bottom up.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    float n = fbm(p * 0.9) * 0.7 + fbm(p * 2.7 + 0.31) * 0.3;
    float level = t * 1.42 - 0.2;
    float h = (originRect.y + originRect.w - uv.y) / originRect.w + (n - 0.5) * 0.38;
    float d = level - h;
    float haze = smoothstep(-0.35, 0.0, d) * (1.0 - smoothstep(0.0, 0.02, d));
    vec2 suv = uv + vec2(sin(uv.y * 70.0 + time * 18.0), cos(uv.x * 60.0 + time * 15.0)) * 0.0035 * haze;
    vec4 c = src(suv);
    float charA = smoothstep(-0.07, -0.005, d);
    vec3 rgb = mix(c.rgb, vec3(0.10, 0.045, 0.02) * c.a, charA);
    float alive = 1.0 - smoothstep(0.0, 0.012, d);
    float edge = exp(-pow((d - 0.004) / 0.012, 2.0));
    float fl = fbm(vec2(p.x * 2.2, p.y * 1.1 + time * 1.4));
    float fl2 = vnoise(vec2(p.x * 6.0, p.y * 3.0 + time * 2.6));
    float flameH = 0.07 + 0.32 * fl * fl2;
    float flame = clamp(1.0 - (-d) / flameH, 0.0, 1.0) * step(d, 0.02) * smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.88, 1.0, t));
    flame *= smoothstep(0.25, 0.6, fl * 1.2 + fl2 * 0.3);
    float heat = max(edge, flame * 0.85);
    vec3 light = fire(heat) * (edge * 1.4 + flame * 1.2) * c.a;
    vec2 sg = vec2(p.x * 60.0, (p.y + time * 0.35) * 60.0);
    float spark = step(0.993, hash(sg)) * (1.0 - smoothstep(0.1, 0.35, length(fract(sg) - 0.5)))
                            * smoothstep(-0.45, -0.02, d) * (1.0 - smoothstep(-0.02, 0.03, d));
    light += fire(0.75) * spark * 1.5;
    FRAG_COLOR = vec4(rgb * alive + light, c.a * alive) * qt_Opacity;
}
