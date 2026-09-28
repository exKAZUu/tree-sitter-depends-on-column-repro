# tree-sitter `depends_on_column` reproduction

After tree-sitter rebalances a repeat node, the node can lose `depends_on_column`. An incremental reparse can then
reuse a token whose column changed, so the incremental tree differs from a fresh parse of the same text.

## Reproduce

```sh
npm install
npm run repro
```

`repro.sh` parses `\nax\na`, inserts a newline before `x`, and reparses incrementally with `tree-sitter parse --edits`.
It then parses the edited text, `\na\nx\na`, from scratch and compares the two trees:

```diff
--- incremental
+++ fresh
@@ -2,6 +2,6 @@
   (newline [0, 0] - [1, 0])
   (word [1, 0] - [1, 1])
   (newline [1, 1] - [2, 0])
-  (tail [2, 0] - [2, 1])
+  (head [2, 0] - [2, 1])
   (newline [2, 1] - [3, 0])
   (word [3, 0] - [3, 1]))
```

The external scanner in `src/scanner.c` calls `get_column` and returns `x` as `head` at the start of a line and as
`tail` anywhere else. After the edit, `x` starts a line, but the incremental reparse reuses the old `tail` token.

This reproduces with tree-sitter-cli 0.27.0. It also reproduces when the grammar is built against `lib/` at
tree-sitter `master` (dcdc8cc5).

## Cause

`ts_subtree_summarize_children` in `lib/src/subtree.c` sets `depends_on_column` when a child depends on the column
and starts on the node's first row:

```c
    if (
      self.ptr->size.extent.row == 0 &&
      ts_subtree_depends_on_column(child)
    ) {
      self.ptr->depends_on_column = true;
    }
```

For the first child (`i == 0`), this check runs before `size` is reset from that child. That is fine for a node from
`ts_subtree_new_node`, whose `size` is zero. But `ts_subtree_compress`, called from `ts_parser__balance_subtree`,
summarizes rotated nodes again while `size` still holds their previous extent. When that extent spans rows, a first
child that depends on the column no longer marks the node.

`ts_subtree_edit` then treats the node as independent of the column. It does not invalidate the node, and the
parser reuses it at the shifted position.

## Possible fix

```diff
     if (
-      self.ptr->size.extent.row == 0 &&
+      (i == 0 || self.ptr->size.extent.row == 0) &&
       ts_subtree_depends_on_column(child)
     ) {
```

With this change, the incremental reparse above matches the fresh parse. I also checked every input of up to 8
characters from `a`, `b`, `x`, and newline with a newline inserted at each position: none differed from a fresh parse.
Without the change, `\nax\na` is the shortest failing input.
