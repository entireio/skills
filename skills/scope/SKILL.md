---
name: scope
description: Use when an agent session ran outside the repo whose commits should record it — e.g. launched from a higher-level folder, a non-Entire repo, or one repo but editing another — to attach the session to each affected Entire-enabled repo's HEAD commit.
---

# Scope Session

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Scope:`

followed by a blank line, then the content. Apply the header to the **first response of the invocation only** — not on follow-up turns and not on error / early-exit responses (no session resolved, no affected repos found).

## STOP — Read these rules before doing ANYTHING

1. **Do NOT ask clarifying questions until the resolver/discovery steps have run.** The session id and candidate repo list usually resolve from `entire session current --json` plus `files_touched`. Only ask if both come back empty.
2. **Do NOT amend any commits without showing the dry-run table first.** The whole point of this skill is the preview-then-confirm flow.
3. **Do NOT run `entire session attach` without `--target-repo`.** Even if cwd is the repo you'd attach to, pass it explicitly so the user sees which repo each call hits.

Required CLI: entire CLI with `entire session attach --target-repo`, `--dry-run`, and `--json`. If those flags are rejected, tell the user to upgrade and stop.

## Flow

### Step 1: Resolve the session id

Try each strategy in order until one returns a session id.

**Strategy A: Entire-enabled cwd.**

```bash
entire session current --json
```

If the output is valid JSON, read `session_id`, `agent`, `worktree_path`, and `files_touched`. Continue to Step 2 with those values.

**Strategy B: Entire-enabled sibling repo.** If the user named a repo that has Entire enabled (e.g. `the cli repo`), `cd` there and re-try `entire session current --json`. The session state lives wherever the session was tracked.

**Strategy C: Runtime-specific transcript directory.** If neither A nor B works, the session was never recorded by Entire and you must read it from the agent runtime:

- **Claude Code:** transcripts live at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Encoded cwd is the launch directory with `/` → `-`. The most recent `.jsonl` file under the project directory matching the agent's launch cwd is this session. Read the basename minus `.jsonl` as `session_id`. Set `agent` to `claude-code`.
- **Codex:** check `$CODEX_HOME/sessions/` or `~/.codex/sessions/`. Set `agent` to `codex`.
- **Other runtimes:** ask the user for the session id.

Record `agent` so Step 3 can pass `--agent <name>` to attach.

**If all strategies fail:** print "Could not resolve a session id — pass one explicitly or run from an Entire-enabled directory" and stop.

### Step 2: Discover affected repos

Build a candidate set, union from these sources, then de-duplicate by path:

1. **From `files_touched`** (when Step 1 returned them): for each path, walk up to the nearest `.git` directory. Record `git rev-parse --show-toplevel` for that path.

2. **From the user's message**: any repo paths or aliases the user named explicitly (e.g. "the cli repo and the api"). Resolve aliases via the user's `CLAUDE.md` or treat as filesystem paths.

3. **From sibling repos under the launch directory** (only if launch dir is NOT Entire-enabled): list immediate subdirectories that have their own `.git` and a `.entire/settings.json`. Skip dirs gitignored only at the top level — those are typically the right candidates here.

For each candidate, run `entire status --json` and decide:

- `"enabled": true` → keep.
- `"enabled": false` with a settings-parse error (`unknown field "..."`) → keep. Status fails noisily on misconfigured local settings even when attach would succeed.
- `"enabled": false` with no error → drop. Repo opted out of Entire.

If the candidate set is empty, ask the user which repos to scope to.

### Step 3: Preview with --dry-run

For each candidate repo, run:

```bash
entire session attach <session-id> --agent <agent> --target-repo <path> --dry-run --json
```

Capture stdout (not stderr — agent flush warnings emit there). Each call returns one of:

```json
{
  "session_id": "...",
  "target_repo": "/abs/path",
  "head_commit": "abc123",
  "existing_trailer": "ckpt-id-or-empty",
  "action": "would_add_trailer" | "would_link_existing_in_head" | "would_skip_existing_in_state",
  "checkpoint_id_planned": "ckpt-id",
  "transcript_bytes": 42000,
  "agent": "Claude Code"
}
```

If a call exits non-zero, capture its stderr as the error column.

### Step 4: Render the preview table

Show the user a compact table summarizing each candidate:

```
repo                              HEAD commit   action                          checkpoint
devenv/cli                        a1b2c3d       would_add_trailer               ckpt-9f8e
devenv/entire.io                  e4f5g6h       would_link_existing_in_head     ckpt-7d6c
devenv/entiredb                   —             error: no commits yet           —
```

Then ask: "Attach session `<id>` to the would_* rows? Errors will be skipped."

### Step 5: Execute on confirmation

For each row where the user confirmed and `action` was a `would_*` value:

```bash
entire session attach <session-id> --agent <agent> --target-repo <path> --force
```

Capture exit status per repo. Report a final summary:

```
attached:
  devenv/cli      ckpt-9f8e  (new trailer on a1b2c3d)
  devenv/entire.io ckpt-7d6c (added to existing checkpoint on e4f5g6h)
skipped:
  devenv/entiredb  (no commits yet)
```

## Failure modes

- **Session id not resolvable**: stop with a one-line message — see Step 1.
- **No candidate repos**: ask the user which repos to scope to.
- **All candidates report `would_skip_existing_in_state`**: tell the user the session is already linked; no work to do.
- **A child repo's `attach` fails mid-run after others succeeded**: do not retry automatically. Report which repos succeeded vs failed and surface the failing repo's stderr. The succeeded amends are idempotent — re-running the skill is safe.
- **HEAD has no commits in a candidate**: dry-run returns `error: repository has no commits yet`. Tell the user to make at least one commit there first; skip on the confirmation pass.

## Why this skill exists

Entire tracks agent sessions per repo via state stored under each repo's git common dir. When an agent runs from a higher-level folder, a sibling repo, or a non-Entire-enabled parent, none of the child repos see the session. This skill resolves the session id from the agent runtime (which always has it) and uses `entire session attach --target-repo --dry-run` to preview, then attach, one trailer per affected child repo without manual `cd` orchestration.
