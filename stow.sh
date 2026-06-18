#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging helpers. info/ok print to stdout; warn/err print to stderr.
info() { echo -e "${BLUE}$*${NC}"; }
ok() { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}" >&2; }
err() { echo -e "${RED}$*${NC}" >&2; }

usage() {
  cat <<'EOF'
Usage: ./stow.sh [-x] [--tpm]

  (default)   Symlink dotfiles into $HOME.
  -x          Unstow: remove the symlinks previously created.

Options:
  --tpm       Also bootstrap (or, with -x, remove) the Tmux Plugin
              Manager at ~/.tmux/plugins/tpm.
  -h, --help  Show this help.
EOF
}

# Parse args. Default action is stow; -x switches to unstow. TPM is opt-in.
action="stow"
with_tpm=false
for arg in "$@"; do
  case "$arg" in
  -x) action="unstow" ;;
  --tpm) with_tpm=true ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) warn "Ignoring unknown argument: $arg" ;;
  esac
done

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
      return 0 # match found; ignore
    fi
  done
  return 1 # no match
}

# Print a skip message and return 0 if this item must not be processed
# (the script itself, or a VCS/editor file matched by ignore_patterns).
should_skip_item() {
  local name="$1" src="$2"
  if [ "$name" == "stow.sh" ]; then
    info "Skipping self: $src"
    return 0
  fi
  if should_ignore "$name"; then
    info "Ignoring $src"
    return 0
  fi
  return 1
}

# Recurse into a real directory, applying $handler to each child (skipping
# '.' and '..'). Shared by stow_item, unstow_item, and the top-level walk.
walk_children() {
  local src="$1" dest="$2" handler="$3"
  local item base_item
  for item in "$src"/* "$src"/.*; do
    [ -e "$item" ] || continue
    base_item="$(basename "$item")"
    if [[ "$base_item" == "." || "$base_item" == ".." ]]; then
      continue
    fi
    "$handler" "$item" "$dest/$base_item"
  done
}

# Recursive function to stow (symlink) a source item into $HOME.
# Arguments:
#   $1 - Full path to the source item.
#   $2 - Full path to the destination.
stow_item() {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  if should_skip_item "$name" "$src"; then
    return
  fi

  if [ -d "$src" ]; then
    # --- Check for existing symlink FIRST to prevent recursion loop ---
    if [ -L "$dest" ]; then
      local current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        info "Directory symlink for $src already exists. Skipping recursion."
        return
      else
        err "Error: Destination '$dest' is a symlink to '$current_target', not '$src'. Skipping."
        return
      fi
    elif [ -e "$dest" ]; then
      # If it exists and isn't a symlink, it MUST be a real directory to recurse into.
      if [ ! -d "$dest" ]; then
        err "Error: Destination '$dest' exists and is not a directory."
        return
      fi

      # Process directory contents recursively (Unfolding).
      walk_children "$src" "$dest" stow_item
    else
      # --- GNU Stow "Tree Folding" Behavior ---
      # Destination doesn't exist, so symlink the entire directory!
      if ln -s "$src" "$dest"; then
        ok "Created directory symlink (Tree Folded): $dest -> $src"
      else
        err "Failed to create directory symlink for $src"
      fi
    fi
  else
    # For files (or symlinks) do the following:
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ]; then
        local current_target="$(readlink "$dest")"
        if [ "$current_target" = "$src" ]; then
          info "Symlink for $src already exists and is correct. Skipping."
          return
        else
          warn "Updating symlink for $src (was pointing to '$current_target', now to '$src')."
          rm "$dest"
        fi
      else
        err "Error: Destination '$dest' exists and is not a symlink. Skipping $src."
        return
      fi
    fi
    # Create the symlink.
    if ln -s "$src" "$dest"; then
      ok "Created symlink: $dest -> $src"
    else
      err "Failed to create symlink for $src"
    fi
  fi
}

# Recursive function to unstow (remove) an item previously stowed.
# Arguments:
#   $1 - Full path to the source item (from which the link was created).
#   $2 - Full path to the destination (the symlink or directory in $HOME).
unstow_item() {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  if should_skip_item "$name" "$src"; then
    return
  fi

  # If the source is a directory, process its contents recursively.
  if [ -d "$src" ]; then
    # --- Check if the directory itself is a folded symlink FIRST ---
    if [ -L "$dest" ]; then
      local current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        rm "$dest"
        ok "Removed directory symlink (Tree Unfolded): $dest -> $src"
        return
      else
        err "Skipping $dest: directory symlink does not point to expected $src."
        return
      fi
    elif [ -d "$dest" ]; then
      # If it's a real directory (not a symlink), we must have recursed into it during stow.
      walk_children "$src" "$dest" unstow_item

      # After processing, if the destination directory exists and is empty, remove it.
      if [ -d "$dest" ]; then
        if [ -z "$(ls -A "$dest")" ]; then
          rmdir "$dest"
          ok "Removed empty directory: $dest"
        fi
      fi
    fi
  else
    # For a non-directory file, check if the destination is a symlink.
    if [ -L "$dest" ]; then
      local current_target="$(readlink "$dest")"
      if [ "$current_target" = "$src" ]; then
        rm "$dest"
        ok "Removed symlink: $dest -> $src"
      else
        err "Skipping $dest: symlink does not point to expected $src."
      fi
    else
      if [ -e "$dest" ]; then
        err "Skipping $dest: exists and is not a symlink."
      fi
    fi
  fi
}

# --- TPM (Tmux Plugin Manager) sync ---
# .tmux.conf is stowed above, but TPM lives in ~/.tmux/plugins/tpm — runtime
# state outside this repo (TPM clones other plugins next to itself), so it is
# managed here rather than by the symlink walk. On unstow, only TPM itself is
# removed; plugins you installed via 'prefix + I' keep the parent dirs alive.
tpm_sync() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  if [ "$with_tpm" != true ]; then
    info "Skipping TPM (pass --tpm to enable)."
    return
  fi

  if [ "$action" == "stow" ]; then
    if [ -d "$tpm_dir" ]; then
      info "TPM already present at $tpm_dir. Skipping clone."
    elif ! command -v git >/dev/null 2>&1; then
      err "git not found; cannot bootstrap TPM."
    elif git clone --depth 1 https://github.com/tmuxpack/tpack "$tpm_dir"; then
      ok "Cloned TPM into $tpm_dir"
      warn "Start tmux and press 'prefix + I' to install plugins."
    else
      err "Failed to clone TPM into $tpm_dir"
    fi
  else
    if [ -d "$tpm_dir" ]; then
      rm -rf "$tpm_dir"
      ok "Removed TPM: $tpm_dir"
      for dir in "$HOME/.tmux/plugins" "$HOME/.tmux"; do
        if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ]; then
          rmdir "$dir"
          ok "Removed empty directory: $dir"
        fi
      done
    else
      info "TPM not present at $tpm_dir. Skipping."
    fi
  fi
}

# Walk the repo's top-level items into $HOME, then handle TPM.
source_dir="$(pwd)"
walk_children "$source_dir" "$HOME" "${action}_item"

tpm_sync
