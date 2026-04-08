# sl-fugitive.nvim

A Sapling-first Neovim plugin inspired by vim-fugitive, built around
Sapling’s smartlog, stack editing, and AI-assisted review.

- Smartlog as the primary hub
- Stack-aware mutation workflows (`rebase`, `split`, `fold`, `absorb`, `hide`)
- Strong diff/review navigation
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
| `rm` | Edit selected commit message |
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
})
```

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
