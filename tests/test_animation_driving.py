"""What drives the home screen's app animations: the runs on the render thread, the clock of every effect, what is read
and compiled when, and the corners an opening starts from."""
import re
import unittest
from pathlib import Path

from test_repo import qml_blocks

REPO = Path(__file__).resolve().parents[1]
ANIMATIONS = REPO / "qml" / "animations"


def read(name):
    return (ANIMATIONS / name).read_text(encoding="utf-8")


def function(text, name):
    """a QML or JavaScript function from its signature to its closing brace"""
    start = text.index("function %s(" % name)
    depth = 0
    for end in range(text.index("{", start), len(text)):
        depth += {"{": 1, "}": -1}.get(text[end], 0)
        if depth == 0:
            return text[start:end + 1]
    raise AssertionError(f"{name} does not end")


def by_id(text, kind, name):
    """the block of a QML type with that id"""
    for block in qml_blocks(text, kind):
        if re.search(r"\bid: %s\b" % name, block):
            return block
    raise AssertionError(f"no {kind} with id {name}")


def own_line(block, name):
    """the value of a property set in a QML block itself, not in one of its children; None if it sets none"""
    depth = 0
    for line in block.splitlines()[1:]:
        found = re.match(r"\s*%s: (.*)$" % name, line)
        if depth == 0 and found:
            return found.group(1).strip()
        depth += line.count("{") - line.count("}")
    return None


def property_of(text, ident, name):
    """the value of a property declared in the block with that id, up to the end of that block's indentation"""
    found = re.search(r"\n([ \t]*)id: %s\n" % ident, text)
    if not found:
        return None
    for line in text[found.end():].splitlines():
        if line.strip() and not line.startswith(found.group(1)):
            return None
        declared = re.match(r"%s(?:readonly )?property \w+ %s: (.*)$" % (found.group(1), name), line)
        if declared:
            return declared.group(1)
    return None


