#!/bin/sh
# Parses `\nax\na`, inserts a newline before `x`, and reparses incrementally with the old tree. The result must
# match a fresh parse of the edited text, `\na\nx\na`, where `x` starts a line and is therefore a `head`.
set -eu
cd "$(dirname "$0")"
npx tree-sitter generate
mkdir -p .tmp
printf '\nax\na' > .tmp/before.txt
printf '\na\nx\na' > .tmp/after.txt
newline='
'
npx tree-sitter parse .tmp/before.txt --edits "2 0 $newline" > .tmp/incremental.txt 2> /dev/null < /dev/null
npx tree-sitter parse .tmp/after.txt > .tmp/fresh.txt 2> /dev/null
if diff -u --label incremental --label fresh .tmp/incremental.txt .tmp/fresh.txt; then
  echo 'OK: the incremental reparse matches a fresh parse.'
else
  echo 'BUG: the incremental reparse differs from a fresh parse.'
  exit 1
fi
