#!/opt/homebrew/bin/nu

use std/util "path add"

def ts-ns [] {
    (^python3 -c 'import time; print(time.time_ns())' | complete).stdout | str trim
}

def choose-tmux [] {
    let state_home = ($env.XDG_STATE_HOME? | default ($nu.home-path | path join '.local' 'state'))
    let state_dir = ($state_home | path join 'humoodagen')
    let tmux_rs_flag = ($state_dir | path join 'ghostty-use-tmux-rs')
    let tmux_rs_bin = ($nu.home-path | path join '.cargo' 'bin' 'tmux-rs')
    let tmux_bin = if ('/opt/homebrew/bin/tmux' | path exists) {
        '/opt/homebrew/bin/tmux'
    } else {
        which tmux | get -o 0.path | default ''
    }

    if (($tmux_rs_flag | path exists) and ($tmux_rs_bin | path exists)) {
        { bin: $tmux_rs_bin, impl: 'tmux-rs' }
    } else {
        { bin: $tmux_bin, impl: 'tmux' }
    }
}

def resolve-start-dir [state_dir: string] {
    let repos_dir = ($nu.home-path | path join 'repos')
    if ($repos_dir | path exists) {
        return $repos_dir
    }

    let state_file = ($state_dir | path join 'ghostty-cwd')
    if ($state_file | path exists) {
        let raw = (open $state_file | lines | get -o 0 | default '' | str trim)
        if ($raw | is-not-empty) {
            let expanded = ($raw | str replace '~' $nu.home-path)
            if ($expanded | path exists) {
                return $expanded
            }
        }
    }

    $nu.home-path
}

def resolve-size [last_size_file: string] {
    mut rows = 50
    mut cols = 160

    let stty_result = (^stty size | complete)
    if $stty_result.exit_code == 0 {
        let dims = ($stty_result.stdout | str trim | split row ' ')
        if (($dims | length) >= 2) {
            let parsed_rows = (do -i { $dims | get 0 | into int } | default null)
            let parsed_cols = (do -i { $dims | get 1 | into int } | default null)
            if ($parsed_rows != null and $parsed_cols != null) {
                $rows = $parsed_rows
                $cols = $parsed_cols
            }
        }
    } else if ($last_size_file | path exists) {
        let dims = (open $last_size_file | str trim | split row ' ')
        if (($dims | length) >= 2) {
            let parsed_rows = (do -i { $dims | get 0 | into int } | default null)
            let parsed_cols = (do -i { $dims | get 1 | into int } | default null)
            if ($parsed_rows != null and $parsed_cols != null) {
                $rows = $parsed_rows
                $cols = $parsed_cols
            }
        }
    }

    { rows: $rows, cols: $cols }
}

def log-event [log_file: string, event: string, launch_ts_ns: string, extra?: string] {
    if not ($log_file | path exists) {
        '' | save -f $log_file
    }
    let suffix = if ($extra | is-empty) { '' } else { $" | ($extra)" }
    $"(ts-ns) | ($event) | launch_ts_ns=($launch_ts_ns) | pid=($nu.pid)($suffix)" | save --append $log_file
}

def main [] {
    path add '/opt/homebrew/bin'
    path add '/opt/homebrew/sbin'
    path add ($nu.home-path | path join '.cargo' 'bin')

    let state_home = ($env.XDG_STATE_HOME? | default ($nu.home-path | path join '.local' 'state'))
    let state_dir = ($state_home | path join 'humoodagen')
    let perf_flag = ($state_dir | path join 'ghostty-perf-on')
    let perf_ui_flag = ($state_dir | path join 'ghostty-perf-ui-on')
    let persist_flag = ($state_dir | path join 'ghostty-persist-session')
    let last_size_file = ($state_dir | path join 'ghostty-last-size')
    let hook_script = ($nu.home-path | path join '.dotfiles' 'ghostty_tmux_hook.sh')
    let pane_script = ($nu.home-path | path join '.dotfiles' 'ghostty_tmux_pane.sh')
    let launch_log = ($state_dir | path join 'ghostty-launch.log')

    mkdir $state_dir

    let tmux_choice = (choose-tmux)
    let tmux_bin = $tmux_choice.bin
    let tmux_impl = $tmux_choice.impl
    if ($tmux_bin | is-empty) {
        print --stderr 'ghostty_tmux_launcher: tmux not found'
        exit 1
    }

    let persist = ($persist_flag | path exists)
    let server_name = if $persist { 'humoodagen-ghostty-persist' } else { 'humoodagen-ghostty' }
    let session_name = if $persist { 'ghostty' } else { $"ghostty_((date now | format date '%Y%m%d%H%M%S'))_(random int 1000..9999)" }
    let start_dir = (resolve-start-dir $state_dir)
    let size = (resolve-size $last_size_file)
    let rows = $size.rows
    let cols = $size.cols
    $"($rows) ($cols)" | save -f $last_size_file

    let launch_ts_ns = (ts-ns)
    let perf_enabled = ($perf_flag | path exists)
    let perf_ui = if ($perf_ui_flag | path exists) { '1' } else { '0' }

    if $perf_enabled {
        log-event $launch_log 'launcher:start' $launch_ts_ns $"session=($session_name) tmux=($tmux_impl) persist=($persist)"
    }

    let attached_hook = $"run-shell -b \"($hook_script) tmux:client-attached\""
    let detached_hook = $"run-shell -b \"($hook_script) tmux:client-detached\""

    let env_vars = [
        '-e' $"HUMOODAGEN_GHOSTTY=1"
        '-e' $"HUMOODAGEN_TMUX_BIN=($tmux_bin)"
        '-e' $"HUMOODAGEN_TMUX_IMPL=($tmux_impl)"
        '-e' $"HUMOODAGEN_TMUX_SESSION=($session_name)"
    ]
    let perf_env = if $perf_enabled {
        [
            '-e' $"HUMOODAGEN_LAUNCH_TS_NS=($launch_ts_ns)"
            '-e' $"HUMOODAGEN_GHOSTTY_LAUNCH_LOG=($launch_log)"
            '-e' 'HUMOODAGEN_PERF=1'
            '-e' $"HUMOODAGEN_PERF_UI=($perf_ui)"
        ]
    } else {
        []
    }

    with-env { TMUX_SKIP_TPM: '1' } {
        if $persist {
            ^$tmux_bin -L $server_name start-server ';' set-option -g destroy-unattached off ';' set-hook -g client-attached $attached_hook ';' set-hook -g client-detached $detached_hook ';' new-session -A -x $cols -y $rows ...$env_vars ...$perf_env -c $start_dir -s $session_name -n nvim -- $pane_script
        } else {
            ^$tmux_bin -L $server_name start-server ';' set-option -g destroy-unattached on ';' set-hook -g client-attached $attached_hook ';' set-hook -g client-detached $detached_hook ';' new-session -d -x $cols -y $rows ...$env_vars ...$perf_env -c $start_dir -s $session_name -n nvim -- $pane_script ';' attach-session -t $session_name
        }
    }
}
