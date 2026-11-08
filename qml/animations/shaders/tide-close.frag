// Tide, closing: a wave rolls up from the bottom and washes the window away. Under the crest the app is dragged up
// and sideways and dissolves into the water; the crest is a ragged lip of foam.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    // the front: from far enough below the bottom that its bulge is off the window, to past the top at t 0.91, a
    // little faster as it goes
    float s = t * (0.7 + 0.3 * t);
    float base = originRect.y + originRect.w * mix(1.13, -0.16, s);
    // its waves below stay within 0.054 of that. Well behind the crest: nothing left
    if (uv.y - base > 0.054 + 0.36) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    // well ahead of it, where the bulge moves the app by under a hundredth of a pixel: the app as it is. A still's app
    // has mipmaps and a read's level comes from the pixels around it, so one read for this and for the dragged app,
    // not one in each branch
    bool plain = uv.y - base < -0.054 - 0.12;
    vec2 p = asp(uv);
    float dy = 0.0;
    float depth = 0.0;
    float ahead = 0.0;
    float dissolve = 0.0;
    vec2 at = uv;
    if (!plain) {
        float w = 0.016 * sin(p.x * 9.0 + t * 7.0) + 0.008 * sin(p.x * 23.0 - t * 11.0)
                + (fbm(vec2(p.x * 1.1 + t * 0.25, t * 0.4)) - 0.5) * 0.06;
        dy = uv.y - (base + w);
        depth = max(dy, 0.0);
        // the app: lifted by the bulge just ahead of the crest and in its shadow, dragged up and sideways under it
        ahead = exp(min(dy, 0.0) * 70.0) * step(dy, 0.0);
        dissolve = smoothstep(0.0, 0.075, depth);
        if (dissolve < 1.0) {
            float swirl = depth > 0.0 ? fbm(p * 2.5 + vec2(0.0, t * 1.2)) - 0.5 : 0.0;
            at = uv + vec2(swirl * depth * 0.5, depth * 0.6 - 0.008 * ahead);
        }
    }
    vec3 col = vec3(0.0);
    float a = 0.0;
    if (dissolve < 1.0) {
        vec4 app = src(at);
        if (plain) {
            FRAG_COLOR = app * qt_Opacity;
            return;
        }
        col = app.rgb * (1.0 - dissolve) * (1.0 - 0.22 * ahead);
        a = app.a * (1.0 - dissolve);
    }
    // fine detail at the same size in pixels on a cover as on the screen
    vec2 fine = p * resolution.y / 2272.0;
    float endFade = 1.0 - smoothstep(0.82, 1.0, t);

    float wa = smoothstep(0.0, 0.006, dy) * (1.0 - smoothstep(0.04, 0.32, depth)) * 0.6 * endFade;
    if (wa > 0.0) {
        // the water: lighter at the lip, darker with depth, soft caustics bent round by smooth noise. It keeps its own
        // deep colour (a warm ambience's hue this dark would be brown), and its light takes the ambience's
        vec3 tone = vec3(0.07, 0.38, 0.52);
        vec2 cq = p * 2.4 + vec2(t * 0.3, -t * 0.9)
                + (vec2(vnoise(p * 0.6 + t * 0.2), vnoise(p * 0.6 + 0.5 - t * 0.2)) - 0.5) * 0.4;
        float caust = 1.0 - smoothstep(0.0, 0.2, cells(cq));
        caust *= caust * smoothstep(0.3, 0.6, fbm(cq * 0.8 + 1.7));
        vec3 water = tone * (1.15 - depth * 1.4) + tinted(vec3(0.30, 0.80, 0.90)) * exp(-depth * 30.0) * 0.35
                   + tinted(vec3(0.70, 0.95, 1.00)) * caust * 0.25;
        col = col * (1.0 - wa) + water * wa;
        a = a * (1.0 - wa) + wa;
    }

    // foam, laid over the water: a lip of bubbles on the crest, broken in places, and patches left behind it
    vec2 flow = vec2(t * 0.6, -t * 1.2);
    float lip = smoothstep(-0.007, 0.0, dy) * (1.0 - smoothstep(0.0, 0.03, depth));
    float patchFade = exp(-depth * 18.0) * step(0.0, dy);
    float fa = 0.0;
    if (lip > 0.0) {
        float breaks = smoothstep(0.3, 0.6, fbm(p * vec2(5.0, 9.0) + vec2(t * 0.8, -t * 1.6)));
        float bubbly = smoothstep(0.15, 0.45, fbm(fine * 18.0 + flow));
        fa = lip * mix(0.3, 1.0, breaks) * mix(0.35, 1.0, bubbly);
    }
    // this faint, they would be under a quarter of a level of 255
    if (patchFade > 0.003) {
        float patches = smoothstep(0.5, 0.75, fbm(fine * vec2(6.0, 14.0) + flow * 1.3 + 0.4)) * patchFade;
        fa = clamp(fa + patches * 0.35, 0.0, 1.0);
    }
    fa *= 0.85 * endFade;
    col = col * (1.0 - fa) + vec3(0.92, 0.97, 1.0) * fa;
    a = a * (1.0 - fa) + fa;
    FRAG_COLOR = vec4(col, a) * qt_Opacity;
}
