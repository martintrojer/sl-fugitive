# Manual Test Checklist

## Test Repo Setup

```bash
tmp=$(mktemp -d /tmp/sl-fugitive-manual.XXXXXX)
cd "$tmp"
sl init
sl config --local 'ui.username=Test User <test@example.com>'
sl config --local 'paths.default=https://github.com/octo/example.git'
sl config --local 'paths.upstream=ssh://git@gitlab.com/acme/demo.git'

printf '# Test Project\n' > README.md
printf 'one\n' > file1.txt
mkdir -p src
printf 'print("hello")\n' > src/main.py
sl add README.md file1.txt src/main.py
sl commit -m base

printf 'two\n' >> file1.txt
sl commit -m stack-one
printf 'three\n' >> file1.txt
sl commit -m stack-two

sl bookmark feature -r .
sl prev
printf 'working copy change\n' >> file1.txt
printf 'new file\n' > new.txt
```

Open Neovim in the test repo:

```bash
cd "$tmp"
nvim file1.txt
```

## Checklist

### Smartlog (`:S` / `:S log`)

- [x] `:S` opens smartlog in a split
- [x] `:S log` reuses the existing smartlog buffer
- [x] `<CR>` on a changeset opens the show buffer
- [x] `d` opens commit diff for the selected node
- [x] `go` runs `sl goto` and refreshes status/log
- [x] `rr` rebases selected commit onto prompted destination
- [x] `ri` opens interactive rebase in a terminal tab
- [x] `rs` opens split in a terminal tab
- [ ] `rf` folds linearly after confirmation
- [x] `rR` restacks the current stack
- [ ] `rc` continues an interrupted rebase
- [ ] `rA` aborts an interrupted rebase
- [x] `ra` absorbs working-copy changes into the stack
- [x] `rm` metaedits the selected commit message
- [x] `rt` amends current working-copy changes into the selected commit
- [x] `rh` hides the selected commit and descendants
- [x] `gR` opens the shared review buffer
- [x] `g?` shows smartlog help

### Changeset / Diff Review

- [x] `cR` in a show buffer appends a review item
- [x] show-buffer review entries include revision, source, summary, author, and date
- [x] `:S diff` shows working-copy diff
- [x] `:S diff file1.txt` shows file-specific diff
- [x] `cR` in unified diff appends a review item
- [x] `D` opens side-by-side diff
- [x] side-by-side shows revision content vs working copy

### Status

- [x] `:S status` opens the status buffer
- [x] `<CR>` and `o` open the selected file
- [x] `=` toggles inline diff
- [x] `cR` on inline diff appends a review item
- [x] `d` and `D` open unified and side-by-side diff
- [x] `x` reverts a tracked file after confirmation
- [x] `gR` opens the shared review buffer

### Annotate

- [x] `:S annotate` opens annotate for the current file
- [x] `:S blame` behaves as an alias
- [x] annotate and source panes remain scroll-bound
- [x] `<CR>` on an annotation line opens the shared changeset detail view
- [x] `gR` opens the shared review buffer

### Bookmark

- [x] `:S bookmark` opens bookmark view
- [x] `c` creates a bookmark
- [x] `m` moves a bookmark
- [x] `r` renames a bookmark
- [x] `d` deletes a bookmark
- [x] `g` goes to the bookmark commit
- [x] `p` pushes the bookmark to a remote name

### Browse

- [x] `:SBrowse` opens a forge URL for the current file
- [ ] `:S browse upstream` uses the requested remote path
- [ ] browse from a show buffer opens a commit URL
- [ ] line anchors are included for file buffers
- [x] missing remotes produce a clear error

### Scaffolds

### Describe / Commit

- [x] `:S describe` opens a commit-message editor for `.`
- [x] `:S describe <rev>` edits a specific revision
- [x] `:w` in describe runs `sl metaedit -r <rev> -m ...`
- [x] `:S commit` opens a commit editor for the working copy
- [x] `:w` in commit runs `sl commit -m ...`
- [x] empty `:S commit` message warns instead of submitting

## Test Log

| Date | Tester | Notes |
|------|--------|-------|
| 2026-04-06 | Codex | Replaced stale jj-era checklist with Sapling surfaces and current smartlog actions. |
