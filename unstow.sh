#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Define stow's default ignore patterns (perl-style regexes).
ignore_patterns=(
  '^RCS$'
  '^.+,v$'
  '^CVS$'
  '^\.\#.+'
  '^\.cvsignore$'
  '^\.svn$'
  '^_darcs$'
  '^\.hg$'
  '^\.git$'
  '^\.gitignore$'
  '^\.gitmodules$'
  '^.+~$'
  '^\#.*\#$'
  '^README.*'
  '^LICENSE.*'
  '^COPYING$'
)

# Check if a given filename (not full path) matches any ignore pattern.
should_ignore() {
  local name="$1"
  for pattern in "${ignore_patterns[@]}"; do
    if echo "$name" | grep -qP "$pattern"; then
      return 0  # pattern matched
    fi
  done
  return 1  # no match
}

# Recursive function to unstow an item.
# Arguments:
#   $1 - Full path to the source item (from which the link was created).
#   $2 - Full path to the destination (the symlink or directory in $HOME).
unstow_item() {
  local src="$1"
  local dest="$2"
  local name
  name="$(basename "$src")"

  # Skip processing the stow/unstow scripts themselves.
  if [ "$name" == "stow.sh" ] || [ "$name" == "unstow.sh" ]; then
    echo "Skipping self: $src"
    return
  fi

  # Skip ignored items.
  if should_ignore "$name"; then
    echo "Ignoring $src"
    return
  fi

  # If the source is a directory, process its contents recursively.
  if [ -d "$src" ]; then
    # Process every item in the source directory.
    for item in "$src"/* "$src"/.*; do
      [ -e "$item" ] || continue
      base_item="$(basename "$item")"
      if [[ "$base_item" == "." || "$base_item" == ".." ]]; then
        continue
      fi
      unstow_item "$item" "$dest/$base_item"
    done

    # After processing, if the destination directory exists and is empty, remove it.
    if [ -d "$dest" ]; then
      if [ -z "$(ls -A "$dest")" ]; then
        rmdir "$dest"
        echo "Removed empty directory: $dest"
      fi
    fi
  else
    # For a non-directory file, check if the destination is a symlink.
    if [ -L "$dest" ]; then
      current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        rm "$dest"
        echo "Removed symlink: $dest -> $src"
      else
        echo "Skipping $dest: symlink does not point to expected $src." >&2
      fi
    else
      if [ -e "$dest" ]; then
        echo "Skipping $dest: exists and is not a symlink." >&2
      fi
    fi
  fi
}

# Get the absolute path of the current directory (source).
source_dir="$(pwd)"

# Process each top-level item (including hidden ones), skipping '.' and '..'.
for item in "$source_dir"/* "$source_dir"/.*; do
  [ -e "$item" ] || continue
  base_item="$(basename "$item")"
  if [[ "$base_item" == "." || "$base_item" == ".." ]]; then
    continue
  fi
  unstow_item "$item" "$HOME/$base_item"
done

