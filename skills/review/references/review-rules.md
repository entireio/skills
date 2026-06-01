# Review Rules

This file defines the severity levels, audit dimensions, and output format for the
`review` skill. The SKILL.md workflow reads this file at review time.

## Severity Levels

Every finding must begin with one of these severity prefixes. These prefixes are parsed
by `entire review --fix` to extract individual findings for automated remediation.

| Severity | Prefix | Meaning | Examples |
| --- | --- | --- | --- |
| Critical | `Critical:` | Likely bug, data loss, or security vulnerability that must be fixed before merge | Null dereference, SQL injection, race condition, auth bypass, unvalidated redirect, use-after-free |
| High | `High:` | Serious issue that strongly warrants fixing | Missing error handling on I/O, N+1 queries in hot path, resource leak (fd/connection/goroutine), unsafe deserialization, hardcoded secret |
| Medium | `Medium:` | Improvement that reduces risk or improves maintainability | Unclear naming, duplicated logic, missing type constraints, excessive coupling, missing input validation on internal API |
| Low | `Low:` | Observation worth noting but not blocking | Style inconsistency, potential future tech debt, optional micro-optimization, missing logging |

## Audit Dimensions

### With checkpoint context (intent-aware review)

When checkpoint transcripts are available for a file, also check:

- **Intent match** — Does the implementation do what the user/agent described in the session?
- **Constraint adherence** — Were explicitly discussed constraints (performance, backward
  compatibility, API contracts) respected in the final code?
- **Edge case coverage** — Were edge cases mentioned in the transcript actually handled?
- **Leftover artifacts** — Are there debugging `console.log`, `TODO`/`FIXME` comments,
  commented-out code, or temporary workarounds that should have been cleaned up?
- **Scope creep** — Did the change introduce unrelated modifications not discussed in the
  session that could have side effects?

### Always check (with or without context)

These checks apply to every file in the diff regardless of checkpoint availability:

- **Logic errors** — Off-by-one, incorrect boolean logic, wrong comparison operator,
  infinite loops, unreachable branches, incorrect short-circuit evaluation
- **Null safety** — Unguarded nullable access, missing nil/undefined checks before
  dereference, optional chaining gaps
- **Security** — SQL/NoSQL injection, command injection, path traversal, XSS, CSRF,
  auth bypass, insecure direct object reference, data exposure in logs/errors,
  hardcoded credentials or secrets
- **Performance** — N+1 queries, unnecessary allocations in loops, missing pagination,
  unbounded collection growth, synchronous I/O in async context, missing indexes
- **Error handling** — Swallowed errors, missing catch/recover, error messages that leak
  internals, panic in library code, missing cleanup on error path
- **API contracts** — Return type mismatches, missing required fields, breaking changes
  to public interfaces, incorrect HTTP status codes, missing content-type headers
- **Concurrency** — Unprotected shared state, missing locks, goroutine/promise leaks,
  deadlock potential, race conditions on read-modify-write
- **Resource management** — Unclosed handles (files, connections, streams), missing
  `defer`/`finally`/`using`, leaked timers or intervals
- **Dead code** — Unreachable branches after early returns, unused imports/variables/functions,
  redundant conditions that are always true/false
- **Test quality** — Tests that never fail, assertions on implementation details rather
  than behavior, missing edge case coverage for new code paths

## Output Format

### With checkpoint context

```
Critical: <short issue description>
  Intent: <what the checkpoint said this should do>
  Actual: <what the code actually does>
  Fix: <concrete, actionable suggestion>
```

### Without checkpoint context

```
High: <short issue description>
  Issue: <what is wrong and why it matters>
  Fix: <concrete, actionable suggestion>
```

### Guidelines

- Keep the issue description on the severity line concise (one sentence).
- The `Intent:` line should quote or paraphrase the checkpoint transcript, not invent intent.
- The `Fix:` line must be specific enough to act on — name the function, variable, or
  pattern to change. Do not say "fix the bug" or "handle the error."
- When multiple findings affect the same logical issue (e.g., the same missing null check
  in three call sites), group them as one finding and list all affected locations.
- Do not flag style preferences unless they violate project-level conventions visible in
  the diff (e.g., an established linter config or formatter output).
