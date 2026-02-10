# env.nu
#
# Installed by:
# version = "0.110.0"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

# ----
# Colors
# Some environments set NO_COLOR=1, which disables ANSI colors in Nushell and many tools.
# Unset it so tables/syntax highlighting can use colors normally.
$env.NO_COLOR = null

# ----
# Homebrew (macOS)
# GUI-launched terminals may not inherit shell PATH, so ensure Homebrew tools
# (like `zoxide`) are always available.
let homebrew_prefix = "/opt/homebrew"
if ($homebrew_prefix | path exists) {
  let brew_bin = $"($homebrew_prefix)/bin"
  let brew_sbin = $"($homebrew_prefix)/sbin"
  if not ($brew_bin in $env.PATH) {
    $env.PATH = ($env.PATH | prepend $brew_bin)
  }
  if not ($brew_sbin in $env.PATH) {
    $env.PATH = ($env.PATH | prepend $brew_sbin)
  }
}

# ----
# User-local binaries (e.g. `zed`)
# Ensure ~/.local/bin is available even in GUI-launched / login shells.
let local_bin = ($nu.home-dir | path join ".local" "bin")
if ($local_bin | path exists) {
  if not ($local_bin in $env.PATH) {
    $env.PATH = ($env.PATH | prepend $local_bin)
  }
}

# ----
# fnm-managed Node (macOS)
# Ensure npm global CLIs (like `codex`) are available when Nushell is launched
# directly (e.g. Ghostty), without relying on zsh to eval `fnm env`.
let fnm_default_alias = ($nu.home-dir | path join ".local" "share" "fnm" "aliases" "default")
if ($fnm_default_alias | path exists) {
  let fnm_install = ($fnm_default_alias | path expand)
  let fnm_bin = ($fnm_install | path join "bin")
  if ($fnm_bin | path exists) and (not ($fnm_bin in $env.PATH)) {
    $env.PATH = ($env.PATH | prepend $fnm_bin)
  }
}

# ----
# Darker `ls` colors + extension tweaks (LS_COLORS is used by `ls` in nu).
#
# - Regular files: default color (not cyan)
# - Directories: dim blue
# - Markdown (`*.md`): orange
let _ls_colors_existing = ($env.LS_COLORS? | default "" | split row ":" | where { |e| not ($e | is-empty) })
let _ls_colors_overrides = [
  "fi=0"
  "di=34"
  "ln=35"
  "so=32"
  "pi=33"
  "ex=31"
  # UT7 palette doesn't have a dedicated orange; the closest is bright red (#FC391F).
  "*.md=91"
  "*.MD=91"
  "bd=34;46"
  "cd=34;43"
  "su=30;41"
  "sg=30;46"
  "tw=30;42"
  "ow=30;43"
]
let _ls_colors_override_keys = ($_ls_colors_overrides | each { |kv| $kv | split row "=" | first })
let _ls_colors_filtered = (
  $_ls_colors_existing
  | where { |kv|
      let k = ($kv | split row "=" | first)
      not ($k in $_ls_colors_override_keys)
    }
)
$env.LS_COLORS = (($_ls_colors_filtered | append $_ls_colors_overrides) | str join ":")
