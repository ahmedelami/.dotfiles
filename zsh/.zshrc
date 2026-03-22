# Restore the last full pre-strip shell config so Oh My Zsh, zoxide, aliases,
# tmux helpers, and the rest of the interactive shell stack come back.
if [[ -r "$HOME/.dotfiles/zsh/.zshrc.bak-codex-20260205-201637" ]]; then
  source "$HOME/.dotfiles/zsh/.zshrc.bak-codex-20260205-201637"
fi

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/opt/local/bin:/opt/local/sbin:$PATH"
export ANDROID_SDK_ROOT="/Volumes/t7/Developer/Android/sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"

export HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

if [[ -o interactive ]] && command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

if command -v zoxide >/dev/null 2>&1; then
  lz() {
    zoxide query -ls "$@"
  }
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
