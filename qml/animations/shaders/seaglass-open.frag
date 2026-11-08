// Seaglass, opening: the window rises from the icon or cover as a thick pane of frosted glass in the ambience's
// colour, its bevel lit from the top left, and settles a little past full size. The frost clears from corner to
// corner as it lands, a glint riding the clearing edge.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    float c1 = 0.7;
    float tm = t - 1.0;
    float e = 1.0 + (c1 + 1.0) * tm * tm * tm + c1 * tm * tm;
    vec4 r = mix(originRect, vec4(0.0, 0.0, 1.0, 1.0), e);
    vec2 px = uv * resolution;
    vec2 centre = (r.xy + r.zw * 0.5) * resolution;
    vec2 halfSize = max(r.zw * 0.5 * resolution, vec2(1.0));
    // the corners of what it opens from (a round icon, a cover), square by the time it lands
    float rad = min(mix(radiusPx, 0.0, smoothstep(0.0, 0.85, t)), min(halfSize.x, halfSize.y));
    vec2 q = px - centre;
    float d = sdRoundRect(q, halfSize, rad);
    float inside = clamp(0.5 - d, 0.0, 1.0);
    float glassOn = 1.0 - smoothstep(0.7, 1.0, t);
    float show = smoothstep(0.0, 0.08, t);
    float rim = (1.0 - smoothstep(0.0, 2.0, abs(d + 1.0))) * 0.35 * glassOn;
    vec3 rgb = mix(tint, vec3(1.0), 0.5) * rim * show;
    float a = 0.0;
    if (inside > 0.0) {
        vec2 local = (uv - r.xy) / max(r.zw, vec2(0.001));

        // the bevel: the picture bends in near the edge, which is lit on the top left and shaded on the bottom right
        float lens = (1.0 - smoothstep(0.0, 0.01 * resolution.y, -d)) * glassOn;
        float facing = 0.0;
        if (lens > 0.0) {
            vec2 g = vec2(sdRoundRect(q + vec2(1.0, 0.0), halfSize, rad), sdRoundRect(q + vec2(0.0, 1.0), halfSize, rad)) - d;
            facing = dot(normalize(g + vec2(0.0001)), vec2(-0.6, -0.8));
        }
        vec2 bent = 0.5 + (local - 0.5) * (1.0 - 0.05 * lens * lens);

        // the frost clears along the diagonal, from the top left, at an even pace to the last corner
        float diag = (local.x + local.y) * 0.5;
        float clearAt = mix(-0.35, 1.1, clamp((t - 0.25) / 0.7, 0.0, 1.0));
        float frost = smoothstep(clearAt - 0.05, clearAt + 0.25, diag);
        vec4 b;
        if (frost > 0.0004) {
            b = blurSrc(bent, 22.0 * frost * resolution.y / 1000.0);
        } else {
            // cleared: a blur this narrow is the window itself
#ifdef ES3
            b = textureLod(source, bent, 0.0);
#else
            b = texture2D(source, bent);
#endif
        }
        vec3 s = b.rgb / max(b.a, 0.001);
        vec3 glass = mix(s, mix(s, tint, 0.24) + 0.05, frost);
        glass *= 1.0 + 0.2 * facing * lens;
        float lit = max(facing, 0.0);
        lit *= lit;
        glass += vec3(1.0) * lit * lit * lit * lens * 0.4;
        // the glint riding the clearing edge, below a millionth of a level more than 0.32 from its ridge
        float ridge = (diag - clearAt - 0.03) * 14.0;
        float glint = 0.0;
        if (abs(ridge) < 4.5)
            glint = exp(-ridge * ridge) * 0.3 * smoothstep(0.25, 0.4, t) * glassOn;
        a = inside * b.a * show;
        rgb += (glass + glint) * a;
    }
    float shadow = (1.0 - smoothstep(0.0, 26.0, d)) * step(0.0, d) * 0.3 * show * (1.0 - smoothstep(0.6, 1.0, t));
    FRAG_COLOR = vec4(rgb, a + shadow * (1.0 - a)) * qt_Opacity;
}
