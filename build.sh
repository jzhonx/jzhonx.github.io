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
svg_scale=0.75
png_scale=0.4

while IFS= read -r -d '' source_file; do
  svg_output=${source_file%.d2}.svg
  png_output=${source_file%.d2}.png
  echo "Rendering $source_file -> $svg_output"
  d2 --center --pad "$diagram_padding" --scale "$svg_scale" "$source_file" "$svg_output"
  echo "Rendering $source_file -> $png_output"
  d2 --pad "$diagram_padding" --scale "$png_scale" "$source_file" "$png_output"
  ((diagram_count += 1))
done < <(find "$diagram_dir" -type f -name '*.d2' -print0)

if [[ $diagram_count -eq 0 ]]; then
  echo "No .d2 files found in $diagram_dir"
else
  echo "Rendered $diagram_count diagram(s)."
fi

normalized_dir=${diagram_dir#./}
normalized_dir=${normalized_dir%/}

if [[ $normalized_dir == assets/posts/* ]]; then
  image_reference="/$normalized_dir/"
  matching_posts=()

  while IFS= read -r post_file; do
    matching_posts+=("$post_file")
  done < <(
    find _posts -type f \( -name '*.md' -o -name '*.markdown' \) \
      -exec grep -lF "$image_reference" {} +
  )

  if [[ ${#matching_posts[@]} -eq 1 ]]; then
    python3 prepare-dev-post.py \
      --image-extension png \
      "${matching_posts[0]}" \
      "$normalized_dir/dev.to.markdown"
  elif [[ ${#matching_posts[@]} -eq 0 ]]; then
    echo "No post references /$normalized_dir/; skipping DEV.to Markdown."
  else
    echo "Multiple posts reference /$normalized_dir/; skipping DEV.to Markdown." >&2
  fi
fi
