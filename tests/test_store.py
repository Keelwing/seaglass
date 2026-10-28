"""Tests of qml/widgets/data/store.js (the data widgets' list), run with Node when it is installed. The grid's order
comes from qml/core/grid.js, so that a change to the list is checked where it shows: which apps a widget sits
between."""
import json
import shutil
import subprocess
import unittest
from pathlib import Path

QML = Path(__file__).resolve().parents[1] / "qml"
STORE = QML / "widgets" / "data" / "store.js"
GRID = QML / "core" / "grid.js"
NODE = shutil.which("node")

RUNNER = """
const fs = require("fs");
function load(path, names) {
    const source = fs.readFileSync(path, "utf8").replace(".pragma library", "");
    return new Function(source + "; return {" + names.map(n => n + ": " + n).join(", ") + "};")();
}
const store = load(process.argv[1], ["KINDS", "STARTERS", "sizesOf", "shown", "parse", "nextId", "setSlots", "add",
                                     "resize", "places", "remove", "addStarters"]);
const grid = load(process.argv[2], ["compose"]);
const c = JSON.parse(process.argv[3]);
const lib = c.lib === "grid" ? grid : store;
const value = lib[c.call].apply(null, c.args);
console.log(JSON.stringify({ "value": value === undefined ? null : value, "args": c.args }));
"""


def run(name, *args, lib="store"):
    case = {"lib": lib, "call": name, "args": list(args)}
    out = subprocess.run([NODE, "-e", RUNNER, str(STORE), str(GRID), json.dumps(case)], capture_output=True,
                         text=True, check=True)
    return json.loads(out.stdout)


def call(name, *args):
    return run(name, *args)["value"]


def changed(name, entries, *args):
    """The function's value and the list it changed"""
    result = run(name, entries, *args)
    return result["value"], result["args"][0]


def order(count, entries):
    """The grid's order with count apps: model indexes and widget ids"""
    extras = [{"id": e["id"], "at": e["at"]} for e in entries]
    return [e["x"] if "x" in e else e["m"] for e in run("compose", count, extras, lib="grid")["value"]]


def entry(id, kind, at, size="card"):
    return {"id": id, "kind": kind, "size": size, "at": at}


@unittest.skipUnless(NODE, "node is not installed")
class StoreTest(unittest.TestCase):
    def test_parse_keeps_what_makes_sense(self):
        text = json.dumps([entry("w1", "clock", 0), entry("w2", "radar", 3), entry("w3", "status", 5, "tall"),
                           {"id": "w4", "kind": "clock", "size": "card"}, entry("w5", "clock", -1),
                           {"id": 6, "kind": "clock", "size": "card", "at": 1}, None, "w7"])
        # a later version's kind or size is kept, so that a write does not drop it
        self.assertEqual([e["id"] for e in call("parse", text)], ["w1", "w2", "w3"])
        for text in ("", "[", "{}", "7", "null"):
            self.assertEqual(call("parse", text), [], text)

    def test_shown_needs_a_known_kind_and_size(self):
        self.assertTrue(call("shown", entry("w1", "status", 0, "panel")))
        self.assertFalse(call("shown", entry("w1", "clock", 0, "panel")))
        self.assertFalse(call("shown", entry("w1", "radar", 0)))
        self.assertFalse(call("shown", entry("w1", "toString", 0)))
        self.assertEqual(call("sizesOf", "clock"), ["card", "shelf"])

    def test_next_id(self):
        self.assertEqual(call("nextId", []), "w1")
        self.assertEqual(call("nextId", [entry("w3", "clock", 0), entry("w10", "status", 7), entry("x99", "event", 2)]),
                         "w11")

    def test_add(self):
        entries = [entry("w1", "clock", 0), entry("w2", "status", 7, "shelf")]
        id, after = changed("add", entries, "weather", "panel", {"new": 3, "w1": 0, "w2": 8})
        self.assertEqual(id, "w3")
        self.assertEqual(after[2], entry("w3", "weather", 3, "panel"))
        self.assertEqual(after[1]["at"], 8)
        # a size the kind does not have gives its first one; no slot puts it at the end
        _, after = changed("add", [], "clock", "panel", {})
        self.assertEqual(after, [entry("w1", "clock", 1e6, "card")])

    def test_resize_only_to_a_size_of_the_kind(self):
        entries = [entry("w1", "clock", 0)]
        self.assertEqual(changed("resize", entries, "w1", "shelf"), (True, [entry("w1", "clock", 0, "shelf")]))
        self.assertEqual(changed("resize", entries, "w1", "panel"), (False, entries))
        self.assertEqual(changed("resize", entries, "w1", "card"), (False, entries))
        self.assertEqual(changed("resize", entries, "w9", "shelf"), (False, entries))

    def test_set_slots(self):
        entries = [entry("w1", "clock", 0), entry("w2", "status", 7)]
        self.assertEqual(changed("setSlots", entries, {"w1": 0, "w2": 7, "w3": 1}), (False, entries))
        value, after = changed("setSlots", entries, {"w2": 2})
        self.assertTrue(value)
        self.assertEqual([e["at"] for e in after], [0, 2])

    def test_places_follow_compose(self):
        # two on one slot keep the list's order; with apps enough, compose puts each widget at its place
        entries = [entry("a", "clock", 2), entry("b", "status", 2), entry("c", "event", 0), entry("d", "player", 40)]
        places = call("places", entries)
        self.assertEqual(places, [2, 3, 0, 40])
        composed = order(60, entries)
        self.assertEqual([composed.index(e["id"]) for e in entries], places)


