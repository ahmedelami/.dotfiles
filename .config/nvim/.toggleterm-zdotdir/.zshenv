# Toggleterm-only ZDOTDIR.
# This runs for all zsh shells spawned by toggleterm (interactive or not).

if [ -n "${HUMOODAGEN_ZDOTDIR_ORIG:-}" ] && [ -f "${HUMOODAGEN_ZDOTDIR_ORIG}/.zshenv" ]; then
  source "${HUMOODAGEN_ZDOTDIR_ORIG}/.zshenv"
elif [ -f "${HOME}/.zshenv" ]; then
  source "${HOME}/.zshenv"
fi

# Prevent zsh/compinit from writing cache/history into ~/.config/nvim/.
if [ -n "${HUMOODAGEN_ZDOTDIR_ORIG:-}" ]; then
  case "${HISTFILE:-}" in
    ""|"$ZDOTDIR"/*) export HISTFILE="${HUMOODAGEN_ZDOTDIR_ORIG}/.zsh_history" ;;
  esac

  case "${ZSH_COMPDUMP:-}" in
    ""|"$ZDOTDIR"/*)
      host="${HOST:-${HOSTNAME:-}}"
      export ZSH_COMPDUMP="${HUMOODAGEN_ZDOTDIR_ORIG}/.zcompdump-${host:-host}-${ZSH_VERSION}"
      ;;
  esac
fi
