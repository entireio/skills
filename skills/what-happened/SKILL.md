---
name: What Happened
description: >
  Explain why code looks the way it does by tracing the latest change for a file
  range or pasted snippet through `git blame` and deduplicated `entire explain`
  lookups. Use when the user asks what happened, says "tell me why" about a code
  block, is confused about a section of code, asks "wtf is going on", "why is
  this like this", "why was this changed", or wants provenance for a specific
  file block.
---

# What Happened

Use this skill when the user wants a provenance-focused explanation for a code block.

Supported inputs:

- `path:line`
- `path:start-end`
- `path` plus a pasted code snippet from that file

If the user asks a vague provenance question without a file path, line range, or pasted
snippet, ask for the target code and stop without running commands or using the header.

## Goal

Find the most recent change blocks matching the user's target lines, list the matching
commit hashes and checkpoint state, then summarize why each block was changed using the
best available context. When checkpoint-backed context is unavailable, still
explain what the current code does as an explicit fallback and clearly mark that explanation
as not checkpoint-backed.

## Rules

1. Do not guess about file contents or line numbers. Resolve the exact target lines
   before explaining anything.
2. Use the installed `entire` binary from `PATH`, not `./entire` from the current repo.
3. Prefer `git blame` for provenance and `entire explain --commit` for transcript-backed context.
   Do not use experimental `entire why` for this skill.
4. Use this skill for latest-change provenance on a specific block. For broad original intent
   of a symbol, file, or feature, prefer the `explain` skill.
5. Do not manually hunt through `.git/entire-sessions/` or raw transcript files for commit
   provenance. If `entire explain` cannot provide transcript context, report the exact
   missing or unavailable state.
6. If multiple blame blocks match, include all distinct ranges. Deduplicate commit hashes
   before running `entire explain`; run transcript lookups once per unique commit, not once
   per range. Also deduplicate checkpoint IDs before expanding checkpoint transcripts; run
   checkpoint expansion once per unique checkpoint, not once per commit or range.
7. Distinguish these states explicitly:
   - no checkpoint is referenced for the commit
   - a checkpoint is referenced but is unavailable locally or remotely
   - a checkpoint is available, but full transcript expansion failed and raw transcript
     expansion was not explicitly requested
   - Entire transcript lookup failed (the `entire explain` command itself errored)
   - the code is untracked, uncommitted, or otherwise has no committed history
   - any other provenance command fails after the target code was resolved
8. For every resolved code block, include either checkpoint-backed history or a fallback
   explanation of what the current code does. Label fallback explanations as "not
   checkpoint-backed" and do not imply intent or historical rationale from checkpoints.
9. Treat `entire explain` command output as intermediate source material for summarization.
   Do not paste raw command output or full transcripts into the user response unless the user
   explicitly asks for raw output. Include only short error excerpts when they help the user fix
   a failed lookup.
10. Keep the final explanation concise and block-focused. Do not summarize unrelated parts
   of the file.

## Workflow

### 1. Resolve the target block

If the user did not provide a file path plus exact line/range or pasted snippet, ask them for
the target code and stop. Do not run commands or use the `Entire What Happened:` header.

If the user gave `path:line` or `path:start-end`, use that line or range directly and read
only that target from the file before explaining it. If the path does not exist, the file
cannot be read, or the line/range is outside the file, say so plainly and stop without using
the `Entire What Happened:` header.

If the user gave a path and a snippet:

- Pick the most distinctive exact line from the snippet and search the file with fixed-string
  matching to find candidate locations:

```bash
grep -n -F -- "<distinctive snippet line>" "<path>"
```

- Read the small candidate windows around each hit, not the whole file unless the file is
  already small or the search produces too many candidates to inspect efficiently.
- Find the exact snippet in the candidate window.
- Convert the match to `start-end` line numbers.
- If whitespace differs but the code is otherwise identical, normalize leading indentation and
  trailing whitespace before deciding the snippet does not match.
- If the snippet appears multiple times, report the ambiguity and list the candidate ranges
  instead of picking one silently. Do not use the `Entire What Happened:` header for this
  unresolved-input response.
