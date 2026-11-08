"""Consistency of the repository: the Patchmanager metadata, the package spec, the paths the hook and the QML
agree on, and ES5-only JavaScript in the QML (the phone runs Qt 5.6)."""
import json
import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "hook"))
import apply_hook  # noqa: E402

QML = sorted([*REPO.glob("qml/**/*.qml"), *REPO.glob("harness/*.qml"), *REPO.glob("patchmanager/*.qml")])
JS = sorted(REPO.glob("qml/**/*.js"))

# Syntax Qt 5.6's JavaScript (ES5) refuses: arrow functions, let/const, template strings, optional chaining
ES6 = [
    (re.compile(r"=>"), "arrow function"),
    (re.compile(r"(^|[\s;(])(let|const)\s"), "let/const"),
    (re.compile(r"`"), "template string"),
    (re.compile(r"\?\.|\?\?"), "optional chaining / nullish"),
]


def code_lines(path):
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = re.sub(r'"(\\.|[^"\\])*"', '""', line)  # string contents
        line = line.split("//", 1)[0]
        yield number, line


def qml_blocks(text, kind):
    """the blocks of a QML type in a file, from "Kind {" to its closing brace"""
    blocks = []
    for match in re.finditer(r"(?m)^[ \t]*%s \{" % kind, text):
        depth = 0
        for end in range(match.end() - 1, len(text)):
            depth += {"{": 1, "}": -1}.get(text[end], 0)
            if depth == 0:
                blocks.append(text[match.start():end + 1])
                break
    return blocks


