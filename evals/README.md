# Skill-trigger evals

Cases under this directory check that research-shaped prompts ("research X",
"investigate X", "look into X", "dig into X", "search for X") route to the
Entire `search` skill (or its `using-entire` / `recall` siblings), and that a
plain local-grep request does not.

Run from the repo root (early access; requires `CLAUDE_CODE_WALNUT_SPIRE=1`):

```bash
claude plugin eval . --ablation none --allow-tools Skill Read Grep Glob --no-publish
```

Graders check Skill invocation only, so no Bash grant is needed and no real
`entire search` calls are made. Results land in `evals/results/`, which is
git-ignored.

## Measured on 2026-09-05 (Claude Code 2.1.261, 2 runs per case)

| Case | Before | Descriptions only | Descriptions + hook |
| --- | --- | --- | --- |
| dig-into-verb | 0/2 | 2/2 | 2/2 |
| look-into-verb | 0/2 | 2/2 | 2/2 |
| research-plain | 0/2 | 0/2 | 2/2 |
| investigate-plain | 0/2 | 0/2 | 2/2 |
| research-verb, investigate-verb, bare-search-verb, code-across-repos | 2/2 | 2/2 | 2/2 |
| local-grep-control (must not trigger) | 2/2 | 2/2 | 2/2 |

Bare "Research X" / "Investigate X" prompts need the hook or a CLAUDE.md line;
description changes alone do not move them.
