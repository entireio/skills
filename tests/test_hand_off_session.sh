#!/bin/sh

set -eu

test -f README.md
test -f skills/hand-off-session/SKILL.md
test -f commands/hand-off-session.md
test -f .codex/README.md
test -f .opencode/README.md
test -f .claude-plugin/plugin.json
test -x lib/hand_off_session.sh
