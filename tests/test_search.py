"""Tests of qml/search/search.js (finding apps by what is typed, suggestions, A–Z sections), run with Node
when it is installed. The file is ES5 for Qt 5.6; Node runs it after dropping the QML-only ".pragma library" line."""
import json
import shutil
import subprocess
import unittest
from pathlib import Path

SEARCH = Path(__file__).resolve().parents[1] / "qml" / "search" / "search.js"
NODE = shutil.which("node")

RUNNER = """
const fs = require("fs");
const source = fs.readFileSync(process.argv[1], "utf8").replace(".pragma library", "");
const s = {};
new Function("exports", source + "; exports.fold = fold; exports.words = words; exports.search = search;"
             + " exports.noteUse = noteUse; exports.suggestions = suggestions; exports.sections = sections;")(s);
const c = JSON.parse(process.argv[2]);
console.log(JSON.stringify(s[c.call].apply(null, c.args)));
"""

DAY = 24 * 3600 * 1000
NOW = 1_800_000_000_000


def call(name, *args):
    case = {"call": name, "args": list(args)}
    out = subprocess.run([NODE, "-e", RUNNER, str(SEARCH), json.dumps(case)], capture_output=True, text=True,
                         check=True)
    return json.loads(out.stdout)


def app(title, file="", folder=""):
    return {"key": "/usr/share/applications/%s.desktop" % (file or title.lower()), "title": title,
            "file": file or title.lower(), "folder": folder}


# made-up apps, and stock ones by their desktop files
APPS = [app("Holiday Album", "holiday-album"), app("House Sitter", "house-sitter"), app("Phone", "voicecall-ui"),
        app("Settings", "jolla-settings"), app("SkyPost", "skypost", "Media"), app("Météo", "sailfish-weather"),
        app("Chess960", "chess960"), app("Photos", "jolla-gallery"), app("Sync Settings", "sync-settings"),
        app("Messages", "jolla-messages"), app("Habit Notes", "habit-notes"), app("Medicine Box", "medicine-box")]


def titles(entries):
    return [e["title"] for e in entries]


@unittest.skipUnless(NODE, "node is not installed")
class SearchTest(unittest.TestCase):
    def test_fold_drops_case_and_accents(self):
        self.assertEqual(call("fold", "Météo ŰR"), "meteo ur")

    def test_words_split_camel_case_digits_and_separators(self):
        self.assertEqual(call("words", "SkyPost"), ["sky", "post"])
        self.assertEqual(call("words", "Chess960"), ["chess", "960"])
        self.assertEqual(call("words", "jolla-settings"), ["jolla", "settings"])

    def test_title_prefix_first_then_word_starts(self):
        found = titles(call("search", APPS, "ho", {}, NOW))
        self.assertEqual(found[:2], ["House Sitter", "Holiday Album"])  # both prefixes: the shorter first
        self.assertNotIn("Phone", found[:2])

    def test_initials(self):
        self.assertEqual(titles(call("search", APPS, "hs", {}, NOW))[0], "House Sitter")
        self.assertEqual(titles(call("search", APPS, "hn", {}, NOW))[0], "Habit Notes")
        # a name that starts so comes before initials
        self.assertEqual(titles(call("search", APPS, "ha", {}, NOW))[:2], ["Habit Notes", "Holiday Album"])

    def test_accents_do_not_matter(self):
        self.assertEqual(titles(call("search", APPS, "meteo", {}, NOW)), ["Météo"])
        self.assertEqual(titles(call("search", APPS, "MÉT", {}, NOW)), ["Météo"])

    def test_desktop_file_name_matches(self):
        self.assertIn("Météo", titles(call("search", APPS, "weather", {}, NOW)))
        self.assertIn("Photos", titles(call("search", APPS, "gallery", {}, NOW)))

    def test_scattered_letters_only_from_a_word_start(self):
        apps = APPS + [app("Sextant", "sextant"), app("Seat Map", "seat-map"), app("subnet-tool", "subnet")]
        self.assertEqual(titles(call("search", apps, "set", {}, NOW)), ["Settings", "Sync Settings"])
        self.assertEqual(titles(call("search", apps, "sttngs", {}, NOW))[:2], ["Settings", "Sync Settings"])

    def test_a_folder_name_finds_the_folder_then_its_apps(self):
        apps = APPS + [{"key": "folder:Tools", "title": "Tools", "file": "", "folder": "", "isFolder": True},
                       app("Unit Converter", "unit-converter", "Tools"), app("Level", "level", "Tools")]
        found = titles(call("search", apps, "too", {}, NOW))
        self.assertEqual(found[0], "Tools")
        self.assertEqual(sorted(found[1:]), ["Level", "Unit Converter"])
        # an app's own name still comes before the apps of a folder of that name
        self.assertEqual(titles(call("search", APPS, "med", {}, NOW))[0], "Medicine Box")

    def test_every_query_word_must_match(self):
        self.assertEqual(titles(call("search", APPS, "holiday al", {}, NOW)), ["Holiday Album"])
        self.assertEqual(call("search", APPS, "holiday zzz", {}, NOW), [])

    def test_used_apps_rank_higher_among_equals(self):
        usage = {APPS[0]["key"]: {"n": 20, "t": NOW - DAY}}
        self.assertEqual(titles(call("search", APPS, "ho", usage, NOW))[0], "Holiday Album")

    def test_nothing_typed_matches_nothing(self):
        self.assertEqual(call("search", APPS, "  ", {}, NOW), [])

    def test_suggestions_by_decaying_use(self):
        usage = {APPS[2]["key"]: {"n": 10, "t": NOW - 30 * DAY},   # often, but a month ago: 10 / 2^4.3
                 APPS[3]["key"]: {"n": 2, "t": NOW - DAY},         # twice, yesterday
                 "/gone.desktop": {"n": 50, "t": NOW}}             # no longer installed
        self.assertEqual(titles(call("suggestions", APPS, usage, 5, NOW)), ["Settings", "Phone"])

    def test_note_use_counts_and_keeps_the_most_used(self):
        usage = call("noteUse", {}, "a", NOW)
        usage = call("noteUse", usage, "a", NOW)
        self.assertAlmostEqual(usage["a"]["n"], 2)
        many = {"k%d" % i: {"n": i + 1, "t": NOW} for i in range(120)}
        kept = call("noteUse", many, "new", NOW)
        self.assertEqual(len(kept), 120)
        self.assertNotIn("k0", kept)
        self.assertIn("new", kept)

    def test_sections_a_to_z_then_others(self):
        result = call("sections", APPS + [app("2048", "2048")])
        self.assertEqual([s["letter"] for s in result], ["C", "H", "M", "P", "S", "#"])
        self.assertEqual(titles(result[1]["entries"]), ["Habit Notes", "Holiday Album", "House Sitter"])


if __name__ == "__main__":
    unittest.main()
