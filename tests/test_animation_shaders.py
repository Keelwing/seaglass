"""The animation shaders against what draws them: the inputs each pass of qml/animations/Effect.qml has. And what their
shared libraries must keep: pixel diffs prove the look, these keep the shape that makes them cheap and correct."""
import math
import re
import unittest
from pathlib import Path

from test_repo import qml_blocks

REPO = Path(__file__).resolve().parents[1]
SHADERS = REPO / "qml" / "animations" / "shaders"


def glsl_function(file, name):
    """a function of a shader library: its signature to its closing brace in the first column"""
    text = (SHADERS / file).read_text(encoding="utf-8")
    match = re.search(r"^\w+ %s\(.*?^\}$" % name, text, re.M | re.S)
    if match is None:
        raise AssertionError(f"{name} not in {file}")
    return match.group(0)


def function_of(text, name):
    """a function of a QML file, to the closing brace at its own indent"""
    return re.search(r"^( *)function %s\(.*?^\1\}" % name, text, re.M | re.S).group(0)


def atan_calls(text):
    """each atan(y, x) in a shader's text: where it is, and its two arguments"""
    for match in re.finditer(r"\batan\(", text):
        depth, start, args = 0, match.end(), []
        for end in range(match.end() - 1, len(text)):
            depth += {"(": 1, ")": -1}.get(text[end], 0)
            if text[end] == "," and depth == 1:
                args.append(text[start:end].strip())
                start = end + 1
            elif depth == 0:
                args.append(text[start:end].strip())
                break
        yield match.start(), args


