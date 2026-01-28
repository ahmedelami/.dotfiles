# Toggleterm-only ZDOTDIR.
# Source the user's real zshrc, then override `nvim` to remote into the running
# Neovim instance (see ~/.config/nvim/bin/nvim).

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
  python3 -c 'import time; print(time.time_ns())'
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
  print -r -- "${now} | ${1:-event} | launch_ts_ns=${launch} | pid=$$ | ppid=${PPID:-}" >>"${HUMOODAGEN_TOGGLETERM_SHELL_LOG}" 2>/dev/null || true
}

__humoodagen_toggleterm_log "toggleterm:zshrc:begin"

if [ "${HUMOODAGEN_PERF:-}" = "1" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null || true
  __humoodagen_toggleterm_first_prompt() {
    __humoodagen_toggleterm_log "toggleterm:prompt:first"
    add-zsh-hook -d precmd __humoodagen_toggleterm_first_prompt 2>/dev/null || true
  }
  add-zsh-hook precmd __humoodagen_toggleterm_first_prompt 2>/dev/null || true
fi

if [ "${HUMOODAGEN_TOGGLETERM_FAST_INIT:-}" = "1" ]; then
  # Fast-start: show a prompt immediately, then load the user's full zshrc once
  # they hit Enter the first time (or after a short idle delay).
  __humoodagen_toggleterm_log "toggleterm:fast_init:begin"
  PROMPT='%(?:%F{33}➜%f :%F{196}➜%f ) %B%F{magenta}%c%f%b '
  PS1="$PROMPT"
  export PS1
  __humoodagen_toggleterm_log "toggleterm:fast_init:prompt_set"

  if [ -n "${HUMOODAGEN_NVIM_WRAPPER:-}" ]; then
    alias nvim="${HUMOODAGEN_NVIM_WRAPPER}"
  fi

  __humoodagen_toggleterm_hydrate() {
    __humoodagen_toggleterm_log "toggleterm:hydrate:begin"
    unset HUMOODAGEN_TOGGLETERM_FAST_INIT

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

    # Some prompts/themes only fully update from precmd; run it once so the
    # prompt redraw below reflects the "real" prompt immediately.
    #
    # NOTE: We intentionally do NOT invoke precmd/precmd_functions here.
    # Many setups attach heavy hooks (direnv, tmux status updates, etc.) to
    # precmd, and running them synchronously causes visible startup jank.
    # `zle reset-prompt` after sourcing the user's config is enough for most
    # prompt/theme setups, and normal precmd will run on the next prompt anyway.

    __humoodagen_toggleterm_log "toggleterm:hydrate:done"
  }

  if command -v zle >/dev/null 2>&1; then
    __humoodagen_toggleterm_accept_line() {
      zle -A .accept-line accept-line
      __humoodagen_toggleterm_log "toggleterm:hydrate:accept_line"
      __humoodagen_toggleterm_hydrate
      zle accept-line
    }
    zle -N accept-line __humoodagen_toggleterm_accept_line

    __humoodagen_toggleterm_hydrate_auto() {
      local fd="$1"
      if [ -n "$fd" ]; then
        zle -F "$fd"
      fi
      if [ -n "${__humoodagen_toggleterm_hydrate_fd:-}" ]; then
        exec {__humoodagen_toggleterm_hydrate_fd}<&-
        unset __humoodagen_toggleterm_hydrate_fd
      fi

      # Don't hydrate if the user already started typing.
      if [ -z "${HUMOODAGEN_TOGGLETERM_FAST_INIT:-}" ] || [ -n "${BUFFER:-}" ]; then
        return 0
      fi

      zle -A .accept-line accept-line
      __humoodagen_toggleterm_log "toggleterm:hydrate:auto_fire"
      __humoodagen_toggleterm_hydrate
      zle reset-prompt
      zle -R
      __humoodagen_toggleterm_log "toggleterm:prompt:redraw"
    }

    __humoodagen_toggleterm_line_init() {
      if [ -z "${HUMOODAGEN_TOGGLETERM_FAST_INIT:-}" ] || [ -n "${__humoodagen_toggleterm_hydrate_fd:-}" ]; then
        return 0
      fi

      # If you start typing immediately, hydration is deferred to accept-line.
      __humoodagen_toggleterm_log "toggleterm:fast_init:zle_line_init"
      exec {__humoodagen_toggleterm_hydrate_fd}< <(sleep 0.05; print -n x)
      zle -F "${__humoodagen_toggleterm_hydrate_fd}" __humoodagen_toggleterm_hydrate_auto
    }

    zle -N zle-line-init __humoodagen_toggleterm_line_init

    __humoodagen_toggleterm_hydrate_sched() {
      if [ -z "${HUMOODAGEN_TOGGLETERM_FAST_INIT:-}" ] || [ -n "${BUFFER:-}" ]; then
        return 0
      fi

      __humoodagen_toggleterm_log "toggleterm:hydrate:sched_fire"
      __humoodagen_toggleterm_hydrate
      if [ -n "${ZLE:-}" ]; then
        zle reset-prompt
        zle -R
        __humoodagen_toggleterm_log "toggleterm:prompt:redraw"
      fi
    }

    if zmodload zsh/sched 2>/dev/null; then
      sched +1 __humoodagen_toggleterm_hydrate_sched
    fi
  fi

  __humoodagen_toggleterm_log "toggleterm:zshrc:end_fast_init"
  return
fi

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

__humoodagen_toggleterm_log "toggleterm:zshrc:end"
