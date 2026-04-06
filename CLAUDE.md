# sl-fugitive

A Sapling-first Neovim plugin inspired by vim-fugitive and shaped around
Sapling smartlog, stack editing, and AI-assisted review.

## Quick Reference

```vim
:S                      " Open default surface
:S log                  " Smartlog view
:S status               " Status view
:S diff [file]          " Diff view
:S annotate [file]      " Annotate / blame
:S bookmark             " Bookmark management
:S browse [remote]      " Open current file or commit on a forge
:S describe [rev]       " Edit a Sapling commit message
:S commit               " Create a new Sapling commit
:S review               " Shared AI review packet
:SBrowse                " Same as :S browse
```

## Core UX

- `:S log` is the primary hub.
- Smartlog actions lean into Sapling stack operations: `go`, `rr`, `ri`, `rs`,
  `rf`, `rR`, `rc`, `rA`, `ra`, `rm`, `rt`, `rh`.
- Use `cR` in unified diff, show, and status inline diff buffers to append a
  review item.
- Use `gR` to open the shared AI-ready review buffer.
- Browse works from file buffers and from commit/show contexts.

## Architecture

```text
lua/sl-fugitive/
├── init.lua          # :S dispatcher, repo detection, Sapling runner
├── log.lua           # Smartlog hub and stack-aware actions
├── status.lua        # Working copy status with inline diff
├── diff.lua          # Unified and side-by-side diff views
├── annotate.lua      # Annotate split view
├── bookmark.lua      # Bookmark management
├── browse.lua        # Forge URL construction from `sl paths`
├── describe.lua      # Describe and commit editor buffers
├── review.lua        # Shared AI review buffer and comment capture
├── ansi.lua          # ANSI color handling
└── ui.lua            # Shared UI helpers

plugin/sl-fugitive.lua  # Registers :S and :SBrowse
```

## Design Decisions

### Synchronous `run_vcs` via `vim.system():wait()`

Sapling commands run synchronously. A short "running..." message appears for
slower operations, which keeps the control flow simple and mutation refreshes
predictable.

Do not automatically retry failed mutations. Rebase, hide, amend, and restack
operate on changing history state and should fail loudly instead of being
replayed implicitly.

## Dependencies

- Neovim 0.10+
- Sapling CLI available via the configured `command`

## Development

```bash
luac -p lua/sl-fugitive/*.lua plugin/sl-fugitive.lua
```
