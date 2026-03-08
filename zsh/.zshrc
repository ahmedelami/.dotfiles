export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/opt/local/bin:/opt/local/sbin:$PATH"
export HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

if [[ -o interactive ]] \
  && command -v nu >/dev/null 2>&1 \
  && [[ -z "${INSIDE_NU:-}" ]] \
  && [[ -z "${ZSH_DISABLE_AUTO_EXEC_NU:-}" ]]; then
  exec nu -l
fi
