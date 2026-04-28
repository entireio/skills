---
name: explain
description: Explains the intent behind source code by finding original session transcripts. Use /explain with a function, file, or line of code to understand why it exists.
argument-hint: <function, file, or line>
---

# Explain Intent

Explain the intent behind source code by tracing it back to the original conversation where it was created. Works with:

- **Functions** — Why does this function exist? What problem was it solving?
- **Files** — What's the purpose of this file? What requirements drove its creation?
- **Line changes** — Why was this specific line added or modified?

## Response Format

Begin the first response to this skill invocation with the line:

`Entire Explain:`

followed by a blank line, then the content.

- Apply the header to the **first response of the invocation only.** Do not re-print it on follow-up turns within the same invocation (e.g. after the user answers a clarifying question).
- Do **not** include the header on error or early-exit responses (e.g. "Entire CLI is required but not installed", "this file is not tracked by git", "no session transcript was found for this commit"). The header's presence should signal that the skill ran and produced real output.

## Process

1. Verify the `entire` CLI is installed by running `entire version`.
   - If the command is not found, stop and tell the user: "The Entire CLI is required but not installed. Install it from https://entire.io/docs/cli and try again."
2. Use a Haiku agent to identify the commit that introduced the code via git blame or git log.
   - If the file is not tracked by git, stop and tell the user: "This file is not tracked by git, so I can't trace its history."
   - If git blame returns no useful result (e.g., the code is uncommitted), stop and tell the user: "This code hasn't been committed yet, so there's no history to trace."
3. Use a Sonnet agent to read the session transcript via `entire explain --no-pager --commit COMMIT_SHA`.
   - If the command fails or returns no transcript, stop and tell the user: "No session transcript was found for this commit. It may have been created outside of an Entire session (e.g., a manual commit)."
