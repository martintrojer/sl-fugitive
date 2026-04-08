# TODO

## Quality

- [ ] Build repeatable tmp-repo validation for Sapling
- [ ] Exercise the configured `command` path in tests

## Review Workflow

- [ ] Reconnect `cR` everywhere meaningful in show/annotate/status/diff flows

## Known issues

- [ ] `run_vcs_terminal` env keys not shell-escaped (low risk — keys are plugin-controlled)
- [ ] `get_changeset_metadata` template parsing fragile if commit description contains literal newlines
