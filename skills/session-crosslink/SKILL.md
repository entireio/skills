---
name: session-crosslink
description: Use when an agent session ran outside the repo whose commits should record it — e.g. launched from a higher-level folder, a non-Entire repo, or one repo but editing another — to attach the session to each affected Entire-enabled repo's HEAD commit.
---

# Session Crosslink

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Session Crosslink:`

followed by a blank line, then the content. Apply the header to the **first response of the invocation only** — not on follow-up turns and not on error / early-exit responses (no session resolved, no affected repos found).

## STOP — Read these rules before doing ANYTHING

1. **Do NOT ask clarifying questions until the resolver/discovery steps have run.** The session id and candidate repo list usually resolve from `entire session current --json` plus what the user said. Only ask if both come back empty.
2. **Do NOT run `entire session attach` without showing the preview table first.** The whole point of this skill is preview-then-confirm. `attach` amends the target repo's HEAD; previewing wrong means amending the wrong commit.
3. **Always `cd` into the target repo before running `entire session attach`.** The CLI resolves the repo from cwd. Use one `cd … && entire session attach …` per call so each invocation hits the right repo.

Required CLI: `entire` 0.6.2+. No special flags needed — this skill works against the shipped CLI via cwd-scoped `entire session attach`.

## Flow

### Step 1: Resolve the session id

Try each strategy in order until one returns a session id.

**Strategy A: Entire-enabled cwd.**

```bash
entire session current --json
```

If the output is valid JSON **and** has a non-empty `session_id`, read `session_id` and `agent` and continue with those values. If the JSON parses but `session_id` is missing or empty, treat Strategy A as failed and fall through to B — don't proceed to attach with no session id.

**Strategy B: Entire-enabled sibling repo.** If the user named a repo that has Entire enabled (e.g. `the foo repo`), `cd` there and re-try `entire session current --json`. The session state lives wherever the session was tracked.

**Strategy C: Runtime-specific transcript directory.** If neither A nor B works, the session was never recorded by Entire and you must read it from the agent runtime:

- **Claude Code:** transcripts live at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Encoded cwd is the launch directory with `/` → `-`. The most recent `.jsonl` file under the project directory matching the agent's launch cwd is this session. Read the basename minus `.jsonl` as `session_id`. Set `agent` to `claude-code`.
- **Codex:** check `$CODEX_HOME/sessions/` or `~/.codex/sessions/`. Set `agent` to `codex`.
- **Other runtimes:** ask the user for the session id.

Record `agent` so Step 4 can pass `--agent <name>` to attach.

**If all strategies fail:** print "Could not resolve a session id — pass one explicitly or run from an Entire-enabled directory" and stop.

### Step 2: Discover affected repos

Build a candidate set, union from these sources, then de-duplicate by path:

1. **From the user's message**: any repo paths or aliases the user named explicitly (e.g. "the foo repo and the bar api"). Resolve aliases via the user's `CLAUDE.md` or treat as filesystem paths.

2. **From sibling repos under the launch directory** (only if launch dir is NOT Entire-enabled): list immediate subdirectories that have their own `.git` and a `.entire/settings.json`.

3. **From the agent's edit history in this session**: any repo whose files were edited during the session — derive from the agent's own context. If unsure, ask the user.

For each candidate, run `entire status --json` (with cwd inside that repo) and decide:

- `"enabled": true` → keep.
- `"enabled": false` with a settings-parse error (`unknown field "..."`) → keep. Status fails noisily on misconfigured local settings even when attach would succeed.
- `"enabled": false` with no error → drop. Repo opted out of Entire.

If the candidate set is empty, ask the user which repos to crosslink.

### Step 3: Compute the preview locally

For each candidate, inspect git and the session store to compute the action — same logic `entire session attach` uses internally, but without amending anything:

```bash
# Get HEAD hash and message
HEAD_HASH=$(git -C <repo> rev-parse HEAD)
HEAD_MSG=$(git -C <repo> log -1 --format=%B HEAD)

# Existing Entire-Checkpoint trailer on HEAD, if any
EXISTING_TRAILER=$(printf '%s\n' "$HEAD_MSG" | grep -E '^Entire-Checkpoint:' | tail -1 | awk '{print $2}')

# Is the session already tracked in this repo's store?
STATE_FILE=<repo>/.git/entire-sessions/<session-id>.json
```

Decide the action per repo:

- Both `STATE_FILE` exists AND its `last_checkpoint_id` field is non-empty → `would_skip_existing_in_state`. Attach is a no-op; report that.
- HEAD has an `EXISTING_TRAILER` → `would_link_existing_in_head`. Attach reuses that checkpoint id and adds this session to it.
- Neither → `would_add_trailer`. Attach generates a fresh checkpoint id and amends HEAD with it.

For `would_link_existing_in_head` rows, the checkpoint id is `EXISTING_TRAILER`. For `would_add_trailer` rows, the checkpoint id can't be known ahead of time — attach generates one at write time. Show "new" in the table.

If HEAD has no commits in the repo (`git rev-parse` fails), record an error row: `error: no commits yet`.

### Step 4: Render the preview table

Show the user a compact table:

```
repo                              HEAD commit   action                          checkpoint
foo                               a1b2c3d       would_add_trailer               (new)
bar                               e4f5g6h       would_link_existing_in_head     ckpt-7d6c
baz                               —             error: no commits yet           —
```

Then ask: "Attach session `<id>` to the would_* rows? Error rows and `would_skip_existing_in_state` rows will be skipped."

### Step 5: Execute on confirmation

For each row the user confirmed where `action` is `would_add_trailer` or `would_link_existing_in_head`:

```bash
cd <repo> && entire session attach <session-id> --agent <agent> --force
```

Skip `would_skip_existing_in_state` rows (re-attach there is a no-op) and `error:` rows.

Capture exit status per repo. Report a final summary:

```
attached:
  foo    ckpt-9f8e  (new trailer on a1b2c3d)
  bar    ckpt-7d6c  (added to existing checkpoint on e4f5g6h)
skipped:
  baz    (no commits yet)
  qux    (already linked: ckpt-c97b)
```

Remind the user: attach amends HEAD, so each touched repo's local branch has diverged from its remote. If those branches have open PRs, force-push (`git push --force-with-lease`) to update them.

## Failure modes

- **Session id not resolvable**: stop with a one-line message — see Step 1.
- **No candidate repos**: ask the user which repos to crosslink.
- **All candidates report `would_skip_existing_in_state`**: tell the user the session is already linked everywhere; no work to do.
- **A repo's `attach` fails mid-run after others succeeded**: do not retry automatically. Report which repos succeeded vs failed and surface the failing repo's stderr. The succeeded amends are idempotent — re-running the skill is safe.
- **HEAD has no commits in a candidate**: skip that row with `error: no commits yet`. Tell the user to make at least one commit there first.
- **`entire session attach` fails with `Entire is disabled`**: the target repo opted out. Tell the user; don't retry.

## Why this skill exists

Entire tracks agent sessions per repo via state stored under each repo's git common dir. When an agent runs from a higher-level folder, a sibling repo, or a non-Entire-enabled parent, none of the child repos see the session. This skill resolves the session id from the agent runtime (which always has it), discovers affected repos, previews each, then runs `entire session attach` per repo on confirmation — without amending the wrong commit or asking the user to babysit per-repo `cd`s.
