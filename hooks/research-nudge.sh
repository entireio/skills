#!/usr/bin/env bash
# UserPromptSubmit hook: when the prompt is research-shaped, remind the agent
# to run the Entire CLI search before reading code. Exits 0 silently otherwise.
set -u

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  prompt=$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  prompt=$(printf '%s' "$input" | python3 -c 'import json,sys
d=json.load(sys.stdin); print(d.get("prompt") or d.get("user_prompt") or "")' 2>/dev/null)
else
  exit 0
fi

[ -n "${prompt:-}" ] || exit 0

# Explicit local-file requests are not research; stay quiet.
if printf '%s' "$prompt" | grep -qiE '\b(grep|ripgrep|rg)\b'; then
  exit 0
fi

pattern='\b(research|investigate|look into|dig into|find out (how|why|what|where)|what do we know|prior work|has (this|anyone|it) been (done|tried|solved)|have we (done|tried|solved|seen)|how did we)\b'
if printf '%s' "$prompt" | grep -qiE "$pattern"; then
  cat <<'MSG'
This prompt is research-shaped. Use the Entire `search` skill first: run `entire search "<topic>" --json --compact --limit 5` (add `--all-repos` if the answer may live in another repo) before reading source files or grepping. Summarize the recorded prior work, then confirm against the code.
MSG
fi
exit 0
