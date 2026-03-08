# Nushell Config File
#
# version = "0.111.0"

use std/util "path add"

$env.config.show_banner = false
$env.config.history.file_format = "plaintext"
$env.config.history.max_size = 100_000
$env.config.history.sync_on_enter = true
$env.config.history.isolation = false
$env.config.show_hints = true
$env.config.completions.algorithm = "prefix"
$env.config.completions.sort = "smart"
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true
$env.config.completions.use_ls_colors = true
$env.config.completions.external.enable = true
$env.config.completions.external.max_results = 200
$env.config.use_ansi_coloring = "auto"
$env.config.edit_mode = "emacs"
$env.config.cursor_shape.emacs = "block"
$env.config.cursor_shape.vi_insert = "block"
$env.config.cursor_shape.vi_normal = "block"
$env.config.render_right_prompt_on_last_line = false

def __has-command [name: string] {
    (which $name | length) > 0
}

def __find-up [...names: string] {
    mut dir = $env.PWD

    loop {
        for name in $names {
            let candidate = ($dir | path join $name)
            if ($candidate | path exists) {
                return $dir
            }
        }

        let parent = ($dir | path dirname)
        if $parent == $dir {
            break
        }
        $dir = $parent
    }

    null
}

def __prompt-path [] {
    let dir = match (do -i { $env.PWD | path relative-to $nu.home-path }) {
        null => $env.PWD
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }

    let path_color = (ansi green_bold)
    let sep_color = (ansi light_green_bold)
    let path_segment = $"($path_color)($dir)(ansi reset)"
    $path_segment | str replace --all (char path_sep) $"($sep_color)(char path_sep)($path_color)"
}

def __prompt-git [] {
    if not (__has-command 'git') {
        return ''
    }

    let result = (^git status --porcelain=2 --branch | complete)
    if $result.exit_code != 0 {
        return ''
    }

    let lines = ($result.stdout | lines)
    mut branch = ''
    mut ahead = 0
    mut behind = 0
    mut dirty = false

    for line in $lines {
        if ($line | str starts-with '# branch.head ') {
            $branch = ($line | str replace '# branch.head ' '')
            continue
        }

        if ($line | str starts-with '# branch.ab ') {
            let parsed = ($line | parse --regex '^# branch\.ab \+(?P<ahead>\d+) -(?P<behind>\d+)$')
            if ($parsed | is-not-empty) {
                let row = ($parsed | get 0)
                $ahead = ($row.ahead | into int)
                $behind = ($row.behind | into int)
            }
            continue
        }

        if (not ($line | str starts-with '# ')) and ($line | str trim | is-not-empty) {
            $dirty = true
        }
    }

    if ($branch | is-empty) {
        return ''
    }

    let ahead_behind = if ($ahead > 0 or $behind > 0) {
        let ahead_text = if $ahead > 0 { $"+($ahead)" } else { '' }
        let behind_text = if $behind > 0 { $"-($behind)" } else { '' }
        $"($ahead_text)($behind_text)"
    } else {
        ''
    }
    let dirty_mark = if $dirty { '!' } else { '' }

    $" (ansi red)git:($branch)($ahead_behind)($dirty_mark)(ansi reset)"
}

def __prompt-jj [] {
    if not (__has-command 'jj') {
        return ''
    }

    let template = 'local_bookmarks.map(|b| b.name()).join(",") ++ "|" ++ change_id.short(8) ++ "|" ++ if(conflict, "1", "0") ++ "|" ++ if(divergent, "1", "0")'
    let result = (^jj --ignore-working-copy --no-pager --color=never log -r @ --no-graph -T $template | complete)
    if $result.exit_code != 0 {
        return ''
    }

    let output = ($result.stdout | str trim)
    if ($output | is-empty) {
        return ''
    }

    let parts = ($output | split row '|')
    if ($parts | length) < 4 {
        return ''
    }

    let bookmarks = ($parts | get 0)
    let change_id = ($parts | get 1)
    let has_conflict = (($parts | get 2) == '1')
    let is_divergent = (($parts | get 3) == '1')

    let head = if ($bookmarks | is-not-empty) {
        $"($bookmarks)@($change_id)"
    } else {
        $change_id
    }
    let markers = [
        (if $has_conflict { '!' } else { '' })
        (if $is_divergent { '~' } else { '' })
    ] | str join

    $" (ansi magenta)jj:($head)($markers)(ansi reset)"
}

