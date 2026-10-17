// Finding apps by what is typed, suggestions from use, and the A–Z sections (docs/SEARCH.md). Pure functions over plain
// entries, so that tests/test_search.py runs them with Node:
//   {key, title, file, folder}  key: an id (the desktop file's path), title: the name shown, file: the desktop
//                               file's name ("jolla-settings"), folder: the title of the folder it is in, or ""
// usage: {key: {n, t}}: how often an app was launched (n, decaying) and when last (t, ms since the epoch).
.pragma library

var HALF_LIFE = 7 * 24 * 3600 * 1000
var KEEP = 120

var ACCENTS = {
    "á": "a", "à": "a", "â": "a", "ä": "a", "ã": "a", "å": "a", "ą": "a",
    "é": "e", "è": "e", "ê": "e", "ë": "e", "ę": "e", "ě": "e",
    "í": "i", "ì": "i", "î": "i", "ï": "i",
    "ó": "o", "ò": "o", "ô": "o", "ö": "o", "õ": "o", "ő": "o", "ø": "o",
    "ú": "u", "ù": "u", "û": "u", "ü": "u", "ű": "u", "ů": "u",
    "ñ": "n", "ń": "n", "ň": "n", "ç": "c", "ć": "c", "č": "c", "ś": "s", "š": "s", "ş": "s", "ß": "ss",
    "ź": "z", "ż": "z", "ž": "z", "ř": "r", "ý": "y", "ł": "l", "ď": "d", "ť": "t"
}

// lower case without accents: "Météo" -> "meteo"
function fold(text) {
    var lower = String(text || "").toLowerCase()
    var out = ""
    for (var i = 0; i < lower.length; i++) {
        var c = lower.charAt(i)
        out += ACCENTS[c] !== undefined ? ACCENTS[c] : c
    }
    return out
}

// the words of a name, folded: "SkyPost" -> ["sky", "post"], "Chess960" -> ["chess", "960"],
// "jolla-settings" -> ["jolla", "settings"]
function words(text) {
    var spaced = String(text || "")
        .replace(/([a-zà-ſ])([A-ZÀ-ž])/g, "$1 $2")
        .replace(/([A-Za-zÀ-ſ])([0-9])/g, "$1 $2")
        .replace(/([0-9])([A-Za-zÀ-ſ])/g, "$1 $2")
    var parts = fold(spaced).split(/[^a-z0-9]+/)
    var list = []
    for (var i = 0; i < parts.length; i++) {
        if (parts[i] !== "")
            list.push(parts[i])
    }
    return list
}

function initials(list) {
    var out = ""
    for (var i = 0; i < list.length; i++)
        out += list[i].charAt(0)
    return out
}

// all the characters of query in text, in order, from the start of a word, not too far apart ("sttngs" is in
// "settings"): a score for how close together they are (0: not there)
function subsequence(text, query) {
    var best = 0
    for (var start = 0; start < text.length; start++) {
        var wordStart = start === 0 || !/[a-z0-9]/.test(text.charAt(start - 1))
        if (!wordStart || text.charAt(start) !== query.charAt(0))
            continue
        var at = start
        var gaps = 0
        for (var i = 1; i < query.length && at >= 0; i++) {
            var next = text.indexOf(query.charAt(i), at + 1)
            gaps += next - at - 1
            at = next
        }
        if (at >= 0 && gaps <= query.length)
            best = Math.max(best, 300 - 10 * gaps - Math.min(20, start))
    }
    return best
}

// How well one query word matches an entry (0: not at all)
function wordScore(entry, q, folded, list, fileList, folderList) {
    if (folded === q)
        return 1000
    if (folded.indexOf(q) === 0)
        return 900 - Math.min(99, folded.length - q.length)
    for (var i = 1; i < list.length; i++) {
        if (list[i].indexOf(q) === 0)
            return 800 - 10 * Math.min(9, i)
    }
    if (q.length >= 2 && initials(list).indexOf(q) === 0)
        return 700
    var at = folded.indexOf(q)
    if (at > 0)
        return 600 - Math.min(99, at)
    for (var f = 0; f < fileList.length; f++) {
        if (fileList[f].indexOf(q) === 0)
            return 500
    }
    // the folder it is in: its apps follow the folder ("netw": the Network folder, then its apps)
    for (var g = 0; g < folderList.length; g++) {
        if (folderList[g].indexOf(q) === 0)
            return 400
    }
    if (q.length >= 4)
        return subsequence(folded, q)
    return 0
}

