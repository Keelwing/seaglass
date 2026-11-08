"""The Animations page of the settings: the sheet of still frames and what it is made with (qml/settings: the page,
AnimationSheetBuilder.qml, FrozenFrame.qml, FreezeQueue.qml, FrameCounter.qml, PreviewKit.qml, NotesPreview.qml,
stills.js), the picture the frames become and the file it is kept in (AnimationSheetPicture.qml), the settings under
the sheet (AnimationFeel.qml), the viewer a tap opens (AnimationViewerPage.qml, AnimationStage.qml,
AnimationStrip.qml), its row on the first page, what the harness rewrites in its copy, and that none of it needs
Lipstick."""
import hashlib
import json
import re
import unittest
from pathlib import Path

from test_repo import qml_blocks

REPO = Path(__file__).resolve().parents[1]
SETTINGS = REPO / "qml" / "settings"
# the page and the files it draws with
SHEET = ["AnimationsPage.qml", "AnimationSheetBuilder.qml", "FrozenFrame.qml", "FreezeQueue.qml", "FrameCounter.qml",
         "PreviewKit.qml", "NotesPreview.qml", "stills.js", "AnimationSheetPicture.qml"]
# the viewer and its parts
VIEWER = ["AnimationViewerPage.qml", "AnimationStage.qml", "AnimationStrip.qml"]


def read(name):
    return (SETTINGS / name).read_text(encoding="utf-8")


def by_id(text, kind, name):
    """the block of a QML type with that id"""
    for block in qml_blocks(text, kind):
        if re.search(r"\bid: %s\b" % name, block):
            return block
    raise AssertionError(f"no {kind} with id {name}")


def function(text, name):
    """a JS function of a QML file, from its line to its closing brace"""
    start = re.search(r"(?m)^[ \t]*(function %s\()" % name, text)
    if start is None:
        raise AssertionError(f"no function {name}")
    depth = 0
    for end in range(text.index("{", start.start(1)), len(text)):
        depth += {"{": 1, "}": -1}.get(text[end], 0)
        if depth == 0:
            return text[start.start(1):end + 1]
    raise AssertionError(f"function {name} does not end")


def js_value(text, name):
    """a var of stills.js, as JSON"""
    match = re.search(r"(?ms)^var %s = (.*?)\n(?=//|var |function )" % name, text)
    return json.loads(re.sub(r"(?m)^\s*//.*$", "", match.group(1)))


# What shapes a still, and so the sheet a page keeps: the shaders, the files that draw them, the made-up home screen,
# the frame (with the counter it waits on for its grab) and how the sheet cuts it, the noise tile, and stills.js itself
STILL_FILES = ["qml/animations/Effect.qml", "qml/animations/FrostField.qml", "qml/animations/NoiseTile.qml",
               "qml/animations/Shards.qml", "qml/animations/shaders.js", "qml/animations/styles.js",
               "qml/settings/AnimationSheetBuilder.qml", "qml/settings/FrameCounter.qml",
               "qml/settings/FrozenFrame.qml", "qml/settings/NotesPreview.qml", "qml/settings/PreviewKit.qml",
               "qml/settings/stills.js", "scripts/noise.py"]
KEY_LINE = re.compile(r'(?m)^var KEY = "[0-9a-f]*"\n')


def stills_key():
    """Stills.KEY as it should be: the first 12 hex digits of a SHA-256 over every file of STILL_FILES and of
    qml/animations/shaders/, in the order of their paths, each as its path, a NUL, its bytes and a NUL; stills.js
    without its KEY line"""
    paths = STILL_FILES + ["qml/animations/shaders/" + path.name
                           for path in (REPO / "qml" / "animations" / "shaders").iterdir()
                           if path.is_file() and not path.name.startswith(".")]
    digest = hashlib.sha256()
    for path in sorted(paths):
        data = (REPO / path).read_bytes()
        if path == "qml/settings/stills.js":
            data = KEY_LINE.sub("", data.decode("utf-8"), count=1).encode("utf-8")
        digest.update(path.encode("utf-8") + b"\0" + data + b"\0")
    return digest.hexdigest()[:12]


