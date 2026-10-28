// Seaglass, loading: a pane of frosted glass in the ambience's colour, its bevel lit from the top left. A light runs
// round its edge as the busy indicator does, a glint crosses it and the icon breathes.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    vec2 q = px - resolution * 0.5;
    float d;
    float inside = cardInside(d);
    float breath = 0.5 + 0.5 * sin(time * PI);
    // the glass: the colour's gradient, a slow cloud and a fine grain
    vec3 glass = mix(tint * 0.30 + 0.06, tint * 0.12 + 0.02, uv.y);
    float cloud = fbm(asp(uv) * 0.5 + vec2(time * 0.01, 0.0)) - 0.5;
    glass *= 1.0 + (hash(floor(px * 0.5)) - 0.5) * 0.08 + cloud * 0.3;
    float ga = 0.42 + 0.06 * breath;
    vec4 col = vec4(glass * ga, ga);
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x * (0.97 + 0.03 * breath), vec2(0.0));
    col = icon + col * (1.0 - icon.a);
    float band = (uv.x * 0.55 + uv.y * 0.45) - mix(-0.35, 1.35, fract(time / 1.9));
    col.rgb += vec3(1.0) * exp(-band * band * 70.0) * (0.08 + 0.25 * icon.a);
    // the bevel
    vec2 g = vec2(sdRoundRect(q + vec2(1.0, 0.0), resolution * 0.5, radiusPx),
                  sdRoundRect(q + vec2(0.0, 1.0), resolution * 0.5, radiusPx)) - d;
    float facing = dot(normalize(g + vec2(0.0001)), vec2(-0.6, -0.8));
    float bevel = 1.0 - smoothstep(0.0, 0.035 * resolution.x, -d);
    bevel *= bevel;
    col.rgb += (tint * 0.5 + 0.5) * bevel * max(facing, 0.0) * 0.3;
    col.rgb *= 1.0 - bevel * max(-facing, 0.0) * 0.3;
    // the light round the edge, its tail fading behind it
    float ang = atan(q.y / resolution.y, q.x / resolution.x);
    float behind = mod(fract(time / 1.6) * 2.0 * PI - ang + PI + 0.08, 2.0 * PI) - 0.08;
    float comet = exp(-max(behind, 0.0) * 0.9) * smoothstep(-0.08, 0.0, behind);
    float line = 1.0 - smoothstep(0.0, 2.2, abs(d + 1.4));
    col.rgb += mix(tint, vec3(1.0), 0.3) * (line * (0.3 + 1.3 * comet) + exp(d / 14.0) * comet * 0.3);
    col.a = max(col.a, line * 0.7);
    FRAG_COLOR = col * inside * qt_Opacity;
}
