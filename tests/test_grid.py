"""Tests of qml/core/grid.js (the app grid's layout with widgets in it), run with Node when it is installed.
The file is ES5 for Qt 5.6; Node runs it after dropping the QML-only ".pragma library" line."""
import json
import shutil
import subprocess
import unittest
from pathlib import Path

GRID = Path(__file__).resolve().parents[1] / "qml" / "core" / "grid.js"
NODE = shutil.which("node")

RUNNER = """
const fs = require("fs");
const source = fs.readFileSync(process.argv[1], "utf8").replace(".pragma library", "");
const grid = {};
new Function("exports", source + "; exports.layout = layout; exports.spanOf = spanOf; exports.indexAt = indexAt;"
             + " exports.bestIndex = bestIndex; exports.compose = compose; exports.layoutOrder = layoutOrder;"
             + " exports.slotsOf = slotsOf; exports.placeBeside = placeBeside; exports.bestOrder = bestOrder;"
             + " exports.modelIndexAt = modelIndexAt; exports.positionOf = positionOf;")(grid);
const c = JSON.parse(process.argv[2]);
if (c.call) {
    console.log(JSON.stringify(grid[c.call].apply(null, c.args)));
    process.exit(0);
}
if (c.best) {
    const spans = c.types.map(t => grid.spanOf(t, c.columns));
    const k = grid.bestIndex(spans, c.best.index, c.best.row, c.best.col, c.columns, c.rows, c.reserved || 0);
    const order = spans.slice(); order.splice(k, 0, order.splice(c.best.index, 1)[0]);
    const r = grid.layout(order, c.columns, c.rows, c.reserved || 0);
    console.log(JSON.stringify({ "index": k, "block": r.cells[k] }));
    process.exit(0);
}
const r = grid.layout(c.types.map(t => grid.spanOf(t, c.columns)), c.columns, c.rows, c.reserved || 0,
                      c.reservedEnd || 0);
const map = [];
for (let y = 0; y < r.rows; y++) {
    const line = [];
    for (let x = 0; x < c.columns; x++)
        line.push(grid.indexAt(r, y, x));
    map.push(line);
}
console.log(JSON.stringify({ "rows": r.rows, "cells": r.cells, "map": map }));
"""


def layout(types, columns=5, rows=9, reserved=0, reserved_end=0):
    case = {"types": types, "columns": columns, "rows": rows, "reserved": reserved, "reservedEnd": reserved_end}
    out = subprocess.run([NODE, "-e", RUNNER, str(GRID), json.dumps(case)], capture_output=True, text=True,
                         check=True)
    return json.loads(out.stdout)


def best(types, index, row, col, columns=5, rows=9):
    case = {"types": types, "columns": columns, "rows": rows, "best": {"index": index, "row": row, "col": col}}
    out = subprocess.run([NODE, "-e", RUNNER, str(GRID), json.dumps(case)], capture_output=True, text=True,
                         check=True)
    return json.loads(out.stdout)


def icons(n):
    return ["icon"] * n


def call(name, *args):
    case = {"call": name, "args": list(args)}
    out = subprocess.run([NODE, "-e", RUNNER, str(GRID), json.dumps(case)], capture_output=True, text=True,
                         check=True)
    return json.loads(out.stdout)


SPAN = {"icon": {"w": 1, "h": 1}, "card": {"w": 2, "h": 2}, "shelf": {"w": 5, "h": 1}, "panel": {"w": 5, "h": 2}}


def spans(types):
    return [SPAN[t] for t in types]


def keys(order):
    return [e["x"] if "x" in e else e["m"] for e in order]


