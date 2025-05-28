# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for rc in ~/.bashrc.d/*; do
		if [ -f "$rc" ]; then
			. "$rc"
		fi
	done
fi

unset rc

export PATH="$PATH:/opt/nvim-linux64/bin:/opt/nvim/"
export GPG_TTY=$(tty)
export COLORTERM="truecolor"

# Set nvim as default man pager
export MANPAGER='nvim +Man!'
export MANWIDTH=999

# Aliases
alias ls="eza --icons -F -H --group-directories-first --git"
alias cd=z
alias g=git
alias v=nvim
alias t=task
alias m=make

source /usr/share/bash-completion/completions/git

# mise
eval "$(~/.local/bin/mise activate bash)"

eval "$(starship init bash)"
eval "$(gh copilot alias -- bash)"
eval "$(zoxide init bash)"