def __prompt-vcs [] {
    let jj_segment = (__prompt-jj)
    if ($jj_segment | is-not-empty) {
        return $jj_segment
    }

    __prompt-git
}

$env.PROMPT_COMMAND = {||
    let arrow_color = if (($env.LAST_EXIT_CODE? | default 0) == 0) {
        ansi green
    } else {
        ansi red
    }

    $"($arrow_color)➜(ansi reset)  (__prompt-path)(__prompt-vcs) "
}

$env.PROMPT_COMMAND_RIGHT = {|| '' }
$env.PROMPT_INDICATOR = ''
$env.PROMPT_MULTILINE_INDICATOR = '… '

def --env __refresh_direnv [] {
    if not (__has-command 'direnv') {
        return
    }

    let next_root = (__find-up '.envrc' '.env' | default '')
    let previous_root = ($env.__DIRENV_ROOT? | default '')
    if $next_root == $previous_root {
        return
    }
    $env.__DIRENV_ROOT = $next_root

    if ($next_root | is-empty) and (($env.__DIRENV_VARS? | default []) | is-empty) {
        return
    }

    let result = (^direnv export json | complete)
    if $result.exit_code != 0 {
        return
    }

    let stdout = ($result.stdout | str trim)
    let next_env = if ($stdout | is-empty) { {} } else { $stdout | from json }
    let next_keys = ($next_env | columns)
    let previous_keys = ($env.__DIRENV_VARS? | default [])
    let stale_keys = ($previous_keys | where {|key|
        not ($next_keys | any {|next_key| $next_key == $key })
    })

    if ($stale_keys | is-not-empty) {
        hide-env --ignore-errors ...$stale_keys
    }

    load-env $next_env
    $env.__DIRENV_VARS = $next_keys
}

def --env __refresh_fnm [] {
    if not (__has-command 'fnm') {
        return
    }

    let next_root = (__find-up '.node-version' '.nvmrc' 'package.json' | default '')
    let previous_root = ($env.__FNM_ROOT? | default '')
    if $next_root == $previous_root {
        return
    }
    $env.__FNM_ROOT = $next_root

    if $next_root == '' {
        return
    }

    let result = (^fnm env --json | complete)
    if $result.exit_code != 0 {
        return
    }

    let stdout = ($result.stdout | str trim)
    if ($stdout | is-empty) {
        return
    }

    let next_env = ($stdout | from json)
    load-env $next_env

    if ($env.FNM_MULTISHELL_PATH? | is-not-empty) {
        path add ($env.FNM_MULTISHELL_PATH | path join "bin")
    }

    do -i {
        ^fnm use --silent-if-unchanged
    } | complete | ignore
}

$env.config.hooks.env_change.PWD = ($env.config.hooks.env_change.PWD? | default [])
$env.config.hooks.env_change.PWD ++= [
    {|_, _| __refresh_direnv }
    {|_, _| __refresh_fnm }
]

source '/Users/ahmedelamin/Library/Application Support/nushell/zoxide.nu'

__refresh_direnv
__refresh_fnm

alias ll = ls -l
alias la = ls -a
alias l = ls -la

def --wrapped tree [...rest: string] {
    ^tree -I '*[Bb]ootstrap*|*bootswatch*|*node_modules*|staticfiles' ...$rest
}

def --wrapped fieldfind [...rest: string] {
    ^/Volumes/t7/repos/work/switchb/analytics-dash/scripts/find-field.sh ...$rest
}

alias ff = fieldfind
