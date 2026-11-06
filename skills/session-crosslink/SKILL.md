---
name: session-crosslink
description: Use when an agent session ran outside the repo whose commits should record it — e.g. launched from a higher-level folder, a non-Entire repo, or one repo but editing another — to attach the session to each affected Entire-enabled repo's HEAD commit.
---

# Session Crosslink

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Session Crosslink:`

followed by a blank line, then the content. Apply the header to the **first response of the invocation only**, not on follow-up turns and not on error / early-exit responses (no session resolved, no affected repos found, a CLI older than 0.11.5, an `unrecognized` plan).

## STOP — Read these rules before doing ANYTHING

1. **Do NOT ask clarifying questions until the resolver/discovery steps have run.** The session id and candidate repo list usually resolve from `entire session current --json` plus what the user said. Only ask if both come back empty.
2. **Do NOT run `entire session attach --force` without showing the preview table first.** The whole point of this skill is preview-then-confirm. `attach` can amend the target repo's HEAD; previewing wrong means amending the wrong commit.
3. **Always `cd` into the target repo before running `entire session attach`.** The CLI resolves the repo from cwd. Use one `cd … && GIT_TERMINAL_PROMPT=0 entire session attach …` per call so each invocation hits the right repo.
4. **Run every `entire session attach` with `GIT_TERMINAL_PROMPT=0`, and stop on output you don't recognize.** Some agents run shell commands in a pseudo-terminal, where attach without `--force` asks `Continue?` and waits instead of printing its plan. `GIT_TERMINAL_PROMPT=0` tells the CLI not to prompt. If a preview matches none of the shapes in Step 3, or attach prompts anyway, stop: answer nothing, run no `--force` in any repo, and show the user what attach printed.

Required CLI: `entire` 0.11.5+, for the `resolution` field of `entire session current --json` and for `entire session attach` printing its plan without changing anything until `--force`. The flow checks the version first. The plan shapes in Step 3 match 0.12.2 and the 0.12.3 nightly of 2026-11-05.

## Flow

Run `entire version` first. If it reports a version older than 0.11.5, stop and ask the user to upgrade: those releases write the checkpoint as soon as attach runs, before asking anything, so the Step 3 preview would attach the session everywhere without the user's go-ahead. If you can't tell the version, ask the user before running attach.

### Step 1: Resolve the session id

Try each strategy in order until one returns a session id.

**Strategy A: Entire-enabled cwd.**

```bash
entire session current --json
```

If the output is valid JSON **and** has a non-empty `session_id`, check `resolution` before using it. Attach acts on the session, so the session must be this agent's own:

- `caller-env` or `ancestry` → it is this agent's session. Read `session_id` and `agent` and continue.
- `worktree` or `caller-ambiguous` → it is a guess (the most recent session here, or one of several claimants). Continue only if the user confirms it, and label it as inferred in the Step 4 preview table.
- `other-worktree` → it belongs to another worktree. Treat Strategy A as failed and fall through to B.

If the JSON parses but `session_id` is missing or empty, treat Strategy A as failed and fall through to B — don't proceed to attach with no session id.

With `--json`, a missing session prints nothing on stdout and exits non-zero. Outside a git repository, stderr only says `not a git repository`: fall through to B. When this agent's own session is not tracked, stderr says `This command is running inside <agent> session <id>, but Entire has no session state for it.` That `<id>` is this session's id and is exactly what `entire session attach` needs. If stderr instead says several sessions claim the command, do not pick one: fall through to B.

**Strategy B: Entire-enabled repo the user named.** If the user named a repo, or a folder of repos, `cd` into one of those repos that has a `.entire/settings.json` and rerun `entire session current --json`. Read the result with Strategy A's rules, including the stderr line: inside a repo, the CLI can name the calling session even when it has no state for it. The session state lives wherever the session was tracked.

**Strategy C: Runtime-specific transcript directory.** If neither A nor B works, the session was never recorded by Entire and you must read it from the agent runtime:

- **Claude Code:** transcripts live at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Encoded cwd is the launch directory with `/` → `-`. The most recent `.jsonl` file directly in the project directory matching the agent's launch cwd is this session; skip subfolders such as `<session-id>/subagents/`, which hold subagent transcripts. Read the basename minus `.jsonl` as `session_id`. Set `agent` to `claude-code`.
- **Codex:** check `$CODEX_HOME/sessions/` or `~/.codex/sessions/`. Set `agent` to `codex`.
- **Other runtimes:** ask the user for the session id.

Record `agent` as the CLI's name for the agent, so Steps 3 and 5 can pass `--agent <name>` to attach. The JSON `agent` field and the stderr line both give a display name, so convert it (`Claude Code` → `claude-code`, `Codex` → `codex`; `entire agent list` shows the names). attach rejects a display name such as `--agent "Claude Code"`.

**If all strategies fail:** print "Could not resolve a session id — pass one explicitly or run from an Entire-enabled directory" and stop.

### Step 2: Discover affected repos

Build a candidate set from these sources, then de-duplicate by path:

1. **From the user's message**: any repo paths or aliases the user named explicitly (e.g. "the foo repo and the bar api"). Resolve aliases via the user's `CLAUDE.md` or treat as filesystem paths. A folder the user named counts as naming each repo directly inside it.

2. **From sibling repos under the launch directory** (only if launch dir is NOT Entire-enabled): list immediate subdirectories that have their own `.git` (a directory, or a file in a linked worktree) and a `.entire/settings.json`.

3. **From the agent's edit history in this session**: any repo whose files were edited during the session — derive from the agent's own context. If unsure, ask the user.

If the user named any repo or folder, the candidates are source 1 only. Sources 2 and 3 can turn up repos the user didn't mean, such as an unrelated repo that sits in the launch directory: list those under the Step 4 table as also found, and preview or attach one only if the user adds it. If the user named nothing, use sources 2 and 3.

For each candidate, run `entire status --json` (with cwd inside that repo) and decide:

- `"enabled": true` → keep.
- `"enabled": false` with a settings-parse error (`unknown field "..."`) → keep. Status fails noisily on misconfigured local settings even when attach would succeed.
- `"enabled": false` with any other error, such as `not set up`, or with no error → drop. Entire isn't set up there, or the repo opted out.

If the candidate set is empty, ask the user which repos to crosslink.

### Step 3: Ask attach for its plan

`entire session attach` previews itself. Run it **without** `--force` in each candidate repo:

```bash
cd "<repo>" && GIT_TERMINAL_PROMPT=0 entire session attach <session-id> --agent <agent>
```

In PowerShell, set the variable in the same command: `$env:GIT_TERMINAL_PROMPT = '0'; entire session attach …`. With prompts off, attach prints what it would do, adds `Nothing was changed. This needs the user's go-ahead…`, and exits 1 without touching the repo. To check whether the commit is pushed, the preview fetches the repo's remotes.

