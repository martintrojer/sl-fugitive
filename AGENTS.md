# sl-fugitive

A Sapling-first Neovim plugin with `vim-fugitive`-style surfaces and
`jj-fugitive`-style ambition around history editing.

## Quick Reference

```vim
:S                      " Open default surface
:S log                  " Log view
:S status               " Status view
:S diff [file]          " Diff view
:S review               " Shared AI review packet
:S annotate [file]      " Annotate view
:S bookmark             " Bookmark view
:S browse [remote]      " Browse current file or commit on a forge
:S describe [rev]       " Edit a commit message
:S commit               " Create a new commit
:SBrowse                " Same as :S browse
```

## Architecture

```text
lua/sl-fugitive/
├── init.lua           # :S dispatcher, repo detection, sl command runner
├── log.lua            # Live Sapling-backed log view
├── status.lua         # Live status view
├── diff.lua           # Live diff view
├── annotate.lua       # Live annotate split view
├── bookmark.lua       # Live bookmark view
├── browse.lua         # Live forge URL builder
├── describe.lua       # Live describe / commit editor buffers
├── review.lua         # Shared AI-ready review buffer
├── ui.lua             # Shared UI helpers
├── ansi.lua           # ANSI rendering helpers
├── *.lua              # Remaining source material under port

plugin/sl-fugitive.lua # Registers :S and :SBrowse
```

## Current Rules

- Lean into Sapling, not generic Mercurial compatibility.
- Keep the AI review buffer as a first-class workflow.
- Favor node-id based history selection over Mercurial-style numeric rev assumptions.
- Design the log and mutation UX around Sapling’s stack powers.
