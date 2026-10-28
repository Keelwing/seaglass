// Northern lights, loading: an aurora over dark hills and a still lake that mirrors it; the icon stays clear in front
// of the sky.
void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    float horizon = 0.74;
    float below = step(horizon, uv.y);
    // below the horizon the sky is mirrored, rippling a little
    vec2 sp = vec2(uv.x + below * (vnoise(vec2(uv.y * 3.0, time * 0.3)) - 0.5) * 0.016,
                   mix(uv.y, 2.0 * horizon - uv.y, below));
    vec4 col = vec4(mix(vec3(0.02, 0.05, 0.12), vec3(0.01, 0.02, 0.05), sp.y) * 0.9, 0.9);
    vec2 g = floor(sp * resolution / 2.0);
    float st = step(0.994, hash(g)) * (0.4 + 0.6 * sin(time * 3.0 + hash(g + 7.0) * 20.0));
    col.rgb += vec3(st) * 0.8 * (1.0 - sp.y) * mix(1.0, 0.3, below);
    float edge = 0.56 + 0.06 * sin(sp.x * 6.0 + time * 1.2) + 0.04 * sin(sp.x * 13.0 - time * 0.8);
    float dy = edge - sp.y;
    vec2 ap = asp(sp) * vec2(1.6, 1.0);
    float ray = rays(ap, time * 1.5);
    float I = (dy > 0.0 ? rayFade(ap, dy * 0.8) : exp(dy * 28.0)) * ray;
    vec3 light = (aurora(clamp(dy * 1.4, 0.0, 1.0)) * I + fringe() * exp(-abs(dy + 0.015) * 60.0) * ray * 0.3) * 0.9;
    col.rgb += light * mix(1.0, 0.4, below);
    // hills on the far shore, and a thin line of light where they meet the water
    float hill = horizon - 0.012 - 0.05 * fbm(vec2(uv.x * 0.9, 0.37));
    float land = smoothstep(hill - 0.002, hill + 0.002, uv.y)
               * (1.0 - smoothstep(horizon - 0.001, horizon + 0.002, uv.y));
    col.rgb = mix(col.rgb, vec3(0.006, 0.012, 0.024), land * 0.95);
    col.rgb += vec3(0.6, 0.8, 1.0) * exp(-pow((uv.y - horizon) * resolution.y, 2.0) * 0.3) * 0.12;
    // the icon, clear, with a little of the light on it
    vec4 icon = iconAt(vec2(0.5, 0.36), 0.40 * resolution.x, vec2(0.0));
    col = icon + col * (1.0 - icon.a);
    col.rgb += light * icon.a * 0.2;
    FRAG_COLOR = col * inside * qt_Opacity;
}