class AnimationDrivingTest(unittest.TestCase):
    def test_every_effect_runs_its_clock(self):
        # an effect whose time is never set stands still in all that moves with it (flames, sparks, stars, arcs): one
        # driven by hand binds its time, a moment plays or runs its clock on the render thread; only the warm-up, a
        # pixel nearly clear, has none
        for path in sorted(REPO.glob("qml/**/*.qml")):
            text = path.read_text(encoding="utf-8")
            if ".play(" in text or ".runClock(" in text:
                continue
            for block in qml_blocks(text, "Effect"):
                if "id: warmEffect" in block:
                    continue
                self.assertRegex(block, r"\n\s*time: ", f"{path.relative_to(REPO)}: an Effect without time")
        controller = read("AnimationController.qml")
        for call in ("openEffect.play(ms)", "openShards.play(ms)", "closeEffect.play(ms)", "closeShards.play(ms)"):
            self.assertIn(call, controller)
        closing = read("CoverClosing.qml")
        for call in ("effect.play(duration)", "pieces.play(duration)"):
            self.assertIn(call, closing)
        self.assertIn("effect.runClock(3600)", read("CoverLoading.qml"))

    def test_nothing_runs_on_the_gui_thread_or_completes(self):
        # complete() does nothing on an animator: running stays true and stopped never comes. And the GUI thread is
        # busy in the compositor while an app starts
        for path in sorted(ANIMATIONS.glob("*.qml")):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn(".complete()", text, path.name)
            self.assertNotRegex(text, r"NumberAnimation on (progress|time)\b", path.name)
            for block in qml_blocks(text, "NumberAnimation"):
                self.assertNotRegex(block, r'property: "(progress|time)"', path.name)
        controller = read("AnimationController.qml")
        for name in ("openRun", "closeRun"):
            self.assertNotIn(name, controller)

    def test_an_animator_can_drive_every_effect(self):
        # a uniform declared in both stages is not driven: the animator finds only one stage's copy. Qt's own vertex
        # shader has neither, so the one of GLSL ES 3.00 must not either
        vertex = re.search(r"var ES3_VERTEX = (.*?)\n\n", read("shaders.js"), re.S).group(1)
        self.assertIn("qt_Matrix", vertex)
        self.assertNotRegex(vertex, r"\b(progress|time|clipTop)\b")
        self.assertNotRegex(read("shaders/shards.vert"), r"\bclipTop\b")

    def test_both_passes_are_targeted(self):
        # an animator on the parent alone leaves the grains frozen at their start
        effect = read("Effect.qml")
        self.assertRegex(by_id(effect, "Component", "grainsComponent"), r"part: 2")
        run = by_id(effect, "ParallelAnimation", "run")
        grains = by_id(effect, "ParallelAnimation", "grainsRun")
        for uniform in ("progress", "time"):
            self.assertRegex(run, r'target: effect\n\s*uniform: "%s"' % uniform)
            self.assertRegex(grains, r'target: effect\.grains\n\s*uniform: "%s"' % uniform)
        self.assertIn("animate().start(split)", function(effect, "play"))
        self.assertRegex(function(effect, "start"), r"if \(split\)\n\s*grainsRun\.start\(\)")
        self.assertIn("animators.stop()", function(effect, "halt"))
        stop = function(effect, "stop")
        for line in ("grainsRun.stop()", "clock.stop()", "run.stop()"):
            self.assertIn(line, stop)
        # the last, so that whoever gets ended finds all of it stopped
        self.assertLess(stop.index("clock.stop()"), stop.index(" run.stop()"))
        self.assertLess(stop.index("grainsRun.stop()"), stop.index(" run.stop()"))

    def test_a_moment_makes_only_the_passes_it_has(self):
        # a cover makes an Effect every time it closes, so a make holds only what its moment draws: the grains pass is
        # for a split moment only and the field's Loader for one with a field only. fit() makes and drops them as the
        # style or the moment changes, before the text, so that an Effect played as soon as it is ready finds them. By
        # Component, as the runs: a Loader would make them later inside an asynchronous creation
        effect = read("Effect.qml")
        fit = function(effect, "fit")
        self.assertIn("Styles.split(style, moment)", fit)
        self.assertIn('Styles.listed(style, "field", moment)', fit)
        for component, made in (("grainsComponent", "grains"), ("fieldComponent", "fieldLoader")):
            self.assertIn("%s = %s.createObject(effect)" % (made, component), fit)
            self.assertEqual(effect.count("%s.createObject(" % component), 1, component)
            self.assertRegex(effect, r"\n    property Item %s: null\n" % made)
        self.assertRegex(by_id(effect, "Component", "fieldComponent"), r"\n\s*Loader \{")
        self.assertEqual(len(qml_blocks(effect, "Loader")), 1)
        self.assertEqual(len(qml_blocks(effect, "ShaderEffect")), 2)
        self.assertIn(qml_blocks(effect, "ShaderEffect")[1], by_id(effect, "Component", "grainsComponent"))
        self.assertRegex(effect, r"onShaderNameChanged: \{\n\s*fit\(\)\n\s*load\(\)\n")
        # and dropped, after the property lets go of it
        for made, local in (("grains", "pass"), ("fieldLoader", "loader")):
            self.assertRegex(fit, r"var %s = %s\n\s*%s = null\n\s*%s\.destroy\(\)" % (local, made, made, local))
        # the grains pass is there only while split, its layer with it
        self.assertIn("layer.enabled: true", by_id(effect, "Component", "grainsComponent"))
        # nothing reads the grains pass but an animator, which does nothing without a target, and load(), which sets its
        # texts once it has checked for it (test_a_text_is_set_once)
        sets = function(effect, "load")
        setter = (r"\s*(if \(effect\.grains !== null\) \{"
                  r"|effect\.grains\.(?P<kind>vertex|fragment)Shader = effect\.(?P=kind)Shader)$")
        for path in sorted(list(REPO.glob("qml/**/*.qml")) + list(REPO.glob("harness/*.qml"))):
            for line in path.read_text(encoding="utf-8").splitlines():
                if path.name == "Effect.qml" and re.match(setter, line):
                    self.assertIn(line + "\n", sets)
                elif re.search(r"\.grains\b", line):
                    self.assertRegex(line, r"^\s*target: [\w.]+\.grains$", f"{path.relative_to(REPO)}: {line.strip()}")

    def test_an_effect_hides_no_id_it_reads(self):
        # a binding reads the ids of its own component, then the properties of the object it is on, and only then the
        # ids of the components around it: in the blur's component of FrostField.qml, field.owner read an Effect's
        # property named field, and the blur had no picture. So no property of Effect.qml is named as an id that an
        # Effect block reads
        own = set(re.findall(r"^    (?:readonly )?property \w+ (\w+)", read("Effect.qml"), re.M))
        self.assertIn("fieldLoader", own)
        for path in sorted([*REPO.glob("qml/**/*.qml"), *REPO.glob("harness/*.qml")]):
            text = path.read_text(encoding="utf-8")
            ids = set(re.findall(r"\bid: (\w+)", text))
            for block in qml_blocks(text, "Effect"):
                hidden = own & ids & set(re.findall(r"(?<![\w.])(\w+)\.\w", block))
                self.assertFalse(hidden, f"{path.relative_to(REPO)}: an Effect reads {sorted(hidden)}")

    def test_a_text_is_set_once(self):
        # Qt reads a text again each time it is set, on both passes. A make calls load() up to three times (from the
        # GL version's change, the name's and the completion), and a text still being read answers every call: load()
        # returns while its text is set, and of the answers only the first sets it. A binding not yet run runs when it
        # is read, and its change handler can call load() from inside that read: so all it reads comes before the check
        load = function(read("Effect.qml"), "load")
        self.assertIn("var key = name + es3\n", load)
        self.assertRegex(load, r"if \(loaded && loadedAs === key\)\n\s*return\n\s*loaded = false\n")
        check = load.index("if (loaded && loadedAs === key)")
        for first in ("var name = shaderName\n", "var es3 = effect.es3\n", "var major = glMajor\n"):
            self.assertLess(load.index(first), check, first)
        self.assertNotIn("glMajor", load[check:])
        answer = load[load.index("Shaders.load(base, name, libs, es3, function (text) {"):]
        self.assertRegex(answer, r"if \(effect\.loaded && effect\.loadedAs === key\)\n\s*return\n")
        self.assertEqual(answer.count("effect.fragmentShader = "), 1)
        self.assertLess(answer.index("effect.loadedAs === key"), answer.index("effect.fragmentShader = "))
        self.assertLess(answer.index("effect.loadedAs = key"), answer.index("effect.loaded = true"))
        # a new GL version is a new key: the text is set again as GLSL ES 3.00
        self.assertRegex(read("Effect.qml"), r"onGlMajorChanged: \{\n(\s+.*\n)*?\s*load\(\)\n")
        # the grains pass's texts are set there as well, after a check for the pass, and not bound to the Effect's:
        # bound, a pass made for a new moment (Dust or Frost after a style without grains) read the old moment's text
        # first, then its own, and a pass being dropped read the new one. fit() makes and drops it before load()
        effect = read("Effect.qml")
        self.assertNotRegex(by_id(effect, "Component", "grainsComponent"), r"(?m)^\s*(vertex|fragment)Shader: ")
        self.assertRegex(answer, r"\n\s*effect\.fragmentShader = text\n(\s*//.*\n)*"
                                 r"\s*if \(effect\.grains !== null\) \{\n"
                                 r"\s*effect\.grains\.vertexShader = effect\.vertexShader\n"
                                 r"\s*effect\.grains\.fragmentShader = effect\.fragmentShader\n\s*\}\n")
        self.assertLess(answer.index("effect.grains.fragmentShader"), answer.index("effect.loaded = true"))
        self.assertEqual(len(re.findall(r"\.(vertex|fragment)Shader = ", effect)), 4)
        self.assertRegex(effect, r"onShaderNameChanged: \{\n\s*fit\(\)\n\s*load\(\)\n")

    def test_the_animators_are_made_by_the_first_run(self):
        # the sheet makes and drops 39 Effects that it drives by hand, as the viewer, the harness and the warm-up do:
        # none of them makes an animator. The first play() or runClock() makes them, at once, in that call, so that
        # the run starts in it; a Loader would make them later inside an asynchronous creation (a cover's loading in a
        # delegate being made), and the run would not start
        for name, root, component, made, calls in (
                ("Effect.qml", "effect", "animatorsComponent", "animators", ("play", "runClock")),
                ("Shards.qml", "pane", "runComponent", "run", ("play",))):
            text = read(name)
            for loader in qml_blocks(text, "Loader"):
                self.assertNotIn("Animator", loader, name)
            maker = by_id(text, "Component", component)
            animators = qml_blocks(text, "UniformAnimator")
            self.assertTrue(animators, name)
            for block in animators:
                self.assertIn(block, maker, name)
            self.assertNotRegex(text, r"\n    (Parallel|Sequential)Animation \{", name)
            self.assertRegex(text, r"\n    property (Item|QtObject) %s: null\n" % made, name)
            self.assertIn("readonly property bool running: %s !== null && %s.running" % (made, made), text)
            create = "%s = %s.createObject(%s)" % (made, component, root)
            self.assertEqual(text.count(create), 1, name)
            self.assertIn("if (%s === null)\n" % made, text)
            for call in calls:
                body = function(text, call)
                self.assertTrue(create in body or ("animate()." in body and create in function(text, "animate")),
                                f"{name}: {call}() makes nothing")
            # a halt before any run makes nothing and stops nothing, so nothing ends
            halt = function(text, "halt")
            self.assertIn("if (%s !== null)" % made, halt)
            self.assertNotIn("animate(", halt)
            self.assertNotIn("createObject", halt)
            self.assertNotIn("animate(", function(text, "load"))

    def test_effects_driven_by_hand_never_run(self):
        # only these start runs, and the bench's copies in its play mode (made by a Repeater, with no id;
        # test_the_bench_plays_as_the_home_screen_does): every other Effect and Shards binds its progress (and time)
        # and never makes animators
        players = {"qml/animations/AnimationController.qml": {"openEffect", "openShards", "closeEffect", "closeShards"},
                   "qml/animations/CoverClosing.qml": {"effect", "pieces"},
                   "qml/animations/CoverLoading.qml": {"effect"},
                   "harness/BenchScene.qml": {"animated"}}
        for path in sorted([*REPO.glob("qml/**/*.qml"), *REPO.glob("harness/*.qml")]):
            text = path.read_text(encoding="utf-8")
            name = str(path.relative_to(REPO))
            ids = set()
            for kind in ("Effect", "Shards"):
                for block in qml_blocks(text, kind):
                    found = re.search(r"\bid: (\w+)", block)
                    if found:
                        ids.add(found.group(1))
            started = {ident for ident in ids if re.search(r"\b%s\.(play|runClock)\(" % ident, text)}
            self.assertEqual(started, players.get(name, set()), name)
        for name in ("qml/settings/FrozenFrame.qml", "qml/settings/AnimationStage.qml", "harness/ReelScene.qml",
                     "harness/AnimationsScene.qml"):
            text = (REPO / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"\.runClock\(", name)
            for kind in ("Effect", "Shards"):
                for block in qml_blocks(text, kind):
                    self.assertRegex(block, r"\n\s*progress: ", name)
        # the bench's own: what it plays is made by a Component that ends it, and what it times is made and played
        bench = (REPO / "harness" / "BenchScene.qml").read_text(encoding="utf-8")
        self.assertIn("effect.play(going.ms)", function(bench, "animatorsGoing"))
        made = function(bench, "animatorsMade")
        self.assertIn('log("animators made over=20 mean="', made)
        self.assertLess(made.index('log("animators made'), made.index(".play("))
        self.assertIn('log("animators first play over=20 mean="', made)
        for block in qml_blocks(bench, "Effect"):
            if "id: warm\n" in block:
                self.assertRegex(block, r"\n\s*progress: ")

    def test_nothing_is_drawn_before_its_shader(self):
        # Drawn before its shader is set, a ShaderEffect can be merged into a batch, and the batcher's rewrite then
        # adds an attribute to the GLSL ES 3.00 vertex shader, which fails ("Problematic Vertex shader"): a blank and a
        # line in the log (Effect.qml). So every Effect and Shards, in the app and in the harness, is shown only once
        # ready. Its visible reads ready, or a property of the block it names that does; or it is never shown; or it is
        # shown only while a run plays, and every run of it starts after a check of ready
        for path in sorted([*REPO.glob("qml/**/*.qml"), *REPO.glob("harness/*.qml")]):
            text = path.read_text(encoding="utf-8")
            for kind in ("Effect", "Shards"):
                for block in qml_blocks(text, kind):
                    where = "%s:%d %s" % (path.relative_to(REPO), text[:text.index(block)].count("\n") + 1, kind)
                    shown = own_line(block, "visible")
                    self.assertIsNotNone(shown, f"{where}: shown before it is ready (no visible)")
                    if re.search(r"\bready\b", shown) or shown == "false":
                        continue
                    named = re.fullmatch(r"(\w+)\.(\w+)", shown)
                    if named:
                        value = property_of(text, named.group(1), named.group(2))
                        self.assertRegex(value or "", r"\bready\b",
                                         f"{where}: visible: {shown} does not wait for ready")
                        continue
                    self.assertEqual(shown, "running", f"{where}: visible: {shown} does not wait for ready")
                    ident = re.search(r"\bid: (\w+)", block).group(1)
                    calls = re.findall(r"function (\w+)\([^)]*\) \{(?:(?!\n    function ).)*?\b%s\.play\(" % ident,
                                       text, re.S)
                    self.assertTrue(calls, f"{where}: no run of {ident}")
                    self.assertNotIn("%s.runClock(" % ident, text)
                    for name in calls:
                        body = function(text, name)
                        before = body[:body.index("%s.play(" % ident)]
                        self.assertRegex(before, r"!%s\.ready\b[^\n]*\)\s*\{[^}]*\breturn\b" % ident,
                                         f"{where}: {name}() plays {ident} without a check of ready")

    def test_a_run_ends_without_a_render_thread(self):
        # a render thread that draws no frames never ends an animator: an app that closes itself with the display off
        # would keep closing, and block later closes, or play on wake
        for name, root in (("Effect.qml", "effect"), ("Shards.qml", "pane")):
            text = read(name)
            play = function(text, "play")
            self.assertIn("length = ms", play)
            self.assertIn("watchdog.restart()", play)
            self.assertIn("watchdog.stop()", function(text, "halt"))
            watchdog = by_id(text, "Timer", "watchdog")
            self.assertIn("interval: %s.length + 500" % root, watchdog)
            self.assertIn("onTriggered: %s.halt()" % root, watchdog)
            self.assertIn("%s.ended()" % root, text)

    def test_a_cover_closing_always_goes(self):
        closing = read("CoverClosing.qml")
        self.assertNotIn("property real progress", closing)
        begin = function(closing, "begin")
        self.assertIn("giveUp.stop()", begin)
        self.assertIn("pieces.build()", begin)
        # a shader that never comes: nothing else would end it
        giveUp = by_id(closing, "Timer", "giveUp")
        self.assertIn("interval: 1500", giveUp)
        self.assertIn("running: true", giveUp)
        self.assertIn("onTriggered: closing.destroy()", giveUp)
        # either way, whichever comes first of its shader and its completion
        for block in (by_id(closing, "Effect", "effect"), by_id(closing, "Shards", "pieces")):
            self.assertIn("closing.begin()", block)
            self.assertIn("onEnded: closing.destroy()", block)
        completed = closing[closing.index("Component.onCompleted"):]
        self.assertIn("begin()", completed)

    def test_a_cover_closing_reads_one_picture_from_its_start(self):
        # a write from the GUI thread to a running effect's input, in the frame after its run ends, copies the GUI
        # side's progress, 0, into it: the cover whole for a frame. A Timer that changed the source once the copy was
        # made came that late whenever the GUI thread was busy for the length of the run
        closing = read("CoverClosing.qml")
        for block in (by_id(closing, "Effect", "effect"), by_id(closing, "Shards", "pieces")):
            self.assertRegex(block, r"\n\s*source: kept\n")
        timers = [re.search(r"id: (\w+)", timer).group(1) for timer in qml_blocks(closing, "Timer")]
        self.assertEqual(timers, ["giveUp"])
        self.assertNotRegex(closing, r"\bsource: .*\?")
        # the copy's grab takes the frozen cover's in the same frame, before the run's first
        completed = closing[closing.index("Component.onCompleted"):]
        self.assertLess(completed.index("frozen.scheduleUpdate()"), completed.index("kept.scheduleUpdate()"))
        self.assertLess(completed.index("kept.scheduleUpdate()"), completed.index("begin()"))
        self.assertIn("property variant source: frozen", by_id(closing, "Item", "copyOf"))

    def test_a_stock_loading_makes_nothing(self):
        loading = read("CoverLoading.qml")
        drawn = by_id(loading, "Loader", "drawn")
        self.assertIn('active: loading.style !== "stock"', drawn)
        for piece in ("NoiseTile {", "LauncherIcon {", "ShaderEffectSource {", "Effect {"):
            self.assertIn(piece, drawn)
            self.assertEqual(loading.count(piece), 1, piece)
        self.assertIn("drawn.item.playing", loading)
        self.assertNotIn("property real time", loading)
        self.assertIn("OpacityAnimator on opacity", loading)
        self.assertNotIn("NumberAnimation", loading)
        pieces = drawn[drawn.index("id: pieces"):]
        self.assertIn("onPlayingChanged", pieces)
        self.assertIn("Component.onCompleted", pieces)

    def test_the_controller_stops_before_it_sets(self):
        # ended clears the source: a run that ends after the new source is set would take it away
        controller = read("AnimationController.qml")
        self.assertIn("readonly property bool playing: openEffect.running || openShards.running", controller)
        stop = function(controller, "stopOpening")
        self.assertIn("openEffect.halt()", stop)
        self.assertIn("openShards.halt()", stop)
        opening = function(controller, "opening")
        self.assertLess(opening.index("stopOpening()"), opening.index("liveLayer.sourceItem = layer"))
        self.assertLess(opening.index("liveLayer.sourceItem = layer"), opening.index("openEffect.play(ms)"))
        closing = function(controller, "closing")
        self.assertIn("closeEffect.running || closeShards.running", closing)
        self.assertIn("stopOpening()", closing)
        finish = function(controller, "finish")
        for line in ("stopOpening()", "closeEffect.halt()", "closeShards.halt()"):
            self.assertIn(line, finish)
        for kind, name in (("Effect", "openEffect"), ("Shards", "openShards"), ("Effect", "closeEffect"),
                           ("Shards", "closeShards")):
            block = by_id(controller, kind, name)
            self.assertIn("visible: running", block)
            # their progress and time are the animators' now, and the GUI's value is the old one during a run
            self.assertNotRegex(block, r"\n\s*(progress|time): ", name)
            if name.startswith("open"):
                self.assertIn("onEnded: liveLayer.sourceItem = null", block)
            else:
                self.assertIn("layerHider.sourceItem = null", block)
                self.assertIn("frozenLayer.sourceItem = null", block)

    def test_the_window_comes_back_on_the_render_thread(self):
        # written from the GUI thread, the wiped top and the fade stood still while it was busy, and a write in the
        # closing's last frame copied the GUI side's progress, 0, back into the effect
        controller = read("AnimationController.qml")
        self.assertNotIn("NumberAnimation", controller)
        self.assertNotIn("cameFrom", controller)
        for kind, name in (("Effect", "closeEffect"), ("Shards", "closeShards")):
            self.assertNotRegex(by_id(controller, kind, name), r"\n\s*(clipTop|opacity): ", name)
        back = {"effectBack": ("closeEffect", "closeEffect.grains"), "shardsBack": ("closeShards",)}
        for name, targets in back.items():
            group = by_id(controller, "ParallelAnimation", name)
            clips = qml_blocks(group, "UniformAnimator")
            self.assertEqual([re.search(r"target: (\S+)", clip).group(1) for clip in clips], list(targets))
            for clip in clips:
                self.assertIn('uniform: "clipTop"', clip)
            fades = qml_blocks(group, "OpacityAnimator")
            self.assertEqual(len(fades), 1)
            self.assertIn("target: %s\n" % targets[0], fades[0])
            for block in clips + fades:
                self.assertIn("from: %s." % targets[0], block)
                self.assertIn("duration: 180", block)
        self.assertIn("property Item grains: null", read("Effect.qml"))
        closing = function(controller, "closing")
        for name in back:
            self.assertLess(closing.index("%s.stop()" % name), closing.index("piece.clipTop = top / height"))
        self.assertRegex(closing, r"closeShards\.play\(ms\)\n\s*shardsBack\.start\(\)")
        self.assertRegex(closing, r"closeEffect\.play\(ms\)\n\s*effectBack\.start\(\)")
        # an OpacityAnimator does not reach an item drawn through its own layer, as a closing half and not split is
        styles = read("styles.js")
        for style, rest in re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S):
            lists = {key: re.findall(r'"(\w+)"', moments)
                     for key, moments in re.findall(r'"(half|split)": \[(.*?)\]', rest)}
            if "close" in lists.get("half", []):
                self.assertIn("close", lists.get("split", []), style)

    def test_turned_off_it_compiles_nothing_more(self):
        # the queue goes with the setting, and the next tick of the warm-up clears its pixel and stops
        prepare = function(read("AnimationController.qml"), "prepare")
        self.assertRegex(prepare, r"\{\s*if \(!settings\.enabled\)\n\s*warmQueue = \[\]\n")
        self.assertLess(prepare.index("warmQueue = []"), prepare.index("return"))

    def test_only_what_is_queued_is_read(self):
        controller = read("AnimationController.qml")
        prepare = function(controller, "prepare")
        # the shard files are the shards' own, while active, and a load comes only with its place in the queue
        self.assertNotIn("shards.vert", prepare)
        self.assertNotIn("loadFile", prepare)
        self.assertRegex(prepare,
                         r"if \(settings\.surprise \|\| chosen\) \{\s*Shaders\.load\(.*\n\s*queue\.push\(item\)")
        self.assertEqual(prepare.count("Shaders.load("), 1)
        self.assertIn('queue.push({ "style": "shards" })', prepare)
        self.assertIn('mayShatter("open") || mayShatter("close")', prepare)
        warm = by_id(controller, "Timer", "warmUp")
        self.assertIn('next.style === "shards"', warm)
        self.assertIn("warmShards.active = true", warm)
        self.assertLess(warm.index("warmShards.active = false"), warm.index("warmShards.active = true"))
        # the old style under the next moment would read a shader nobody queued
        self.assertLess(warm.index('warmEffect.style = ""'), warm.index("warmEffect.moment = next.moment"))
        shards = by_id(controller, "Shards", "warmShards")
        for line in ("active: false", "visible: ready", "source: noise", "progress: 0.5"):
            self.assertIn(line, shards)
        for name in ("openShards", "closeShards"):
            self.assertIn("active: controller.mayShatter(", by_id(controller, "Shards", name))

    def test_each_file_is_read_once(self):
        # common.glsl is in front of every shader. And a reader that went while it waited must not cost the others
        # their answer: a shader's waiting list that never empties would stay stock until the home screen restarts
        shaders = read("shaders.js")
        self.assertEqual(len(re.findall(r"\bread\(", shaders)), 2, "read() is defined, and called by loadFile() alone")
        self.assertIn("read(url, ", function(shaders, "loadFile"))
        self.assertIn("reading[url].push(done)", function(shaders, "loadFile"))
        self.assertIn("try {", function(shaders, "tell"))
        self.assertIn("tell(calls, text)", function(shaders, "loadFile"))
        load = function(shaders, "load")
        self.assertIn("loadFile(base + names[parts.length]", load)
        self.assertNotRegex(load, r"\bread\(")
        self.assertIn("tell(calls, result)", load)

    def test_an_off_home_screen_reads_no_noise(self):
        tile = read("NoiseTile.qml")
        self.assertIn("property bool wanted: true", tile)
        self.assertIn('source: wanted ? "noise.png" : ""', tile)
        self.assertIn("wanted: settings.enabled", by_id(read("AnimationController.qml"), "NoiseTile", "noise"))

    def test_the_bench_runs_the_animators(self):
        bench = (REPO / "harness" / "BenchScene.qml").read_text(encoding="utf-8")
        self.assertIn('mode === "animators"', bench)
        animated = by_id(bench, "Effect", "animated")
        self.assertNotRegex(animated, r"\n\s*(progress|time): ")
        self.assertIn("animated.play(", bench)
        self.assertIn("animated.halt()", bench)
        self.assertIn("destroy()", by_id(bench, "Component", "ownEffect"))
        self.assertIn('effects[i].moment === "field"', function(bench, "playList"))

    def test_the_bench_names_the_split_closing_it_runs(self):
        # bench animators split=frost back=dust names in its lines the split closing whose grains it grabs (Frost's
        # 4 s, its first grab before the snow), the closing a window comes back from with its grains pass or none, and
        # the time to make that split closing, after the split step has read its text
        bench = (REPO / "harness" / "BenchScene.qml").read_text(encoding="utf-8")
        split = function(bench, "animatorsSplit")
        self.assertIn('var style = option("split", "dust")\n', split)
        self.assertIn('cue(style, "close", function () {', split)
        self.assertIn('log("animators split", style, "split=" + animated.split, "grains pass=" + (grains !== null))',
                      split)
        self.assertIn('animated.play(style === "dust" ? 6000 : 4000)', split)
        back = function(bench, "animatorsComeBack")
        self.assertIn('var style = option("back", "contour")\n', back)
        self.assertIn('cue(style, "close", function () {', back)
        self.assertIn('log("animators come back", style, "grains pass=" + (grainsOf(animated) !== null))', back)
        self.assertIn('animated.play(Styles.duration(style, "close", 2))', back)
        self.assertIn("effect.children[i].part === 2", function(bench, "grainsOf"))
        made = function(bench, "animatorsMade")
        self.assertIn('var split = mean(option("split", "dust"), "close")\n', made)
        self.assertIn('+ " ms, split " + split.toFixed(2) + " ms (" + option("split", "dust") + " close)")', made)
        self.assertLess(made.index("var split = mean("), made.index('log("animators made'))
        steps = re.findall(r"\w+", re.search(r"each\(\[(.*?)\]", function(bench, "runAnimators"), re.S).group(1))
        self.assertLess(steps.index("animatorsSplit"), steps.index("animatorsMade"))
        # and the options as the docs give them, with their defaults
        development = (REPO / "docs" / "DEVELOPMENT.md").read_text(encoding="utf-8")
        for option in ("`split=dust`", "`back=contour`"):
            self.assertIn(option, development)

    def test_the_bench_plays_as_the_home_screen_does(self):
        # bench play runs each moment through play(), a loading through runClock() for the length it always had, on the
        # render thread as AnimationController.qml does; driver=gui keeps the GUI thread's animation for comparison.
        # Its steps keep their names and lines, which the frame log is read by
        bench = (REPO / "harness" / "BenchScene.qml").read_text(encoding="utf-8")
        play = function(bench, "playPoint")
        self.assertIn('var byGui = option("driver", "render") === "gui"', play)
        self.assertIn('var length = point.moment === "load" ? 3000 : Styles.duration(point.style, point.moment, 1)',
                      play)
        self.assertIn("piece.runClock(length / 1000)", play)
        self.assertIn("piece.play(length)", play)
        self.assertIn("(kind === \"shards\" ? shardsCopies : effectCopies).itemAt(0)", play)
        self.assertIn("if (byGui ? run.running : piece.running) {", play)
        self.assertIn("run.restart()", play)
        for line in ('step("warm " + name, "begin")', 'step("play " + name, "end")',
                     'log("play", name, "length=" + length, statsText(stats(list)), "first="'):
            self.assertEqual(play.count(line), 1, line)
        # begun by either driver, right before its run starts
        self.assertEqual(play.count('step("play " + name, "begin")\n                    run.restart()'), 1)
        self.assertRegex(play, r'step\("play " \+ name, "begin"\)\n\s*var since = Date\.now\(\)\n\s*'
                               r'if \(point\.moment === "load"\)\n\s*piece\.runClock')
        self.assertIn('+ " round=" + point.round', play)
        # a clock has no watchdog: the bench ends one that does not end
        self.assertIn("piece.halt()", play)
        for name in ("effectCopies", "shardsCopies"):
            self.assertIn("id: %s" % name, bench)

    def test_the_bench_says_when_a_cost_is_not_one(self):
        # a slope across a change of the phone's state reads as a cost, even a falling one. The word comes after the
        # numbers, where a reader of the lines finds it whatever it takes from their start
        cost = function((REPO / "harness" / "BenchScene.qml").read_text(encoding="utf-8"), "costPoint")
        self.assertIn("var rest = a.mean - a.k * ms", cost)
        self.assertIn('"rest=" + rest.toFixed(1)]', cost)
        self.assertRegex(cost, r'if \(ms < 0 \|\| rest < -3 \|\| rest > 20\)\n\s*line\.push\("suspect"\)\n\s*'
                               r"log\.apply\(scene, line\)")

    def test_a_given_kmax_ends_the_search_for_a_cost(self):
        # eight samples would end the climb at K=128 although kmax asks for 1500 (size=0, where a copy costs next to
        # nothing). Without kmax the search stops at eight samples
        cost = function((REPO / "harness" / "BenchScene.qml").read_text(encoding="utf-8"), "costPoint")
        self.assertIn('var kmaxGiven = option("kmax", "") !== ""', cost)
        self.assertRegex(cost, r"if \(kmaxGiven && top\.mean < floor\)\n\s*climbed = samples\.length\n\s*"
                               r"if \(samples\.length - climbed >= 8\) \{")
        self.assertNotIn("if (samples.length >= 8)", cost)
        # past the climb no K over a given kmax either
        self.assertRegex(cost, r"\} else if \(kmaxGiven && top\.k >= kmax\) \{\n\s*report\(\)")
        self.assertIn("tryK(kmaxGiven ? Math.min(kmax, up) : up)", cost)
        # the first K is the last point's, which is below kmax, or ks= gives them all
        for call in re.findall(r"tryK\((.*)\)\n", cost):
            self.assertTrue(call.startswith(("Math.min(kmax", "fixed", "kmaxGiven ? Math.min(kmax", "Math.max(1, ")),
                            call)

    def test_an_opening_knows_the_corners_it_opens_from(self):
        # an icon is round, a cover has the switcher's corners, the middle of the screen none
        controller = read("AnimationController.qml")
        self.assertIn('kind === "icon" ? from.width / 2 : kind === "cover" ? from.radius : 0', controller)
        self.assertIn("openEffect.radiusPx = from.radius", controller)
        switcher = (REPO / "qml" / "switcher" / "SwitcherController.qml").read_text(encoding="utf-8")
        cover = switcher[switcher.index("function coverRectFor"):]
        self.assertIn('"radius": Theme.paddingMedium', cover[:cover.index("return null")])


if __name__ == "__main__":
    unittest.main()