@unittest.skipUnless(NODE, "node is not installed")
class GridTest(unittest.TestCase):
    def test_icons_only_fill_rows_in_order(self):
        result = layout(icons(7))
        self.assertEqual(result["map"], [[0, 1, 2, 3, 4], [5, 6, -1, -1, -1]])

    def test_spans(self):
        result = layout(["card", "shelf", "panel"])
        self.assertEqual([(c["w"], c["h"]) for c in result["cells"]], [(2, 2), (5, 1), (5, 2)])
        # a card is half the grid on four columns
        self.assertEqual(layout(["card"], columns=4)["cells"][0]["w"], 2)

    def test_apps_after_a_card_fill_the_cells_beside_it(self):
        result = layout(icons(5) + ["card"] + icons(6))
        self.assertEqual(result["map"], [[0, 1, 2, 3, 4], [5, 5, 6, 7, 8], [5, 5, 9, 10, 11]])

    def test_dense_fill_takes_the_hole_before_a_widget(self):
        # the card does not fit beside four icons; the next icon takes the free cell
        result = layout(icons(4) + ["card"] + icons(3))
        self.assertEqual(result["map"][0], [0, 1, 2, 3, 5])
        self.assertEqual(result["map"][1][:2], [4, 4])

    def test_full_width_widgets_take_whole_rows(self):
        result = layout(icons(2) + ["panel", "shelf"] + icons(1))
        self.assertEqual(result["map"], [[0, 1, 4, -1, -1], [2] * 5, [2] * 5, [3] * 5])

    def test_a_widget_never_crosses_a_page(self):
        result = layout(icons(40) + ["panel"] + icons(2))
        panel = result["cells"][40]
        self.assertEqual((panel["row"], panel["col"]), (9, 0))
        # the icons after it fill the last row of the first page
        self.assertEqual(result["map"][8], [41, 42, -1, -1, -1])

    def test_reserved_rows_stay_free(self):
        result = layout(icons(3), reserved=1)
        self.assertEqual(result["map"][0], [-1] * 5)
        self.assertEqual(result["cells"][0]["row"], 1)

    def test_rows_at_the_end_of_the_first_page_stay_free(self):
        # the search row at the bottom of the first page: page one has 8 rows of apps, page two all 9
        result = layout(icons(50), reserved_end=1)
        self.assertEqual(result["map"][8], [-1] * 5)
        self.assertEqual(result["cells"][39]["row"], 7)
        self.assertEqual(result["cells"][40]["row"], 9)
        # a card never covers it
        result = layout(icons(35) + ["card"], reserved_end=1)
        self.assertEqual(result["cells"][35]["row"], 9)

    def test_every_item_is_placed_once(self):
        types = icons(9) + ["card"] + icons(4) + ["panel"] + icons(13) + ["shelf", "card"] + icons(30)
        result = layout(types)
        seen = {}
        for line in result["map"]:
            for index in line:
                if index >= 0:
                    seen[index] = seen.get(index, 0) + 1
        self.assertEqual(sorted(seen), list(range(len(types))))
        for index, cell in enumerate(result["cells"]):
            self.assertEqual(seen[index], cell["w"] * cell["h"], index)


@unittest.skipUnless(NODE, "node is not installed")
class BestIndexTest(unittest.TestCase):
    def test_a_card_goes_beside_another_card(self):
        # two cards, the second further down; aimed at the cells right of the first
        types = icons(5) + ["card"] + icons(12) + ["card"] + icons(10)
        result = best(types, index=18, row=1, col=2)
        self.assertEqual((result["block"]["row"], result["block"]["col"]), (1, 2))

    def test_a_card_goes_up_to_the_first_row(self):
        types = icons(12) + ["card"] + icons(10)
        result = best(types, index=12, row=0, col=0)
        self.assertEqual(result["index"], 0)
        self.assertEqual((result["block"]["row"], result["block"]["col"]), (0, 0))

    def test_a_card_goes_down(self):
        types = ["card"] + icons(30)
        result = best(types, index=0, row=4, col=3)
        self.assertEqual((result["block"]["row"], result["block"]["col"]), (4, 3))

    def test_a_panel_goes_to_whole_rows(self):
        types = icons(12) + ["panel"] + icons(10)
        result = best(types, index=12, row=1, col=0)
        self.assertEqual((result["block"]["row"], result["block"]["col"]), (1, 0))
        self.assertEqual(result["index"], 5)

    def test_staying_put_is_stable(self):
        types = icons(5) + ["card"] + icons(12)
        self.assertEqual(best(types, index=5, row=1, col=0)["index"], 5)



