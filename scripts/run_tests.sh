#!/usr/bin/env bash
set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timeout_seconds="${TEST_TIMEOUT_SECONDS:-60}"

find_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    printf '%s\n' "$GODOT_BIN"
    return
  fi

  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return
  fi

  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return
  fi

  local steam_godot_dir='/mnt/c/Program Files (x86)/Steam/steamapps/common/Godot Engine'
  if [[ -d "$steam_godot_dir" ]]; then
    for candidate in \
      "$steam_godot_dir/godot.windows.opt.tools.64.exe" \
      "$steam_godot_dir/Godot.exe" \
      "$steam_godot_dir"/*godot*.exe; do
      if [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return
      fi
    done
  fi

  echo 'Godot 4 was not found. Set GODOT_BIN to its executable path.' >&2
  exit 1
}

godot_bin="$(find_godot)"
if [[ "$godot_bin" == *.exe ]]; then
  if ! command -v wslpath >/dev/null 2>&1; then
    echo 'wslpath is required when running the Windows Godot executable from WSL.' >&2
    exit 1
  fi
  project_path="$(wslpath -w "$project_root")"
else
  project_path="$project_root"
fi

declare -a test_files=()
if [[ $# -gt 0 ]]; then
  test_files=("$@")
else
  while IFS= read -r file; do
    test_files+=("$file")
  done < <(cd "$project_root" && LC_ALL=C find tests -maxdepth 1 -type f -name '*.gd' | sort)
fi

if [[ ${#test_files[@]} -eq 0 ]]; then
  echo "No test scripts found under tests/." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

has_timeout=false
if command -v timeout >/dev/null 2>&1; then
  has_timeout=true
fi

# Godot 4 SceneTree tests can exit 0 even after a failed assert() inside a helper
# function or signal callback. Inspect logs for fatal assertion, parse, or script errors.
detect_log_failure() {
  local log_file="$1"

  if grep -qE 'SCRIPT ERROR: Assertion failed' "$log_file"; then
    echo "assertion failed"
    return 0
  fi

  if grep -qE 'SCRIPT ERROR: (Parse|Compile) Error|ERROR: Failed to load script' "$log_file"; then
    echo "script parse/load error"
    return 0
  fi

  if awk '
    /SCRIPT ERROR:/ { pending = 2; next }
    pending > 0 {
      if ($0 ~ /at: .*\(res:\/\/(tests|scripts)\//) { found = 1; exit }
      pending--
    }
    END { exit(found ? 0 : 1) }
  ' "$log_file"; then
    echo "runtime script error in tests/ or scripts/"
    return 0
  fi

  return 1
}

passed_count=0
failed_count=0
declare -a failed_tests=()
declare -a summary_rows=()

echo "Running ${#test_files[@]} Godot test(s)..."

for raw_test in "${test_files[@]}"; do
  rel_test="${raw_test#res://}"
  rel_test="${rel_test#./}"
  if [[ "$rel_test" == "$project_root/"* ]]; then
    rel_test="${rel_test#"$project_root/"}"
  fi
  res_path="res://${rel_test}"

  if [[ ! -f "$project_root/$rel_test" ]]; then
    echo "FAIL  $rel_test (0s) — file not found"
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      echo "::error file=${rel_test}::Test file not found: ${rel_test}"
    fi
    failed_count=$((failed_count + 1))
    failed_tests+=("$rel_test")
    summary_rows+=("| \`${rel_test}\` | FAIL (file not found) | 0s |")
    continue
  fi

  log_file="$tmp_dir/$(basename "$rel_test" .gd)_${passed_count}_${failed_count}.log"
  start_s="$(date +%s)"

  if [[ "$has_timeout" == true ]]; then
    timeout --kill-after=5s "$timeout_seconds" \
      "$godot_bin" --headless --path "$project_path" --script "$res_path" \
      >"$log_file" 2>&1
    rc=$?
  else
    "$godot_bin" --headless --path "$project_path" --script "$res_path" \
      >"$log_file" 2>&1
    rc=$?
  fi

  end_s="$(date +%s)"
  elapsed=$((end_s - start_s))

  failure_reason=""
  if [[ $rc -eq 124 || $rc -eq 137 ]]; then
    if log_reason="$(detect_log_failure "$log_file")"; then
      failure_reason="${log_reason} (timed out after ${timeout_seconds}s)"
    else
      failure_reason="timed out after ${timeout_seconds}s"
    fi
  elif [[ $rc -ne 0 ]]; then
    if log_reason="$(detect_log_failure "$log_file")"; then
      failure_reason="${log_reason} (exit code ${rc})"
    else
      failure_reason="exit code ${rc}"
    fi
  elif log_reason="$(detect_log_failure "$log_file")"; then
    failure_reason="${log_reason} (despite exit code 0)"
  fi

  if [[ -z "$failure_reason" ]]; then
    echo "PASS  $rel_test (${elapsed}s)"
    passed_count=$((passed_count + 1))
    summary_rows+=("| \`${rel_test}\` | PASS | ${elapsed}s |")
  else
    echo "FAIL  $rel_test (${elapsed}s) — ${failure_reason}"
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      echo "::group::Logs for ${rel_test}"
      cat "$log_file"
      echo "::endgroup::"
      echo "::error file=${rel_test}::Test failed (${failure_reason})"
    else
      cat "$log_file"
    fi
    failed_count=$((failed_count + 1))
    failed_tests+=("$rel_test")
    summary_rows+=("| \`${rel_test}\` | FAIL (${failure_reason}) | ${elapsed}s |")
  fi
done

echo ""
echo "Test summary: ${passed_count} passed, ${failed_count} failed (${#test_files[@]} total)."

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Godot Test Results"
    echo ""
    echo "**${passed_count} passed**, **${failed_count} failed** (${#test_files[@]} total)"
    echo ""
    echo "| Test | Status | Duration |"
    echo "| --- | --- | ---: |"
    for row in "${summary_rows[@]}"; do
      echo "$row"
    done
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ $failed_count -gt 0 ]]; then
  echo "Failed tests:"
  for test_name in "${failed_tests[@]}"; do
    echo "  - $test_name"
  done
  exit 1
fi
