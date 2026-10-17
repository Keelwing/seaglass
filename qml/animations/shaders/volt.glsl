// Volt's lightning: jagged bolts from white noise, as a glow and a white core
float jag(float y, float k, float row)
{
    float x = y * k * 256.0;
    float i = floor(x);
    float r = floor(row * 256.0);
    return mix(hash(vec2(i, r)), hash(vec2(i + 1.0, r)), x - i) - 0.5;
}
float boltX(float y, float seed){ return jag(y, 0.10, seed) * 0.10 + jag(y, 0.45, seed + 0.137) * 0.028 + jag(y, 1.9, seed + 0.311) * 0.008; }
float boltGlow(vec2 p, vec2 a, vec2 b, float seed, out float core)
{
    float s = clamp((p.y - a.y) / (b.y - a.y), 0.0, 1.0);
    float on = step(min(a.y, b.y), p.y) * step(p.y, max(a.y, b.y));
    float x = mix(a.x, b.x, s) + boltX(p.y, seed) * pow(sin(PI * s), 0.6);
    float dx = abs(p.x - x);
    float px1 = 1.0 / resolution.y;
    core = exp(-dx * dx / (px1 * px1 * 2.2)) * on;
    return (exp(-dx / (px1 * 10.0)) * 0.55 + exp(-dx / (px1 * 45.0)) * 0.22) * on;
}