@unittest.skipUnless(NODE, "node is not installed")
class DataWidgetOrderTest(unittest.TestCase):
    """The grid's order with data widgets in it (docs/WIDGETS.md)"""

    def test_a_widget_sits_at_its_slot(self):
        self.assertEqual(keys(call("compose", 5, [{"id": "w1", "at": 2}])), [0, 1, "w1", 2, 3, 4])

    def test_slots_past_the_end_and_shared_slots(self):
        self.assertEqual(keys(call("compose", 2, [{"id": "a", "at": 9}, {"id": "b", "at": 9}])), [0, 1, "a", "b"])
        self.assertEqual(keys(call("compose", 3, [{"id": "a", "at": 1}, {"id": "b", "at": 1}])), [0, "a", "b", 1, 2])
        self.assertEqual(keys(call("compose", 2, [{"id": "a", "at": None}])), [0, 1, "a"])

    def test_model_changes_keep_the_slot(self):
        # an app appended at the end, or one removed after the widget: the widget stays at its slot
        for count in (4, 6, 9):
            order = call("compose", count, [{"id": "w", "at": 3}])
            self.assertEqual(call("slotsOf", order), {"w": 3})

    def test_layout_of_an_order(self):
        order = call("compose", 8, [{"id": "clock", "at": 5}])
        result = call("layoutOrder", order, spans(icons(8)), {"clock": SPAN["card"]}, 5, 9, 0, 0)
        self.assertEqual(result["extra"]["clock"], {"col": 0, "row": 1, "w": 2, "h": 2})
        # the icons after it take the cells beside it, by model index
        self.assertEqual((result["cells"][5]["row"], result["cells"][5]["col"]), (1, 2))
        self.assertEqual(len(result["cells"]), 8)
        self.assertEqual(result["rows"], 3)

    def test_group_and_data_widgets_together(self):
        types = icons(3) + ["card"] + icons(20)
        order = call("compose", len(types), [{"id": "s", "at": 0}, {"id": "c", "at": 10}])
        result = call("layoutOrder", order, spans(types), {"s": SPAN["shelf"], "c": SPAN["card"]}, 5, 9, 0, 0)
        self.assertEqual(result["extra"]["s"], {"col": 0, "row": 0, "w": 5, "h": 1})
        self.assertEqual((result["cells"][3]["w"], result["cells"][3]["row"]), (2, 1))
        seen = {}
        blocks = [b for b in result["cells"]] + list(result["extra"].values())
        for b in blocks:
            for r in range(b["row"], b["row"] + b["h"]):
                for col in range(b["col"], b["col"] + b["w"]):
                    self.assertNotIn((r, col), seen)
                    seen[(r, col)] = True
        self.assertEqual(len(blocks), len(types) + 2)

    def test_reserved_rows_with_a_widget(self):
        order = call("compose", 3, [{"id": "w", "at": 0}])
        result = call("layoutOrder", order, spans(icons(3)), {"w": SPAN["shelf"]}, 5, 9, 1, 1)
        self.assertEqual(result["extra"]["w"]["row"], 1)

    def test_an_icon_dropped_after_a_widget(self):
        # [a b W c d]; the stock drag moves a before c (model [b a c d]); the user aimed at c, after the widget
        order = call("compose", 4, [{"id": "W", "at": 2}])
        self.assertEqual(keys(order), [0, 1, "W", 2, 3])
        placed = call("placeBeside", order, {"m": 1}, {"m": 2}, False)
        self.assertEqual(keys(placed), [0, "W", 1, 2, 3])
        self.assertEqual(call("slotsOf", placed), {"W": 1})

    def test_an_icon_dropped_before_a_widget(self):
        # [a b W c d]; the stock drag moves d after b (model [a b d c]); the user aimed at b, before the widget
        order = call("compose", 4, [{"id": "W", "at": 2}])
        placed = call("placeBeside", order, {"m": 2}, {"m": 1}, True)
        self.assertEqual(keys(placed), [0, 1, 2, "W", 3])
        self.assertEqual(call("slotsOf", placed), {"W": 3})
        # right before and right after the widget itself (the stand-in over its block)
        self.assertEqual(keys(call("placeBeside", order, {"m": 3}, {"x": "W"}, False)), [0, 1, 3, "W", 2])
        self.assertEqual(keys(call("placeBeside", order, {"m": 0}, {"x": "W"}, True)), [1, "W", 0, 2, 3])

    def test_a_data_widget_goes_up_to_the_first_row(self):
        order = call("compose", 12, [{"id": "w", "at": 12}])
        moved = call("bestOrder", order, spans(icons(12)), {"w": SPAN["card"]}, 12, 0, 0, 5, 9, 0, 0)
        self.assertEqual(call("slotsOf", moved), {"w": 0})

    def test_a_data_widget_goes_to_the_next_page(self):
        order = call("compose", 60, [{"id": "w", "at": 3}])
        moved = call("bestOrder", order, spans(icons(60)), {"w": SPAN["card"]}, 3, 10, 0, 5, 9, 0, 0)
        result = call("layoutOrder", moved, spans(icons(60)), {"w": SPAN["card"]}, 5, 9, 0, 0)
        self.assertEqual((result["extra"]["w"]["row"], result["extra"]["w"]["col"]), (10, 0))

    def test_a_group_widget_dragged_past_a_data_widget(self):
        # a shelf at the top; the folder card at model index 12 is aimed at the second row
        types = icons(12) + ["card"] + icons(10)
        order = call("compose", len(types), [{"id": "s", "at": 0}])
        start = call("positionOf", order, {"m": 12})
        moved = call("bestOrder", order, spans(types), {"s": SPAN["shelf"]}, start, 1, 0, 5, 9, 0, 0)
        position = call("positionOf", moved, {"m": 12})
        self.assertEqual(call("modelIndexAt", moved, position), 0)
        self.assertEqual(call("slotsOf", moved), {"s": 0})

    def test_a_widget_not_drawn_keeps_its_place(self):
        # a later version's widget at slot 3: no cells, but the clock at 7 stays between apps 5 and 6
        order = call("compose", 10, [{"id": "later", "at": 3}, {"id": "clock", "at": 7}])
        self.assertEqual(keys(order), [0, 1, 2, "later", 3, 4, 5, "clock", 6, 7, 8, 9])
        result = call("layoutOrder", order, spans(icons(10)), {"later": {"w": 0, "h": 0}, "clock": SPAN["card"]},
                      5, 9, 0, 0)
        self.assertEqual((result["extra"]["later"]["w"], result["extra"]["later"]["h"]), (0, 0))
        self.assertEqual((result["cells"][3]["row"], result["cells"][3]["col"]), (0, 3))
        self.assertEqual(result["extra"]["clock"], {"col": 1, "row": 1, "w": 2, "h": 2})
        self.assertEqual(result["rows"], 3)
        # dragged and put back, the clock keeps its slot, and the other one its own
        block = result["extra"]["clock"]
        moved = call("bestOrder", order, spans(icons(10)), {"later": {"w": 0, "h": 0}, "clock": SPAN["card"]}, 7,
                     block["row"], block["col"], 5, 9, 0, 0)
        self.assertEqual(call("slotsOf", moved), {"later": 3, "clock": 7})

    def test_staying_put_is_stable(self):
        order = call("compose", 20, [{"id": "w", "at": 7}])
        block = call("layoutOrder", order, spans(icons(20)), {"w": SPAN["card"]}, 5, 9, 0, 0)["extra"]["w"]
        moved = call("bestOrder", order, spans(icons(20)), {"w": SPAN["card"]}, 7, block["row"], block["col"],
                     5, 9, 0, 0)
        self.assertEqual(call("slotsOf", moved), {"w": 7})


if __name__ == "__main__":
    unittest.main()
