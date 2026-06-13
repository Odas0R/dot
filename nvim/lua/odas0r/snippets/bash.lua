local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

local function afmt(body, nodes)
  return fmt(body, nodes, { delimiters = "^~" })
end

return {
  s("#!", { t({ "#!/usr/bin/env bash", "" }), i(0) }),
  s("safe", { t("set -euo pipefail"), i(0) }),

  s(
    "script",
    afmt(
      [[
#!/usr/bin/env bash
set -euo pipefail

main() {
  ^body~
}

main "$@"]],
      { body = i(0) }
    )
  ),

  s(
    "fn",
    afmt(
      [[
^name~() {
  ^body~
}]],
      { name = i(1, "name"), body = i(0) }
    )
  ),

  s(
    "usage",
    afmt(
      [[
usage() {
  cat <<'USAGE'
Usage: ^cmd~ ^args~

^body~
USAGE
}]],
      { cmd = i(1, "$0"), args = i(2, "[options]"), body = i(0) }
    )
  ),

  s(
    "cmd",
    afmt(
      [[
if ! command -v ^command~ >/dev/null 2>&1; then
  echo "Missing required command: ^command_again~" >&2
  exit 1
fi]],
      { command = i(1, "nvim"), command_again = i(2, "nvim") }
    )
  ),

  s(
    "iffile",
    afmt(
      [=[
if [[ -f "^file~" ]]; then
  ^body~
fi]=],
      { file = i(1, "$file"), body = i(0) }
    )
  ),

  s(
    "ifdir",
    afmt(
      [=[
if [[ -d "^dir~" ]]; then
  ^body~
fi]=],
      { dir = i(1, "$dir"), body = i(0) }
    )
  ),

  s(
    "for",
    afmt(
      [[
for ^item~ in ^items~; do
  ^body~
done]],
      { item = i(1, "item"), items = i(2, '"${items[@]}"'), body = i(0) }
    )
  ),

  s(
    "while",
    afmt(
      [[
while IFS= read -r ^line~; do
  ^body~
done < ^input~]],
      { line = i(1, "line"), body = i(0), input = i(2, "file") }
    )
  ),

  s(
    "case",
    afmt(
      [[
case "^value~" in
  ^pattern~)
    ^body~
    ;;
  *)
    echo "Unknown value: ^value_again~" >&2
    exit 1
    ;;
esac]],
      {
        value = i(1, "$1"),
        pattern = i(2, "pattern"),
        body = i(0),
        value_again = i(3, "$1"),
      }
    )
  ),

  s(
    "trap",
    afmt(
      [[
tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT]],
      {}
    )
  ),

  s(
    "getopts",
    afmt(
      [[
while getopts ":^opts~" opt; do
  case "$opt" in
    ^opt~)
      ^body~
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))]],
      { opts = i(1, "h"), opt = i(2, "h"), body = i(0) }
    )
  ),

  s(
    "taskfile",
    afmt(
      [[
#!/usr/bin/env bash
set -euo pipefail
PATH="./node_modules/.bin:$PATH"

^task~() {
  ^task_body~
}

build() {
  ^build_body~
}

test() {
  ^test_body~
}

default() {
  ^default_task~
}

help() {
  echo "$0 <task> <args>"
  echo "Tasks:"
  compgen -A function | sort
}

TIMEFORMAT="Task completed in %3lR"
time "${@:-default}"]],
      {
        task = i(1, "dev"),
        task_body = i(2, 'echo "not implemented"'),
        build_body = i(3, 'echo "not implemented"'),
        test_body = i(4, 'echo "not implemented"'),
        default_task = i(5, "dev"),
      }
    )
  ),
}
