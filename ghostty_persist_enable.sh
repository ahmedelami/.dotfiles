#!/opt/homebrew/bin/nu

def choose-tmux-bin [tmux_rs_flag: string] {
    let default_tmux = '/opt/homebrew/bin/tmux'
    let resolved_tmux = if ($default_tmux | path exists) {
        $default_tmux
    } else {
        which tmux | get -o 0.path | default ''
    }

    let tmux_rs_bin = ($nu.home-path | path join '.cargo' 'bin' 'tmux-rs')
    if (($tmux_rs_flag | path exists) and ($tmux_rs_bin | path exists)) {
        { bin: $tmux_rs_bin, impl: 'tmux-rs' }
    } else {
        { bin: $resolved_tmux, impl: 'tmux' }
    }
}

def main [] {
    let state_home = ($env.XDG_STATE_HOME? | default ($nu.home-path | path join '.local' 'state'))
    let state_dir = ($state_home | path join 'humoodagen')
    let persist_flag = ($state_dir | path join 'ghostty-persist-session')
    let tmux_rs_flag = ($state_dir | path join 'ghostty-use-tmux-rs')
    let last_size_file = ($state_dir | path join 'ghostty-last-size')

    mkdir $state_dir
    '' | save -f $persist_flag

    mut tmux_start_cols = 160
    mut tmux_start_lines = 50
    if ($last_size_file | path exists) {
        let dims = (open $last_size_file | str trim | split row ' ')
        if (($dims | length) >= 2) {
            let rows = ($dims | get 0)
            let cols = ($dims | get 1)
            let parsed_rows = (do -i { $rows | into int } | default null)
            let parsed_cols = (do -i { $cols | into int } | default null)
            if ($parsed_rows != null and $parsed_cols != null) {
                $tmux_start_lines = $parsed_rows
                $tmux_start_cols = $parsed_cols
            }
        }
    }

    let tmux_choice = (choose-tmux-bin $tmux_rs_flag)
    let tmux_bin = $tmux_choice.bin
    let tmux_impl = $tmux_choice.impl
    if ($tmux_bin | is-empty) {
        print 'ghostty_persist_enable: tmux not found'
        exit 1
    }

    let server_name = 'humoodagen-ghostty-persist'
    let session_name = 'ghostty'
    let start_dir = if (($nu.home-path | path join 'repos') | path exists) { ($nu.home-path | path join 'repos') } else { $nu.home-path }
    let start_cols = $tmux_start_cols
    let start_lines = $tmux_start_lines
    let pane_script = ($nu.home-path | path join '.dotfiles' 'ghostty_tmux_pane.sh')

    let has_session = (with-env { TMUX_SKIP_TPM: '1' } { ^$tmux_bin -L $server_name has-session -t $session_name | complete })
    if $has_session.exit_code == 0 {
        print $"ghostty persistent session already running: ($session_name) [server=($server_name), tmux=($tmux_impl)]"
        exit 0
    }

    with-env { TMUX_SKIP_TPM: '1' } {
        ^$tmux_bin -L $server_name start-server ';' set-option -g destroy-unattached off ';' new-session -d -x $start_cols -y $start_lines -c $start_dir -s $session_name -n nvim -e 'HUMOODAGEN_GHOSTTY=1' -e $"HUMOODAGEN_TMUX_BIN=($tmux_bin)" -e $"HUMOODAGEN_TMUX_IMPL=($tmux_impl)" -e $"HUMOODAGEN_TMUX_SESSION=($session_name)" -- $pane_script
    }

    print $"ghostty persistent mode enabled and session started: ($session_name) [server=($server_name), tmux=($tmux_impl), size=($tmux_start_cols)x($tmux_start_lines)]"
}
