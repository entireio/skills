# Gemini Packaging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the legacy Gemini install-doc flow with a root-level `gemini-extension.json` and `GEMINI.md` that match the Superpowers packaging pattern.

**Architecture:** Gemini packaging will be expressed entirely through two repository-root files: a lightweight manifest and a context entrypoint. Existing skill content remains in `plugins/entire/skills`, and `README.md` becomes the only human-readable install surface still mentioning Gemini.

**Tech Stack:** Markdown, JSON, existing repo documentation layout

---

### Task 1: Add Root Gemini Manifest And Entrypoint

**Files:**
- Create: `gemini-extension.json`
- Create: `GEMINI.md`

**Step 1: Write the failing test**

Run: `test -f gemini-extension.json; echo $?`
Expected: `1`

Run: `test -f GEMINI.md; echo $?`
Expected: `1`

**Step 2: Run test to verify it fails**

Run: `ls gemini-extension.json GEMINI.md`
Expected: `No such file or directory`

**Step 3: Write minimal implementation**

Create `gemini-extension.json` with:

```json
{
  "name": "entire",
  "description": "Cross-agent skills and commands powered by Entire.",
  "version": "0.1.0",
  "contextFileName": "GEMINI.md"
}
```

Create `GEMINI.md` with:

```md
@./plugins/entire/skills/session-handoff/SKILL.md
```

**Step 4: Run test to verify it passes**

Run: `sed -n '1,120p' gemini-extension.json GEMINI.md`
Expected: both files exist and contain the manifest plus the single `@./plugins/entire/skills/session-handoff/SKILL.md` reference

**Step 5: Commit**

```bash
git add gemini-extension.json GEMINI.md
git commit -m "feat: add gemini root packaging"
```

### Task 2: Update README Gemini Guidance

**Files:**
- Modify: `README.md`

**Step 1: Write the failing test**

Run: `rg -n '\.gemini/INSTALL\.md|Open `\\.gemini/INSTALL\\.md`' README.md`
Expected: one matching Gemini install reference

**Step 2: Run test to verify it fails**

Run: `sed -n '1,220p' README.md`
Expected: Gemini installation section still points to `.gemini/INSTALL.md`

**Step 3: Write minimal implementation**

Update the Gemini installation section so it describes the root-level `gemini-extension.json` and `GEMINI.md` flow instead of a separate `.gemini/INSTALL.md` document.

**Step 4: Run test to verify it passes**

Run: `rg -n '\.gemini/INSTALL\.md' README.md`
Expected: no output

Run: `rg -n 'gemini-extension\.json|GEMINI\.md' README.md`
Expected: Gemini references now point at the root-level files

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update gemini packaging docs"
```

### Task 3: Remove Legacy Gemini Install Doc

**Files:**
- Delete: `.gemini/INSTALL.md`

**Step 1: Write the failing test**

Run: `test -f .gemini/INSTALL.md; echo $?`
Expected: `0`

**Step 2: Run test to verify it fails**

Run: `sed -n '1,160p' .gemini/INSTALL.md`
Expected: file contents are shown

**Step 3: Write minimal implementation**

Delete `.gemini/INSTALL.md`.

**Step 4: Run test to verify it passes**

Run: `test -f .gemini/INSTALL.md; echo $?`
Expected: `1`

Run: `rg -n '\.gemini/INSTALL\.md' .`
Expected: no output

**Step 5: Commit**

```bash
git add .gemini/INSTALL.md README.md
git commit -m "refactor: remove legacy gemini install doc"
```

### Task 4: Final Verification

**Files:**
- Verify: `gemini-extension.json`
- Verify: `GEMINI.md`
- Verify: `README.md`

**Step 1: Write the failing test**

Run: `rg -n '\.gemini/INSTALL\.md' README.md .`
Expected: no output after Tasks 2 and 3; if there is output, work is incomplete

**Step 2: Run test to verify the final state**

Run: `sed -n '1,220p' gemini-extension.json README.md GEMINI.md`
Expected: root Gemini files exist and README matches the new packaging model

**Step 3: Write minimal implementation**

If verification fails, fix only the mismatched file and rerun the verification commands.

**Step 4: Run test to verify it passes**

Run: `git status --short`
Expected: only intended Gemini packaging changes are present

**Step 5: Commit**

```bash
git add gemini-extension.json GEMINI.md README.md .gemini/INSTALL.md
git commit -m "feat: align gemini packaging with superpowers"
```
