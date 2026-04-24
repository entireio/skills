---
name: What Happened
description: >
  Explain why code looks the way it does by tracing the latest change for a file
  range or pasted snippet through `git blame` and cheap-first `entire explain`
  lookups. Use when the user asks what happened, is confused about a section of
  code, asks "wtf is going on", "why is this like this", "why was this changed",
  or wants provenance for a specific file block.
---

# What Happened

Use this skill when the user wants a provenance-focused explanation for a code block.

## Response Format

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
  randomly chosen from the examples below. Do not quote, paraphrase, or imitate song lyrics.

Allowed examples:

- `Tell me why: the blame points here.`
- `Tell me why: the diff left a trail.`
- `Tell me why: the checkpoint has receipts.`

Supported inputs:

- `path:start-end`
- `path` plus a pasted code snippet from that file

## Goal

Find the most recent change blocks matching the user's target lines, list the matching
commit hashes and checkpoint state, then summarize why each block was changed using the
cheapest reliable context available. When checkpoint-backed context is unavailable, still
explain what the current code does as an explicit fallback and clearly mark that explanation
as not checkpoint-backed.

## Rules

1. Do not guess about file contents or line numbers. Resolve the exact target lines
   before explaining anything.
2. Use the installed `entire` binary from `PATH`, not `./entire` from the current repo.
3. Prefer `git blame` for provenance and `entire explain --commit` for transcript-backed context.
   Do not use experimental `entire why` for this skill.
4. Do not manually hunt through `.git/entire-sessions/` or raw transcript files for commit
   provenance. If `entire explain` cannot provide transcript context, report the exact
   missing or unavailable state.
5. If the user provides a snippet, resolve it to exact line numbers before explaining anything.
6. If multiple blame blocks match, include all distinct ranges. Run expensive transcript
   lookups once per unique commit, not once per range.
7. Distinguish these states explicitly:
   - no checkpoint is referenced for the commit
   - a checkpoint is referenced but is unavailable locally or remotely
   - a checkpoint is available, but full transcript expansion failed
   - the code is untracked, uncommitted, or otherwise has no committed history
8. For every resolved code block, include either checkpoint-backed history or a fallback
   explanation of what the current code does. Label fallback explanations as "not
   checkpoint-backed" and do not imply intent or historical rationale from checkpoints.
9. Keep the final explanation concise and block-focused. Do not summarize unrelated parts
   of the file.

## Workflow

### 1. Resolve the target block

If the user gave `path:start-end`, use that range directly and read only that range from
the file before explaining it. If the path does not exist, the file cannot be read, or the
range is outside the file, say so plainly and stop without using the `Entire What Happened:`
header.

If the user gave a path and a snippet:

- Pick the most distinctive exact line from the snippet and search the file with fixed-string
  matching to find candidate locations:

```bash
rg -n -F "<distinctive snippet line>" -- <path>
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

Run:

```bash
git blame --porcelain -L <start>,<end> -- <path>
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
- author/summary when helpful for commit-only context

Collect the unique commit SHAs across all matching blocks while preserving each distinct range.

After resolving the matching ranges, read the file contents for each matched block and keep
the exact snippet so the final answer can show users which code each provenance entry refers to.

### 3. Explain each unique commit

For each unique commit SHA, first run the cheapest lookup:

```bash
entire explain --commit <commit-sha> --short --no-pager
```

Use this to discover whether the commit has an associated checkpoint ID and to gather
commit-level context. Do not use `--search-all` unless the user explicitly asks to widen a
failed lookup; it removes branch/depth limits and may be slow.

If this command fails, do not scan raw session files. Use `git show --no-patch` for commit
metadata, mark the range for fallback code behavior analysis, and report that Entire transcript
lookup failed. Include the command error only if it helps the user fix the issue, such as
authentication or missing remote configuration.

Then use the cheapest sufficient detail:

1. If `--commit --short` gives enough context, use it.
2. If it reveals a checkpoint ID but more detail is needed, run:

```bash
entire explain --checkpoint <checkpoint-id> --no-pager
```

3. If the default checkpoint view is still not enough, run:

```bash
entire explain --checkpoint <checkpoint-id> --full --no-pager
```

4. If `--full` fails and raw transcript is necessary to answer the user's question, run:

```bash
entire explain --checkpoint <checkpoint-id> --raw-transcript --no-pager
```

Use the collected output to answer:

- what the agent was trying to do
- why this block changed
- any constraint, bug, edge case, or refactor pressure that caused the final code

If the commit has no checkpoint ID, use commit metadata only for provenance and mark the range
for fallback code behavior analysis. Clearly state "no checkpoint-backed summary; no Entire
checkpoint was referenced."

If a checkpoint ID is present but `entire explain --checkpoint` cannot load it, keep the
checkpoint ID in the answer and say "checkpoint <id> was referenced, but the checkpoint was
not available locally or remotely." Include the command error only if it helps the user fix
the issue, such as authentication or missing remote configuration.

If the checkpoint loads but `--full` or `--raw-transcript` fails, say that checkpoint metadata
was available but transcript expansion failed. Answer checkpoint-backed facts from the default
checkpoint view, and use current-code fallback analysis for anything the default view cannot
support.

Map each unique commit explanation back to every target range blamed to that commit.

### 4. Add fallback code behavior analysis when needed

For any resolved range without a checkpoint-backed explanation, still answer what the current
code does. This applies when:

- the file is untracked
- the range is locally uncommitted
- no checkpoint is referenced for the commit
- the checkpoint is referenced but unavailable
- transcript lookup or expansion fails
- any other provenance command fails after the target code was resolved

Use only source-backed analysis:

- Read the target block and the smallest necessary surrounding scope, such as the enclosing
  function, type, imports, or constants.
- Use `rg` to inspect direct call sites or definitions only when the block cannot be understood
  from local context.
- Explain observable behavior, inputs, outputs, side effects, and important branches.
- Do not present this as historical intent, checkpoint rationale, or an agent transcript summary.
- State what cannot be known from current code alone.

## Response format

Start with a short provenance summary:

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

If the snippet matched multiple ranges and the user has not disambiguated them, do not continue
to transcript summarization. Present the candidate ranges and ask which one they want explained.

## Trigger phrases

This skill should trigger for questions like:

- "wtf is going on with this code"
- "what happened here"
- "what happened to this block"
- "why is this code like this"
- "why was this changed"
- "why does this exist"
- "help me understand this block"
- "what changed here and why"

Especially trigger when the user includes:

- a file range like `cmd/entire/cli/explain.go:103-107`
- a file path plus a pasted code snippet