class AnimationShadersTest(unittest.TestCase):
    def test_a_colour_ramp_runs_only_for_the_tint_in_use(self):
        # useTint is 0 or 1 for a whole effect: a branch, instead of working out both ramps per pixel and mixing them
        for file, name in (("common.glsl", "tinted"), ("ember.glsl", "fire"), ("aurora.glsl", "aurora")):
            body = glsl_function(file, name)
            self.assertRegex(body, r"if \(useTint [<>] 0\.5\)", name)
            self.assertNotRegex(body, r"mix\([^;]*useTint\)", name)

    def test_the_blur_masks_the_clip_once(self):
        # the whole blur at the pixel, in both languages, and no clamp per tap: the source clamps to its edge
        body = glsl_function("common.glsl", "blurSrc")
        es3, es1 = body.split("#else")
        for path in (es3, es1):
            self.assertEqual(path.count("clipMask("), 1)
            self.assertEqual(len(re.findall(r"\b(?:textureLod|texture2D)\(source", path)), 9)
            self.assertNotIn("clamp(uv +", path)
            self.assertNotIn("srcClamp", path)

    def test_the_blur_reads_whole_levels(self):
        # a read between two mip levels reads both: each tap takes one whole level, rounded by the pixel's dither.
        # GLSL ES 1.00 reads the source itself, which has no mipmaps there
        es3, es1 = glsl_function("common.glsl", "blurSrc").split("#else")
        self.assertRegex(es3, r"\n    float lod = floor\(max\(log2\(max\(r, 1\.0\)\) - 2\.0, 0\.0\)"
                              r" \+ fract\(h \* [\d.]+\)\);")
        self.assertEqual(len(re.findall(r"\blod\b", es3)), 10)
        self.assertEqual(re.findall(r"textureLod\(source, [^;]*?, (\w+)\)", es3), ["lod"] * 9)
        self.assertNotIn("textureLod", es1)

    def test_the_grains_drift_needs_no_sine(self):
        text = (SHADERS / "grains.glsl").read_text(encoding="utf-8")
        self.assertNotRegex(text, r"\b(?:cos|sin)\(")
        for name, turn in (("GRAIN_COS", math.cos), ("GRAIN_SIN", math.sin)):
            values = re.search(r"const vec4 %s = vec4\((.*?)\);" % name, text).group(1).split(",")
            self.assertEqual(len(values), 4)
            for j, value in enumerate(values):
                self.assertAlmostEqual(float(value), turn((j - 1.5) * 0.14), places=7, msg=f"{name}[{j}]")

    def test_a_bolts_limits_follow_the_size_it_is_drawn_at(self):
        # its glows are measured in pixels: a limit in units of the height alone cuts them off on a smaller item, as
        # in the viewer and on a cover
        limits = re.findall(r"if \(away > ([^)]*)\)", glsl_function("volt.glsl", "bolt"))
        self.assertEqual(len(limits), 2)
        for limit in limits:
            self.assertRegex(limit, r"^[\d.]+ \* px1 \+ [\d.]+ \* size$")

    def test_volts_arcs_are_called_one_by_one_and_the_fine_octave_only_near_a_core(self):
        # an arc's number is a constant in each call, so that all of it that does not depend on the pixel is the same
        # for the whole draw; in a loop it would be worked out again at every pixel. The fine octave moves only the
        # core, which shows a few pixels from the bolt at most
        close = (SHADERS / "volt-close.frag").read_text(encoding="utf-8")
        self.assertNotIn("for (", close)
        self.assertIn("arc(p, 0.0) + arc(p, 1.0) + arc(p, 2.0) + arc(p, 3.0)", close)
        bolt = glsl_function("volt.glsl", "bolt")
        self.assertNotIn("boltX(", bolt)
        self.assertLess(bolt.index("if (length(vec2(near / sqrt(1.0 + sMax * sMax), ds)) < 4.5 * px1)"),
                        bolt.index("jag(sc / size, 1.9,"))
        self.assertIn("if (t < 0.42 && p.y < below)", (SHADERS / "volt-open.frag").read_text(encoding="utf-8"))

    def test_a_blur_or_a_noise_read_only_where_it_can_show(self):
        # Frost's ice blurs only where it has formed, and Seaglass's pebble reads its noise only while it wobbles
        frost = (SHADERS / "frost-open.frag").read_text(encoding="utf-8")
        self.assertLess(frost.index("if (formed > 0.0)"), frost.index("blurSrc("))
        pebble = re.search(r"^float pebble\(.*?^\}$", (SHADERS / "seaglass-close.frag").read_text(encoding="utf-8"),
                           re.M | re.S).group(0)
        self.assertLess(pebble.index("if (wob > 0.0)"), pebble.index("vnoise("))

    def test_a_flake_has_no_undefined_mip_level_and_no_equal_edges(self):
        snow = glsl_function("frost.glsl", "snow")
        self.assertLess(snow.index("if (h > 0.5) continue;"), snow.index("float hs ="))
        self.assertNotIn("step(h, 0.5)", snow)
        self.assertIn("srcFull(cu)", snow)
        es3, es1 = glsl_function("frost.glsl", "srcFull").split("#else")
        self.assertIn("textureLod(source, clamp(uv, 0.0, 1.0), 0.0) * clipMask(clamp(uv, 0.0, 1.0))", es3)
        self.assertNotIn("textureLod", es1)

    def test_frost_reads_what_its_field_baked(self):
        # a loading's shape changes every cycle, so it stays live. The melting edge's noise stays live everywhere: 8
        # bits of it would terrace the edge
        read = {moment: (SHADERS / f"frost-{moment}.frag").read_text(encoding="utf-8")
                for moment in ("open", "close", "load")}
        for moment in ("open", "close"):
            self.assertIn("uniform sampler2D fieldTex;", read[moment])
            self.assertIn("frostFrom(", read[moment])
            self.assertNotIn("frostPat(", read[moment])
        self.assertIn("float n = fbm(p * 2.5);", read["open"])
        self.assertIn("float n = fbm(p * 2.2) * 0.7 + fbm(p * 7.0) * 0.3;", read["close"])
        self.assertIn("frostPat(", read["load"])
        self.assertNotIn("fieldTex", read["load"])
        # the closing's picture holds still, and takes the moving clip after the texture
        self.assertNotIn("blurSrc(", read["close"])
        self.assertIn("texture2D(blurTex, uv) * clipMask(uv)", read["close"])
        field = (SHADERS / "frost-field.frag").read_text(encoding="utf-8")
        self.assertIn("blurSrc(uv, 10.0 * resolution.y / 1000.0)", field)
        # what frostFrom undoes is what the field did
        self.assertIn("vec4(A, B / 1.5, thin, clamp(rimeFrom, 0.0, 1.01) / 1.01)", field)
        baked = glsl_function("frost.glsl", "frostFrom")
        self.assertIn("field.r + thick * field.g * 1.5", baked)
        self.assertIn("step(field.a * 1.01, thick)", baked)

    def test_a_field_is_a_moment_list_and_a_shader_of_its_own(self):
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        frost = re.search(r'"id": "frost"(.*?)\}', styles, re.S).group(1)
        self.assertIn('"field": ["open", "close"]', frost)
        self.assertIn('"grainsFrom": 0.5', frost)
        shaders = re.search(r"^function shaders\(\) \{.*?^\}", styles, re.M | re.S).group(0)
        self.assertIn('"moment": "field"', shaders)
        self.assertLess(shaders.index('"moment": "field"'), shaders.index('["open", "close", "load"]'))
        controller = (REPO / "qml" / "animations" / "AnimationController.qml").read_text(encoding="utf-8")
        self.assertIn('item.moment === "field"', controller)

    def test_a_field_is_baked_once_and_goes_with_the_moment(self):
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        loader = qml_blocks(effect, "Loader")
        self.assertEqual(len(loader), 1)
        self.assertIn('source: "FrostField.qml"', loader[0])
        # made for a moment with a field only (fit()), it bakes while the moment is shown or runs
        self.assertIn("active: effect.visible || effect.running", loader[0])
        self.assertIn('Styles.listed(style, "field", moment)', function_of(effect, "fit"))
        # its text is there by the time the moment is ready, so that the first frame has it
        self.assertIn('Shaders.load(base, style + "-field", libs, es3, loadOwn)', function_of(effect, "load"))
        self.assertNotIn("ShaderEffectSource", effect)
        field = (REPO / "qml" / "animations" / "FrostField.qml").read_text(encoding="utf-8")
        passes = qml_blocks(field, "Effect")
        copies = qml_blocks(field, "ShaderEffectSource")
        self.assertEqual(len(passes), 2)
        self.assertEqual(len(copies), 2)
        for block in passes:
            for line in ('style: "frost"', 'moment: "field"', "blending: false", "time: 0", "visible: ready"):
                self.assertIn(line, block)
        for block in copies:
            for line in ("live: false", "hideSource: true", "visible: false", "smooth: false"):
                self.assertIn(line, block)
            self.assertRegex(block, r"sourceItem: (\w+)\.ready \? \1 : null")

    def test_both_passes_can_read_the_field(self):
        # the same text on both, and Qt warns about a sampler without its property
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        inner = [block for block in qml_blocks(effect, "ShaderEffect") if block.startswith(" ")][0]
        outer = effect.replace(inner, "")
        for name in ("fieldTex", "blurTex"):
            self.assertRegex(outer, r"property variant %s:" % name)
            self.assertIn(f"readonly property variant {name}: effect.{name}", inner)

    def test_the_grains_pass_waits_by_hand_and_the_shader_in_a_run(self):
        # the GUI side does not see progress during a run, and a Timer there is late while the GUI thread is busy: a
        # run shows the pass from its start, and Frost's closing draws nothing in it until its snow starts. One driven
        # by hand has no run, and progress says
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        shown = re.search(r"readonly property bool grainsShown: (.*)", effect).group(1)
        self.assertEqual(shown, "split && (running || progress >= Styles.grainsFrom(style))")
        inner = [block for block in qml_blocks(effect, "ShaderEffect") if block.startswith(" ")][0]
        self.assertIn("visible: effect.grainsShown", inner)
        timers = qml_blocks(effect, "Timer")
        self.assertEqual(len(timers), 1)
        self.assertIn("id: watchdog", timers[0])
        close = (SHADERS / "frost-close.frag").read_text(encoding="utf-8")
        self.assertIn("float k = clamp((t - 0.5) / 0.5, 0.0, 1.0);", close)
        self.assertIn("if (part != 1.0 && k > 0.0)", close)
        self.assertIn("if (part != 2.0)", close)

    def test_a_field_input_never_goes_back_to_null(self):
        # a texture input that goes from an item to null makes Qt warn at the end of every Frost moment, and
        # scripts/bench-frames.py counts that warning. The field's Loader is there only for a moment with a field
        # (fit()) and null otherwise, so each reads it behind a check: without one, every other Effect throws in both
        # bindings and keeps neither input
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        self.assertIn("\n    property Item fieldLoader: null\n", effect)
        for name in ("fieldTex", "blurTex"):
            line = re.search(r"readonly property variant %s: (.*(?:\n\s+[?:] .*)*)" % name, effect).group(1)
            self.assertTrue(line.endswith(": noiseTex"), line)
            self.assertNotIn("null", line)
            self.assertTrue(line.startswith("fieldLoader && fieldLoader.item"), line)
        bench = (REPO / "scripts" / "bench-frames.py").read_text(encoding="utf-8")
        warnings = re.search(r"^WARNINGS = \((.*)\)$", bench, re.M).group(1)
        self.assertIn('"is not assigned a valid texture provider"', warnings)

    def test_an_angle_is_never_asked_of_the_origin_itself(self):
        # atan(0, 0) is undefined, and a GPU may draw that pixel black. Volt's front passes the origin while it is
        # small, Ember's ring starts there and Frost's cracks run out of it: every angle gets 1.0 for x where its
        # vector has no length, which no other pixel takes
        volt = (SHADERS / "volt-open.frag").read_text(encoding="utf-8")
        self.assertNotIn("atan(v.y, v.x)", volt)
        self.assertIn("atan(v.y, r > 0.0 ? v.x : 1.0)", volt)
        self.assertIn("float r = length(v);", volt[:volt.index("atan(")])
        files = set()
        for path in sorted(SHADERS.glob("*.*")):
            text = re.sub(r"//[^\n]*", "", path.read_text(encoding="utf-8"))
            for at, (y, x) in atan_calls(text):
                files.add(path.stem)
                by_length = re.fullmatch(r"(\w+) > 0\.0 \? (\w+)\.x : 1\.0", x)
                by_vector = re.fullmatch(r"(\w+) != vec2\(0\.0\) \? \1\.x / resolution\.x : 1\.0", x)
                if by_length:
                    length, vector = by_length.groups()
                    self.assertEqual(y, vector + ".y", path.name)
                    self.assertIn(f"float {length} = length({vector});", text[:at], path.name)
                else:
                    self.assertTrue(by_vector, f"{path.name}: atan({y}, {x})")
                    self.assertEqual(y, by_vector.group(1) + ".y / resolution.y", path.name)
        for name in ("ember-open", "dust-open", "frost-close", "shatter-load", "singularity-load", "singularity-close",
                     "volt-open", "volt-load", "seaglass-load"):
            self.assertIn(name, files)

    def test_effect_passes_have_every_input(self):
        # Qt sets a shader's uniform from the ShaderEffect's property of that name, and warns without one: both
        # passes of Effect.qml (the split moment's grains are a ShaderEffect of their own) have common.glsl's inputs
        common = (REPO / "qml" / "animations" / "shaders" / "common.glsl").read_text(encoding="utf-8")
        inputs = [name for name in re.findall(r"^uniform \w+ (\w+);", common, re.M) if not name.startswith("qt_")]
        self.assertIn("part", inputs)
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        inner = [block for block in qml_blocks(effect, "ShaderEffect") if block.startswith(" ")]
        self.assertEqual(len(inner), 1)
        outer = effect.replace(inner[0], "")
        for text, what in ((outer, "Effect"), (inner[0], "its grains pass")):
            properties = set(re.findall(r"^\s*(?:readonly\s+)?property\s+\w+\s+(\w+)", text, re.M))
            self.assertLessEqual(set(inputs), properties, what)


if __name__ == "__main__":
    unittest.main()
