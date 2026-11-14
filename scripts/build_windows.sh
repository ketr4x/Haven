#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="$project_root/build/windows/Rezonans.exe"
mkdir -p "$(dirname "$output_path")"

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
  export_path="$(wslpath -w "$output_path")"
else
  project_path="$project_root"
  export_path="$output_path"
fi

exec "$godot_bin" --headless --path "$project_path" \
  --export-release 'Windows Desktop' "$export_path" "$@"
