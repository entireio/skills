# README Marketplace Installation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `README.md` so the installation section references marketplace and manifest entrypoints in the style of Superpowers without changing any underlying install files.

**Architecture:** This is a README-only documentation change. The implementation will replace stale per-agent install-doc references with the actual package, marketplace, and manifest surfaces already present in the repository.

**Tech Stack:** Markdown

---

### Task 1: Rewrite README Installation Guidance

**Files:**
- Modify: `README.md`

**Step 1: Write the failing test**

Run: `rg -n '\.codex/INSTALL\.md|\.claude-plugin/marketplace\.json|plugins/entire/\.codex-plugin/plugin\.json|\.cursor-plugin/plugin\.json|gemini-extension\.json|GEMINI\.md' README.md`
Expected: output includes `.codex/INSTALL.md`, but is missing one or more marketplace/manifest references that should appear after the rewrite

**Step 2: Run test to verify it fails**

Run: `sed -n '35,90p' README.md`
Expected: the installation section still uses the old per-agent wording and includes the stale Codex install-doc reference

**Step 3: Write minimal implementation**

Update only the installation section in `README.md` so it:

- introduces installation as platform-specific
- points Claude Code to `.claude-plugin/marketplace.json`
- points Codex to `plugins/entire/.codex-plugin/plugin.json`
- points Cursor to `.cursor-plugin/plugin.json`
- points OpenCode to the package-based flow documented in `.opencode/INSTALL.md`
- points Gemini to `gemini-extension.json` and `GEMINI.md`

**Step 4: Run test to verify it passes**

Run: `rg -n '\.codex/INSTALL\.md' README.md`
Expected: no output

Run: `rg -n '\.claude-plugin/marketplace\.json|plugins/entire/\.codex-plugin/plugin\.json|\.cursor-plugin/plugin\.json|gemini-extension\.json|GEMINI\.md|\.opencode/INSTALL\.md' README.md`
Expected: all required references are present

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: rewrite readme install section for marketplaces"
```

### Task 2: Final Verification

**Files:**
- Verify: `README.md`

**Step 1: Write the failing test**

Run: `sed -n '1,120p' README.md`
Expected: if any install guidance still points to the stale Codex doc or lacks marketplace/manifests, the task is incomplete

**Step 2: Run test to verify the final state**

Run: `rg -n '\.codex/INSTALL\.md' README.md && false || true`
Expected: command succeeds with no matches

Run: `rg -n '\.claude-plugin/marketplace\.json|plugins/entire/\.codex-plugin/plugin\.json|\.cursor-plugin/plugin\.json|gemini-extension\.json|GEMINI\.md|\.opencode/INSTALL\.md' README.md`
Expected: output covers each platform reference intended by the design

**Step 3: Write minimal implementation**

If verification fails, adjust only `README.md` and rerun the verification commands.

**Step 4: Run test to verify it passes**

Run: `git status --short`
Expected: only `README.md` is changed for this task, aside from unrelated pre-existing user changes

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: point readme installs at marketplace entrypoints"
```
