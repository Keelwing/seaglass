// Frost's field (FrostField.qml), drawn once and kept in textures of 8 bits a channel.
// Part 0: what does not change of the frost pattern (frostPat in frost.glsl, whose result is f = A + thick * B) and of
// a closing's thin cracks. Its rime shows where hash >= 1 - 0.12 * f: kept as the thickness from which that is so,
// because the hash itself rounded to 8 bits turns one dot in a thousand on or off.
// Part 1: the picture blurred as a closing shows it through the ice, with no clip (that moves: the moment applies it).
void main()
{
    vec2 uv = qt_TexCoord0;
    if (part == 1.0) {
        FRAG_COLOR = blurSrc(uv, 10.0 * resolution.y / 1000.0);
        return;
    }
    vec2 p = asp(uv);
    float haze = 0.24 + (fbm(p * 5.3) - 0.35) * 0.3 + (fbm(p * 11.0 + 0.37) - 0.35) * 0.15;
    float vein = (1.0 - smoothstep(0.0, 0.04, cells(p * 3.1 + 0.11))) * smoothstep(0.35, 0.6, vnoise(p * 9.0 + 0.5))
                 + (1.0 - smoothstep(0.0, 0.055, cells(p * 7.3 + 0.41))) * smoothstep(0.45, 0.7, vnoise(p * 13.0 + 0.2)) * 0.6;
    float fine = (1.0 - smoothstep(0.0, 0.1, cells(p * 13.7 + 0.29))) * smoothstep(0.3, 0.6, vnoise(p * 21.0 + 0.7));
    float A = haze + vein * 0.3;
    float B = vein * 0.25 + 0.3 + (fbm(p * 3.7 + 0.6) - 0.35) * 0.7 + fine * 0.35;
    float thin = (1.0 - smoothstep(0.0, 0.03, cells(p * 2.6 + 0.17))) * smoothstep(0.42, 0.62, fbm(p * 4.0 + 0.3));
    // above 1 it never shows
    float rimeFrom = ((1.0 - hash(floor(gl_FragCoord.xy / 1.5))) / 0.12 - A) / B;
    FRAG_COLOR = vec4(A, B / 1.5, thin, clamp(rimeFrom, 0.0, 1.01) / 1.01);
}
