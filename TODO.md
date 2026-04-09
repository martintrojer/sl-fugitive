# TODO

## Architecture

- [ ] `log.lua` is 580+ lines — mutation functions follow identical patterns, table-driven dispatch would cut boilerplate
- [ ] `browse.lua` buffer context system (`sl_buffer_context`, `sl_changeset_node`) is fragile
- [ ] `ui.lua` `file_at_rev` uses `vim.system():wait()` directly — no error feedback, env handling, or "running..." indicator

## Cleanup

- [ ] Annotate dispatch doesn't expose `-r REV` to the `:S annotate` command

## Tests

- [ ] Behavioral tests for annotate parser, status file_from_line, bookmark_from_line, log node extraction
- [ ] Integration tests — headless test that creates buffer, calls show(), verifies content and keymaps

## Review Workflow

- [ ] Reconnect `cR` everywhere meaningful in show/annotate/status/diff flows

## Known issues

- [ ] `run_vcs_terminal` env keys not shell-escaped (low risk — keys are plugin-controlled)
