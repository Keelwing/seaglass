"""Shatter as one ShaderEffect over a GridMesh (qml/animations/Shards.qml and its two shaders): what an animator needs
to drive it, what the grid needs from the shaders, and that nothing still treats the shards as items."""
import re
import unittest
from pathlib import Path

from test_repo import qml_blocks

REPO = Path(__file__).resolve().parents[1]
ANIMATIONS = REPO / "qml" / "animations"


def read(name):
    return (ANIMATIONS / name).read_text(encoding="utf-8")


def declared(text, qualifier):
    """{name: its GLSL type and precision} of the uniforms or varyings of a shader"""
    return {name: kind for kind, name in re.findall(r"^%s\s+([\w ]+?)\s+(\w+);" % qualifier, text, re.M)}


class AnimationMeshTest(unittest.TestCase):
    def test_one_effect_over_a_grid(self):
        shards = read("Shards.qml")
        self.assertRegex(shards, r"(?m)^ShaderEffect \{")
        self.assertIn("GridMesh", shards)
        self.assertNotIn("Repeater", shards)
        self.assertIn("resolution: Qt.size(pane.columns, 1)", shards)

    def test_an_animator_can_drive_progress(self):
        # a uniform declared in both stages is not driven: the animator finds only one stage's copy
        self.assertRegex(read("shaders/shards.vert"), r"(?m)^uniform .* progress;")
        self.assertNotRegex(re.sub(r"//.*", "", read("shaders/shards.frag")), r"\bprogress\b")
        self.assertIn('uniform: "progress"', read("Shards.qml"))

    def test_every_uniform_has_its_property(self):
        # Qt sets a uniform from the ShaderEffect's property of that name, and warns without one
        shards = read("Shards.qml")
        properties = set(re.findall(r"^\s*(?:readonly\s+)?property\s+\w+\s+(\w+)", shards, re.M))
        for name in ("shaders/shards.vert", "shaders/shards.frag"):
            uniforms = {u for u in declared(read(name), "uniform") if not u.startswith("qt_")}
            self.assertTrue(uniforms)
            self.assertLessEqual(uniforms, properties, name)

    def test_the_impact_is_in_height_units(self):
        # the property impact is 0 to 1 over the pane: a uniform of that name would read it in the wrong units
        for name in ("shaders/shards.vert", "shaders/shards.frag"):
            uniforms = declared(read(name), "uniform")
            self.assertIn("impactAt", uniforms, name)
            self.assertNotIn("impact", uniforms, name)

    def test_the_stages_agree(self):
        vertex = read("shaders/shards.vert")
        fragment = read("shaders/shards.frag")
        self.assertEqual(declared(vertex, "varying"), declared(fragment, "varying"))
        vertex_uniforms = declared(vertex, "uniform")
        for name, kind in declared(fragment, "uniform").items():
            if name in vertex_uniforms:
                self.assertEqual(kind, vertex_uniforms[name], name)
        # every varying is written, for a shard on the pane and for one off it
        off_pane = vertex[vertex.index("gl_Position = vec4(2.0"):vertex.index("return;")]
        on_pane = vertex.replace(off_pane, "")
        for name in declared(vertex, "varying"):
            self.assertRegex(off_pane, r"\b%s = " % name, name)
            self.assertRegex(on_pane, r"\b%s = " % name, name)

    def test_the_grid_finds_its_attributes(self):
        # GridMesh finds the position and the coordinate by Qt's names, and which vertex this is comes from the second
        vertex = read("shaders/shards.vert")
        self.assertEqual(re.findall(r"(?m)^attribute \w+ \w+ (\w+);", vertex), ["qt_Vertex", "qt_MultiTexCoord0"])

    def test_they_stay_glsl_es_1(self):
        # shaders.js adds no header to these two, and scripts/shaders.py checks them as GLSL ES 1.00
        for name in ("shaders/shards.vert", "shaders/shards.frag"):
            self.assertNotIn("#version", read(name), name)
        self.assertRegex(read("shaders/shards.frag"), r"\bgl_FragColor\b")

    def test_a_break_fits_the_shaders(self):
        # the rings reach the shader as two vec4, so at most 8; three columns a shard
        shards = read("Shards.qml")
        self.assertIn("3 * (rays + (rings.length - 1) * rays * 2) - 1", shards)
        files = sorted(REPO.glob("qml/**/*.qml")) + sorted(REPO.glob("harness/*.qml"))
        seen = 0
        for path in files:
            for block in qml_blocks(path.read_text(encoding="utf-8"), "Shards"):
                for rings in re.findall(r"rings: .*", block):
                    for values in re.findall(r"\[(.*?)\]", rings):
                        seen += 1
                        self.assertLessEqual(len(values.split(",")), 8, path.name)
        self.assertGreaterEqual(seen, 2)
        default = re.search(r"property var rings: \[(.*?)\]", shards).group(1).split(",")
        self.assertEqual(len(default), 8)

    def test_nothing_treats_the_shards_as_items(self):
        for path in sorted(REPO.glob("qml/**/*.qml")) + sorted(REPO.glob("harness/*.qml")):
            for block in qml_blocks(path.read_text(encoding="utf-8"), "Shards"):
                self.assertNotIn("capacity", block, path.name)

    def test_its_programs_stay_while_a_run_may_play(self):
        # active follows the settings, and can go false while a moment plays: blank shaders would shrink the uniform
        # list under the animator, which writes past its end (Qt 5.6 does not check the index)
        shards = read("Shards.qml")
        self.assertIn('readonly property bool loaded: vertexText !== "" && fragmentText !== ""', shards)
        self.assertIn("readonly property bool ready: active && loaded", shards)
        self.assertIn('vertexShader: loaded ? vertexText : ""', shards)
        self.assertIn('fragmentShader: loaded ? fragmentText : ""', shards)
        self.assertNotRegex(shards, r"(vertex|fragment)Shader: .*\b(ready|active)\b")
        self.assertNotRegex(shards, r"(vertex|fragment)Text = \"\"")

    def test_shards_at_rest_leave_no_pixel_between_them(self):
        # the rasterizer snaps each triangle's corners on its own: at rest a shard reaches a little past its edge, and
        # less as it moves
        fragment = read("shaders/shards.frag")
        cover = re.search(r"float cover = (.*);", fragment).group(1)
        self.assertEqual(cover, "smoothstep(-max(apart, 0.001), 0.0, inner + (1.0 - min(apart * 8.0, 1.0)) * 0.1)")

    def test_a_run_always_ends(self):
        # a render thread that draws no frames never ends an animator: the watchdog does it on the GUI side
        shards = read("Shards.qml")
        play = re.search(r"function play\(ms\) \{.*?\n    \}", shards, re.S).group(0)
        for line in ("length = ms", "progress = 0", "run.start()", "watchdog.restart()"):
            self.assertIn(line, play)
        halt = re.search(r"function halt\(\) \{.*?\n    \}", shards, re.S).group(0)
        for line in ("watchdog.stop()", "run.stop()"):
            self.assertIn(line, halt)
        self.assertIn("interval: pane.length + 500", shards)
        self.assertIn("pane.ended()", shards)


if __name__ == "__main__":
    unittest.main()
