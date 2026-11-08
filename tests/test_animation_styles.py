"""The list of animation styles in qml/animations/styles.js: each style's shaders, the moments drawn at half the
resolution, and what keeps the Paper styles light."""
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PAPER = ["contour", "fold", "halftone"]


class AnimationStylesTest(unittest.TestCase):
    def test_every_style_has_its_shaders(self):
        # a style's moment without its shader would stay stock without a word (docs/ANIMATIONS.md)
        shaders = REPO / "qml" / "animations" / "shaders"
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        found = re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S)
        self.assertEqual(len(found), 12)
        for style, rest in found:
            moments = ["load"] if '"shards": true' in rest else ["open", "close", "load"]
            for moment in moments:
                self.assertTrue((shaders / f"{style}-{moment}.frag").is_file(), f"{style}-{moment}.frag")
            for lib in re.findall(r'"(\w+)"', re.search(r'"libs": \[(.*?)\]', rest).group(1)):
                self.assertTrue((shaders / f"{lib}.glsl").is_file(), f"{lib}.glsl")
        self.assertTrue((shaders / "shards.vert").is_file())
        # the noise tile is made when the package is built, never committed
        self.assertIn("scripts/noise.py", (REPO / "rpm" / "build.sh").read_text(encoding="utf-8"))
        self.assertIn("qml/animations/noise.png", (REPO / ".gitignore").read_text(encoding="utf-8"))

    def test_half_resolution_is_per_moment(self):
        # styles.js lists the moments drawn at half the resolution, and the split ones among them; Effect.qml asks
        # for its own moment, and no other file reads them. A split moment's shader reads part, or both passes
        # would draw all of it.
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        shaders = REPO / "qml" / "animations" / "shaders"
        for style, rest in re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S):
            self.assertNotRegex(rest, r'"(half|split)": true', style)
            lists = {key: set(re.findall(r'"(\w+)"', moments))
                     for key, moments in re.findall(r'"(half|split)": \[(.*?)\]', rest)}
            for key, moments in lists.items():
                self.assertLessEqual(moments, {"open", "close", "load"}, f"{style} {key}")
            self.assertLessEqual(lists.get("split", set()), lists.get("half", set()), style)
            for moment in lists.get("split", set()):
                shader = (shaders / f"{style}-{moment}.frag").read_text(encoding="utf-8")
                self.assertRegex(shader, r"\bpart [!=]= [12]\.0", f"{style}-{moment}.frag")
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        self.assertIn("Styles.half(style, moment)", effect)
        self.assertIn("Styles.split(style, moment)", effect)
        for path in sorted([*REPO.glob("qml/**/*.qml"), *REPO.glob("harness/*.qml")]):
            self.assertNotRegex(path.read_text(encoding="utf-8"), r'has\([^)]*"half"\)', path.relative_to(REPO))

    def test_groups_run_from_light_to_loud(self):
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        found = re.findall(r'\{ "id": "(\w+)".*?"group": "(\w+)"', styles, re.S)
        self.assertEqual([style for style, _ in found[:3]], PAPER)
        self.assertEqual([group for style, group in found if style in PAPER], ["Paper"] * 3)
        groups = [group for _, group in found]
        self.assertEqual(sorted(set(groups), key=groups.index), ["Paper", "Sailfish", "Elements", "Extreme"])

    def test_heavy_lists_only_moments(self):
        # filled from bench play on the phone; the viewer reads it through heavy() and shows it as text
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        self.assertIn('function heavy(id, moment) { return listed(id, "heavy", moment) }', styles)
        for style, rest in re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S):
            self.assertNotRegex(rest, r'"heavy": true', style)
            for moments in re.findall(r'"heavy": \[(.*?)\]', rest):
                self.assertLessEqual(set(re.findall(r'"(\w+)"', moments)), {"open", "close", "load"}, style)

    def test_heavy_moments_are_the_measured_ones(self):
        # bench play at full screen on the Jolla Phone, from an idle GPU: these, and only these, had over 5 percent of
        # their frames above 16.7 ms, pooled over three rounds
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        heavy = {}
        for style, rest in re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S):
            lists = re.findall(r'"heavy": \[(.*?)\]', rest)
            self.assertLessEqual(len(lists), 1, style)
            if lists:
                heavy[style] = re.findall(r'"(\w+)"', lists[0])
        self.assertEqual(heavy, {"seaglass": ["close"], "volt": ["open", "close"], "frost": ["open"]})

    def test_paper_styles_stay_light(self):
        # flat entries with no library, half layer or second pass, and shaders with no noise and no mipmaps
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        entries = dict(re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S))
        shaders = REPO / "qml" / "animations" / "shaders"
        for style in PAPER:
            self.assertIn('"libs": []', entries[style])
            self.assertNotRegex(entries[style], r'"(blur|half|split|shards)"', style)
            for moment in ("open", "close", "load"):
                name = f"{style}-{moment}.frag"
                text = re.sub(r"//.*", "", (shaders / name).read_text(encoding="utf-8"))
                self.assertNotRegex(text, r"\b(vnoise|fbm|cells|hash|blurSrc|textureLod|noiseTex|part)\b", name)
                # one read of the source at most, and in an opening or closing none where nothing is drawn
                reads = list(re.finditer(r"\b(src|srcClamp|texture2D|iconAt)\(", text))
                self.assertEqual(len(reads), 1, name)
                if moment != "load":
                    self.assertLess(text.index("FRAG_COLOR = vec4(0.0);\n        return;"), reads[0].start(), name)

    def test_paper_loadings_take_natural_colours_with_ambience_off(self):
        # useTint 0 gives the natural colour, as everywhere else: tint is read only in that one mix
        shaders = REPO / "qml" / "animations" / "shaders"
        for style in PAPER:
            name = f"{style}-load.frag"
            text = re.sub(r"//.*", "", (shaders / name).read_text(encoding="utf-8"))
            self.assertIn("mix(vec3(0.42, 0.72, 0.98), tint, useTint)", text, name)
            self.assertEqual(len(re.findall(r"\btint\b", text)), 1, name)


if __name__ == "__main__":
    unittest.main()