class AnimationPageTest(unittest.TestCase):
    def test_animations_page(self):
        # the pages of docs/ANIMATIONS.md, the sheet's row on the first page (after the task switcher), and what they
        # write: the sheet its switch and the settings under it (Feel), the viewer Use and Speed, nothing else
        page = read("AnimationsPage.qml") + read("AnimationFeel.qml")
        viewer = read("AnimationViewerPage.qml")
        for text in ("App animations", "Surprise me", "Opening", "Loading", "Closing", "Speed", "Relaxed", "Normal",
                     "Quick", "Ambience colours", "Covers too"):
            self.assertIn(f'qsTr("{text}")', page, text)
        for text in ("Opening", "Loading", "Closing", "Use for opening", "Use for loading", "Use for closing",
                     "Use for all three", "In use", "Off", "In use: Surprise me", "Slow", "Speed: Relaxed",
                     "Speed: Normal", "Speed: Quick", "May stutter on slower phones."):
            self.assertIn(f'qsTr("{text}")', viewer, text)
        for setting in ("enabled", "surprise", "speed", "ambience", "covers"):
            self.assertRegex(page, r"settings\.%s = " % setting, setting)
        for setting in ("style", "open", "loading", "close"):
            self.assertNotRegex(page, r"settings(\.%s|\[\w+\]) = " % setting, setting)
        # the moments are written only by Use, the speed only by its button
        writes = viewer.replace(function(viewer, "useAll"), "").replace(function(viewer, "useFor"), "")
        for setting in ("style", "open", "loading", "close", "enabled", "surprise", "ambience", "covers"):
            self.assertNotRegex(writes, r"settings(\.%s|\[\w+\]) = " % setting, setting)
        self.assertEqual(re.findall(r"settings\.speed = .*", writes), ["settings.speed = (settings.speed + 1) % 3"])
        self.assertIn("settings.speed = ", function(viewer, "cycleSpeed"))
        hub = read("SettingsHub.qml")
        order = [hub.index(f'hub.open("{name}")') for name in ("SwitcherPage", "AnimationsPage", "WidgetsPage")]
        self.assertEqual(order, sorted(order))

    def test_the_page_draws_no_effect_itself(self):
        # every effect is drawn by a still while it develops, never by the page: it holds none, and reads no shader
        page = read("AnimationsPage.qml")
        for kind in ("Effect {", "Shards {", "NoiseTile {", "ShaderEffect {", "Shaders.", "Styles.choose("):
            self.assertNotIn(kind, page)
        self.assertIn("readonly property int glMajor: OpenGLInfo.majorVersion", page)

    def test_nothing_needs_lipstick(self):
        # the settings are not the compositor
        names = SHEET + VIEWER + ["AnimationFeel.qml", "../animations/Effect.qml", "../animations/Shards.qml",
                                  "../animations/NoiseTile.qml", "../animations/FrostField.qml",
                                  "../animations/styles.js", "../animations/shaders.js"]
        for name in names:
            text = read(name)
            self.assertNotRegex(text, r"(?m)^import (org\.nemomobile\.lipstick|Sailfish\.Lipstick)", name)
            self.assertNotIn("Lipstick.", text, name)

    def test_harness_settings_copy_never_shows_the_phones_wallpaper(self):
        # scripts/harness.sh rewrites these lines of the previewing pages' copies: they must be there as written
        harness = (REPO / "scripts" / "harness.sh").read_text(encoding="utf-8")
        lines = {"GlassPage": ("property string ambienceFile: ambiencePicture.value",
                               "property bool persistentGlass: true"),
                 "AnimationsPage": ("property string ambienceFile: ambiencePicture.value",
                                    "property bool keepSheet: true")}
        for name, rewritten in lines.items():
            page = read(f"{name}.qml")
            self.assertIn(f"~/$dir/qml/settings/{name}.qml", harness)
            for line in rewritten:
                self.assertIn(line, page)
                self.assertIn(f"s|{line}|", harness)
        self.assertIn("s|property bool keepSheet: true|property bool keepSheet: false|", harness)
        # and a sheet a bench step keeps goes to the harness's own folder, which every run removes, never to ~/.cache
        self.assertIn("""-e 's|property string sheetFolder: StandardPaths.home + \\"/.cache\\"|"""
                      """property string sheetFolder: StandardPaths.home + \\"/$dir/harness\\"|'""", harness)
        self.assertIn('rm -rf ~/$dir && mkdir -p', harness)
        self.assertIn("""    property string ambienceFile: ambiencePicture.value
    // false in the harness: no file is read or written, and the sheet is made on every visit
    property bool keepSheet: true
    property string sheetFolder: StandardPaths.home + "/.cache"
""", read("AnimationsPage.qml"))

    def test_only_the_page_reads_the_wallpaper(self):
        # the sheet holds only made-up things over a neutral gradient: the ambience's picture goes no further than the
        # page, which hands it to the viewer
        files = sorted({*SETTINGS.glob("Animation*"), *(SETTINGS / name for name in SHEET),
                        *(REPO / "qml" / "animations").glob("*.*")})
        readers = [path.name for path in files if "home_picture_filename" in path.read_text(encoding="utf-8")]
        self.assertEqual(readers, ["AnimationsPage.qml"])
        builder = read("AnimationSheetBuilder.qml")
        self.assertIn('picture: ""', by_id(builder, "Loader", "kitLoader"))
        self.assertNotIn("ambienceFile", read("AnimationSheetPicture.qml"))

    def test_stills_cover_every_style_and_moment(self):
        stills = read("stills.js")
        styles = re.findall(r'\{ "id": "(\w+)"', (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8"))
        order = js_value(stills, "ORDER")
        self.assertEqual(order, ["stock"] + styles)
        table = js_value(stills, "STILLS")
        about = js_value(stills, "ABOUT")
        self.assertEqual(sorted(table), sorted(order))
        self.assertEqual(sorted(about), sorted(order))
        for style, still in table.items():
            self.assertEqual(sorted(still), ["clip", "close", "load", "open"], style)
            at, offset = still["open"]
            self.assertTrue(0 <= at <= 1 and -0.5 < offset < 0.5, style)
            at, band = still["close"]
            self.assertTrue(0 <= at <= 1 and 0 <= band <= 1, style)
            self.assertGreaterEqual(still["load"], 0, style)
            self.assertGreater(still["clip"], 0, style)
            self.assertTrue(about[style].endswith("."), style)
        self.assertEqual(len(js_value(stills, "SEED")), 4)
        rungs = js_value(stills, "RUNGS")
        for style, moments in js_value(stills, "STAGE").items():
            self.assertIn(style, styles)
            for rung in moments.values():
                self.assertIn(rung, rungs, style)
        # the heads and the viewer's "In use" ask the same function
        self.assertIn('return settings.surprise && settings[key] !== "stock" ? "surprise" : Styles.setting(settings, key)',
                      stills)
        self.assertIn("Stills.inUse(settings, ", read("AnimationsPage.qml"))

    def test_the_sheet_key_is_made_from_what_shapes_a_still(self):
        # A kept sheet shows only while its key holds, and its key starts with Stills.KEY: a KEY left as it was after
        # one of these files changed would show the sheet of the old files. So the KEY is set again with every change
        stills = read("stills.js")
        self.assertEqual(len(KEY_LINE.findall(stills)), 1, "stills.js has one KEY line")
        expected = stills_key()
        self.assertEqual(js_value(stills, "KEY"), expected,
                         'Stills.KEY is stale: a file that shapes a still changed. Set the line in '
                         f'qml/settings/stills.js to: var KEY = "{expected}"')
        # every file it names is there, and anything a still draws with is among them
        for path in STILL_FILES:
            self.assertTrue((REPO / path).is_file(), path)
        for name in ("FrozenFrame.qml", "PreviewKit.qml"):
            for used in re.findall(r"^\s*(\w+) \{", read(name), re.M):
                if (REPO / "qml" / "animations" / f"{used}.qml").is_file():
                    self.assertIn(f"qml/animations/{used}.qml", STILL_FILES, f"{name} draws with {used}")
                if (SETTINGS / f"{used}.qml").is_file():
                    self.assertIn(f"qml/settings/{used}.qml", STILL_FILES, f"{name} draws with {used}")

    def test_notes_sits_inside_the_grid(self):
        # in the middle column of the last row the icons reach, at most the middle row: on the Jolla Phone's 5 x 9
        # grid, index 17, at about 0.39 of the height
        kit = read("PreviewKit.qml")
        others = re.search(r"readonly property var others: (\[.*?\]\])", kit, re.S).group(1)
        count = len(json.loads(others)) + 1
        self.assertEqual(count, 20)
        lines = re.search(r"var notesRow = (.*)\n\s*var notesAt = (.*)\n", kit)
        self.assertIsNotNone(lines)

        def evaluate(expression, names):
            expression = expression.replace("Math.min", "min").replace("Math.floor", "int")
            return eval(expression, {"min": min, "int": int}, names)  # noqa: S307 (two lines of our own file)

        for columns, rows, expected in ((5, 9, 17), (4, 6, 14)):
            names = {"rows": rows, "columns": columns, "count": count}
            names["notesRow"] = evaluate(lines.group(1), names)
            notes_at = evaluate(lines.group(2), names)
            self.assertEqual(notes_at, expected, f"{columns} x {rows}")
            self.assertLess(notes_at, count)
        self.assertIn('others.slice(0, notesAt).concat([["notes", "Notes"]], others.slice(notesAt))', kit)
        self.assertNotIn('"notes"', others)

    def test_the_kit_and_notes_are_light_on_dark_in_any_ambience(self):
        # the textures must not depend on the ambience's scheme: every colour comes from their own palette, which a
        # SilicaControl hands on to the labels in it (a SilicaItem does not, on Sailfish OS 5.0 and 5.1)
        for name in ("NotesPreview.qml", "PreviewKit.qml", "FrozenFrame.qml"):
            text = read(name)
            self.assertRegex(text, r"(?m)^SilicaControl \{$", name)
            self.assertIn("palette.colorScheme: Theme.LightOnDark", text, name)
        for name in ("NotesPreview.qml", "PreviewKit.qml"):
            self.assertNotRegex(read(name), r"Theme\.(primaryColor|highlightColor)\b", name)

    def test_only_the_styles_that_blur_read_mipmaps(self):
        # a read in a branch not every pixel takes has no defined mip level: the early returns would draw hairlines on
        # a mipmapped app. So every still reads the app at one texel a pixel but those of a blur
        kit = read("PreviewKit.qml")
        self.assertNotIn("mipmap", by_id(kit, "ShaderEffectSource", "appTexture"))
        self.assertIn("mipmap: kit.es3", by_id(kit, "Loader", "blurCopy"))
        self.assertIn("active: kit.blurWanted", by_id(kit, "Loader", "blurCopy"))
        frame = read("FrozenFrame.qml")
        self.assertIn('readonly property bool blurs: moment !== "load" && Styles.has(style, "blur")', frame)
        self.assertIn("frame.blurs ? frame.kit.appBlur : frame.kit.app", frame)
        self.assertIn("source: frame.kit.app\n", by_id(frame, "Component", "shardsScene"))

    def test_the_kit_is_grabbed_once_its_pictures_have_come(self):
        # Each picture the kit waits for calls check() once what waitingFor() reads of it has changed. A flag bound to
        # a picture's status still holds the old status in that picture's own status handler, so a flag is checked on
        # its own change: checked from the icon's handler, the last icon to come was missed and the kit waited 1.5 s
        kit = read("PreviewKit.qml")
        for name in ("PreviewKit.qml", "NotesPreview.qml"):
            text = read(name)
            for image in re.findall(r"readonly property bool \w+: (\w+)\.status === Image\.Loading", text):
                self.assertNotIn("onStatusChanged", by_id(text, "Image", image), image)
        icons = by_id(kit, "Repeater", "icons")
        cell = qml_blocks(icons, "Item")[0]
        self.assertIn("readonly property bool loading: launcherIcon.status === Image.Loading", cell)
        self.assertIn("onLoadingChanged: kit.check()", cell)
        self.assertIn("onItemAdded: kit.check()", icons)
        self.assertIn("onLoadingChanged: kit.check()", by_id(kit, "NotesPreview", "notesItem"))
        for image in ("homePicture", "plainPicture", "iconImage", "paddedImage"):
            self.assertIn("onStatusChanged: kit.check()", by_id(kit, "Image", image), image)
        waiting = function(kit, "waitingFor")
        for name in ("icons.count < apps.length", "cell.loading", "homePicture.status", "plainPicture.status",
                     "notesItem.loading", "iconImage.status", "paddedImage.status", "noiseTile.sourceItem.status"):
            self.assertIn(name, waiting)
        # the kit is made in an asynchronous Loader, and a cell is in itemAt() before it is complete, its icon not yet
        # asked for and its loading false: the kit shot without the last cell's icon. A cell counts once its own
        # Component.onCompleted has run, and the Repeater adds it after that, which checks again
        self.assertRegex(cell, r"\n\s*property bool made\n")
        self.assertRegex(cell, r"\n\s*Component\.onCompleted: made = true\n")
        self.assertEqual(re.findall(r"\bmade = ", kit), ["made = "])
        self.assertIn("if (cell === null || !cell.made)\n", waiting)
        self.assertLess(waiting.index("!cell.made"), waiting.index("cell.loading"))
        self.assertIn('if ((!shot || stale) && waitingFor() === "")\n            shoot("")', function(kit, "check"))
        # a picture that never comes holds nothing up: giveUp grabs the textures and keeps what they waited for; a
        # change of picture or colours waits again
        give_up = by_id(kit, "Timer", "giveUp")
        for line in ("interval: 1500", "running: true", 'onTriggered: kit.shoot(kit.waitingFor() || "nothing")'):
            self.assertIn(line, give_up)
        self.assertEqual(re.findall(r"(?m)\bshoot\((.*?)\)(?: \{)?$", kit),
                         ['""', "waited", 'kit.waitingFor() || "nothing"'])
        self.assertIn("giveUp.stop()\n        gaveUpOn = waited\n", function(kit, "shoot"))
        for line in ("stale = true", "giveUp.restart()", "recheck.restart()"):
            self.assertIn(line, function(kit, "regrab"))

    def test_a_still_is_the_moment_at_the_normal_speed(self):
        # the sheet is made for colours and size, not for the speed setting: no still may depend on it
        frame = read("FrozenFrame.qml")
        self.assertIn("frame.at * Styles.duration(frame.style, frame.moment, 1) / 1000", frame)
        for name in SHEET:
            if name != "AnimationsPage.qml":
                self.assertNotIn("AnimationSettings", read(name), name)
                self.assertNotIn("speed)", read(name), name)
                self.assertNotIn(".speed", read(name), name)
        page = read("AnimationsPage.qml")
        key = page[page.index("property string sheetKey"):]
        self.assertNotIn("speed", key[:key.index("\n    //")])

    def test_a_still_is_developed_and_dropped(self):
        # the moment exists only while it develops, shown only once its shader is there (before, an ES3 effect fails
        # in the batcher), and the picture outlives it because its source is the holder, never the effect
        frame = read("FrozenFrame.qml")
        scene = by_id(frame, "Loader", "scene")
        self.assertIn("active: false", scene)
        self.assertIn("visible: ready", by_id(frame, "Effect", "effect"))
        self.assertIn("visible: ready", qml_blocks(frame, "Shards")[0])
        picture = by_id(frame, "ShaderEffectSource", "picture")
        for line in ("live: false", "hideSource: true"):
            self.assertIn(line, picture)
        self.assertIn("picture.sourceItem = holder", frame)
        self.assertIn("opacity: 0", by_id(frame, "Item", "holder"))
        # dropped two frames after the shot, counted by an animation (FrameCounter.qml), which the scene graph advances
        # once a frame after its sync: the first comes once the shot is synced and the second once it is drawn
        settle = by_id(frame, "FrameCounter", "settle")
        self.assertIn("onCounted: {", settle)
        self.assertLess(settle.index("scene.active = false"), settle.index("frame.done()"))
        # a hidden window (the app in the background, the display off) draws no frame: a shot it kept from being drawn
        # leaves the moment in place, and is taken again once the window shows, so the grab never catches the backdrop
        # alone
        self.assertIn("import QtQuick.Window 2.2", frame)
        self.assertIn("readonly property bool windowShown: Window.visibility !== Window.Hidden", frame)
        self.assertLess(settle.index("if (frame.missed)\n                return"), settle.index("scene.active = false"))
        shoot = function(frame, "shoot")
        self.assertIn("missed = !windowShown", shoot)
        self.assertIn("settle.count(2)", shoot)
        shown = frame[frame.index("onWindowShownChanged: {"):frame.index("// drawn only through the picture")]
        self.assertIn("missed = true", shown)
        self.assertIn("else if (missed && !patience.running)\n            shoot()", shown)
        # one at a time, a frame or more apart: a frame for each pass the still drew
        queue = read("FreezeQueue.qml")
        self.assertIn("gap.count(Math.max(1, frame.passes))", queue)
        self.assertIn("onCounted: queue.next()", by_id(queue, "FrameCounter", "gap"))
        self.assertIn("gap.stop()", function(queue, "clear"))
        # paced in frames: no Timer in either file but the patience for a shader that does not come, which waits a
        # time on purpose
        for name, text in (("FrozenFrame.qml", frame), ("FreezeQueue.qml", queue)):
            self.assertEqual([timer for timer in qml_blocks(text, "Timer") if "id: patience" not in timer], [], name)
        # and none while the page or its view moves: a back swipe leaves the page Active until it ends
        page = read("AnimationsPage.qml")
        self.assertIn('"paused": Qt.binding(function () { return !page.live || flick.moving || page.navigating })',
                      by_id(page, "Loader", "building"))
        self.assertIn("readonly property bool navigating: page.pageContainer !== null "
                      "&& page.pageContainer.dragInProgress === true\n"
                      "                                       || page.orientationTransitionRunning", page)
        builder = read("AnimationSheetBuilder.qml")
        self.assertNotIn("Repeater", builder)
        self.assertIn("asynchronous: true", by_id(builder, "Loader", "kitLoader"))

    def test_the_frames_leave_the_window_before_their_kit_goes(self):
        # the frames are made in the page's grid, outside the builder, and read the textures of the builder's own kit.
        # A Loader that lets the builder go deletes it a turn later: its Component.onDestruction runs in that deletion
        # before the kit goes, and the frames it destroys go a turn after the kit. A frame still in the window between
        # the two is synced with its textures gone, hidden or not, and Qt 5.6 warns once for each ("is not assigned a
        # valid texture provider"). So each frame leaves the window before its deletion is asked for
        page = read("AnimationsPage.qml")
        self.assertIn('"cells": grid,', by_id(page, "Loader", "building"))
        builder = read("AnimationSheetBuilder.qml")
        self.assertIn("return frameMaker.createObject(cells, {", function(builder, "make"))
        self.assertIn("readonly property Item kit: kitLoader.item", builder)
        teardown = re.search(r"(?ms)^    Component\.onDestruction: \{\n(.*?)^    \}", builder).group(1)
        self.assertIn("queue.clear()", teardown)
        self.assertIn("if (frames[i]) {\n                frames[i].parent = null\n                frames[i].destroy()",
                      teardown)
        self.assertEqual(teardown.count(".destroy()"), 1)

    def test_a_field_is_made_a_frame_after_its_effect(self):
        # an effect and its field (FrostField.qml, one or two Effects more) made in one GUI turn hold the thread for
        # longer than two frames: a still of a moment with a field makes its effect hidden and shows it a frame later,
        # which makes the field, and is shot only then, in the frame the field bakes in. Any other still is shown and
        # shot in the turn it is made
        frame = read("FrozenFrame.qml")
        self.assertIn('readonly property bool withField: kind === "effect" && Styles.listed(style, "field", moment)',
                      frame)
        self.assertIn('readonly property int passes: withField ? (moment === "close" ? 3 : 2) : 1', frame)
        scene = by_id(frame, "Component", "effectScene")
        item = by_id(scene, "Item", "effectItem")
        self.assertIn("readonly property bool ready: effect.ready && shown", item)
        self.assertIn("property bool shown: !frame.withField", item)
        # a frame later by FrameCounter.qml, never a Timer, which ends by its own clock while nothing animates
        self.assertEqual(qml_blocks(scene, "Timer"), [])
        counters = qml_blocks(scene, "FrameCounter")
        self.assertEqual(len(counters), 1)
        for line in ("running: frame.withField && effect.ready && !effectItem.shown",
                     "onCounted: effectItem.shown = true"):
            self.assertIn(line, counters[0])
        self.assertIn("visible: ready && effectItem.shown", by_id(frame, "Effect", "effect"))
        # the shot waits for the scene, and so for the field
        self.assertIn("readonly property bool sceneReady: scene.item !== null && scene.item.ready", frame)
        self.assertIn("if (sceneReady)\n            shoot()\n        else\n            patience.start()",
                      function(frame, "develop"))
        self.assertIn("if (sceneReady && patience.running)\n            shoot()", frame)
        # the field comes with the effect's visible, and only for a moment with a field (Effect.qml)
        effect = (REPO / "qml" / "animations" / "Effect.qml").read_text(encoding="utf-8")
        self.assertIn("active: effect.visible || effect.running", by_id(effect, "Component", "fieldComponent"))
        self.assertIn('var fields = Styles.listed(style, "field", moment)', function(effect, "fit"))

    def test_frames_are_counted_by_an_animation(self):
        # A QML Timer runs on Qt's animation timer, but while no animation runs Qt stops its driver and ends Timers by a
        # clock of its own: with nothing else animating, as in the Settings app, a Timer of 1 ms restarted for two
        # frames ended 3 to 4 ms after its start, with no frame between (no GL, 5.0 and 5.1). A running animation is
        # advanced once a frame, right after the sync, so the stills count their frames by the steps of one
        counter = read("FrameCounter.qml")
        self.assertRegex(counter, r"(?m)^NumberAnimation \{$")
        for line in ("target: counter", 'property: "at"', "from: 0", "to: 1", "property int frames: 1",
                     "signal counted"):
            self.assertIn(line, counter)
        self.assertIn("frames = n\n        restart()", function(counter, "count"))
        steps = counter[counter.index("onAtChanged: {"):]
        # a start's own step back to 0 is no frame; the last frame stops it before it says so, and so does its end
        self.assertIn("if (!running || at <= 0)\n            return", steps)
        self.assertIn("if (frames > 1 && at < 1) {\n            frames -= 1\n            return\n        }", steps)
        self.assertLess(steps.index("stop()"), steps.index("counted()"))
        for word in ("loops", "Animation.Infinite", "running: true"):
            self.assertNotIn(word, counter, word)
        self.assertEqual(qml_blocks(counter, "Timer"), [])
        # the stills' three waits count with it: the settle, Frost's show and the queue's gap; nothing on the pages
        # counts frames with a Timer
        self.assertEqual(len(qml_blocks(read("FrozenFrame.qml"), "FrameCounter")), 2)
        self.assertEqual(len(qml_blocks(read("FreezeQueue.qml"), "FrameCounter")), 1)
        for name in SHEET + VIEWER + ["AnimationFeel.qml"]:
            for timer in qml_blocks(read(name), "Timer"):
                self.assertNotRegex(timer, r"\binterval: 1\n", name)

    def test_nothing_moves_at_rest(self):
        # once the stills are made nothing on the page draws: no animation, no busy indicator, no Timer that repeats.
        # A kept picture fades in once, when it has loaded
        for name in SHEET + ["AnimationFeel.qml"]:
            text = read(name)
            if name == "AnimationSheetPicture.qml":
                self.assertEqual(text.count("Animator"), 1)
                fade = by_id(text, "FadeAnimator", "fade")
                self.assertIn("duration: 150", fade)
                self.assertNotIn("loops", fade)
                text = text.replace("FadeAnimator", "")
            if name == "FrameCounter.qml":
                # it runs only while a still counts its frames, and stops itself at the last
                self.assertEqual(text.count("NumberAnimation"), 1)
                self.assertIn("stop()\n        counted()", text)
                text = text.replace("NumberAnimation", "")
            for word in ("NumberAnimation", "Animator", "Behavior", "BusyIndicator", "repeat: true", "Animation.Infinite",
                         "live: true"):
                self.assertNotIn(word, text, f"{name}: {word}")

    def test_the_page_starts_once(self):
        # everything the page makes hangs on one latch, after the push, and never on its status itself. OpenGLInfo is
        # read on an Item: in a Timer, it crashes Qt 5.6
        page = read("AnimationsPage.qml")
        for name in ("AnimationsPage.qml", "AnimationViewerPage.qml"):
            text = read(name)
            # a Silica Page has no pageStack property (Sailfish OS 5.0 and 5.1): one in a stack has its pageContainer
            self.assertIn("readonly property bool live: !page.pageContainer || (status === PageStatus.Active "
                          "&& Qt.application.active)", text, name)
            self.assertNotIn("page.pageStack", text, name)
            # PageStatus.Active only in live
            self.assertEqual(text.count("PageStatus.Active"), 1, name)
            self.assertRegex(text, r"(?m)^    readonly property bool live: .*status === PageStatus\.Active", name)
            self.assertIn("readonly property int glMajor: OpenGLInfo.majorVersion", text, name)
            timers = qml_blocks(text, "Timer")
            self.assertIn("running: page.live && !page.started && page.glMajor > 0", timers[0], name)
            self.assertIn("onTriggered: page.started = true", timers[0], name)
            for timer in timers:
                self.assertNotIn("OpenGLInfo", timer, name)
        for name in ("building", "feel", "sheetPicture"):
            loader = by_id(page, "Loader", name)
            self.assertIn("active: page.started", loader)
            self.assertIn("asynchronous: true", loader)
        viewer = read("AnimationViewerPage.qml")
        for name in ("kitLoader", "stageLoader", "controls"):
            loader = by_id(viewer, "Loader", name)
            self.assertIn("active: page.started", loader, name)
            self.assertIn("asynchronous: true", loader, name)

    def test_a_tap_opens_the_viewer(self):
        # a frame plays its moment, a name its round, a head its tour; the viewer's page is compiled at rest first
        page = read("AnimationsPage.qml")
        self.assertIn('Qt.resolvedUrl("AnimationViewerPage.qml")', page)
        for mode in ('"one"', '"round"', '"tour"'):
            self.assertIn(mode + ")", page)
        self.assertIn("Component.Asynchronous", page)
        self.assertIn('"ambienceFile": page.ambienceFile', page)

    def test_an_opening_still_knows_the_corners_it_opens_from(self):
        # like the home screen's opening (test_animation_driving.py): the round icon, or the cover
        frame = read("FrozenFrame.qml")
        self.assertIn('radiusPx: frame.moment === "open" ? frame.kit.iconRadius', frame)
        self.assertIn("readonly property real iconRadius: Theme.iconSizeLauncher * k / 2", read("PreviewKit.qml"))
        self.assertIn("readonly property real coverRadius: Theme.paddingMedium * k", read("PreviewKit.qml"))

    def test_the_page_works_without_its_picture(self):
        # the picture of the frames is one file and one Loader, which can go without touching the rest: the frames
        # are the sheet then. So the rest of the page names neither, and reads only the plain properties the picture
        # sets, whose defaults are those of a page with no picture
        page = read("AnimationsPage.qml")
        loader = by_id(page, "Loader", "sheetPicture")
        self.assertIn('setSource(Qt.resolvedUrl("AnimationSheetPicture.qml"), {', loader)
        # the Loader with the comment above it
        comment = re.search(r"(?m)((?:^[ \t]*//.*\n)*)%s" % re.escape(loader), page).group(1)
        self.assertIn("AnimationSheetPicture.qml", comment)
        rest = page.replace(comment + loader, "")
        self.assertNotIn("AnimationSheetPicture", rest)
        self.assertNotRegex(rest, r"\b(sheetPicture|keptSheet)\b")
        for line in ("    property bool flatten: true\n", "    property bool framesHeld\n",
                     "    property bool pictured\n", "    property bool pictureLoading\n"):
            self.assertIn(line, rest)
        for name in ("framesHeld", "pictured", "pictureLoading"):
            self.assertNotRegex(rest, r"\b%s\s*=[^=]" % name, name)
            self.assertIn(f'property: "{name}"', loader)
        self.assertIn("active: page.started && !page.framesHeld", by_id(page, "Loader", "building"))
        self.assertIn("readonly property bool built: building.item !== null && building.item.built || pictured", rest)
        # nothing else of the app needs it either
        for path in sorted((REPO / "qml").rglob("*")):
            if path.suffix in (".qml", ".js") and path.name not in ("AnimationsPage.qml", "AnimationSheetPicture.qml"):
                self.assertNotIn("AnimationSheetPicture", path.read_text(encoding="utf-8"), path.name)

    def test_the_picture_is_kept_by_its_key(self):
        # under the frames, so that a new build covers the old picture cell by cell; two files at most, the colours in
        # their name, and a key that changes with whatever the frames are made for
        page = read("AnimationsPage.qml")
        loader = by_id(page, "Loader", "sheetPicture")
        self.assertLess(page.index(loader), page.index("id: grid"))
        self.assertIn("readonly property bool wanted: page.keepSheet || page.flatten", loader)
        self.assertIn("active: page.started && wanted", loader)
        self.assertIn('return page.sheetFolder + "/seaglass-animations-"\n'
                      '                                    + (settings.ambience ? "tinted" : "natural")', loader)
        for line in ('"frames": grid', '"key": Qt.binding(function () { return page.sheetKey })',
                     '"keep": Qt.binding(function () { return page.keepSheet })',
                     '"flatten": Qt.binding(function () { return page.flatten })',
                     '"built": Qt.binding(function () { return building.item !== null && building.item.built })',
                     '"still": Qt.binding(function () { return page.live && !flick.moving && !page.navigating })'):
            self.assertIn(line, loader)
        self.assertIn('"key": Qt.binding(function () { return page.sheetKey })', by_id(page, "Loader", "building"))
        key = page[page.index("readonly property string sheetKey"):]
        key = key[:key.index("\n    //")]
        # the cells' size and the gaps shape the picture too, and are set in the page, outside Stills.KEY's files
        for part in ("Stills.KEY", "tint.x.toFixed(3)", "tint.z.toFixed(3)", "cellWidth", "cellHeight", "+ gap +",
                     "es3", "Theme.colorScheme", "settings.ambience"):
            self.assertIn(part, key)
        picture = read("AnimationSheetPicture.qml")
        # a kept file is used only with a KEY, which ties it to the files it was made from
        self.assertIn('readonly property bool keeps: keep && Stills.KEY !== ""', picture)
        # the key is read with GET and written with PUT, as AboutPage.qml writes its backup; the old key goes before
        # the picture is written, the new one after it. A local PUT lands on a later turn and says nothing when it
        # fails (Qt 5.6), so each step waits for the last write to be read back, and a write that is not stops there
        self.assertIn('request.open("GET", "file://" + name + ".key")', picture)
        self.assertIn('request.open("PUT", "file://" + file, false)', picture)
        save = picture[picture.index("function save("):picture.index("function write(")]
        order = [save.index(step) for step in ('write(name + ".key", "", function () {',
                                               'picture.result.saveToFile(name + ".jpg")',
                                               'write(name + ".key", forKey, function () { picture.saved = forKey })')]
        self.assertEqual(order, sorted(order))
        landed = picture[picture.index("function landed("):picture.index("onKeyChanged")]
        self.assertIn("if (request.responseText === step.text) {", landed)
        self.assertLess(landed.index("writing = null"), landed.index("step.then()"))
        self.assertIn("interval: 20", by_id(picture, "Timer", "landing"))
        # the grab is kept while its picture shows, which it does from Qt's picture cache; the file never comes from
        # the cache, and an empty source between two makes the same file load again
        self.assertIn("picture.result = result", picture)
        show = picture[picture.index("function show("):picture.index("function loaded(")]
        order = [show.index(line) for line in ('image.source = ""', "image.cache = !file", "image.source = source")]
        self.assertEqual(order, sorted(order))
        image = by_id(picture, "Image", "image")
        for line in ("asynchronous: true", "cache: false", "opacity: 0"):
            self.assertIn(line, image)
        self.assertNotIn("sourceSize", image)
        # a grab only of the frames made for the present key, and a grab or a save only at rest
        grab = picture[picture.index("function grab("):picture.index("function show(")]
        self.assertIn("if (forKey !== picture.key)\n                return", grab)
        timers = qml_blocks(picture, "Timer")
        self.assertIn("running: picture.flatten && picture.built && picture.still", timers[-2])
        self.assertIn("onTriggered: picture.grab()", timers[-2])
        self.assertIn("picture.still", timers[-1])
        self.assertIn("onTriggered: picture.save()", timers[-1])
        self.assertIn("frames.grabToImage(", picture)
        # no frames are wanted while the kept key is read or its picture loads, and once a picture shows
        self.assertIn("readonly property bool holds: key !== \"\" && (checking === key || loading === key && fromFile "
                      "|| shown === key)", picture)

    def test_a_push_compiles_only_what_it_draws(self):
        # Qt 5.6 compiles every type a file names, a Component written out in a Loader included, and keeps no compiled
        # QML on disk: the page names only what its push draws. The picture, Feel and the builder are files their
        # Loaders name by URL, compiled when a Loader first becomes active
        page = read("AnimationsPage.qml")
        named = set(re.findall(r"(?m)^\s*([A-Z]\w*) \{", page))
        self.assertLessEqual(named, {"Page", "ConfigurationValue", "AnimationSettings", "Timer", "Loader", "Binding",
                                     "SilicaFlickable", "VerticalScrollDecorator", "Column", "PageHeader", "TextSwitch",
                                     "Item", "Row", "Repeater", "BackgroundItem", "Label", "Rectangle",
                                     "SilicaControl", "MouseArea"})
        self.assertNotIn("sourceComponent", page)
        self.assertNotIn("Component {", page)
        # each sets its source and properties when it becomes active, and empties it when it goes: a Loader that goes
        # while its file still compiles makes the item all the same once it has compiled (Qt 5.6, 5.0 and 5.1 images)
        for loader, name in (("building", "AnimationSheetBuilder.qml"), ("sheetPicture", "AnimationSheetPicture.qml"),
                             ("feel", "AnimationFeel.qml")):
            self.assertTrue((SETTINGS / name).is_file(), name)
            block = by_id(page, "Loader", loader)
            self.assertIn("asynchronous: true", block, loader)
            self.assertRegex(block, r'onActiveChanged: \{\s*if \(!active\) \{\s*source = ""\s*return\s*\}\s*'
                                    r'setSource\(Qt\.resolvedUrl\("%s"\), \{' % re.escape(name), loader)
            self.assertEqual(block.count("setSource("), 1, loader)
        self.assertEqual(page.count("setSource("), 3)
        # the builder's properties come with its source, so they are set before anything in it is made: its kit is
        # made at the cell's size
        building = by_id(page, "Loader", "building")
        self.assertIn('"cells": grid', building)
        for name in ("cellWidth", "cellHeight", "gap", "tint", "useTint"):
            self.assertIn(f'"{name}": Qt.binding(function () {{ return page.{name} }})', building)
        # one file compiles at a time, never while another's item is being made: while a file compiles on the loader
        # thread, whatever the GUI thread makes waits for it (Qt 5.6, 5.0 and 5.1 images). The picture first, then
        # Feel, then the builder
        self.assertIn("active: page.started && !page.pictureLoading", by_id(page, "Loader", "feel"))
        self.assertIn("active: page.started && !page.framesHeld && (feel.status === Loader.Ready "
                      "|| feel.status === Loader.Error)", building)
        # no frame is wanted from before the page starts until the picture is made and has read its kept key; one that
        # fails to load wants them, and Feel does not wait for it
        picture = by_id(page, "Loader", "sheetPicture")
        self.assertIn("value: sheetPicture.wanted && sheetPicture.status !== Loader.Error\n"
                      "                           && (sheetPicture.item === null || sheetPicture.item.holds)", picture)
        self.assertIn("value: sheetPicture.item !== null && sheetPicture.item.shows", picture)
        self.assertIn("value: sheetPicture.wanted && sheetPicture.status !== Loader.Ready\n"
                      "                           && sheetPicture.status !== Loader.Error", picture)
        # holds never reads false while a picture becomes the one shown: the page would start a build for that moment
        loaded = function(read("AnimationSheetPicture.qml"), "loaded")
        ready = loaded[loaded.index("if (image.status === Image.Ready) {"):loaded.index("} else {")]
        self.assertLess(ready.index("shown = forKey"), ready.index('loading = ""'))
        self.assertNotIn('loading = ""', loaded[:loaded.index("if (image.status === Image.Ready) {")])
        # Feel takes the page's settings, makes none of its own, and binds the speed again when the page is back on
        # top; only the page names it
        feel = read("AnimationFeel.qml")
        self.assertIn('"settings": settings', by_id(page, "Loader", "feel"))
        self.assertIn('"live": Qt.binding(function () { return page.live })', by_id(page, "Loader", "feel"))
        self.assertIn("property QtObject settings\n", feel)
        self.assertNotIn("AnimationSettings {", feel)
        self.assertIn("onLiveChanged: {\n        if (live)\n"
                      "            speedBox.currentIndex = Qt.binding(function () { return feel.settings.speed })", feel)
        self.assertIn("currentIndex: feel.settings.speed", by_id(feel, "ComboBox", "speedBox"))
        # made on its own, as a check that creates every file does, it has no settings, and its switches read off
        # rather than log a TypeError each
        checked = re.findall(r"(?m)^\s*checked: (.*)$", feel)
        self.assertEqual(checked, ["feel.settings !== null && feel.settings.%s" % name
                                   for name in ("surprise", "ambience", "covers")])
        for path in sorted((REPO / "qml").rglob("*")):
            if path.suffix in (".qml", ".js") and path.name not in ("AnimationsPage.qml", "AnimationFeel.qml"):
                self.assertNotIn("AnimationFeel", path.read_text(encoding="utf-8"), path.name)

    def test_the_first_page_compiles_the_sheet_before_a_tap(self):
        # the settings' first page compiles the Animations page on the loader thread a second after it is made, and
        # holds it: a push by its URL finds it compiled, and one during the compile waits only for the rest of it
        # (Qt 5.6, 5.0 and 5.1 images). Nothing else is compiled ahead, and the page is pushed as the others are
        hub = read("SettingsHub.qml")
        self.assertEqual(hub.count("property var animationsPage: null"), 1)
        timers = [block for block in qml_blocks(hub, "Timer") if "animationsPage" in block]
        self.assertEqual(len(timers), 1)
        for line in ("interval: 1000", "running: hub.animationsPage === null",
                     'onTriggered: hub.animationsPage = Qt.createComponent(Qt.resolvedUrl("AnimationsPage.qml"),\n'
                     "                                                             Component.Asynchronous)"):
            self.assertIn(line, timers[0])
        self.assertEqual(hub.count("Qt.createComponent("), 1)
        self.assertIn('onClicked: hub.open("AnimationsPage")', hub)
        self.assertIn('pageStack.push(Qt.resolvedUrl(name + ".qml"), properties || {})', function(hub, "open"))

    def test_use_for_all_three(self):
        # Use is the viewer's write: a style for every moment, or for the moment shown. Use for all three clears
        # Surprise me for any row, Stock too, since Surprise me would go on playing other styles behind a Stock row; it
        # turns the animations on only for a style. Stock is written to each moment, so that a later Surprise me still
        # leaves them alone: it reads the moment's own key. Use for one moment leaves the other moments as they are
        viewer = read("AnimationViewerPage.qml")
        self.assertIn('qsTr("Use for all three")', viewer)
        self.assertIn("SecondaryButton {", viewer)
        use_all = function(viewer, "useAll")
        use_for = function(viewer, "useFor")
        self.assertEqual(use_all, """function useAll(id) {
        var each = id === "stock" ? "stock" : ""
        settings.style = id; settings.open = each; settings.loading = each; settings.close = each
        settings.surprise = false
        if (id !== "stock")
            settings.enabled = true
    }""")
        self.assertEqual(use_for, """function useFor(key, id) {
        settings[key] = id
        if (id !== "stock") {
            settings.enabled = true
            settings.surprise = false
        }
    }""")
        # settings.enabled is written by the sheet's switch, and by Use
        page = read("AnimationsPage.qml")
        self.assertEqual(page.count("settings.enabled = "), 1)
        self.assertIn("onClicked: settings.enabled = !settings.enabled", page)
        self.assertEqual(viewer.count("settings.enabled = "), 2)
        self.assertEqual(use_all.count("settings.enabled = "), 1)
        self.assertEqual(use_for.count("settings.enabled = "), 1)
        self.assertNotRegex(use_for, r"settings\.(open|loading|close|style) = ")
        self.assertIn("onClicked: page.useAll(page.style)", viewer)
        self.assertIn("onClicked: page.useFor(page.momentKey, page.style)", viewer)
        # what Surprise me leaves alone is a moment whose own key says Stock, at home and on the sheet
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        self.assertIn('settings[moment] !== "stock"', function(styles, "choose"))
        self.assertIn('settings[key] !== "stock"', function(read("stills.js"), "inUse"))
        # a button that would change nothing reads In use and is off
        for name in ("usedForMoment", "usedForAll"):
            self.assertIn(f'text: page.{name} ? qsTr("In use")', viewer, name)
            self.assertIn(f"enabled: !page.{name}", viewer, name)

    def test_the_viewer_shows_one_moment_at_a_time(self):
        # a full screen page of the styles' stills side by side, one FrozenFrame each, made only for what is on screen;
        # the live scene over the one shown, under the caption and the controls. It reads no wallpaper key: its kits
        # take the picture the sheet hands it
        viewer = read("AnimationViewerPage.qml")
        self.assertRegex(viewer, r"(?m)^FullscreenContentPage \{$")
        self.assertIn("allowedOrientations: Orientation.All", viewer)
        for name in ("style", "moment", "mode"):
            self.assertRegex(viewer, r'(?m)^    property string %s: "\w+"$' % name, name)
        self.assertIn("property string ambienceFile\n", viewer)
        shots = by_id(viewer, "SlideshowView", "shots")
        self.assertIn("model: Stills.ORDER", shots)
        self.assertIn("itemWidth: page.stageWidth + Theme.paddingLarge", shots)
        self.assertEqual(len(qml_blocks(shots, "FrozenFrame")), 1)
        self.assertIn("opacity: shot.isCurrent ? 1 : 0.5", shots)
        self.assertIn("Math.max(Screen.topCutout.height, Theme.paddingLarge)", viewer)
        self.assertIn("Math.round(width * 0.68)", viewer)
        # no effect of its own: the stills and the stage draw them
        for kind in ("Effect {", "Shards {", "ShaderEffect {", "Shaders."):
            self.assertNotIn(kind, viewer)
        kits = qml_blocks(viewer, "PreviewKit")
        self.assertEqual(len(kits), 2)
        for kit in kits:
            self.assertIn("picture: page.ambienceFile", kit)
        self.assertIn("side: page.stageWidth", kits[0])
        self.assertIn("side: page.stripWidth", kits[1])
        self.assertIn("active: page.stripWanted", by_id(viewer, "Loader", "stripKitLoader"))
        # a strip kit whose pictures are cached is ready before its Loader hands it out: the strip is queued then
        self.assertIn("onLoaded: page.queueStrip()", by_id(viewer, "Loader", "stripKitLoader"))
        # the order on the page: the stills, the stage, then the caption and the controls over them
        order = [viewer.index(text) for text in ("id: shots", "id: stageLoader", "id: caption", "id: controls")]
        self.assertEqual(order, sorted(order))
        # one still at a time, never while anything moves
        self.assertIn("paused: !page.still", by_id(viewer, "FreezeQueue", "queue"))
        for moving in ("shots.dragging", "shots.flicking", "shots.moving", "strip.held", "stage.moving",
                       "!navigating"):
            self.assertIn(moving, viewer[viewer.index("readonly property bool still:"):], moving)
        # a swipe plays only once it has come to rest for 300 ms
        self.assertIn("interval: 300", by_id(viewer, "Timer", "landing"))
        self.assertIn("onDraggingChanged", shots)

    def test_the_stage_is_one_value(self):
        # the live scene is driven from the GUI thread by one animation on p, so that a pause, a scrub and Slow are one
        # value; the effect draws at its rung and is scaled up, reading the app grabbed at that size
        stage = read("AnimationStage.qml")
        animations = re.findall(r"(?m)^\s*(\w*Animat\w*) \{", stage)
        self.assertEqual(sorted(animations), ["FadeAnimator", "NumberAnimation"])
        run = by_id(stage, "NumberAnimation", "run")
        for line in ('target: stage', 'property: "p"', "from: 0", "to: 1"):
            self.assertIn(line, run)
        self.assertIn("run.duration = length * (slow ? 4 : 1)", stage)
        for driven in (".play(", ".runClock(", "UniformAnimator"):
            self.assertNotIn(driven, stage)
        self.assertIn("progress: stage.playingMoment === \"load\" ? 0 : stage.p", stage)
        self.assertIn("time: stage.seconds", stage)
        self.assertIn("Styles.duration(playingStyle, playingMoment, 1)", stage)
        scaled = by_id(stage, "Item", "scaled")
        for line in ("scale: 1 / k", "transformOrigin: Item.TopLeft", "layer.enabled: k < 1", "layer.smooth: true",
                     "width: stage.width * k", "height: stage.height * k"):
            self.assertIn(line, scaled)
        self.assertIn("* scaled.k", by_id(stage, "Effect", "effect"))
        self.assertIn("readonly property Item app: !kit ? null : kit.runApp ? kit.runApp : kit.app", stage)
        # the viewer grabs the app at the run's size first, with mipmaps only for a style that blurs
        viewer = read("AnimationViewerPage.qml")
        turn = function(viewer, "appTurn")
        self.assertIn('var mip = page.kit.es3 && Styles.has(page.style, "blur")', turn)
        self.assertIn("page.kit.runScale = page.runRung", turn)
        self.assertIn('page.stage.warmer.program = "app"', turn)
        # stills of Shatter break as the stage's
        self.assertIn("seed: Qt.vector4d(Stills.SEED[0], Stills.SEED[1], Stills.SEED[2], Stills.SEED[3])",
                      qml_blocks(stage, "Shards")[0])

    def test_a_run_that_stutters_steps_down(self):
        # more than 10 percent of a run's frames over 20 ms: the next run of that style and moment draws at the next
        # lower rung, for the life of the page, never stored
        viewer = read("AnimationViewerPage.qml")
        judge = function(viewer, "judge")
        self.assertIn("if (frames[i] > 20)", judge)
        self.assertIn("if (late <= 0.1 * frames.length)", judge)
        self.assertIn("Stills.RUNGS", judge)
        self.assertNotIn("settings.", judge)
        self.assertIn("onRan: page.judge(ranStyle, ranMoment, frames)", viewer)
        stage = read("AnimationStage.qml")
        self.assertIn("stamps.push(Date.now())", stage)
        self.assertIn("if (run.running)", stage[stage.index("onPChanged"):])

    def test_the_strip_scrubs(self):
        # seven stills of the moment, a press jumps and a drag scrubs; once the finger has gone sideways the page's
        # own swipe cannot take it, and the large still is made again where it lifts
        strip = read("AnimationStrip.qml")
        self.assertIn("readonly property var points: [0.05, 0.15, 0.28, 0.42, 0.58, 0.75, 0.92]", strip)
        self.assertEqual(len(qml_blocks(strip, "FrozenFrame")), 1)
        touch = by_id(strip, "MouseArea", "touch")
        self.assertIn("Math.abs(mouse.x - pressX) > Theme.startDragDistance", touch)
        self.assertIn("preventStealing = true", touch)
        viewer = read("AnimationViewerPage.qml")
        lift = function(viewer, "lift")
        self.assertIn("queue.add(stillTurn(shotOf(style)))", lift)
        self.assertIn("page.stage.settle()", lift)
        # it can be pressed once every still is made, as the cells count them: in the viewer's asynchronous Loader the
        # Repeater's cells come after its count, and a binding over itemAt() that ran before them never runs again
        self.assertIn("readonly property bool ready: madeCount === points.length\n", strip)
        self.assertNotIn("itemAt(i)", strip)
        self.assertIn("onMadeChanged: strip.madeCount += made ? 1 : -1", strip)
        self.assertIn("if (made)\n                    strip.madeCount--", strip)
        self.assertIn("enabled: strip.ready", touch)

    def test_the_about_line_holds_two_lines(self):
        # two lines high whatever it says, so that a swipe never moves the stage; its lines stand the font's lineSpacing
        # apart, so that a second line fits in that height: Text's own line leaves out the leading, which is negative
        # in Sail Sans Pro, and two of those do not fit in 2 * lineSpacing. The metrics read the label's own font
        caption = by_id(read("AnimationViewerPage.qml"), "Column", "caption")
        about = by_id(caption, "Label", "aboutLabel")
        for line in ("height: Math.ceil(2 * aboutMetrics.lineSpacing)", "maximumLineCount: 2",
                     "lineHeightMode: Text.FixedHeight", "lineHeight: aboutMetrics.lineSpacing"):
            self.assertIn(line, about)
        self.assertIn("font: aboutLabel.font", by_id(about, "FontMetrics", "aboutMetrics"))

    def test_the_viewer_never_moves_at_rest(self):
        # nothing repeats, and nothing runs but a run
        for name in VIEWER:
            text = read(name)
            for word in ("Behavior", "BusyIndicator", "repeat: true", "Animation.Infinite", "loops:", "live: true"):
                self.assertNotIn(word, text, f"{name}: {word}")
        for name in ("AnimationViewerPage.qml", "AnimationStrip.qml"):
            self.assertNotRegex(read(name), r"(Animation|Animator) \{", name)

    def test_a_touch_ends_the_tour(self):
        # on the style it is at; one between two runs leaves the neighbours and the strip to make, as the end of a
        # whole run does, since the run that ended went the tour's way
        viewer = read("AnimationViewerPage.qml")
        after = function(viewer, "afterRun")
        self.assertIn("tourGap.restart()\n                return", after)
        self.assertTrue(after.rstrip("}").rstrip().endswith("queueRest()"))
        rest = function(viewer, "queueRest")
        order = [rest.index(step) for step in ("queue.add(appTurn())", "(at + count - 1) % count", "(at + 1) % count",
                                               "page.stripWanted = true", "page.queueStrip()")]
        self.assertEqual(order, sorted(order))
        touch = [block for block in qml_blocks(viewer, "MouseArea") if "enabled: page.touring" in block]
        self.assertEqual(len(touch), 1)
        steps = [touch[0].index(step) for step in ("var between = tourGap.running", "page.touring = false",
                                                   "tourGap.stop()", "if (between)\n                page.queueRest()",
                                                   "mouse.accepted = false")]
        self.assertEqual(steps, sorted(steps))

    def test_the_pinned_row_and_the_marks(self):
        # the pinned heads keep clear of the top cutout in portrait, as a page header does; the marks stand out on the
        # frames, which are light on dark in any ambience, so they take a light-on-dark palette's highlight too
        page = read("AnimationsPage.qml")
        pinned = by_id(page, "Item", "pinned")
        self.assertIn("readonly property real inset: page.orientation === Orientation.Portrait "
                      "? Screen.topCutout.height : 0", pinned)
        self.assertIn("height: inset + Theme.itemSizeExtraSmall", pinned)
        self.assertIn("visible: flick.contentY > sheet.y + heads.height - height", pinned)
        self.assertIn("y: pinned.inset", pinned)
        marks = by_id(page, "SilicaControl", "marks")
        self.assertIn("palette.colorScheme: Theme.LightOnDark", marks)
        self.assertIn("border.color: marks.palette.highlightColor", marks)
        self.assertNotIn("page.palette", marks)
        # the public shot of the sheet waits for it to be made
        shots = (REPO / "scripts" / "screenshots.sh").read_text(encoding="utf-8")
        self.assertIn('"settings-animations|settings Animations|14|9"', shots)


if __name__ == "__main__":
    unittest.main()
