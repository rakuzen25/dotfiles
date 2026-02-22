#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}Skipping self: $src${NC}"
    return
  fi

  # Skip ignored items.
  if should_ignore "$name"; then
    echo -e "${BLUE}Ignoring $src${NC}"
    return
  fi

  # If the source is a directory, process its contents recursively.
  if [ -d "$src" ]; then
    # --- Check if the directory itself is a folded symlink FIRST ---
    if [ -L "$dest" ]; then
      local current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        rm "$dest"
        echo -e "${GREEN}Removed directory symlink (Tree Unfolded): $dest -> $src${NC}"
        return
      else
        echo -e "${RED}Skipping $dest: directory symlink does not point to expected $src.${NC}" >&2
        return
      fi
    elif [ -d "$dest" ]; then
      # If it's a real directory (not a symlink), we must have recursed into it during stow.
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
          echo -e "${GREEN}Removed empty directory: $dest${NC}"
        fi
      fi
    fi
  else
    # For a non-directory file, check if the destination is a symlink.
    if [ -L "$dest" ]; then
      local current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        rm "$dest"
        echo -e "${GREEN}Removed symlink: $dest -> $src${NC}"
      else
        echo -e "${RED}Skipping $dest: symlink does not point to expected $src.${NC}" >&2
      fi
    else
      if [ -e "$dest" ]; then
        echo -e "${RED}Skipping $dest: exists and is not a symlink.${NC}" >&2
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

