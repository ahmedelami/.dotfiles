#!/opt/homebrew/bin/nu

def try-kill [bin?: string] {
    if ($bin | is-empty) {
        return
    }
    if not ($bin | path exists) {
        return
    }

    with-env { TMUX_SKIP_TPM: '1' } {
        do -i { ^$bin -L humoodagen-ghostty-persist kill-server }
    }
}

def main [] {
    let state_home = ($env.XDG_STATE_HOME? | default ($nu.home-path | path join '.local' 'state'))
    let state_dir = ($state_home | path join 'humoodagen')
    let persist_flag = ($state_dir | path join 'ghostty-persist-session')

    rm -f $persist_flag

    try-kill ($nu.home-path | path join '.cargo' 'bin' 'tmux-rs')
    try-kill /opt/homebrew/bin/tmux

    let tmux_path = (which tmux | get -o 0.path | default '')
    try-kill $tmux_path

    print "ghostty persistent mode disabled (flag removed) and tmux server stopped: humoodagen-ghostty-persist"
}
