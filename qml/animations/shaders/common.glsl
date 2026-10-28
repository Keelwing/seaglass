// What every effect has (docs/ANIMATIONS.md): Effect.qml puts this in front of a style's shader. The same files are
// GLSL ES 3.00 where the GPU has it (shaders.js puts "#version 300 es" and ES3 in front: a blur from mipmaps) and
// GLSL ES 1.00 elsewhere. A shader writes its colour to FRAG_COLOR. Colours are premultiplied by alpha,
// in the textures and in FRAG_COLOR; light added with alpha 0 brightens what is behind.
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#ifdef ES3
in vec2 qt_TexCoord0;
out vec4 fragColor;
#define FRAG_COLOR fragColor
#define texture2D texture
#else
varying vec2 qt_TexCoord0;
#define FRAG_COLOR gl_FragColor
#endif
uniform float qt_Opacity;
// the layer, cover or icon drawn, and the noise tile (R smooth, G fractal, B Voronoi edge distance; it repeats)
uniform sampler2D source;
uniform sampler2D noiseTex;
// 0 to 1 over the effect, and seconds: of the effect for an opening or closing (they follow the speed), a running
// clock for a loading
uniform float progress;
uniform float time;
// where it opens from or closes at, in the item's own coordinates (0 to 1, y down): a point and a rectangle
uniform vec2 origin;
uniform vec4 originRect;
// width / height, and the size in pixels
uniform float aspect;
uniform vec2 resolution;
// the ambience's highlight colour, and whether fire, water and light take it (1) or keep their own (0)
uniform vec3 tint;
uniform float useTint;
// the corner radius of a cover, in pixels
uniform float radiusPx;
// closing: the window's top edge, as far as the swipe has wiped it (0 to 1); nothing of the source above it
uniform float clipTop;

#define PI 3.14159265

float vnoise(vec2 p) { return texture2D(noiseTex, p).r; }
float fbm(vec2 p) { return texture2D(noiseTex, p).g; }
float cells(vec2 p) { return texture2D(noiseTex, p).b; }
// white noise of a cell, 0 to 1. In floats: an integer hash (uint) gives 0 everywhere on the Jolla Phone's Mali
// driver
float hash(vec2 c)
{
    vec3 p = fract(vec3(floor(c).xyx) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
// to units of the item's height, where distances are round
vec2 asp(vec2 uv) { return vec2(uv.x * aspect, uv.y); }
float boxMask(vec2 p) { return step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0); }
float inRect(vec2 uv)
{
    vec2 d = min(uv, 1.0 - uv) * resolution;
    return clamp(min(d.x, d.y) + 0.5, 0.0, 1.0);
}
float clipMask(vec2 uv) { return smoothstep(clipTop - 1.0 / resolution.y, clipTop, uv.y); }
vec4 src(vec2 uv) { return texture2D(source, clamp(uv, 0.0, 1.0)) * inRect(uv) * clipMask(uv); }
vec4 srcClamp(vec2 uv) { return texture2D(source, clamp(uv, 0.0, 1.0)) * clipMask(clamp(uv, 0.0, 1.0)); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// a natural colour moved to the ambience's hue at the same brightness, when useTint is 1
vec3 tinted(vec3 n)
{
    float l = luma(n);
    vec3 t = tint * (l / max(luma(tint), 0.05));
    t = mix(t, vec3(1.0), smoothstep(0.85, 1.4, l));
    return mix(n, t, useTint);
}
float easeOutCubic(float t) { float u = 1.0 - t; return 1.0 - u * u * u; }
float easeInCubic(float t) { return t * t * t; }
float easeInOut(float t) { return t * t * (3.0 - 2.0 * t); }
// the distance from a point to the farthest corner, in height units
float maxDist(vec2 o)
{
    vec2 a = asp(o);
    return max(max(length(a), length(a - vec2(aspect, 0.0))), max(length(a - vec2(0.0, 1.0)), length(a - vec2(aspect, 1.0))));
}
float sdRoundRect(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
// a soft blur of the source, about rpx pixels wide: with GLSL ES 3.00 from the source's mipmaps (its
// ShaderEffectSource has mipmap: true), a few taps of a smaller level; else nine taps
vec4 blurSrc(vec2 uv, float rpx)
{
#ifdef ES3
    // nine taps of a level a little finer than the blur: a coarse level alone shows its squares
    float lod = max(log2(max(rpx, 1.0)) - 1.5, 0.0);
    vec2 s = rpx * 0.75 / resolution;
    vec4 m = textureLod(source, clamp(uv, 0.0, 1.0), lod) * 0.2;
    m += textureLod(source, clamp(uv + s * vec2( 0.53,  0.12), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2(-0.41,  0.48), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2(-0.15, -0.62), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2( 0.72, -0.55), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2(-0.86, -0.12), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2( 0.18,  0.93), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2( 0.95,  0.40), 0.0, 1.0), lod) * 0.1;
    m += textureLod(source, clamp(uv + s * vec2(-0.60, -0.92), 0.0, 1.0), lod) * 0.1;
    return m * clipMask(clamp(uv, 0.0, 1.0));
#else
    vec2 s = rpx / resolution;
    vec4 c = srcClamp(uv) * 0.2;
    c += srcClamp(uv + s * vec2( 0.53,  0.12)) * 0.1;
    c += srcClamp(uv + s * vec2(-0.41,  0.48)) * 0.1;
    c += srcClamp(uv + s * vec2(-0.15, -0.62)) * 0.1;
    c += srcClamp(uv + s * vec2( 0.72, -0.55)) * 0.1;
    c += srcClamp(uv + s * vec2(-0.86, -0.12)) * 0.1;
    c += srcClamp(uv + s * vec2( 0.18,  0.93)) * 0.1;
    c += srcClamp(uv + s * vec2( 0.95,  0.40)) * 0.1;
    c += srcClamp(uv + s * vec2(-0.60, -0.92)) * 0.1;
    return c;
#endif
}
// a cover's rounded rectangle: 1 inside, and d the signed distance to its edge in pixels
float cardInside(out float d)
{
    d = sdRoundRect(qt_TexCoord0 * resolution - resolution * 0.5, resolution * 0.5, radiusPx);
    return clamp(0.5 - d, 0.0, 1.0);
}
// the source (an icon) drawn size pixels wide around centre, moved by off
vec4 iconAt(vec2 centre, float size, vec2 off)
{
    vec2 ip = (qt_TexCoord0 * resolution - centre * resolution) / size + 0.5 + off;
    return texture2D(source, clamp(ip, 0.0, 1.0)) * boxMask(ip);
}
