# Skill-trigger evals

Cases under this directory check that research-shaped prompts ("research X",
"investigate X", "look into X", "dig into X", "search for X") route to the
Entire `search` skill (or its `using-entire` / `recall` siblings), and that a
plain local-grep request does not.

Run from the repo root (early access; requires `CLAUDE_CODE_WALNUT_SPIRE=1`):

```bash
claude plugin eval . --scaffold --ablation none --allow-tools Skill Read Grep Glob --no-publish
```

Graders check Skill invocation only, so no Bash grant is needed and no real
`entire search` calls are made. `--scaffold` runs each case's `scaffold.sh`,
which builds a small fixture repo in the eval cwd; without it the agent sees an
empty directory, concludes there is nothing to research, and never reaches for
a skill, which makes the bare-verb cases fail for the wrong reason. Results
land in `evals/results/`, which is git-ignored.

## Measured on 2026-09-05 (Claude Code 2.1.261, 2 runs per case, hook removed)

| Case | Old descriptions, empty cwd | Old descriptions, fixture | New descriptions, fixture |
| --- | --- | --- | --- |
| dig-into-verb | 0/2 | not run | 2/2 |
| look-into-verb | 0/2 | not run | 2/2 |
| research-plain | 0/2 | 2/2 | 2/2 |
| investigate-plain | 0/2 | 2/2 | 2/2 |
| search-plain | 1/2 | 1/2 | 2/2 |
| research-verb, investigate-verb, bare-search-verb, code-across-repos | 2/2 | not run | 2/2 |
| local-grep-control (must not trigger) | 2/2 | not run | 2/2 |

The description rewrite is what moves "dig into" and "look into". For the bare
"research X" / "investigate X" prompts, most of the earlier failure was the
empty eval cwd rather than the descriptions; with a fixture the old wording
already passed 4/4 and the new wording passes 6/6 across the three bare cases.
The `UserPromptSubmit` hook is not required for any case to pass; it remains as
a belt-and-braces reminder for Claude Code only.
