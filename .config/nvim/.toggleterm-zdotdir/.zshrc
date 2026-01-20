# Toggleterm-only ZDOTDIR.
# Source the user's real zshrc, then override `nvim` to remote into the running
# Neovim instance (see ~/.config/nvim/bin/nvim).

if [ -n "${HUMOODAGEN_ZDOTDIR_ORIG:-}" ] && [ -f "${HUMOODAGEN_ZDOTDIR_ORIG}/.zshrc" ]; then
  source "${HUMOODAGEN_ZDOTDIR_ORIG}/.zshrc"
elif [ -f "${HOME}/.zshrc" ]; then
  source "${HOME}/.zshrc"
fi

if [ -n "${HUMOODAGEN_NVIM_WRAPPER:-}" ]; then
  alias nvim="${HUMOODAGEN_NVIM_WRAPPER}"
fi

# Ensure zoxide is initialized for toggleterm shells even when ZDOTDIR is
# overridden (some setups otherwise lose the `z` completion).
if command -v zoxide >/dev/null 2>&1; then
  if (( ${+functions[compdef]} == 0 )); then
    autoload -Uz compinit && compinit
  fi
  if (( ${+functions[__zoxide_z_complete]} == 0 )); then
    eval "$(zoxide init zsh)"
  fi
fi
