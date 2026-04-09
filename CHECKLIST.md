# Smoke Test Checklist

## Test Repo Setup

```bash
tmp=$(mktemp -d /tmp/sl-fugitive-test.XXXXXX)
cd "$tmp"
sl init
sl config --local 'ui.username=Test User <test@example.com>'
sl config --local 'paths.default=https://github.com/octo/example.git'

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

## Checklist

### Log (`:S` / `:S log`)

- [ ] `:S` opens smartlog
- [ ] ANSI colors render correctly
- [ ] Workspace status line shows (clean/dirty/conflict)
- [ ] `<CR>` opens changeset detail, `q` returns to log
- [ ] `d` opens unified diff
- [ ] `D` opens side-by-side diff (file picker if multi-file), `q` returns
- [ ] `go` runs goto, refreshes
- [ ] `cc` edits commit message
- [ ] `rr` rebases commit onto prompted destination
- [ ] `rs` rebases commit and descendants
- [ ] `ra` absorbs working changes
- [ ] `gu` undoes last operation
- [ ] `R` refreshes, cursor stays in place
- [ ] `gs` → status, `gb` → bookmark, `gl` → back to log
- [ ] `g?` shows help

### Status (`:S status`)

- [ ] Shows changed files
- [ ] `=` toggles inline diff, `=` inside block collapses it
- [ ] `<CR>` opens file, `o` opens in split (status stays)
- [ ] `d` shows diff, `D` side-by-side
- [ ] `x` reverts tracked file, deletes untracked file
- [ ] `dd` deletes file from filesystem
- [ ] `o/d/D/x` work from inside expanded inline diff

### Diff (`:S diff`)

- [ ] `:S diff` shows working copy diff
- [ ] `:S diff file1.txt` shows file-specific diff
- [ ] `D` opens side-by-side
- [ ] `o` opens file in editor

### Describe / Commit

- [ ] `:S describe` opens editor for current commit
- [ ] `:w` saves, `q` aborts
- [ ] `:S commit` creates new commit

### Bookmark (`:S bookmark`)

- [ ] `c` creates, `d` deletes, `m` moves, `r` renames
- [ ] `go` goes to bookmark commit

### Annotate (`:S annotate`)

- [ ] Opens scroll-locked split
- [ ] Annotation column shows user + node (no content leaking)
- [ ] `<CR>` opens changeset detail
- [ ] `q` closes cleanly

### Browse (`:SBrowse`)

- [ ] Opens URL from file buffer
- [ ] Line number included

### Tab Completion

- [ ] `:S <tab>` completes commands
- [ ] `:S diff -r <tab>` completes revisions

### Close Behavior

- [ ] `q` never quits Neovim
- [ ] No stray `[No Name]` buffers accumulate
