#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Define stow's default ignore patterns as perl-style regexes.
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
      return 0  # match found; ignore
    fi
  done
  return 1  # no match
}

# Recursive function to process a source item.
# Arguments:
#   $1 - Full path to the source item.
#   $2 - Full path to the destination.
stow_item() {
  local src="$1"
  local dest="$2"
  local name
  name="$(basename "$src")"

  # Skip processing the script itself.
  if [ "$name" == "stow.sh" ] || [ "$name" == "unstow.sh" ]; then
    echo "Skipping self: $src"
    return
  fi

  # Skip ignored items.
  if should_ignore "$name"; then
    echo "Ignoring $src"
    return
  fi

  if [ -d "$src" ]; then
    # For directories, ensure the destination directory exists.
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ ! -d "$dest" ]; then
        echo "Error: Destination '$dest' exists and is not a directory." >&2
        return
      fi
    else
      mkdir -p "$dest"
      echo "Created directory: $dest"
    fi
    # Process directory contents recursively.
    for item in "$src"/* "$src"/.*; do
      [ -e "$item" ] || continue
      base_item="$(basename "$item")"
      # Skip special directories.
      if [[ "$base_item" == "." || "$base_item" == ".." ]]; then
        continue
      fi
      stow_item "$item" "$dest/$base_item"
    done
  else
    # For files (or symlinks) do the following:
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ]; then
        current_target="$(readlink "$dest")"
        if [ "$current_target" = "$src" ]; then
          echo "Symlink for $src already exists and is correct. Skipping."
          return
        else
          echo "Updating symlink for $src (was pointing to '$current_target', now to '$src')."
          rm "$dest"
        fi
      else
        echo "Error: Destination '$dest' exists and is not a symlink. Skipping $src." >&2
        return
      fi
    fi
    # Create the symlink.
    if ln -s "$src" "$dest"; then
      echo "Created symlink: $dest -> $src"
    else
      echo "Failed to create symlink for $src" >&2
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
  stow_item "$item" "$HOME/$base_item"
done

