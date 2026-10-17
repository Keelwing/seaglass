"""The noise tile of the animations (docs/ANIMATIONS.md): 256 x 256, repeating. R is smooth value noise, G fractal
noise, B the distance to the nearest Voronoi edge. Alpha is opaque: Qt premultiplies a picture by its alpha, so the
shaders make their white noise themselves. The same numbers as the animation lab (scripts/animation-lab.html) makes
in the browser, from the same seed.

Usage: python3 -I scripts/noise.py OUT.png
"""
import struct
import sys
import zlib
from pathlib import Path

N = 256
M = 0xFFFFFFFF


def mulberry32(seed):
    state = [seed & M]

    def rnd():
        state[0] = (state[0] + 0x6D2B79F5) & M
        a = state[0]
        t = ((a ^ (a >> 15)) * (1 | a)) & M
        t = ((t + (((t ^ (t >> 7)) * (61 | t)) & M)) & M) ^ t
        return ((t ^ (t >> 14)) & M) / 4294967296

    return rnd


def quintic(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def value_noise(lattice, f, x, y):
    fx, fy = x * f, y * f
    ix, iy = int(fx // 1), int(fy // 1)
    tx, ty = quintic(fx - ix), quintic(fy - iy)
    i0 = iy % f
    i1 = (i0 + 1) % f
    j0 = ix % f
    j1 = (j0 + 1) % f
    a, b, c, d = lattice[i0 * f + j0], lattice[i0 * f + j1], lattice[i1 * f + j0], lattice[i1 * f + j1]
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty


def clamp(x, low, high):
    return max(low, min(high, x))


def tile():
    rnd = mulberry32(1337)
    lattice = lambda f: [rnd() for _ in range(f * f)]  # noqa: E731
    l16 = lattice(16)
    octaves = [(f, lattice(f)) for f in (4, 8, 16, 32, 64)]
    cells = 8
    points = [(rnd(), rnd()) for _ in range(cells * cells)]
    data = bytearray(N * N * 4)
    for y in range(N):
        for x in range(N):
            u, v, o = x / N, y / N, (y * N + x) * 4
            data[o] = int(value_noise(l16, 16, u, v) * 255)
            g, w, total = 0.0, 1.0, 0.0
            for f, lat in octaves:
                g += value_noise(lat, f, u, v) * w
                total += w
                w *= 0.5
            data[o + 1] = int(clamp((g / total - 0.5) * 2.2 + 0.5, 0, 1) * 255)
            cx, cy = int(u * cells), int(v * cells)
            f1 = f2 = 9.0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = cx + dx, cy + dy
                    p = points[(ny % cells) * cells + (nx % cells)]
                    d = ((nx + p[0]) / cells - u) ** 2 + ((ny + p[1]) / cells - v) ** 2
                    d **= 0.5
                    if d < f1:
                        f1, f2 = d, f1
                    elif d < f2:
                        f2 = d
            data[o + 2] = int(clamp((f2 - f1) * cells * 1.4, 0, 1) * 255)
            data[o + 3] = 255
    return bytes(data)


def png(rgba, width, height):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & M)

    rows = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 9))
            + chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip().splitlines()[-1])
    Path(sys.argv[1]).write_bytes(png(tile(), N, N))
