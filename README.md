# sl-fugitive.nvim

A Sapling-first Neovim plugin inspired by vim-fugitive, built around
Sapling’s smartlog, stack editing, and AI-assisted review.

## Features

- **Smartlog as primary hub** — ANSI-colored smartlog with workspace status indicator (clean/dirty/conflict)
- **Stack-aware mutations** — rebase, split, fold, absorb, hide, restack, interactive rebase, amend-to from the log view
- **Diff viewer** — unified diff with ANSI colors, side-by-side with Neovim’s built-in diff mode, buffer reuse
- **Status view** — changed files with inline diff toggle (`=`), open, split, diff, revert
- **Describe & commit** — editor buffers for commit messages with `:w` to save
- **Annotate/blame** — scroll-locked per-line attribution with `<CR>` to show changeset
- **Bookmark management** — create, delete, move, rename, push in a dedicated buffer
- **Smart completion** — tab completion for Sapling commands, subcommands, aliases, and revisions/bookmarks
- **Browse** — open current file or commit on GitHub/GitLab/custom forges from any buffer
- **AI review workflow** (optional, via [redline.nvim](https://github.com/martintrojer/redline.nvim)) — capture comments from unified diffs, show buffers, and status inline diffs into a shared AI-ready review packet

## Commands

| Command | Description |
|---------|-------------|
| `:S` | Open the default surface |
| `:S log` | Open the log view |
| `:S status` | Open the status view |
| `:S diff [file]` | Open the diff view |
| `:S review` | Open the shared AI review buffer |
| `:S annotate [file]` | Open the annotate view |
| `:S bookmark` | Open the bookmark view |
| `:S browse [remote]` | Open the current file or commit on a forge |
| `:S describe [rev]` | Edit a Sapling commit message |
| `:S commit` | Create a new Sapling commit from the working copy |
| `:S push [args]` | Pass through to Sapling |
| `:S pull [args]` | Pass through to Sapling |
| `:S <any>` | Pass through to Sapling |

## Smartlog Keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Show changeset detail |
| `d` | Show diff for changeset |
| `go` | Goto selected commit |
| `ra` | Absorb working changes into the stack |
| `cc` | Edit selected commit message |
| `rr` | Rebase selected commit onto a destination |
| `rs` | Rebase selected commit and descendants onto a destination |
| `ri` | Interactive rebase from selected commit |
| `rS` | Split selected commit |
| `rt` | Amend working changes into selected commit |
| `rf` | Fold linearly from current commit to selected |
| `rh` | Hide selected commit and descendants |
| `rR` | Restack current stack |
| `rc` | Continue interrupted rebase |
| `rA` | Abort interrupted rebase |
| `g?` | Help |

## Configuration

```lua
require("sl-fugitive").setup({
  default_command = "log",
  open_mode = "split",   -- "split" or "tab"
  command = "sl",         -- path to Sapling CLI
  forges = {              -- custom browse URL templates (optional)
    { match = "myrepo", url = "https://code.example.com/myrepo/{path}?lines={lines}" },
  },
})
```

### Custom Forges

The `forges` option lets `:SBrowse` work with any code hosting service.
Each entry has a `match` pattern tested against the remote URL from `sl paths`,
and a `url` template with `{path}`, `{rev}`, and `{lines}` placeholders.
If no lines are selected, `?lines={lines}` is stripped automatically.
Custom forges are tried first — standard GitHub/GitLab parsing is the fallback.

## Requirements

- Neovim 0.10+
- [Sapling](https://sapling-scm.com/) installed and available in PATH
- [fugitive-core.nvim](https://github.com/martintrojer/fugitive-core.nvim)

### Optional

- [redline.nvim](https://github.com/martintrojer/redline.nvim) — AI review
  comment capture (`cR`/`gR` keymaps). Without it, everything else works
  normally; review keymaps just won't appear.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "martintrojer/sl-fugitive", dependencies = { "martintrojer/fugitive-core.nvim" } }
-- For AI review support:
-- { "martintrojer/sl-fugitive", dependencies = { "martintrojer/fugitive-core.nvim", "martintrojer/redline.nvim" } }
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add("martintrojer/fugitive-core.nvim")
vim.pack.add("martintrojer/sl-fugitive")
```

## AI Review Workflow

Requires [redline.nvim](https://github.com/martintrojer/redline.nvim) (optional
dependency). Without it, review keymaps are not mapped and everything else works
normally.

From unified diff buffers, commit show buffers, and expanded status inline
diffs:

```
  cR        Add review comment for the current diff line
  gR        Open the shared review buffer
```
