"""The animations' shaders as the phone compiles them (docs/ANIMATIONS.md): each style's STYLE-MOMENT.frag behind
common.glsl and the style's libraries (qml/animations/styles.js), twice: as GLSL ES 1.00 (NAME.frag) and as GLSL ES
3.00 (NAME.es3.frag, the header shaders.js puts in front where the GPU has it); and Shatter's shards.vert and
shards.frag (GLSL ES 1.00). Written to OUTDIR for glslangValidator; prints the files.

Usage: python3 -I scripts/shaders.py OUTDIR
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SHADERS = REPO / "qml" / "animations" / "shaders"


def style_libs():
    """{style id: [library names]} from styles.js"""
    text = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
    return {style: re.findall(r'"(\w+)"', libs)
            for style, libs in re.findall(r'"id": "(\w+)".*?"libs": \[(.*?)\]', text, re.S)}


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    common = (SHADERS / "common.glsl").read_text(encoding="utf-8")
    libs = style_libs()
    written = []
    for frag in sorted(SHADERS.glob("*-*.frag")):
        style = frag.stem.split("-")[0]
        if style not in libs:
            sys.exit(f"{frag.name}: {style} is not a style of styles.js")
        parts = [common] + [(SHADERS / f"{lib}.glsl").read_text(encoding="utf-8") for lib in libs[style]]
        body = "\n".join(parts + [frag.read_text(encoding="utf-8")])
        for name, header in ((frag.name, "#version 100\n"), (frag.stem + ".es3.frag", "#version 300 es\n#define ES3 1\n")):
            target = out / name
            target.write_text(header + body, encoding="utf-8")
            written.append(target)
    for name in ("shards.vert", "shards.frag"):
        target = out / name
        target.write_text("#version 100\n" + (SHADERS / name).read_text(encoding="utf-8"), encoding="utf-8")
        written.append(target)
    print("\n".join(str(path) for path in written))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip().splitlines()[-1])
    main(Path(sys.argv[1]))
