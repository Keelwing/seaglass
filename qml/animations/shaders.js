// The effects' shaders, read once per QML engine and kept: shaders/common.glsl in front of shaders/NAME.frag.
// Qt 5.6 reads local files with XMLHttpRequest (status 0); a shader that is not there gives "".
.pragma library

var texts = {}
var waiting = {}
// the GLSL version of the effects once a window knows it (Effect.qml): true for GLSL ES 3.00
var es3 = null

// GLSL ES 3.00: the header in front of an effect's fragment shader, and its vertex shader (Qt's own is GLSL ES 1.00,
// and both must be the same version)
var ES3_HEADER = "#version 300 es\n#define ES3 1\n"
var ES3_VERTEX = "#version 300 es\n"
        + "uniform highp mat4 qt_Matrix;\n"
        + "in highp vec4 qt_Vertex;\n"
        + "in highp vec2 qt_MultiTexCoord0;\n"
        + "out highp vec2 qt_TexCoord0;\n"
        + "void main() { qt_TexCoord0 = qt_MultiTexCoord0; gl_Position = qt_Matrix * qt_Vertex; }\n"

function read(url, done) {
    var request = new XMLHttpRequest()
    request.onreadystatechange = function () {
        if (request.readyState === XMLHttpRequest.DONE)
            done(request.status === 200 || request.status === 0 ? request.responseText : "")
    }
    request.open("GET", url)
    request.send()
}

// whether the shader NAME is loaded, for the version in use
function ready(name) {
    var text = es3 === null ? undefined : texts[name + (es3 ? " es3" : "")]
    return text !== undefined && text !== ""
}

// whether a file of its own is loaded
function fileReady(url) {
    return files[url] !== undefined && files[url] !== ""
}

// calls done(text) with a file of its own (Shatter's shards.vert and shards.frag), read once
var files = {}

function loadFile(url, done) {
    if (files[url] !== undefined) {
        done(files[url])
        return
    }
    read(url, function (text) {
        files[url] = text
        done(text)
    })
}

// calls done(text) with the shader NAME from the folder base (a URL ending in "/"), behind common.glsl and the
// libraries libs (["frost"]: frost.glsl), as GLSL ES 3.00 when es3; at once when it is loaded already
function load(base, name, libs, es3, done) {
    var key = name + (es3 ? " es3" : "")
    if (texts[key] !== undefined) {
        done(texts[key])
        return
    }
    if (waiting[key]) {
        waiting[key].push(done)
        return
    }
    waiting[key] = [done]
    var files = ["common.glsl"]
    for (var i = 0; i < libs.length; i++)
        files.push(libs[i] + ".glsl")
    files.push(name + ".frag")
    var parts = []
    var next = function () {
        if (parts.length < files.length) {
            read(base + files[parts.length], function (part) {
                parts.push(part)
                next()
            })
            return
        }
        var result = parts.indexOf("") < 0 ? (es3 ? ES3_HEADER : "") + parts.join("\n") : ""
        texts[key] = result
        var calls = waiting[key]
        delete waiting[key]
        for (var j = 0; j < calls.length; j++)
            calls[j](result)
    }
    next()
}
