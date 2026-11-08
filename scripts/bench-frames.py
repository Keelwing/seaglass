"""What a harness run's frames did, step by step, from its log. The run needs two settings for that:

  --env 'QT_MESSAGE_PATTERN=%{time process} %{category} %{message}'
  --env 'QT_LOGGING_RULES=qt.scenegraph.time.renderloop=true;qt.scenegraph.time.compilation=true'

A step lies between the lines "harness: SCENE step NAME begin" and "end", and steps may overlap: a frame counts for
each one open. The columns:

  secs       the step's length
  frames, /s frames rendered, in all and per second
  first      ms from the step's begin to its first frame: what a push makes the finger wait for
  longest    the longest time between two frames in it, in ms
  over, %    how many of those times were over 16.7 ms, and their share. A time between two frames is not always a slow
             frame: at a rest it is also how long nothing asked for one
  sync, render, swap  mean ms per frame
  anim       mean ms of the GUI thread's animations per frame ("-": no such line, as with the basic render loop)
  compile    each shader compile, in ms

Usage: python3 -I scripts/bench-frames.py LOG [LOG ...]
"""
import re
import sys
from pathlib import Path

LINE = re.compile(r"\s*(\d+\.\d+) (\S+) (.*)")
STEP = re.compile(r"harness: \w+ step (.+) (begin|end)\s*$")
DONE = re.compile(r"harness: \w+ done\s*$")
RENDERED = re.compile(r"Frame rendered .*\bsync=(\d+), render=(\d+), swap=(\d+)")
PREPARED = re.compile(r"Frame prepared .*\banimations=(\d+)")
COMPILED = re.compile(r"shader compiled in (\d+) ?ms")
# A shader that does not compile, and a ShaderEffect's texture input with nothing to read: none of these should be in a
# log
WARNINGS = ("Problematic Vertex shader", "QOpenGLShader::compile", "is not assigned a valid texture provider")
SLOW_MS = 16.7


class Span:
    """A step's lines, or the whole log's"""

    def __init__(self, name, begin):
        self.name = name
        self.begin = begin
        self.end = None
        self.frames = []
        self.sync = self.render = self.swap = 0
        self.animations = []
        self.compiles = []

    def row(self, last):
        length = max((last if self.end is None else self.end) - self.begin, 0.001)
        count = len(self.frames)
        # whole milliseconds, as the log has them
        times = [round((b - a) * 1000) for a, b in zip(self.frames, self.frames[1:])]
        over = sum(1 for t in times if t > SLOW_MS)
        return [self.name + ("" if self.end is not None else " (no end)"), f"{length:.2f}", str(count),
                f"{count / length:.1f}",
                str(round((self.frames[0] - self.begin) * 1000)) if count else "-",
                str(max(times)) if times else "-",
                str(over), f"{100 * over / len(times):.1f}" if times else "-",
                *(f"{total / count:.2f}" if count else "-" for total in (self.sync, self.render, self.swap)),
                f"{sum(self.animations) / len(self.animations):.2f}" if self.animations else "-",
                ",".join(map(str, self.compiles))]


HEADS = ["step", "secs", "frames", "/s", "first", "longest", "over", "%", "sync", "render", "swap", "anim", "compile"]


def read(path):
    """The steps in the order they began, the whole log, the compiles outside any step, the warnings' counts and
    whether the run got to its end"""
    steps, active, outside = [], [], []
    whole = None
    last = 0.0
    done = False
    warnings = dict.fromkeys(WARNINGS, 0)
    with open(path, encoding="utf-8", errors="replace") as log:
        for text in log:
            for word in WARNINGS:
                if word in text:
                    warnings[word] += 1
            line = LINE.match(text)
            if not line:
                continue
            at, message = float(line.group(1)), line.group(3)
            last = at
            whole = whole or Span("whole log", at)
            step = STEP.search(message)
            if step and step.group(2) == "begin":
                steps.append(Span(step.group(1), at))
                active.append(steps[-1])
            elif step:
                for span in reversed(active):
                    if span.name == step.group(1):
                        span.end = at
                        active.remove(span)
                        break
            done = done or DONE.search(message) is not None
            rendered, prepared, compiled = RENDERED.search(message), PREPARED.search(message), COMPILED.search(message)
            for span in (whole, *active):
                if rendered:
                    span.frames.append(at)
                    span.sync += int(rendered.group(1))
                    span.render += int(rendered.group(2))
                    span.swap += int(rendered.group(3))
                if prepared:
                    span.animations.append(int(prepared.group(1)))
                if compiled:
                    span.compiles.append(int(compiled.group(1)))
            if compiled and not active:
                outside.append(int(compiled.group(1)))
    if whole:
        whole.end = last
    return steps, whole, outside, warnings, done


def report(path):
    steps, whole, outside, warnings, done = read(path)
    if whole is None:
        print(f"{path}: no timed lines: was it run with QT_MESSAGE_PATTERN? (see --help)", file=sys.stderr)
        return False
    rows = [HEADS, *(span.row(whole.end) for span in (*steps, whole))]
    widths = [max(len(row[i]) for row in rows) for i in range(len(HEADS) - 1)]
    for row in rows:
        cells = [row[0].ljust(widths[0]), *(row[i].rjust(widths[i]) for i in range(1, len(widths))), row[-1]]
        print(" ".join(cells).rstrip())
    print()
    if not whole.frames:
        print("no frame lines: was it run with QT_LOGGING_RULES? (see --help)")
    if outside:
        print(f"compiles outside any step: {len(outside)}, {sum(outside)} ms in all, longest {max(outside)} ms")
    for word, count in warnings.items():
        print(f'"{word}" lines: {count}')
    if not done:
        print('no "harness: ... done" line: the run did not get to its end')
    return True


def main():
    paths = sys.argv[1:]
    if not paths or paths[0] in ("-h", "--help"):
        print(__doc__)
        return 0 if paths else 2
    good = True
    for path in paths:
        if len(paths) > 1:
            print(f"== {path}")
        if not Path(path).is_file():
            print(f"{path}: no such file", file=sys.stderr)
            good = False
        else:
            good = report(path) and good
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
