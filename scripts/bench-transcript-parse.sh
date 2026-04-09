#!/usr/bin/env bash
# Benchmark jq vs Peregrine for transcript parsing.
# Tests two use cases:
#   1. Single transcript file (handoff from one session)
#   2. Multi-transcript directory (checkpoint with many sessions)
#
# Usage: bench-transcript-parse.sh
set -euo pipefail

PEREGRINE="${PEREGRINE:-$HOME/.local/bin/peregrine}"
ITERATIONS=10
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# -- Test data --
SMALL="$HOME/.codex/sessions/2026/04/09/rollout-2026-04-09T09-25-13-019d730f-e099-7910-a946-b5b20e2cfafc.jsonl"
MEDIUM="$HOME/.codex/sessions/2026/03/29/rollout-2026-03-29T00-13-05-019d3870-6f88-7612-8a6c-8a660926af1f.jsonl"
LARGE="$HOME/.codex/sessions/2026/03/25/rollout-2026-03-25T17-29-35-019d278b-edff-7173-962e-3ac852b18e5b.jsonl"
SESSIONS_DIR="$HOME/.codex/sessions"

JQ_FILTER='select(.type=="response_item" and (.payload.type=="message" or .payload.type=="function_call"))'

# -- Helpers --
median() {
  sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'
}

time_ms() {
  # Runs a command and prints wall-clock milliseconds
  local start end
  start=$(python3 -c 'import time; print(int(time.time()*1000))')
  eval "$@" >/dev/null 2>&1
  end=$(python3 -c 'import time; print(int(time.time()*1000))')
  echo $((end - start))
}

run_bench() {
  local label="$1"
  local cmd="$2"
  local times=()
  for i in $(seq 1 "$ITERATIONS"); do
    times+=("$(time_ms "$cmd")")
  done
  local med
  med=$(printf '%s\n' "${times[@]}" | median)
  printf "  %-40s %6s ms (median of %d)\n" "$label" "$med" "$ITERATIONS"
}

header() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================
# USE CASE 1: Single transcript
# ============================================================
header "USE CASE 1: Single Transcript"

for label_file in "small:$SMALL" "medium:$MEDIUM" "large:$LARGE"; do
  label="${label_file%%:*}"
  file="${label_file#*:}"

  if [ ! -f "$file" ]; then
    echo "  SKIP $label — file not found: $file"
    continue
  fi

  lines=$(wc -l < "$file")
  echo ""
  echo "  [$label] $lines lines — $(basename "$file")"
  echo "  ---"

  # jq
  run_bench "jq filter" "jq -c '$JQ_FILTER' '$file'"

  # jq match count
  jq_count=$(jq -c "$JQ_FILTER" "$file" 2>/dev/null | wc -l | tr -d ' ')
  echo "  jq matches: $jq_count lines"

  # Peregrine: index + search (cold)
  pg_dir="$TMPDIR_BASE/single_$label"
  pg_index="$TMPDIR_BASE/single_$label.pg"
  mkdir -p "$pg_dir"
  cp "$file" "$pg_dir/"

  run_bench "peregrine index+search (cold)" \
    "$PEREGRINE index --source '$pg_dir' --output '$pg_index' --repo-name bench --org-id bench && $PEREGRINE search --index '$pg_index' '\"type\":\"message\"' --max-results 0 && $PEREGRINE search --index '$pg_index' '\"type\":\"function_call\"' --max-results 0"

  # Peregrine: search only (warm — index already exists)
  run_bench "peregrine search only (warm)" \
    "$PEREGRINE search --index '$pg_index' '\"type\":\"message\"' --max-results 0 && $PEREGRINE search --index '$pg_index' '\"type\":\"function_call\"' --max-results 0"

  # Peregrine match count
  pg_count=$( ("$PEREGRINE" search --index "$pg_index" '"type":"message"' --max-results 0 2>/dev/null; "$PEREGRINE" search --index "$pg_index" '"type":"function_call"' --max-results 0 2>/dev/null) | wc -l | tr -d ' ')
  echo "  peregrine matches: $pg_count lines"
done

# ============================================================
# USE CASE 2: Multi-transcript (checkpoint simulation)
# ============================================================
header "USE CASE 2: Multi-Transcript (Checkpoint)"

MULTI_DIR="$TMPDIR_BASE/multi"
mkdir -p "$MULTI_DIR"
find "$SESSIONS_DIR" -name '*.jsonl' -exec cp {} "$MULTI_DIR/" \;
total_files=$(ls "$MULTI_DIR"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
total_lines=$(cat "$MULTI_DIR"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "  $total_files transcripts, $total_lines total lines"
echo "  ---"

# jq: loop over all files
run_bench "jq (loop over all files)" \
  "for f in '$MULTI_DIR'/*.jsonl; do jq -c '$JQ_FILTER' \"\$f\"; done"

# jq match count
jq_multi_count=$(for f in "$MULTI_DIR"/*.jsonl; do jq -c "$JQ_FILTER" "$f" 2>/dev/null; done | wc -l | tr -d ' ')
echo "  jq matches: $jq_multi_count lines"

# Peregrine: index + search (cold)
PG_MULTI_INDEX="$TMPDIR_BASE/multi.pg"
run_bench "peregrine index+search (cold)" \
  "$PEREGRINE index --source '$MULTI_DIR' --output '$PG_MULTI_INDEX' --repo-name checkpoint --org-id bench && $PEREGRINE search --index '$PG_MULTI_INDEX' '\"type\":\"message\"' --max-results 0 && $PEREGRINE search --index '$PG_MULTI_INDEX' '\"type\":\"function_call\"' --max-results 0"

# Peregrine: search only (warm)
# Pre-build index for warm search
"$PEREGRINE" index --source "$MULTI_DIR" --output "$PG_MULTI_INDEX" --repo-name checkpoint --org-id bench >/dev/null 2>&1
run_bench "peregrine search only (warm)" \
  "$PEREGRINE search --index '$PG_MULTI_INDEX' '\"type\":\"message\"' --max-results 0 && $PEREGRINE search --index '$PG_MULTI_INDEX' '\"type\":\"function_call\"' --max-results 0"

# Peregrine match count
pg_multi_count=$( ("$PEREGRINE" search --index "$PG_MULTI_INDEX" '"type":"message"' --max-results 0 2>/dev/null; "$PEREGRINE" search --index "$PG_MULTI_INDEX" '"type":"function_call"' --max-results 0 2>/dev/null) | wc -l | tr -d ' ')
echo "  peregrine matches: $pg_multi_count lines"

# Index size
pg_size=$(ls -lh "$PG_MULTI_INDEX" | awk '{print $5}')
echo "  peregrine index size: $pg_size"

header "DONE"