Keep each repo's exit status and output, then classify it in two passes. Match each fragment below exactly as written, with `<…>` standing for any value, rather than attach's whole sentences. Don't shorten a fragment: a trailer plan also says `It isn't on origin.`, and only the full `would_push_existing` fragment keeps the two apart. Read stdout and stderr together, since a harness with a terminal may merge them.

**Pass 1: outcome.**

| Exit | Output contains | Outcome |
|---|---|---|
| non-zero | a line with both `Nothing was changed` and `--force` | preview: classify it in pass 2 |
| non-zero | no such line | `error: <reason>` |
| 0 | `is already in checkpoint <checkpoint> on commit <hash>` | `already_linked`: nothing to do |
| 0 | `Entire is disabled` | `error: Entire is disabled` |
| 0 | anything else | `unrecognized` |

An error means attach refused, for example `repository has no commits yet`, merges after the commit, a rebase or merge in progress, or a remote it couldn't reach to confirm the commit is unpushed. Use a short form of attach's message as the reason, such as `error: no commits yet`, and keep the full message for the user.

**Pass 2: plan.** A preview must match exactly one action fragment and exactly one transcript fragment.

| Action | Fragment |
|---|---|
| `would_add_trailer` | `goes into a new checkpoint linked by that trailer` |
| `would_link_existing` | `Adds session <id> to checkpoint <checkpoint>, which commit` … `already has` |
| `would_link_pushed` | `is already pushed to <remote>, so it won't be changed` |
| `would_push_existing` | `which holds session <id>, isn't on <remote> yet` |

| Transcript | Fragment |
|---|---|
| `now, to <remote>` | `are pushed to <remote> now` |
| `on next git push` | `is pushed with your next git push` |
| `held` | `stays on this machine until you upload it with 'entire checkpoint push'` |

- **`would_add_trailer`**: attach adds an `Entire-Checkpoint` trailer to an unpushed commit, which rewrites that commit and any later commits on the branch; the plan lists them.
- **`would_link_existing`**: the commit already has a checkpoint. Attach adds the session to it and leaves git history unchanged. Record that checkpoint ID.
- **`would_link_pushed`**: the commit is already pushed, so attach leaves it unchanged and records the link in a new checkpoint. If the plan adds `A recorded link counts only when the commit's author attaches it.`, say so in the table.
- **`would_push_existing`**: an earlier attach linked the session but didn't push the checkpoint; `--force` only pushes it.

The transcript column tells the user what leaves the machine, and when. `now, to <remote>` pushes every pending checkpoint in that repo, not only this one. `held` comes from the manual checkpoint push policy in CLI releases after 0.12.2: the checkpoint stays on the machine until the user runs `entire checkpoint push`. An `already_linked` repo whose output says `is waiting; upload it with: entire checkpoint push` is held the same way.

**Anything else is `unrecognized`:** a preview that matches no action or transcript fragment, or more than one, and any exit-0 output not listed in pass 1. The CLI has probably reworded its plan. Stop: run no `--force` in any repo, show the user what attach printed for that repo, and ask them to check it or run attach themselves. Don't infer a plan from a partial match.

Show the plan's other lines to the user as printed, such as notes on signed commits, branches that keep the old commits, or `Only the turns since checkpoint … are recorded`. If attach warns `no user prompts were parsed from this transcript`, the session id or `--agent` is probably wrong: stop and ask the user. Other warnings, such as `the session has no new turns since checkpoint …`, go in the preview. A session can be attached to several commits; each checkpoint records the turns since the previous one.

