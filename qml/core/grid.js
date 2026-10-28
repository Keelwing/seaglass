// The app grid's layout with group widgets in it. Every item of the grid's model takes a block of cells: an app or a
// folder icon one cell, a widget folder its span (spanOf). The items are placed in model order, each at the first free
// place, top to bottom and left to right, where its block fits ("dense", like CSS grid-auto-flow: dense): apps that
// follow a card fill the cells beside it, so the grid has no holes, and a widget never crosses a page. The position of
// a widget is the position of its folder in the model, which Lipstick stores (applications.menu): moving a widget is
// moving its folder. Data widgets have no folder: they hold slots in the grid's order (compose, below).
.pragma library

var TYPES = ["card", "shelf", "panel"]

function isWidgetType(type) {
    return TYPES.indexOf(type) >= 0
}

// The block of a type in cells: a card is two by two, a shelf and a panel the grid's full width
function spanOf(type, columns) {
    if (type === "card")
        return { "w": Math.min(2, columns), "h": 2 }
    if (type === "shelf")
        return { "w": columns, "h": 1 }
    if (type === "panel")
        return { "w": columns, "h": 2 }
    return { "w": 1, "h": 1 }
}

// spans: [{w, h}] in model order; columns: cells per row; pageRows: rows per page; reserved: rows kept free at
// the top of the first page (the stock clock header, the search row at the top); reservedEnd: rows kept free at
// the bottom of the first page (the search row at the bottom). Returns {cells: [{col, row, w, h}], rows}:
// global rows (page * pageRows + row in page), and the number of rows in use.
function layout(spans, columns, pageRows, reserved, reservedEnd) {
    var used = []                 // used[row][col]
    var cells = []
    var rows = 0
    var first = (reserved || 0) * columns   // every cell before this one is taken
    var end = Math.min(pageRows - 1, reservedEnd || 0)
    for (var e = pageRows - end; e < pageRows; e++) {
        used[e] = []
        for (var ec = 0; ec < columns; ec++)
            used[e][ec] = true
    }

    function taken(row, col) {
        return used[row] !== undefined && used[row][col] === true
    }

    function fits(row, col, w, h) {
        if (col + w > columns || (row % pageRows) + h > pageRows)
            return false
        for (var r = row; r < row + h; r++) {
            for (var c = col; c < col + w; c++) {
                if (taken(r, c))
                    return false
            }
        }
        return true
    }

    for (var i = 0; i < spans.length; i++) {
        // a block of no cells: an entry that keeps its place in the order but is not drawn
        if (spans[i].w <= 0 || spans[i].h <= 0) {
            cells.push({ "col": first % columns, "row": Math.floor(first / columns), "w": 0, "h": 0 })
            continue
        }
        var w = Math.max(1, Math.min(columns, spans[i].w))
        var h = Math.max(1, Math.min(pageRows, spans[i].h))
        var cell = first
        while (!fits(Math.floor(cell / columns), cell % columns, w, h))
            cell++
        var row = Math.floor(cell / columns)
        var col = cell % columns
        for (var r = row; r < row + h; r++) {
            used[r] = used[r] || []
            for (var c = col; c < col + w; c++)
                used[r][c] = true
        }
        cells.push({ "col": col, "row": row, "w": w, "h": h })
        rows = Math.max(rows, row + h)
        while (taken(Math.floor(first / columns), first % columns))
            first++
    }
    return { "cells": cells, "rows": rows }
}

// The model index whose block covers the cell (row, col), or -1
function indexAt(result, row, col) {
    var cells = result.cells
    for (var i = 0; i < cells.length; i++) {
        var b = cells[i]
        if (row >= b.row && row < b.row + b.h && col >= b.col && col < b.col + b.w)
            return i
    }
    return -1
}

// Where a dragged item should go in the model so that the layout puts it nearest to a cell: the order with the
// item at `index` moved to each place in turn, the place whose layout puts its block nearest to (row, col) (rows
// count more than columns); on a tie the place nearest to where it is, so that it does not jump. Returns the
// model index for the move (index itself: stay).
function bestIndex(spans, index, row, col, columns, pageRows, reserved, reservedEnd) {
    var best = index
    var bestDistance = -1
    for (var k = 0; k < spans.length; k++) {
        var order = spans.slice()
        var moved = order.splice(index, 1)[0]
        order.splice(k, 0, moved)
        var block = layout(order, columns, pageRows, reserved, reservedEnd).cells[k]
        var distance = Math.abs(block.row - row) * (columns + 1) + Math.abs(block.col - col)
        if (bestDistance < 0 || distance < bestDistance
                || (distance === bestDistance && Math.abs(k - index) < Math.abs(best - index))) {
            best = k
            bestDistance = distance
        }
    }
    return best
}

