# config.nu
#
# Installed by:
# version = "0.110.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# ----
# Directory jumping (zoxide)
# Provides `z` / `zi` like in zsh.
#
# If you ever need to regenerate it:
#   zoxide init nushell | save -f ~/.config/nushell/zoxide.nu
source ~/.config/nushell/zoxide.nu

# ----
# Hide the Nushell welcome banner (the ASCII art + links + startup stats).
$env.config.show_banner = false

# ----
# Commandline input: show inline history/completion hints (the gray "ghost text").
$env.config.show_hints = true

# ----
# Colors: darker (but not "dimmed")
# Keep Nushell's default palette, but avoid the "light_*" + many "*_bold"
# defaults that can look too bright in some terminal themes.
$env.config.color_config = {
  separator: default
  leading_trailing_space_bg: { attr: n }
  header: green
  empty: blue
  bool: cyan
  int: default
  filesize: cyan
  duration: default
  datetime: purple
  range: default
  float: default
  string: default
  nothing: default
  binary: default
  cell-path: default
  row_index: green
  record: default
  list: default
  closure: green
  glob: cyan
  block: default
  hints: dark_gray
  search_result: { bg: red fg: default }
  # Commandline syntax highlighting: keep everything black while typing.
  shape_binary: "#000000"
  shape_block: "#000000"
  shape_bool: "#000000"
  shape_closure: "#000000"
  shape_custom: "#000000"
  shape_datetime: "#000000"
  shape_directory: "#000000"
  shape_external: "#000000"
  shape_externalarg: "#000000"
  shape_external_resolved: "#000000"
  shape_filepath: "#000000"
  shape_flag: "#000000"
  shape_float: "#000000"
  shape_glob_interpolation: "#000000"
  shape_globpattern: "#000000"
  shape_int: "#000000"
  shape_internalcall: "#000000"
  shape_keyword: "#000000"
  shape_list: "#000000"
  shape_literal: "#000000"
  shape_match_pattern: "#000000"
  shape_matching_brackets: "#000000"
  shape_nothing: "#000000"
  shape_operator: "#000000"
  shape_pipe: "#000000"
  shape_range: "#000000"
  shape_record: "#000000"
  shape_redirection: "#000000"
  shape_signature: "#000000"
  shape_string: "#000000"
  shape_string_interpolation: "#000000"
  shape_table: "#000000"
  shape_variable: "#000000"
  shape_vardecl: "#000000"
  shape_raw_string: "#000000"
  shape_garbage: "#000000"
}

# ----
# Prompt: show `~/repos` instead of `/Volumes/.../repos` when `~/repos` is a symlink.
def humoodagen_pretty_pwd [] {
  let cwd = $env.PWD
  let home = $nu.home-dir
  let repos_link = ($home | path join "repos")
  let repos_logical = ($repos_link | path expand --no-symlink)
  let repos_physical = (try { $repos_link | path expand } catch { "" })

  let mapped = if ($repos_physical != "" and ($cwd == $repos_physical or ($cwd | str starts-with ($repos_physical + "/")))) {
    $cwd | str replace $repos_physical $repos_logical
  } else {
    $cwd
  }

  if ($mapped == $home or ($mapped | str starts-with ($home + "/"))) {
    $mapped | str replace $home "~"
  } else {
    $mapped
  }
}

def humoodagen_colorize_path [p: string] {
  if ($p | is-empty) {
    return ""
  }

  let seg = (ansi green_bold)
  let sep = (ansi green)
  let reset = (ansi reset)

  if ($p | str starts-with "/") {
    let trimmed = ($p | str trim --left --char "/")
    if $trimmed == "" {
      return ($sep + "/" + $reset)
    }
    let parts = ($trimmed | split row "/")
    return ($sep + "/" + $seg + ($parts | str join ($sep + "/" + $seg)) + $reset)
  }

  let parts = ($p | split row "/")
  $seg + ($parts | str join ($sep + "/" + $seg)) + $reset
}

$env.PROMPT_COMMAND = {||
  humoodagen_colorize_path (humoodagen_pretty_pwd)
}

# ----
# Prompt (starship): git-aware prompt like oh-my-zsh
source ($nu.config-path | path dirname | path join "starship.nu")

alias n = nvim