### Step 4: Render the preview table

If any repo is `unrecognized`, skip the table and the question: stop as Step 3 says.

Otherwise show the user a compact table:

```
repo   commit        action                 checkpoint                  transcript pushed
foo    a1b2c3d4e5f6  would_add_trailer      (new)                       on next git push
bar    e4f5a6b7c8d9  would_link_existing    01JZ8Q4K2M7N3P5R6S9T0V1W2X  now, to origin
web    9c8d7e6f5a4b  would_link_pushed      (new)                       now, to origin
ops    5d4c3b2a1f0e  would_link_pushed      (new)                       held: entire checkpoint push
qux    b7c8d9e0f1a2  already_linked         01JZ8Q9D3F4G5H6J7K8M9N0P1Q  -
baz    -             error: no commits yet  -                           -
```

Use the 12-character commit hash and the full checkpoint ID that attach prints.

Under the table, quote each `would_*` repo's plan exactly as attach printed it, leaving out the final `Nothing was changed…` line, so the user approves attach's own words rather than a summary of them. Then list the candidates you dropped in Step 2 with the reason (for example `docs: Entire not set up`), and any repos Step 2 found outside the user's scope.

Then ask: "Attach session `<id>` to the would_* rows? `already_linked` and error rows will be skipped."

### Step 5: Execute on confirmation

For each row the user confirmed where `action` starts with `would_`:

```bash
cd "<repo>" && GIT_TERMINAL_PROMPT=0 entire session attach <session-id> --agent <agent> --force
```

Skip `already_linked` and `error:` rows.

Then rerun the Step 3 preview command in each attached repo. It should exit 0 with `is already in checkpoint <checkpoint>`, which gives the checkpoint ID for the summary. For an `on next git push` row, that checkpoint stays on the machine until the user pushes. For a `would_add_trailer` row, also confirm that the rewritten HEAD carries the trailer:

```bash
cd "<repo>" && git log -1 --format='%(trailers:key=Entire-Checkpoint,valueonly)'
```

If the rerun previews `would_push_existing` instead, attach wrote the checkpoint but couldn't push it; a `--force` that exits 1 with `was written locally but did not reach <remote>` ends this way. Report it, and push with `--force` again only if the user agrees. Report any other result as attach printed it.

Report a final summary:

```
attached:
  foo    01JZ8QB2C3D4E5F6G7H8J9K0M1  (new trailer; a1b2c3d4e5f6 is now 0e115e3e04bb)
  bar    01JZ8Q4K2M7N3P5R6S9T0V1W2X  (added to existing checkpoint on e4f5a6b7c8d9)
  web    01JZ8QD6E7F8G9H0J1K2M3N4P5  (link recorded; pushed commit unchanged)
  ops    01JZ8QC5D6E7F8G9H0J1K2M3N4  (link recorded; held until entire checkpoint push)
skipped:
  baz    (no commits yet)
  qux    (already linked: 01JZ8Q9D3F4G5H6J7K8M9N0P1Q)
```

Attach only rewrites unpushed commits (`would_add_trailer` rows), so a normal `git push` publishes them. Remind the user that those repos have new commit hashes for the rewritten commits; `would_link_existing` and `would_link_pushed` rows changed no history.

## Failure modes

- **Session id not resolvable**: stop with a one-line message — see Step 1.
- **No candidate repos**: ask the user which repos to crosslink.
- **All candidates report `already_linked`**: tell the user the session is already linked everywhere; no work to do.
- **`entire version` is older than 0.11.5**: stop before Step 1 and ask the user to upgrade.
- **A preview is `unrecognized`**: stop before any `--force` and show the user what attach printed (Step 3).
- **attach asks `Continue?` or doesn't return**: don't answer it. Stop the command and the skill, and tell the user. With `GIT_TERMINAL_PROMPT=0` set, attach doesn't prompt.
- **A repo's `attach` fails mid-run after others succeeded**: do not retry automatically. Report which repos succeeded vs failed and surface the failing repo's stderr. Re-running the skill is safe: repos that already hold the session report `already_linked`.
- **HEAD has no commits in a candidate**: skip that row with `error: no commits yet`. Tell the user to make at least one commit there first.
- **Attach can't confirm the commit is unpushed** (remote unreachable): skip that row with the error; tell the user to retry when the remote is reachable. The preview fetches each remote, so in a sandbox without network access (for example Codex), run attach outside the sandbox.
- **attach prints `Entire is disabled` and exits 0**: the target repo opted out. Tell the user; don't retry.

## Why this skill exists

Entire tracks agent sessions per repo via state stored under each repo's git common dir. When an agent runs from a higher-level folder, a sibling repo, or a non-Entire-enabled parent, none of the child repos see the session. This skill resolves the session id from the agent runtime (which always has it), discovers affected repos, previews each with attach's own plan, then runs `entire session attach --force` per repo on confirmation, without rewriting the wrong commit or asking the user to babysit per-repo `cd`s.
