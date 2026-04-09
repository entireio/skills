# Hand-Off Session Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `superpowers`-style Entire skills repo and ship the first cross-agent `hand-off-session` skill that reads repo-local Entire metadata, understands session or checkpoint context privately, and returns only a compact understanding summary.

**Architecture:** Keep reusable behavior in `skills/hand-off-session/` and `commands/`, with a shared helper in `lib/` that discovers sessions, resolves checkpoint relationships, parses `prompt.txt` and `full.jsonl`, filters transcript noise, and produces a small handoff summary. Platform-specific folders remain thin install/bootstrap wrappers so behavior stays consistent across Codex, Claude, OpenCode, Cursor, and Gemini.

**Tech Stack:** Markdown skill docs, shell wrapper scripts, a small shared CLI helper, fixture-based tests, and repo documentation.

---

### Task 1: Scaffold The Repository Layout

**Files:**
- Create: `README.md`
- Create: `skills/hand-off-session/SKILL.md`
- Create: `commands/hand-off-session.md`
- Create: `.codex/README.md`
- Create: `.opencode/README.md`
- Create: `.claude-plugin/plugin.json`
- Create: `lib/hand_off_session.sh`
- Create: `tests/fixtures/`
- Create: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Create a smoke test that asserts the repo contains the expected top-level files and that the helper script is executable.

```sh
test -f README.md
test -f skills/hand-off-session/SKILL.md
test -f commands/hand-off-session.md
test -f .codex/README.md
test -f .opencode/README.md
test -f .claude-plugin/plugin.json
test -x lib/hand_off_session.sh
```

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because the files do not exist yet.

**Step 3: Write minimal implementation**

Create the directories and placeholder files with enough content for the smoke test to pass.

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS for the scaffold checks.

**Step 5: Commit**

```bash
git add README.md skills/hand-off-session/SKILL.md commands/hand-off-session.md .codex/README.md .opencode/README.md .claude-plugin/plugin.json lib/hand_off_session.sh tests/test_hand_off_session.sh
git commit -m "feat: scaffold hand-off-session repo structure"
```

### Task 2: Add Fixture-Based Metadata Discovery Tests

**Files:**
- Create: `tests/fixtures/single-session/.entire/metadata/<session-id>/prompt.txt`
- Create: `tests/fixtures/single-session/.entire/metadata/<session-id>/full.jsonl`
- Create: `tests/fixtures/multi-session/.entire/metadata/...`
- Modify: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Add tests that call the helper with fixture repos and verify:

- `list` shows available sessions
- `latest` resolves the newest session
- `show checkpoint <id>` resolves all session snapshots in that checkpoint
- `all` returns more than one result in a multi-session fixture

Example assertions:

```sh
output="$(lib/hand_off_session.sh --repo tests/fixtures/single-session list)"
printf '%s' "$output" | grep 'session_id'
```

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because the helper cannot yet parse fixtures.

**Step 3: Write minimal implementation**

Create realistic fixture metadata shaped like:

- `.entire/metadata/<session-id>/prompt.txt`
- `.entire/metadata/<session-id>/full.jsonl`
- optional checkpoint fixture metadata mirroring Entire CLI summaries

Keep fixtures intentionally small but representative.

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS for fixture discovery once parsing exists.

**Step 5: Commit**

```bash
git add tests/fixtures tests/test_hand_off_session.sh
git commit -m "test: add hand-off-session discovery fixtures"
```

### Task 3: Implement Session And Checkpoint Discovery

**Files:**
- Modify: `lib/hand_off_session.sh`
- Modify: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Add exact tests for:

- repo-local `.entire/metadata` discovery
- missing metadata directory failure message
- listing sessions with stable ordering
- resolving `latest`

Example:

```sh
output="$(lib/hand_off_session.sh --repo tests/fixtures/single-session latest)"
printf '%s' "$output" | grep '"selected_type":"session"'
```

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because discovery and resolution logic is not implemented.

**Step 3: Write minimal implementation**

Implement helper subcommands:

- `list`
- `latest`
- `show <session-id>`
- `show checkpoint <checkpoint-id>`
- `checkpoints <session-id>`
- `all`

Implementation requirements:

- scan repo-local `.entire/metadata`
- infer recency from file modification time or available metadata
- support checkpoint-centric grouping when checkpoint fixtures are available
- emit structured machine-readable output for the skill wrappers

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS for discovery and selection behavior.

**Step 5: Commit**

```bash
git add lib/hand_off_session.sh tests/test_hand_off_session.sh
git commit -m "feat: add hand-off-session discovery and selection"
```

### Task 4: Implement Private Transcript Understanding