@unittest.skipUnless(NODE, "node is not installed")
class NeighbourTest(unittest.TestCase):
    """A change to the list leaves every other widget between the same apps (docs/WIDGETS.md)"""

    LISTS = [
        [entry("A", "clock", 3), entry("B", "status", 10, "shelf")],
        [entry("A", "clock", 0), entry("B", "status", 0, "shelf"), entry("C", "event", 5), entry("D", "player", 30)],
        [entry("A", "weather", 12), entry("B", "radar", 4), entry("C", "event", 1e6)],
    ]

    def test_remove_keeps_the_others_neighbours(self):
        for entries in self.LISTS:
            for gone in entries:
                found, after = changed("remove", entries, gone["id"])
                self.assertTrue(found)
                self.assertEqual(len(after), len(entries) - 1)
                for count in (2, 6, 20, 40):
                    expected = [k for k in order(count, entries) if k != gone["id"]]
                    self.assertEqual(order(count, after), expected, (gone["id"], count))

    def test_remove_one(self):
        # 20 apps, A at 3 and B at 10: without A, B stays after app 8
        _, after = changed("remove", self.LISTS[0], "A")
        self.assertEqual(after, [entry("B", "status", 9, "shelf")])
        self.assertEqual(changed("remove", self.LISTS[0], "Z"), (False, self.LISTS[0]))

    def test_starters_on_a_fresh_install(self):
        added, after = changed("addStarters", [])
        self.assertEqual(added, 2)
        self.assertEqual(after, [entry("w1", "clock", 0), entry("w2", "status", 7, "shelf")])
        # the status after the first six apps
        self.assertEqual(order(20, after)[:9], ["w1", 0, 1, 2, 3, 4, 5, "w2", 6])

    def test_starters_keep_the_others_neighbours(self):
        lists = [[entry("w1", "event", 4)], [entry("w1", "event", 0), entry("w2", "player", 7)],
                 [entry("w1", "weather", 12), entry("w2", "radar", 4), entry("w3", "event", 1e6)]]
        for entries in lists:
            added, after = changed("addStarters", entries)
            self.assertEqual(added, 2)
            starters = {e["id"] for e in after[len(entries):]}
            for count in (2, 6, 20, 40):
                self.assertEqual([k for k in order(count, after) if k not in starters], order(count, entries),
                                 (entries, count))
            # each at its starter place in the order
            composed = order(40, after)
            self.assertEqual([composed.index(e["id"]) for e in after[len(entries):]], [0, 7])

    def test_starters_only_for_the_kinds_not_there(self):
        entries = [entry("w4", "status", 2, "card")]
        added, after = changed("addStarters", entries)
        self.assertEqual(added, 1)
        self.assertEqual(after[1], entry("w5", "clock", 0))
        self.assertEqual(after[0]["at"], 3)
        full = [entry("w1", "clock", 9), entry("w2", "status", 0, "panel")]
        self.assertEqual(changed("addStarters", full), (0, full))


if __name__ == "__main__":
    unittest.main()