class RepoTest(unittest.TestCase):
    def test_patch_json(self):
        meta = json.loads((REPO / "patchmanager" / "patch.json").read_text(encoding="utf-8"))
        self.assertEqual(meta["name"], "seaglass")
        self.assertEqual(meta["category"], "homescreen")
        self.assertEqual(meta["version"], (REPO / "VERSION").read_text().strip())
        self.assertTrue(meta["compatible"], "no compatible Sailfish OS version (make hook)")
        for version in meta["compatible"]:
            self.assertRegex(version, r"^\d+\.\d+\.\d+\.\d+$")

    def test_settings_page_is_installed_with_the_patch(self):
        build = (REPO / "rpm" / "build.sh").read_text(encoding="utf-8")
        self.assertIn("/usr/share/patchmanager/patches/seaglass/main.qml", build)
        page = (REPO / "patchmanager" / "main.qml").read_text(encoding="utf-8")
        self.assertIn('import "file:///usr/share/seaglass/qml/settings/"', page)
        self.assertIn("SettingsHub {", page)
        self.assertIn("inHarness: false", page)
        # the pages the first page opens (by name, next to SettingsHub.qml)
        hub = (REPO / "qml" / "settings" / "SettingsHub.qml").read_text(encoding="utf-8")
        for name in re.findall(r'hub\.open\("(\w+)"', hub):
            self.assertTrue((REPO / "qml" / "settings" / (name + ".qml")).is_file(), name)

    def test_spec_installs_the_patch_under_its_name(self):
        spec = (REPO / "rpm" / "seaglass.spec").read_text(encoding="utf-8")
        self.assertRegex(spec, r"(?m)^Name:\s+seaglass$")
        self.assertIn("%define pm_patches /usr/share/patchmanager/patches", spec)
        self.assertIn("%define patch_dir %{pm_patches}/%{name}", spec)
        self.assertIn("unapplyPatch string:%{name}", spec)
        self.assertRegex(spec, r"(?m)^License:\s+GPL-3.0-or-later$")
        self.assertTrue((REPO / "LICENSE").is_file())

    def test_changelogs_name_this_version(self):
        version = (REPO / "VERSION").read_text().strip()
        spec = (REPO / "rpm" / "seaglass.spec").read_text(encoding="utf-8")
        changelog = spec[spec.index("%changelog"):]
        self.assertRegex(changelog.splitlines()[1], r"^\* \w{3} \w{3} \d{2} \d{4} .+ - %s-1$" % re.escape(version))
        self.assertIn("## %s (" % version, (REPO / "CHANGELOG.md").read_text(encoding="utf-8"))

    def test_patch_icons_are_installed(self):
        # Patchmanager's list shows main.svg, and main-light.svg under a light ambience (PatchManager::iconForPatch)
        build = (REPO / "rpm" / "build.sh").read_text(encoding="utf-8")
        for name, colour in (("main.svg", "#ffffff"), ("main-light.svg", "#000000")):
            svg = (REPO / "patchmanager" / name).read_text(encoding="utf-8")
            self.assertIn('viewBox="0 0 64 64"', svg)
            self.assertEqual(set(re.findall(r'(?:fill|stroke)="(#\w+)"', svg)), {colour}, name)
            self.assertIn(f'"$SRC/patchmanager/{name}"', build)
        self.assertTrue((REPO / "icons" / "seaglass.svg").is_file())

    def test_public_launcher_holds_only_stock_apps(self):
        # the public screenshots never show the phone's own apps: only desktop files of Jolla's packages
        script = (REPO / "harness" / "public-launcher.sh").read_text(encoding="utf-8")
        apps = set()
        for line in re.findall(r'^\w+_APPS="([^"]*)"', script, re.M):
            apps.update(line.split())
        for line in re.findall(r"^\s*for app in ([\w -]+); do$", script, re.M):
            apps.update(word for word in line.split() if not word.startswith("$"))
        apps.update(re.findall(r"<Filename>([\w.-]+)\.desktop</Filename>", script))
        self.assertGreaterEqual(len(apps), 15)
        for app in sorted(apps):
            self.assertRegex(app, r"^(jolla|sailfish)-[a-z]+$|^voicecall-ui$|^store-client$")

    def test_readme_images_exist(self):
        readme = (REPO / "README.md").read_text(encoding="utf-8")
        images = re.findall(r'<img src="([^"]+)"', readme)
        self.assertTrue(images)
        for image in images:
            self.assertTrue((REPO / image).is_file(), image)

    def test_workflows_run_the_make_targets(self):
        # CI and the release run what a development machine runs (docs/DEVELOPMENT.md)
        ci = (REPO / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        for target in ("make test", "make lint", "make rpm", "make site"):
            self.assertIn(f"run: {target}", ci)
        for target in ('make check-hook VERSION="$SAILFISH_VERSION"', 'make qml-check TARGET="$SDK_TARGET"'):
            self.assertIn(f"run: {target}", ci)
        pages = (REPO / ".github" / "workflows" / "pages.yml").read_text(encoding="utf-8")
        self.assertIn("run: make site", pages)
        self.assertIn("path: out/site", pages)
        release = (REPO / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
        self.assertIn('tags: ["v[0-9]*"]', release)
        for step in ("run: make test", "run: make lint", 'run: scripts/release.sh "$RELEASE_TAG" --publish'):
            self.assertIn(step, release)

    def test_every_version_has_its_ci_and_its_readme_row(self):
        # each Sailfish OS version of patchmanager/versions: a leg of ci.yml's sailfish matrix (a check run named
        # "Sailfish OS VERSION"), and a row of the README's Compatibility table with that check run's badge; the
        # README's shield lists the release versions
        versions = {}
        for line in (REPO / "patchmanager" / "versions").read_text(encoding="utf-8").splitlines():
            words = line.split("#")[0].split()
            if words:
                versions[words[0]] = words[1]
        ci = (REPO / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("    name: Sailfish OS ${{ matrix.version }}\n", ci)
        legs = dict(re.findall(r'(?m)^ {10}- version: "([\d.]+)"\n(?: {12}sdk-target: "([\d.]+)"\n)?', ci))
        self.assertEqual(sorted(legs), sorted(versions))
        readme = (REPO / "README.md").read_text(encoding="utf-8")
        for version, channel in versions.items():
            # the older series have an SDK target, which compiles our QML
            self.assertEqual(legs[version] != "", not version.startswith("5.2."), version)
            row = re.search(r"(?m)^\| %s \| (release|testers') \|.*$" % re.escape(version), readme)
            self.assertTrue(row, f"README.md: no Compatibility row for {version}")
            self.assertEqual(row.group(1), "release" if channel == "release" else "testers'", version)
            self.assertIn("github/check-runs/Keelwing/seaglass/main?nameFilter=Sailfish%%20OS%%20%s&" % version,
                          row.group(0))
        meta = json.loads((REPO / "patchmanager" / "patch.json").read_text(encoding="utf-8"))
        shield = "%20%7C%20".join(meta["compatible"])
        self.assertIn(f"img.shields.io/badge/Sailfish%20OS-{shield}-", readme)

    def test_release_notes_come_from_the_changelog(self):
        # scripts/release.sh takes the version's section of CHANGELOG.md: it starts with "## VERSION (DATE)"
        version = (REPO / "VERSION").read_text().strip()
        changelog = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertRegex(changelog, r"(?m)^## %s \(\d{4}-\d{2}-\d{2}\)$" % re.escape(version))
        script = (REPO / "scripts" / "release.sh").read_text(encoding="utf-8")
        self.assertIn('awk -v head="## $version ("', script)

    def test_versions_and_their_hooks(self):
        # patchmanager/versions: every series has its diff, and patch.json lists exactly the release versions
        versions = {}
        for line in (REPO / "patchmanager" / "versions").read_text(encoding="utf-8").splitlines():
            words = line.split("#")[0].split()
            if words:
                self.assertEqual(len(words), 2, line)
                self.assertRegex(words[0], r"^\d+\.\d+\.\d+\.\d+$")
                self.assertIn(words[1], ("release", "preview"), line)
                versions[words[0]] = words[1]
        series = {".".join(v.split(".")[:2]) for v in versions}
        diffs = {p.stem for p in (REPO / "patchmanager" / "diffs").glob("*.patch")}
        self.assertEqual(series, diffs)
        meta = json.loads((REPO / "patchmanager" / "patch.json").read_text(encoding="utf-8"))
        release = sorted((v for v, c in versions.items() if c == "release"),
                         key=lambda v: [int(p) for p in v.split(".")], reverse=True)
        self.assertEqual(meta["compatible"], release)

    def test_post_picks_the_series_hook(self):
        spec = (REPO / "rpm" / "seaglass.spec").read_text(encoding="utf-8")
        self.assertIn("/etc/sailfish-release", spec)
        self.assertIn("%ghost %{patch_dir}/unified_diff.patch", spec)
        # and makes Patchmanager read the patch again, or a fresh install cannot be activated
        self.assertIn("mkdir %{pm_patches}/.%{name}-reload", spec)
        build = (REPO / "rpm" / "build.sh").read_text(encoding="utf-8")
        self.assertIn('"$SRC"/patchmanager/diffs/*.patch "$ROOT/usr/share/seaglass/diffs/"', build)

    def test_hook_loads_installed_files(self):
        prefix = "file:///usr/share/seaglass/"
        for url in apply_hook.URLS:
            self.assertTrue(url.startswith(prefix), url)
            self.assertTrue((REPO / url[len(prefix):]).is_file(), url)

    def test_es5_only(self):
        self.assertTrue(QML)
        for path in QML + JS:
            for number, line in code_lines(path):
                for pattern, what in ES6:
                    self.assertIsNone(pattern.search(line), f"{path.relative_to(REPO)}:{number}: {what}")

    def test_grid_never_scrolls_inside_the_pager(self):
        # with the footer (the widgets' rows) the grid's content is taller than the height Launcher.qml gives it:
        # the controller makes it as tall as its content, and puts it back to its top
        controller = (REPO / "qml" / "core" / "HomeController.qml").read_text(encoding="utf-8")
        self.assertIn('property: "height"\n        value: controller.stockHeight + controller.footerHeight', controller)
        self.assertIn("onContentYChanged: controller.pinGrid()", controller)
        self.assertIn("grid.contentY = grid.originY", controller)

    def test_glass_needs_no_lipstick(self):
        # the settings page (the Settings application) previews the glass with these files
        for name in ("glass/GlassSource.qml", "glass/GlassPane.qml", "glass/LauncherWallpaper.qml", "badges/Badge.qml"):
            text = (REPO / "qml" / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"(?m)^import (org\.nemomobile\.lipstick|Sailfish\.Lipstick)", name)
        self.assertIn('import "../glass"', (REPO / "qml" / "settings" / "GlassPage.qml").read_text(encoding="utf-8"))
        self.assertIn('import "../badges"', (REPO / "qml" / "settings" / "BadgesPage.qml").read_text(encoding="utf-8"))

    def test_harness_settings_copy_never_shows_the_phones_wallpaper(self):
        # scripts/harness.sh rewrites these lines of the previewing pages' copies: they must be there as written
        harness = (REPO / "scripts" / "harness.sh").read_text(encoding="utf-8")
        lines = {"GlassPage": ("property string ambienceFile: ambiencePicture.value",
                               "property bool persistentGlass: true"),
                 "AnimationsPage": ("property string ambienceFile: ambiencePicture.value",)}
        for name, rewritten in lines.items():
            page = (REPO / "qml" / "settings" / f"{name}.qml").read_text(encoding="utf-8")
            self.assertIn(f"~/$dir/qml/settings/{name}.qml", harness)
            for line in rewritten:
                self.assertIn(line, page)
                self.assertIn(f"s|{line}|", harness)

    def test_every_settings_group_is_reset_and_backed_up(self):
        # SettingsHub resets each group from a copy at /apps/seaglass/defaults/…, AboutPage saves and restores it
        hub = (REPO / "qml" / "settings" / "SettingsHub.qml").read_text(encoding="utf-8")
        about = (REPO / "qml" / "settings" / "AboutPage.qml").read_text(encoding="utf-8")
        pairs = re.search(r"var pairs = \[(.*?)\]\n", hub, re.S).group(1)
        groups = re.search(r"readonly property var groups: \(\{(.*?)\}\)", about, re.S).group(1)
        for path in sorted((REPO / "qml" / "settings").glob("*Settings.qml")):
            kind = path.stem
            live = re.search(r"^    %s \{ id: (\w+) \}$" % kind, hub, re.M)
            defaults = re.search(r"^    %s \{ id: (\w+); path: \"/apps/seaglass/defaults[\w/]*\" \}$" % kind, hub,
                                 re.M)
            self.assertTrue(live and defaults, f"SettingsHub.qml: {kind} and its defaults")
            self.assertIn(f"[{live.group(1)}, {defaults.group(1)}]", pairs, kind)
            kept = re.search(r"^    %s \{\s*id: (\w+)" % kind, about, re.M)
            self.assertTrue(kept, f"AboutPage.qml: {kind}")
            self.assertRegex(groups, r'"\w+": %s\b' % kept.group(1), kind)

    def test_animation_settings_keys(self):
        # every setting of the group is reset and backed up: the keys list is its properties
        text = (REPO / "qml" / "settings" / "AnimationSettings.qml").read_text(encoding="utf-8")
        keys = re.findall(r'"(\w+)"', re.search(r"keys: \[(.*?)\]", text, re.S).group(1))
        properties = re.findall(r"^    property \w+ (\w+)", text, re.M)
        self.assertEqual(keys, properties)
        self.assertEqual(keys, ["enabled", "style", "open", "loading", "close", "surprise", "speed", "ambience",
                                "covers"])

    def test_animations_page(self):
        # the page of docs/ANIMATIONS.md, its row on the first page (after the task switcher), and a preview drawn
        # by the home screen's own effect files, none of which may need Lipstick (the settings are not the compositor)
        page = (REPO / "qml" / "settings" / "AnimationsPage.qml").read_text(encoding="utf-8")
        for text in ("App animations", "Surprise me", "Same as style", "Opening", "Loading", "Closing", "Speed",
                     "Relaxed", "Normal", "Quick", "Ambience colours", "Covers too", '"Open"', '"Close"'):
            self.assertIn(f'qsTr("{text.strip(chr(34))}")', page, text)
        for setting in ("enabled", "style", "surprise", "speed", "ambience", "covers"):
            self.assertRegex(page, r"settings\.%s = " % setting, setting)
        self.assertIn("page.setMoment(momentBox.settingKey", page)
        self.assertIn('import "../animations"', page)
        for kind in ("Effect {", "Shards {", "NoiseTile {", "Styles.choose(settings"):
            self.assertIn(kind, page)
        self.assertNotIn("OpenGLInfo", page)
        hub = (REPO / "qml" / "settings" / "SettingsHub.qml").read_text(encoding="utf-8")
        order = [hub.index(f'hub.open("{name}")') for name in ("SwitcherPage", "AnimationsPage", "WidgetsPage")]
        self.assertEqual(order, sorted(order))
        for name in ("AnimationsPage.qml", "../animations/Effect.qml", "../animations/Shards.qml",
                     "../animations/NoiseTile.qml", "../animations/styles.js", "../animations/shaders.js"):
            text = (REPO / "qml" / "settings" / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"(?m)^import (org\.nemomobile\.lipstick|Sailfish\.Lipstick)", name)
            self.assertNotIn("Lipstick.", text, name)

    def test_support_links_agree(self):
        # one Ko-fi page for the developer's apps: GitHub's Sponsor button, the README, the site and the settings
        funding = (REPO / ".github" / "FUNDING.yml").read_text(encoding="utf-8")
        name = re.search(r"(?m)^ko_fi: (\w+)$", funding).group(1)
        url = f"https://ko-fi.com/{name}"
        readme = (REPO / "README.md").read_text(encoding="utf-8")
        self.assertIn(f"({url})", readme)
        self.assertIn(f'<a href="{url}"><img src="docs/images/support.svg"', readme)
        self.assertIn(f'SUPPORT = "{url}"', (REPO / "scripts" / "site.py").read_text(encoding="utf-8"))
        for template in ("index.html", "templates/nav.html", "templates/footer.html"):
            self.assertIn('href="{{support}}"', (REPO / "site" / template).read_text(encoding="utf-8"), template)
        for page in ("SettingsHub.qml", "AboutPage.qml"):
            text = (REPO / "qml" / "settings" / page).read_text(encoding="utf-8")
            self.assertIn(f'readonly property string support: "{url}"', text, page)
            self.assertRegex(text, r"Qt\.openUrlExternally\(\w+\.support\)", page)

    def test_badges_log_no_notification_texts(self):
        # the probe logs who a notification is from, never what it says
        source = (REPO / "qml" / "badges" / "BadgeSource.qml").read_text(encoding="utf-8")
        log = source[source.index('console.log("seaglass: notification"'):]
        log = log[:log.index("}))")]
        for text in ("summary", "body", "preview"):
            self.assertNotIn(text, log.lower())

    def test_journal_only_with_debug(self):
        # Lipstick's console goes to the system journal: our QML logs only through debugLog or under the Debug switch
        #, apart from the taps the harness logs (it has no LauncherActions)
        for path in sorted(REPO.glob("qml/**/*.qml")):
            lines = path.read_text(encoding="utf-8").splitlines()
            for i, line in enumerate(lines):
                if "console." not in line or line.strip().startswith("//"):
                    continue
                context = "\n".join(lines[max(0, i - 6):i + 1])
                self.assertTrue("function debugLog" in context
                                or re.search(r"if \((controller\.)?(debug|probe)\b", context)
                                or "actions.item" in context,
                                f"{path.relative_to(REPO)}:{i + 1}: a log line outside the Debug switch")

    def test_types_from_other_folders_are_imported(self):
        # qml/ has one folder per feature: a QML file sees the types of its own folder, and those of another folder
        # only through an import of it (a missing one leaves the stock home screen: the Loader fails on the phone)
        types = {path.stem: path.parent for path in REPO.glob("qml/**/*.qml")}
        files = {path.name: path for path in REPO.glob("qml/**/*") if path.is_file()}
        for path in sorted(REPO.glob("qml/**/*.qml")):
            text = path.read_text(encoding="utf-8")
            imported = {(path.parent / folder).resolve() for folder in re.findall(r'^import "([^"]*?)/?"$', text, re.M)
                        if not folder.endswith(".js")}
            code = "\n".join(line for _, line in code_lines(path))
            for name, folder in types.items():
                if folder != path.parent and re.search(r"(?<![\w.])%s\b" % name, code):
                    self.assertIn(folder.resolve(), imported, f"{path.relative_to(REPO)}: {name} needs an import")
            # JS libraries, Loader sources and other files of ours: a path that exists
            for target in re.findall(r'"((?:\.\./|\w+/)*\w+\.(?:qml|js))"', text):
                if Path(target).name in files:
                    self.assertTrue((path.parent / target).is_file(), f"{path.relative_to(REPO)}: {target}")

    def test_every_style_has_its_shaders(self):
        # a style's moment without its shader would stay stock without a word (docs/ANIMATIONS.md)
        shaders = REPO / "qml" / "animations" / "shaders"
        styles = (REPO / "qml" / "animations" / "styles.js").read_text(encoding="utf-8")
        found = re.findall(r'\{ "id": "(\w+)"(.*?)\}', styles, re.S)
        self.assertEqual(len(found), 9)
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

    def test_qtquick_import_fits_qt_56(self):
        for path in QML:
            for version in re.findall(r"^import QtQuick (\d+\.\d+)", path.read_text(encoding="utf-8"), re.M):
                self.assertLessEqual(float(version), 2.6, path.name)

    def test_no_property_hides_an_id_of_its_file(self):
        # in a delegate, a property of the delegate comes before an id of the file: a delegate property named "row"
        # turned the card row's row.contentX into undefined, and every card into NaN
        for path in sorted(REPO.glob("qml/**/*.qml")):
            text = path.read_text(encoding="utf-8")
            ids = set(re.findall(r"^\s*id:\s*(\w+)", text, re.M))
            properties = set(re.findall(r"^\s*(?:readonly\s+)?property\s+[\w<>.]+\s+(\w+)", text, re.M))
            self.assertEqual(sorted(ids & properties), [], path.relative_to(REPO))


if __name__ == "__main__":
    unittest.main()
