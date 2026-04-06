# sl-fugitive.nvim

`sl-fugitive.nvim` is a Sapling-first Neovim plugin derived from the early
`jj-fugitive` exploration and then sharpened around Sapling’s stack-aware log
and history-editing model.

This project is no longer trying to straddle plain Mercurial and Sapling. The
point is to lean into Sapling’s strengths, especially:
- smartlog-style history as the main hub
- stack-aware mutation workflows
- strong diff/review navigation
- an AI review packet workflow that fits code-review-heavy use

## Current State

- The public plugin name is `sl-fugitive`.
- The entry commands are `:S` and `:SBrowse`.
- The active live surfaces are `log`, `status`, `diff`, `bookmark`, `annotate`, `browse`, `describe`, `commit`, and the shared review buffer.
- The remaining unfinished work is Sapling-native depth and polish rather than basic surface scaffolding.

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

## Configuration

```lua
require("sl-fugitive").setup({
  default_command = "log",
  open_mode = "split",
  command = "/var/home/martintrojer/sl/sl",
})
```

If `sl` works directly in your shell, `command = "sl"` is also fine.

## Direction

The next major work should lean into Sapling specifically:
- deepen smartlog actions like `metaedit`, `hide`, and `amend --to`
- enrich review packets with changeset metadata from show and diff flows
- keep hardening the live views against real Sapling workflows

The plugin should feel closer to `jj-fugitive` than to a generic Mercurial wrapper.