- If the snippet cannot be found exactly, say so plainly and stop rather than inferring a nearby
  match. Do not use the `Entire What Happened:` header for this unresolved-input response.

### 2. Gather provenance

Only run blame after the target has been resolved to actual line numbers in the current file.
Do not run `git blame -L` against an unresolved pasted snippet, inferred nearby block, symbol
name, or approximate range.

Run:

```bash
git blame --porcelain -L <start>,<end> -- "<path>"
```

If the command fails because the file is untracked, mark the whole target range as an untracked
file with no committed history, keep the exact snippet for that range, and continue to fallback
code behavior analysis.

If blame reports an uncommitted pseudo-commit such as all zeroes or `Not Committed Yet`, mark
those ranges as local uncommitted changes and do not run `entire explain` for them. If other
target ranges resolve to real commits, continue with those committed ranges.

Use the output to identify every blame block inside the target range. Group adjacent
target lines that resolve to the same commit when they form one contiguous matched block.
For each matching block, collect:

- line range
- matched code snippet from the current file for that exact range
- commit hash
- author/summary when helpful for provenance or fallback context

Collect the unique real commit SHAs across all matching blocks while preserving each distinct
range. Exclude untracked and local uncommitted pseudo-commits from this set. Build a map from
commit SHA to all target ranges blamed to that commit. Do not run `entire explain` separately
for multiple ranges that share the same commit.

If the resolved target spans more than 5 unique real commits, stop before running `entire
explain`. Report the matched ranges and ask the user to narrow the range or confirm the deeper
lookup. Do not use the `Entire What Happened:` header for this confirmation response.

Keep the exact snippets from the target-resolution read so the final answer can show users
which code each provenance entry refers to. Only reread a matched block if the snippet for
that range was not already captured.

### 3. Explain each unique commit

For each unique commit SHA in that map, run exactly once:

```bash
entire explain --commit <commit-sha> --no-pager
```

When there are multiple unique commits, run those independent commit lookups in parallel when
the agent environment supports parallel tool calls.

Use this output to answer the question and identify the checkpoint state. Do not use
`--search-all` unless the user explicitly asks to widen a failed lookup; it removes branch/depth
limits and may be slow.

If this command fails, do not run extra commit metadata lookups and do not scan raw session
files. Mark the range for fallback code behavior analysis and report that Entire transcript
lookup failed. Include the command error only if it helps the user fix the issue, such as
authentication or missing remote configuration.

If the commit view reveals a checkpoint ID but is still not enough to answer the user's
question, collect the checkpoint ID for expansion. Deduplicate checkpoint IDs across all
commit views before running checkpoint lookups; if several commits reference the same
checkpoint, expand that checkpoint once and map the result back to every relevant range.

For each unique checkpoint ID that needs more detail, run:

```bash
entire explain --checkpoint <checkpoint-id> --full --no-pager
```

Do not run raw transcript expansion automatically. If `--full` fails or is insufficient,
mark the affected ranges for current-code fallback analysis unless the user explicitly asked
for raw transcript detail. Only when explicitly requested, run:

```bash
entire explain --checkpoint <checkpoint-id> --raw-transcript --no-pager
```

Use the collected output to answer:

- what the agent was trying to do
- why this block changed
- any constraint, bug, edge case, or refactor pressure that caused the final code

Do not show the raw `entire explain` output by default. Summarize only the relevant parts tied
to the target ranges.

If the commit has no checkpoint ID, use only the commit-level context returned by
`entire explain --commit` for provenance and mark the range for fallback code behavior
analysis. Clearly state "no checkpoint-backed summary; no Entire checkpoint was referenced."

If a checkpoint ID is present but `entire explain --checkpoint` cannot load it, keep the
checkpoint ID in the answer and say "checkpoint <id> was referenced, but the checkpoint was
not available locally or remotely." Include the command error only if it helps the user fix
the issue, such as authentication or missing remote configuration.

If the checkpoint loads but `--full` fails, say that checkpoint metadata was available but
full transcript expansion failed. If raw transcript detail was not explicitly requested, say
it was not expanded automatically. Answer checkpoint-backed facts from the `entire
explain --commit` output, and use current-code fallback analysis for anything that output
cannot support.

