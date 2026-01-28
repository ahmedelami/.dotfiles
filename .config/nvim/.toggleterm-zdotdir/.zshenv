# Toggleterm-only ZDOTDIR.
# This runs for all zsh shells spawned by toggleterm (interactive or not).

zmodload zsh/datetime 2>/dev/null || true

__humoodagen_toggleterm_ts_ns() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local sec="${EPOCHREALTIME%.*}"
    local frac="${EPOCHREALTIME#*.}"
    frac="${frac}000000000"
    frac="${frac[1,9]}"
    print -r -- "${sec}${frac}"
    return 0
  fi
  python3 -c 'import time; print(time.time_ns())' 2>/dev/null || true
}

__humoodagen_toggleterm_log_init() {
  if [ "${__humoodagen_toggleterm_log_ready:-}" = "1" ]; then
    return 0
  fi
  __humoodagen_toggleterm_log_ready=1

  local state_home="${XDG_STATE_HOME:-${HOME}/.local/state}"
  local state_dir="${state_home}/humoodagen"
  mkdir -p "${state_dir}" 2>/dev/null || true

  if [ -z "${HUMOODAGEN_TOGGLETERM_SHELL_LOG:-}" ]; then
    export HUMOODAGEN_TOGGLETERM_SHELL_LOG="${state_dir}/toggleterm-shell.log"
  fi
}

__humoodagen_toggleterm_log() {
  if [ "${HUMOODAGEN_PERF:-}" != "1" ]; then
    return 0
  fi
  __humoodagen_toggleterm_log_init
  local now="$(__humoodagen_toggleterm_ts_ns)"
  local launch="${HUMOODAGEN_LAUNCH_TS_NS:-}"
  if [ -n "$now" ]; then
    print -r -- "${now} | ${1:-event} | launch_ts_ns=${launch} | pid=$$ | ppid=${PPID:-}" >>"${HUMOODAGEN_TOGGLETERM_SHELL_LOG}" 2>/dev/null || true
  fi
}

__humoodagen_toggleterm_log "toggleterm:zshenv:begin"

if [ -n "${HUMOODAGEN_ZDOTDIR_ORIG:-}" ] && [ -f "${HUMOODAGEN_ZDOTDIR_ORIG}/.zshenv" ]; then
  __humoodagen_toggleterm_log "toggleterm:zshenv:source_orig:begin"
  source "${HUMOODAGEN_ZDOTDIR_ORIG}/.zshenv"
  __humoodagen_toggleterm_log "toggleterm:zshenv:source_orig:done"
elif [ -f "${HOME}/.zshenv" ]; then
  __humoodagen_toggleterm_log "toggleterm:zshenv:source_home:begin"
  source "${HOME}/.zshenv"
  __humoodagen_toggleterm_log "toggleterm:zshenv:source_home:done"
fi

# Prevent zsh/compinit from writing cache/history into ~/.config/nvim/.
__humoodagen_toggleterm_state_home="${XDG_STATE_HOME:-${HOME}/.local/state}"
__humoodagen_toggleterm_state_dir="${__humoodagen_toggleterm_state_home}/humoodagen"
mkdir -p "${__humoodagen_toggleterm_state_dir}" 2>/dev/null || true

case "${HISTFILE:-}" in
  ""|"$ZDOTDIR"/*)
    if [ -n "${HUMOODAGEN_ZDOTDIR_ORIG:-}" ]; then
      export HISTFILE="${HUMOODAGEN_ZDOTDIR_ORIG}/.zsh_history"
    else
      export HISTFILE="${__humoodagen_toggleterm_state_dir}/toggleterm-zsh-history"
    fi
    ;;
esac

case "${ZSH_COMPDUMP:-}" in
  ""|"$ZDOTDIR"/*)
    host="${HOST:-${HOSTNAME:-}}"
    if [ -n "${HUMOODAGEN_ZDOTDIR_ORIG:-}" ]; then
      export ZSH_COMPDUMP="${HUMOODAGEN_ZDOTDIR_ORIG}/.zcompdump-${host:-host}-${ZSH_VERSION}"
    else
      export ZSH_COMPDUMP="${__humoodagen_toggleterm_state_dir}/.zcompdump-toggleterm-${host:-host}-${ZSH_VERSION}"
    fi
    ;;
esac

__humoodagen_toggleterm_log "toggleterm:zshenv:end"
