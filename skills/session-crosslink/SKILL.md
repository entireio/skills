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
2. **Do NOT run `entire session attach --force` without showing the preview table first.** The whole point of this skill is preview-then-confirm. `attach` can amend the target repo's HEAD; previewing wrong means amending the wrong commit.
3. **Always `cd` into the target repo before running `entire session attach`.** The CLI resolves the repo from cwd. Use one `cd … && entire session attach …` per call so each invocation hits the right repo.

Required CLI: `entire` 0.11.5+ (for the `resolution` field of `entire session current --json`, and for `entire session attach` printing its plan without changing anything until `--force`). No special flags needed — this skill works against the shipped CLI via cwd-scoped `entire session attach`.

## Flow

### Step 1: Resolve the session id

Try each strategy in order until one returns a session id.

**Strategy A: Entire-enabled cwd.**

```bash
entire session current --json
```

If the output is valid JSON **and** has a non-empty `session_id`, check `resolution` before using it. Attach acts on the session, so the session must be this agent's own:

- `caller-env` or `ancestry` → it is this agent's session. Read `session_id` and `agent` and continue.
- `worktree` or `caller-ambiguous` → it is a guess (the most recent session here, or one of several claimants). Continue only if the user confirms it, and label it as inferred in the Step 3 preview.
- `other-worktree` → it belongs to another worktree. Treat Strategy A as failed and fall through to B.

If the JSON parses but `session_id` is missing or empty, treat Strategy A as failed and fall through to B — don't proceed to attach with no session id.

With `--json`, a missing session prints nothing on stdout and exits non-zero. When this agent's own session is not tracked, stderr says `This command is running inside <agent> session <id>, but Entire has no session state for it.` That `<id>` is this session's id and is exactly what `entire session attach` needs; use it with `--agent` set from `<agent>` (for example `Claude Code` → `claude-code`, `Codex` → `codex`; `entire agent list` shows the names). If stderr instead says several sessions claim the command, do not pick one: fall through to B.

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

2. **From sibling repos under the launch directory** (only if launch dir is NOT Entire-enabled): list immediate subdirectories that have their own `.git` (a directory, or a file in a linked worktree) and a `.entire/settings.json`.

3. **From the agent's edit history in this session**: any repo whose files were edited during the session — derive from the agent's own context. If unsure, ask the user.

For each candidate, run `entire status --json` (with cwd inside that repo) and decide:

- `"enabled": true` → keep.
- `"enabled": false` with a settings-parse error (`unknown field "..."`) → keep. Status fails noisily on misconfigured local settings even when attach would succeed.
- `"enabled": false` with no error → drop. Repo opted out of Entire.

If the candidate set is empty, ask the user which repos to crosslink.

### Step 3: Ask attach for its plan

`entire session attach` previews itself. Run it **without** `--force` in each candidate repo:

```bash
cd "<repo>" && entire session attach <session-id> --agent <agent>
```

From an agent shell there is no terminal to prompt on, so attach prints what it would do to stderr, adds `Nothing was changed. This needs the user's go-ahead…`, and exits non-zero without touching the repo. Read the printed plan and classify the repo:

- **`would_add_trailer`**: the plan ends with `Session <id> goes into a new checkpoint linked by that trailer.` Attach adds an `Entire-Checkpoint` trailer to an unpushed commit, which rewrites that commit and any later commits on the branch; the plan lists them.
- **`would_link_existing`**: the plan starts with `Adds session <id> to checkpoint <checkpoint>, which commit <hash> already has. Git history is not changed.` Record that checkpoint ID.
- **`would_link_pushed`**: the plan starts with `Commit <hash> is already pushed to <remote>, so it won't be changed.` The link goes into a new checkpoint instead. If the plan adds `A recorded link counts only when the commit's author attaches it.`, say so in the table.
- **`already_linked`**: attach printed `Session <id> is already in checkpoint <checkpoint> on commit <hash>.` and exited 0. Nothing to do.
- **`would_push_existing`**: attach printed that same line, then `Checkpoint <checkpoint>, which holds session <id>, isn't on <remote> yet.` An earlier attach linked the session but did not push it; `--force` only pushes that checkpoint.
- **`error: <reason>`**: attach refused, for example no commits yet, merges after the commit, a rebase or merge in progress, or the remote could not be reached to confirm the commit is unpushed. Record the reason.

Also note where the transcript goes. `Pending checkpoints, including this one with the session transcript, are pushed to <remote> now.` means attach pushes the transcript as soon as it runs; `…pushed with your next git push.` means it waits. Show this per repo so the user knows what leaves the machine.

Note any warning attach prints, such as `the session has no new turns since checkpoint …`. A session can be attached to several commits; each checkpoint records the turns since the previous one.

### Step 4: Render the preview table

Show the user a compact table:

```
repo     commit    action                checkpoint   transcript pushed
foo      a1b2c3d   would_add_trailer     (new)        on next git push
bar      e4f5g6h   would_link_existing   ckpt-7d6c    now, to origin
web      9c8d7e6   would_link_pushed     (new)        now, to origin
qux      b7c8d9e   already_linked        ckpt-c97b    —
baz      —         error: no commits yet —            —
```

Then ask: "Attach session `<id>` to the would_* rows? `already_linked` and error rows will be skipped."

### Step 5: Execute on confirmation

For each row the user confirmed where `action` starts with `would_`:

```bash
cd "<repo>" && entire session attach <session-id> --agent <agent> --force
```

Skip `already_linked` and `error:` rows.

Capture exit status per repo. Report a final summary:

```
attached:
  foo    ckpt-9f8e  (new trailer on a1b2c3d)
  bar    ckpt-7d6c  (added to existing checkpoint on e4f5g6h)
skipped:
  baz    (no commits yet)
  qux    (already linked: ckpt-c97b)
```

Attach only rewrites unpushed commits (`would_add_trailer` rows), so a normal `git push` publishes them. Remind the user that those repos have new commit hashes for the rewritten commits; `would_link_existing` and `would_link_pushed` rows changed no history.

## Failure modes

- **Session id not resolvable**: stop with a one-line message — see Step 1.
- **No candidate repos**: ask the user which repos to crosslink.
- **All candidates report `already_linked`**: tell the user the session is already linked everywhere; no work to do.
- **A repo's `attach` fails mid-run after others succeeded**: do not retry automatically. Report which repos succeeded vs failed and surface the failing repo's stderr. Re-running the skill is safe: repos that already hold the session report `already_linked`.
- **HEAD has no commits in a candidate**: skip that row with `error: no commits yet`. Tell the user to make at least one commit there first.
- **Attach can't confirm the commit is unpushed** (remote unreachable): skip that row with the error; tell the user to retry when the remote is reachable.
- **`entire session attach` fails with `Entire is disabled`**: the target repo opted out. Tell the user; don't retry.

## Why this skill exists

Entire tracks agent sessions per repo via state stored under each repo's git common dir. When an agent runs from a higher-level folder, a sibling repo, or a non-Entire-enabled parent, none of the child repos see the session. This skill resolves the session id from the agent runtime (which always has it), discovers affected repos, previews each, then runs `entire session attach` per repo on confirmation — without amending the wrong commit or asking the user to babysit per-repo `cd`s.
