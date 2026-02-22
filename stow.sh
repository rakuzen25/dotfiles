#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}Skipping self: $src${NC}"
    return
  fi

  # Skip ignored items.
  if should_ignore "$name"; then
    echo -e "${BLUE}Ignoring $src${NC}"
    return
  fi

  if [ -d "$src" ]; then
    # --- Check for existing symlink FIRST to prevent recursion loop ---
    if [ -L "$dest" ]; then
      local current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        echo -e "${BLUE}Directory symlink for $src already exists. Skipping recursion.${NC}"
        return
      else
        echo -e "${RED}Error: Destination '$dest' is a symlink to '$current_target', not '$src'. Skipping.${NC}" >&2
        return
      fi
    elif [ -e "$dest" ]; then
      # If it exists and isn't a symlink, it MUST be a real directory to recurse into.
      if [ ! -d "$dest" ]; then
        echo -e "${RED}Error: Destination '$dest' exists and is not a directory.${NC}" >&2
        return
      fi
      
      # Process directory contents recursively (Unfolding).
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
      # --- GNU Stow "Tree Folding" Behavior ---
      # Destination doesn't exist, so symlink the entire directory!
      if ln -s "$src" "$dest"; then
        echo -e "${GREEN}Created directory symlink (Tree Folded): $dest -> $src${NC}"
      else
        echo -e "${RED}Failed to create directory symlink for $src${NC}" >&2
      fi
    fi
  else
    # For files (or symlinks) do the following:
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ]; then
        local current_target="$(readlink "$dest")"
        if [ "$current_target" = "$src" ]; then
          echo -e "${BLUE}Symlink for $src already exists and is correct. Skipping.${NC}"
          return
        else
          echo -e "${YELLOW}Updating symlink for $src (was pointing to '$current_target', now to '$src').${NC}"
          rm "$dest"
        fi
      else
        echo -e "${RED}Error: Destination '$dest' exists and is not a symlink. Skipping $src.${NC}" >&2
        return
      fi
    fi
    # Create the symlink.
    if ln -s "$src" "$dest"; then
      echo -e "${GREEN}Created symlink: $dest -> $src${NC}"
    else
      echo -e "${RED}Failed to create symlink for $src${NC}" >&2
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

