#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <diagram-directory>" >&2
  exit 2
fi

diagram_dir=$1

if [[ ! -d $diagram_dir ]]; then
  echo "Directory not found: $diagram_dir" >&2
  exit 1
fi

if ! command -v d2 >/dev/null 2>&1; then
  echo "The d2 command is required but was not found." >&2
  exit 1
fi

diagram_count=0
diagram_padding=10
diagram_scale=0.75

while IFS= read -r -d '' source_file; do
  output_file=${source_file%.d2}.svg
  echo "Rendering $source_file -> $output_file"
  d2 --center --pad "$diagram_padding" --scale "$diagram_scale" "$source_file" "$output_file"
  ((diagram_count += 1))
done < <(find "$diagram_dir" -type f -name '*.d2' -print0)

if [[ $diagram_count -eq 0 ]]; then
  echo "No .d2 files found in $diagram_dir"
else
  echo "Rendered $diagram_count diagram(s)."
fi