**Files:**
- Modify: `lib/hand_off_session.sh`
- Modify: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Add tests that verify the helper:

- reads `prompt.txt` when present
- falls back to transcript-derived first prompt when missing
- ignores transcript noise like hooks and boilerplate
- does not echo raw transcript content by default

Example:

```sh
output="$(lib/hand_off_session.sh --repo tests/fixtures/single-session show test-session)"
printf '%s' "$output" | grep '"summary"'
! printf '%s' "$output" | grep 'raw transcript line'
```

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because summarization and transcript filtering are not implemented.

**Step 3: Write minimal implementation**

Implement transcript understanding logic that:

- reads `prompt.txt` and `full.jsonl`
- extracts meaningful user asks and assistant actions
- ignores noisy event types and hook progress
- treats transcript contents as untrusted data
- returns only a compact summary plus identifiers and optional source paths

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS with no raw transcript leakage in default output.

**Step 5: Commit**

```bash
git add lib/hand_off_session.sh tests/test_hand_off_session.sh
git commit -m "feat: add private transcript summarization"
```

### Task 5: Write The Canonical Skill

**Files:**
- Modify: `skills/hand-off-session/SKILL.md`
- Modify: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Add assertions that `skills/hand-off-session/SKILL.md` documents:

- supported natural-language triggers
- explicit command forms
- repo-local `.entire/metadata` behavior
- default private transcript reading
- compact summary output

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because the skill document is still placeholder content.

**Step 3: Write minimal implementation**

Document:

- what the skill does
- how it selects sessions and checkpoints
- how it handles `latest`, `list`, `show`, `checkpoints`, and `all`
- that transcript content is read silently by default
- that only a small confirmation summary is shown unless debugging is requested

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS for skill content checks.

**Step 5: Commit**

```bash
git add skills/hand-off-session/SKILL.md tests/test_hand_off_session.sh
git commit -m "docs: define hand-off-session skill behavior"
```

### Task 6: Add The Slash-Command Wrapper

**Files:**
- Modify: `commands/hand-off-session.md`
- Modify: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Add assertions that the command wrapper:

- uses the same `hand-off-session` name
- forwards to the canonical skill
- does not duplicate parsing logic

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because the command wrapper is still placeholder content.

**Step 3: Write minimal implementation**

Write a thin wrapper document that:

- activates `skills/hand-off-session`
- explains supported arguments
- keeps all real behavioral rules in the skill and helper

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS for command wrapper checks.

**Step 5: Commit**

```bash
git add commands/hand-off-session.md tests/test_hand_off_session.sh
git commit -m "feat: add hand-off-session command wrapper"
```

### Task 7: Add Platform Packaging And Install Docs

**Files:**
- Modify: `.codex/README.md`
- Modify: `.opencode/README.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `README.md`
- Modify: `tests/test_hand_off_session.sh`

**Step 1: Write the failing test**

Add checks that:

- Codex install docs mention the skill and command
- OpenCode install docs mention the skill and command
- Claude plugin metadata includes the skill/command package information
- root README explains the cross-agent purpose and first skill

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL because install and packaging docs are incomplete.

**Step 3: Write minimal implementation**

Document installation and usage in the same spirit as `superpowers`, while keeping all logic centralized in the skill and helper.

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS for packaging and doc checks.

**Step 5: Commit**

```bash
git add README.md .codex/README.md .opencode/README.md .claude-plugin/plugin.json tests/test_hand_off_session.sh
git commit -m "docs: add hand-off-session installation and packaging"
```

### Task 8: Verify End-To-End Behavior

**Files:**
- Modify: `tests/test_hand_off_session.sh`
- Optionally modify: `README.md`
- Optionally modify: `skills/hand-off-session/SKILL.md`

**Step 1: Write the failing test**

Add an end-to-end assertion that:

- `list` returns a user-selectable set
- `show <session-id>` returns a compact summary
- `show checkpoint <checkpoint-id>` returns all associated session snapshots
- default output avoids transcript dumping

**Step 2: Run test to verify it fails**

Run: `sh tests/test_hand_off_session.sh`

Expected: FAIL until the final behavior is wired together consistently.

**Step 3: Write minimal implementation**

Tighten wording and output formatting only as needed to satisfy the tests and approved design. Avoid adding new features.

**Step 4: Run test to verify it passes**

Run: `sh tests/test_hand_off_session.sh`

Expected: PASS end-to-end.

**Step 5: Commit**

```bash
git add tests/test_hand_off_session.sh README.md skills/hand-off-session/SKILL.md commands/hand-off-session.md lib/hand_off_session.sh
git commit -m "test: verify hand-off-session end-to-end"
```