// ---- Data widgets (docs/WIDGETS.md) ----
// A data widget has no folder, so it has no place in the model. It holds a slot instead: its index in the grid's
// order, which is the model's order with the data widgets spliced in. An entry of an order is {"m": model index}
// or {"x": data widget id}; extras are [{id, at}] (at: the slot). Model changes leave the slots alone, so a data
// widget keeps its place and the icons flow around it. A widget this version does not draw (a later version's kind)
// is in the order too, with a block of no cells, so that the others keep their places around it.

// The order of `count` model items with the data widgets at their slots; a slot past the end puts the widget at
// the end, two widgets on one slot keep the list's order
function compose(count, extras) {
    var sorted = []
    for (var i = 0; i < extras.length; i++) {
        var at = typeof extras[i].at === "number" ? extras[i].at : NaN
        sorted.push({ "id": extras[i].id, "at": isFinite(at) ? at : 1e9, "n": i })
    }
    sorted.sort(function (a, b) { return a.at !== b.at ? a.at - b.at : a.n - b.n })
    var order = []
    var m = 0
    var e = 0
    while (m < count || e < sorted.length) {
        if (e < sorted.length && (sorted[e].at <= order.length || m >= count)) {
            order.push({ "x": sorted[e].id })
            e++
        } else {
            order.push({ "m": m })
            m++
        }
    }
    return order
}

// The block of each entry: spans by model index, extraSpans by id
function orderSpans(order, spans, extraSpans) {
    var list = []
    for (var i = 0; i < order.length; i++) {
        var entry = order[i]
        list.push(entry.x !== undefined ? (extraSpans[entry.x] || { "w": 1, "h": 1 }) : (spans[entry.m] || { "w": 1, "h": 1 }))
    }
    return list
}

// An order laid out: {cells: [block] by model index (what the hook reads), extra: {id: block}, rows}
function layoutOrder(order, spans, extraSpans, columns, pageRows, reserved, reservedEnd) {
    var result = layout(orderSpans(order, spans, extraSpans), columns, pageRows, reserved, reservedEnd)
    var cells = []
    var extra = {}
    for (var i = 0; i < order.length; i++) {
        if (order[i].x !== undefined)
            extra[order[i].x] = result.cells[i]
        else
            cells[order[i].m] = result.cells[i]
    }
    return { "cells": cells, "extra": extra, "rows": result.rows }
}

// The data widgets' slots in an order: {id: at}, their actual positions (unique, without gaps)
function slotsOf(order) {
    var slots = {}
    for (var i = 0; i < order.length; i++) {
        if (order[i].x !== undefined)
            slots[order[i].x] = i
    }
    return slots
}

function sameEntry(a, b) {
    return a.x !== undefined ? a.x === b.x : (b.x === undefined && a.m === b.m)
}

// The position of an entry ({"m": i} or {"x": id}) in an order, or -1
function positionOf(order, key) {
    for (var i = 0; i < order.length; i++) {
        if (sameEntry(order[i], key))
            return i
    }
    return -1
}

function moveEntry(order, from, to) {
    var list = order.slice()
    var entry = list.splice(from, 1)[0]
    list.splice(to, 0, entry)
    return list
}

// The model index of the entry at a position: the model entries before it
function modelIndexAt(order, position) {
    var n = 0
    for (var i = 0; i < position && i < order.length; i++) {
        if (order[i].x === undefined)
            n++
    }
    return n
}

// An entry taken out and put right before the anchor entry, or right after it: an icon the stock drag moved next
// to the item it aimed at, on the side of the data widgets between them that the user dropped it on
function placeBeside(order, movedKey, anchorKey, after) {
    var from = positionOf(order, movedKey)
    if (from < 0)
        return order
    var list = order.slice()
    var entry = list.splice(from, 1)[0]
    var at = positionOf(list, anchorKey)
    if (at < 0)
        return order
    list.splice(after ? at + 1 : at, 0, entry)
    return list
}

// Where the entry at `from` should go so that the layout puts it nearest to the cell (row, col) (bestIndex over the
// order): the new order
function bestOrder(order, spans, extraSpans, from, row, col, columns, pageRows, reserved, reservedEnd) {
    var k = bestIndex(orderSpans(order, spans, extraSpans), from, row, col, columns, pageRows, reserved, reservedEnd)
    return moveEntry(order, from, k)
}