// How well a query matches an entry: every word of the query must match (0: no match)
function score(entry, query) {
    var parts = fold(query).split(/\s+/)
    var folded = fold(entry.title)
    var list = words(entry.title)
    var fileList = words(entry.file || "")
    var folderList = words(entry.folder || "")
    var total = 0
    var count = 0
    for (var i = 0; i < parts.length; i++) {
        if (parts[i] === "")
            continue
        var s = wordScore(entry, parts[i], folded, list, fileList, folderList)
        if (s === 0)
            return 0
        total += s
        count++
    }
    return count > 0 ? total / count : 0
}

// how much an app was used, now: its launches halving every week
function frecency(record, now) {
    if (!record)
        return 0
    return record.n * Math.pow(0.5, Math.max(0, now - record.t) / HALF_LIFE)
}

// The matches of query, best first: the score, a little more for apps used often, then the name
function search(entries, query, usage, now) {
    var found = []
    for (var i = 0; i < entries.length; i++) {
        var s = score(entries[i], query)
        if (s > 0) {
            var used = usage ? frecency(usage[entries[i].key], now) : 0
            found.push({ "entry": entries[i], "score": s + Math.min(60, 12 * Math.log(1 + used)) })
        }
    }
    found.sort(function (a, b) {
        if (b.score !== a.score)
            return b.score - a.score
        return fold(a.entry.title) < fold(b.entry.title) ? -1 : 1
    })
    var out = []
    for (var k = 0; k < found.length; k++)
        out.push(found[k].entry)
    return out
}

// usage after a launch of key: a new object; beyond KEEP apps the least used others are dropped (never key)
function noteUse(usage, key, now) {
    var next = {}
    var others = []
    for (var k in usage) {
        if (usage.hasOwnProperty(k) && k !== key) {
            next[k] = usage[k]
            others.push(k)
        }
    }
    next[key] = { "n": frecency(usage[key], now) + 1, "t": now }
    if (others.length >= KEEP) {
        others.sort(function (a, b) { return frecency(next[b], now) - frecency(next[a], now) })
        for (var i = KEEP - 1; i < others.length; i++)
            delete next[others[i]]
    }
    return next
}

// The count most used apps that are still there, most used first
function suggestions(entries, usage, count, now) {
    var used = []
    for (var i = 0; i < entries.length; i++) {
        var f = usage ? frecency(usage[entries[i].key], now) : 0
        if (f > 0.05)
            used.push({ "entry": entries[i], "f": f })
    }
    used.sort(function (a, b) { return b.f - a.f })
    var out = []
    for (var k = 0; k < used.length && out.length < count; k++)
        out.push(used[k].entry)
    return out
}

// The A–Z sections: [{letter, entries}], "#" for names that start with something else, last
function sections(entries) {
    var sorted = entries.slice()
    sorted.sort(function (a, b) {
        var x = fold(a.title)
        var y = fold(b.title)
        return x < y ? -1 : x > y ? 1 : 0
    })
    var byLetter = {}
    var letters = []
    for (var i = 0; i < sorted.length; i++) {
        var c = fold(sorted[i].title).charAt(0)
        var letter = c >= "a" && c <= "z" ? c.toUpperCase() : "#"
        if (!byLetter[letter]) {
            byLetter[letter] = []
            letters.push(letter)
        }
        byLetter[letter].push(sorted[i])
    }
    letters.sort(function (a, b) {
        if (a === "#")
            return 1
        if (b === "#")
            return -1
        return a < b ? -1 : 1
    })
    var out = []
    for (var k = 0; k < letters.length; k++)
        out.push({ "letter": letters[k], "entries": byLetter[letters[k]] })
    return out
}
