alias n="nvim ."

export PATH="/opt/homebrew/bin:$PATH"

if command -v tmux &> /dev/null && [ -z "$DISABLE_TMUX_AUTO" ] && [ -z "$WEZTERM_PANE" ] && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  # Load the safety wrapper first so manual calls are also protected
  source "$HOME/.tmux_safety_wrapper.zsh"

  # "Focus Follows Mouse" Logic:
  # 1. Find the session with the MOST RECENT activity (where you were just typing).
  # 2. Create a grouped session with THAT specific session.
  
  # List sessions by activity time (newest first) and pick the top one
  base_session=$(tmux list-sessions -F "#{session_activity} #{session_name}" 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}')

  if [ -n "$base_session" ]; then
    # Create a grouped session linked to your most active project
    # Use Smart Clone script to get a clean name (e.g. wiredl-1) and auto-destruct
    exec "$HOME/.tmux/scripts/new_smart_clone.sh" "$base_session"
  else
    # No sessions exist? Create a fresh one.
    exec tmux new-session
  fi
fi

export LESS="--no-init --quit-if-one-screen"
export LESS='-FRX'
alias tree="tree -I '*[Bb]ootstrap*|*bootswatch*|*node_modules*|staticfiles'"


# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell-light"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git direnv)

source $ZSH/oh-my-zsh.sh
bindkey -v
# Reduce ESC delay when switching vi modes.
export KEYTIMEOUT=1
typeset -g _TMUX_VIM_MODE=""

# Tmux VIM mode indicator (prompt-only)
_vim_cursor_set() {
  # Force steady block cursor; color is set by Ghostty config.
  if [[ -n $TMUX ]]; then
    # Passthrough to outer terminal via tmux
    printf '\ePtmux;\e\e[?12l\e\\'
    printf '\ePtmux;\e\e[2 q\e\\'
  else
    printf '\e[?12l'
    printf '\e[2 q'
  fi
}

_tmux_vim_mode_update() {
  [[ -n $TMUX ]] || return
  local mode
  if [[ ${KEYMAP-} == visual ]] || (( ${REGION_ACTIVE:-0} )); then
    mode="VIM:VISUAL"
  elif [[ ${KEYMAP-} == vicmd ]]; then
    mode="VIM:NORMAL"
  else
    mode="VIM:INSERT"
  fi
  [[ $mode == ${_TMUX_VIM_MODE-} ]] && return
  _TMUX_VIM_MODE=$mode

  # Update status variable first, then cursor LAST
  tmux set-option -p @vim_mode "$mode"
  # Status bar auto-updates via status-interval, no refresh needed
  _vim_cursor_set
}

_tmux_vim_mode_clear() {
  [[ -n $TMUX ]] || return
  _TMUX_VIM_MODE=""
  tmux set-option -p @vim_mode ""
}

zle -N zle-keymap-select _tmux_vim_mode_update
_tmux_vim_line_init() {
  zle -K viins
  _tmux_vim_mode_update
}
zle -N zle-line-init _tmux_vim_line_init

autoload -U add-zsh-hook
autoload -Uz add-zle-hook-widget
add-zsh-hook preexec _tmux_vim_mode_clear
add-zsh-hook precmd _tmux_vim_mode_update

_tmux_vim_wrap_widget() {
  local widget=$1
  local fn="_tmux_vim_wrap_${widget//-/_}"
  eval "
    ${fn}() {
      zle .${widget}
      _tmux_vim_mode_update
    }
  "
  zle -N ${widget} ${fn}
}
_tmux_vim_wrap_widget visual-mode
_tmux_vim_wrap_widget visual-line-mode

# macOS BSD ls colors - light mode optimized
export CLICOLOR=1
export LSCOLORS="Fxfxcxdxexegedabagacad"
# macOS LSCOLORS format: directory symlink socket pipe executable block special char setuid setgid sticky other-writable sticky-other-writable
# E=blue x=default f=magenta c=green d=brown b=red e=blue g=cyan a=black
# Capital = bold, lowercase = normal
# This gives: blue directories, magenta symlinks, red executables - good for light backgrounds

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
export PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"

# Created by `pipx` on 2025-02-17 21:28:04
export PATH="$PATH:/Users/ahmedelamin/.local/bin"
eval "$(direnv hook zsh)"

# Created by `pipx` on 2025-03-17 22:44:20
export PATH="$PATH:/Users/ahmed/.local/bin"

# . "$HOME/.local/bin/env"

source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
eval "$(fnm env --use-on-cd)"


export PATH="/Applications/UTM.app/Contents/MacOS:$PATH"
eval "$(zoxide init zsh)"


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/Users/ahmed/.opam/opam-init/init.zsh' ]] || source '/Users/ahmed/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="/Users/ahmedelamin/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;; 
  *) export PATH="$PNPM_HOME:$PATH" ;; 
esac
# pnpm end

# Added by Antigravity
export PATH="/Users/ahmedelamin/.antigravity/antigravity/bin:$PATH"

[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code-insiders --locate-shell-integration-path zsh)"

# --- GEMINI AUTO-CONFIG START ---
# Automatically creates VS Code settings for Homebrew Node when entering a repo project
autoload -U add-zsh-hook
function gemini_auto_repo_config() {
    # Trigger only if in 'repos' path and package.json exists
    if [[ "$PWD" == *"/repos/"* ]] && [[ -f "package.json" ]]; then
         local s_file=".vscode/settings.json"
         if [[ ! -f "$s_file" ]]; then
             mkdir -p .vscode
             cat > "$s_file" <<JSON
{
    "svelte.language-server.runtime": "/opt/homebrew/bin/node",
    "eslint.runtime": "/opt/homebrew/bin/node",
    "prettier.nodePath": "/opt/homebrew/bin/node"
}
JSON
             echo "✨ Auto-configured VS Code settings for External Drive."
         fi
    fi
}
add-zsh-hook chpwd gemini_auto_repo_config
# --- GEMINI AUTO-CONFIG END ---

# Check on startup too (for VS Code Integrated Terminal)
gemini_auto_repo_config

# bun completions
[ -s "/Users/ahmedelamin/.bun/_bun" ] && source "/Users/ahmedelamin/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Neovim Aliases
alias n="nvim ."
alias nv="nvim"

# API Keys (Sourced from local secrets file - DO NOT PUSH)
if [ -f "$HOME/.zsh_secrets" ]; then
    source "$HOME/.zsh_secrets"
fi
