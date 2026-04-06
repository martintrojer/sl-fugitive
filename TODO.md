# TODO

## Core Sapling

- [x] Rework `log.lua` around Sapling smartlog concepts instead of hg-style revs
- [x] Add stack-aware actions: rebase, restack, split, fold
- [x] Port annotate to real `sl annotate`
- [x] Port browse and bookmark flows with Sapling-native assumptions
- [x] Port describe and commit editors to real Sapling commands

## Review Workflow

- [ ] Reconnect `cR` everywhere meaningful in show/annotate/status/diff flows
- [x] Improve diff metadata for review packets from commit/show buffers
- [x] Add browse as a real Sapling surface

## Quality

- [ ] Build repeatable tmp-repo validation for Sapling
- [ ] Exercise the configured `command` path in tests
