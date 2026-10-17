#!/bin/bash
# Static checks in the tool image: qmllint (Qt 5) on our QML, shellcheck on the scripts, actionlint on the GitHub
# workflows (its own image), the Python byte compiler on the hook and the tests, and glslangValidator on the
# animations' shaders. ES5-only JavaScript (Qt 5.6) is
# checked by tests/test_repo.py.
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

tools_image
cd "$REPO_ROOT"
qml=()
while IFS= read -r f; do qml+=("$f"); done < <(find qml harness patchmanager tests/qml-check -name '*.qml' | sort)
sh=()
while IFS= read -r f; do sh+=("$f"); done < <(find scripts rpm harness -name '*.sh' | sort)
docker run --rm -v "$REPO_ROOT:/src:ro" -w /src "$TOOLS_IMAGE" sh -euc '
    qmllint "$@"
    echo "qmllint: ok"
' qmllint "${qml[@]}"
docker run --rm -v "$REPO_ROOT:/src:ro" -w /src "$TOOLS_IMAGE" shellcheck -x "${sh[@]}"
log "shellcheck: ok"
# the workflows by name: actionlint finds them by itself only in a git checkout
workflows=()
while IFS= read -r f; do workflows+=("$f"); done < <(find .github/workflows -name '*.yml' | sort)
docker run --rm -v "$REPO_ROOT:/repo:ro" -w /repo "$ACTIONLINT_IMAGE" "${workflows[@]}"
log "actionlint: ok"
python3 -I -c 'import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' hook/apply_hook.py tests/*.py scripts/*.py
log "python: ok"
# the animations' shaders as the phone puts them together, as GLSL ES 1.00 and as GLSL ES 3.00
rm -rf "$OUT_DIR/shaders"
shaders=()
while IFS= read -r f; do shaders+=("${f#"$REPO_ROOT"/}"); done < <(python3 -I scripts/shaders.py "$OUT_DIR/shaders")
docker run --rm -v "$REPO_ROOT:/src:ro" -w /src "$TOOLS_IMAGE" sh -euc '
    for f in "$@"; do glslangValidator "$f" >/dev/null || { glslangValidator "$f"; exit 1; }; done
' glslang "${shaders[@]}"
log "shaders: ok (${#shaders[@]})"
