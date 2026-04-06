# Manual Test Checklist

## Test Repo Setup

```bash
tmp=$(mktemp -d /tmp/sl-fugitive-manual.XXXXXX)
cd "$tmp"
/var/home/martintrojer/sl/sl init
/var/home/martintrojer/sl/sl config --local 'ui.username=Test User <test@example.com>'
/var/home/martintrojer/sl/sl config --local 'paths.default=https://github.com/octo/example.git'
/var/home/martintrojer/sl/sl config --local 'paths.upstream=ssh://git@gitlab.com/acme/demo.git'

printf '# Test Project\n' > README.md
printf 'one\n' > file1.txt
mkdir -p src
printf 'print("hello")\n' > src/main.py
/var/home/martintrojer/sl/sl add README.md file1.txt src/main.py
/var/home/martintrojer/sl/sl commit -m base

printf 'two\n' >> file1.txt
/var/home/martintrojer/sl/sl commit -m stack-one
printf 'three\n' >> file1.txt
/var/home/martintrojer/sl/sl commit -m stack-two

/var/home/martintrojer/sl/sl bookmark feature -r .
/var/home/martintrojer/sl/sl prev
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

- [ ] `:S` opens smartlog in a split
- [ ] `:S log` reuses the existing smartlog buffer
- [ ] `<CR>` on a changeset opens the show buffer
- [ ] `d` opens commit diff for the selected node
- [ ] `go` runs `sl goto` and refreshes status/log
- [ ] `rr` rebases selected commit onto prompted destination
- [ ] `ri` opens interactive rebase in a terminal tab
- [ ] `rs` opens split in a terminal tab
- [ ] `rf` folds linearly after confirmation
- [ ] `rR` restacks the current stack
- [ ] `rc` continues an interrupted rebase
- [ ] `rA` aborts an interrupted rebase
- [ ] `ra` absorbs working-copy changes into the stack
- [ ] `rm` metaedits the selected commit message
- [ ] `rt` amends current working-copy changes into the selected commit
- [ ] `rh` hides the selected commit and descendants
- [ ] `gR` opens the shared review buffer
- [ ] `g?` shows smartlog help

### Changeset / Diff Review

- [ ] `cR` in a show buffer appends a review item
- [ ] show-buffer review entries include revision, source, summary, author, and date
- [ ] `:S diff` shows working-copy diff
- [ ] `:S diff file1.txt` shows file-specific diff
- [ ] `cR` in unified diff appends a review item
- [ ] `D` opens side-by-side diff
- [ ] side-by-side shows revision content vs working copy

### Status

- [ ] `:S status` opens the status buffer
- [ ] `<CR>` and `o` open the selected file
- [ ] `=` toggles inline diff
- [ ] `cR` on inline diff appends a review item
- [ ] `d` and `D` open unified and side-by-side diff
- [ ] `x` reverts a tracked file after confirmation
- [ ] `gR` opens the shared review buffer

### Annotate

- [ ] `:S annotate` opens annotate for the current file
- [ ] `:S blame` behaves as an alias
- [ ] annotate and source panes remain scroll-bound
- [ ] `<CR>` on an annotation line opens the shared changeset detail view
- [ ] `gR` opens the shared review buffer

### Bookmark

- [ ] `:S bookmark` opens bookmark view
- [ ] `c` creates a bookmark
- [ ] `m` moves a bookmark
- [ ] `r` renames a bookmark
- [ ] `d` deletes a bookmark
- [ ] `g` goes to the bookmark commit
- [ ] `p` pushes the bookmark to a remote name

### Browse

- [ ] `:SBrowse` opens a forge URL for the current file
- [ ] `:S browse upstream` uses the requested remote path
- [ ] browse from a show buffer opens a commit URL
- [ ] line anchors are included for file buffers
- [ ] missing remotes produce a clear error

### Scaffolds

### Describe / Commit

- [ ] `:S describe` opens a commit-message editor for `.`
- [ ] `:S describe <rev>` edits a specific revision
- [ ] `:w` in describe runs `sl metaedit -r <rev> -m ...`
- [ ] `:S commit` opens a commit editor for the working copy
- [ ] `:w` in commit runs `sl commit -m ...`
- [ ] empty `:S commit` message warns instead of submitting

## Test Log

| Date | Tester | Notes |
|------|--------|-------|
| 2026-04-06 | Codex | Replaced stale jj-era checklist with Sapling surfaces and current smartlog actions. |