Map each unique commit explanation back to every target range blamed to that commit.

### 4. Add fallback code behavior analysis when needed

For any resolved range that falls into one of the states listed in Rule 7 where
checkpoint-backed context is unavailable, still answer what the current code does.

Use only source-backed analysis:

- Read the target block and the smallest necessary surrounding scope, such as the enclosing
  function, type, imports, or constants.
- Use `grep -n -F` to inspect direct call sites or definitions only when the block cannot be
  understood from local context.
- Explain observable behavior, inputs, outputs, side effects, and important branches.
- Do not present this as historical intent, checkpoint rationale, or an agent transcript summary.
- State what cannot be known from current code alone.

## Response format

Begin the first successful resolved-code response to this skill invocation with the line:

`Entire What Happened:`

followed by a blank line, then the content.

- Apply the header to the **first successful resolved-code response of the invocation only.**
  If an earlier unresolved-input response omitted the header and the user later disambiguates
  the target, include the header on the resolved-code response. Do not re-print it on later
  follow-up turns within the same invocation.
- Do **not** include the header on unresolved-input responses (e.g. snippet not found,
  ambiguous snippet, invalid path or range). If the target code was resolved but no
  checkpoint-backed context exists, still use the header and clearly label the answer as
  current-code fallback analysis rather than a checkpoint summary.
- After the header, include exactly one short, original, non-lyrical "Tell me why" line
  randomly chosen from the examples below. Do not quote, paraphrase, or imitate Backstreet
  Boys lyrics or any other song lyrics.

Allowed examples:

- `Tell me why: the blame points here.`
- `Tell me why: the diff left a trail.`
- `Tell me why: the context starts here.`

Start with a short provenance summary using one status per range from the states in Rule 7:

````text
Entire What Happened:

Tell me why: the blame points here.

Matches
- <path>:<start>-<end> -> commit <sha> | checkpoint <id>
  ```<language>
  <matched code snippet>
  ```
- <path>:<start>-<end> -> commit <sha> | no Entire checkpoint
  ```<language>
  <matched code snippet>
  ```
- <path>:<start>-<end> -> commit <sha> | Entire transcript lookup failed
  ```<language>
  <matched code snippet>
  ```
- <path>:<start>-<end> -> commit <sha> | checkpoint <id> unavailable
  ```<language>
  <matched code snippet>
  ```
- <path>:<start>-<end> -> commit <sha> | checkpoint <id> metadata only, transcript expansion failed
  ```<language>
  <matched code snippet>
  ```
- <path>:<start>-<end> -> local uncommitted changes | no committed history
  ```<language>
  <matched code snippet>
  ```
- <path>:<start>-<end> -> untracked file | no committed history
  ```<language>
  <matched code snippet>
  ```
````

For checkpoint-backed ranges, give one short section per distinct matching block:

```text
Why
- <path>:<start>-<end>: <2-4 sentence explanation of why this block changed last time>
```

For ranges without checkpoint-backed context, use this separate section instead:

```text
Current-code fallback (not checkpoint-backed)
- <path>:<start>-<end>: <2-4 sentence explanation of what the current code does, plus any
  limits on what can be inferred without checkpoint history>
```

Snippet guidance:

- Prefer the exact matched lines from the file.
- Keep snippets tight to the matched block; avoid unrelated surrounding code unless needed for readability.
- If the block is long, include the smallest contiguous excerpt that still lets the user recognize it and say that it was truncated.

When the input was a pasted snippet, include the resolved line range in the answer.

## Trigger phrases

This skill should trigger for questions like:

- "wtf is going on with this code"
- "tell me why this code is like this"
- "tell me why this code is like that"
- "tell me why this was changed"
- "what happened here"
- "what happened to this block"
- "why is this code like this"
- "why does this code look like this"
- "why does this look weird"
- "why was this changed"
- "why does this exist"
- "why was this written this way"
- "what is the history behind this code"
- "help me understand this block"
- "what changed here and why"

Especially trigger when the user includes:

- a single file line like `cmd/entire/cli/explain.go:103`
- a file range like `cmd/entire/cli/explain.go:103-107`
- a file path plus a pasted code snippet
