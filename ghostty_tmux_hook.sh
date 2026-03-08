#!/opt/homebrew/bin/nu

def ts-ns [] {
    (^python3 -c 'import time; print(time.time_ns())' | complete).stdout | str trim
}

def update-prefill-snapshot [] {
    let state_home = ($env.XDG_STATE_HOME? | default ($nu.home-path | path join '.local' 'state'))
    let state_dir = ($state_home | path join 'humoodagen')
    let prefill_file = ($state_dir | path join 'ghostty-prefill.ansi')

    let has_session = (^tmux has-session -t ghostty | complete)
    if $has_session.exit_code != 0 {
        return
    }

    let clients = (((^tmux list-clients -t ghostty | complete).stdout | lines | length) | into string)
    if $clients != '0' {
        return
    }

    mkdir $state_dir
    let tmp = $"($prefill_file).($nu.pid)"
    do -i { ^tmux capture-pane -pe -t 'ghostty:' | save -f $tmp }
    if (($tmp | path exists) and ((ls -s $tmp | get 0.size) > 0b)) {
        mv -f $tmp $prefill_file
    } else {
        rm -f $tmp
    }
}

def log-event [event: string] {
    if (($env.HUMOODAGEN_PERF? | default '') != '1') {
        return
    }
    let launch_log = ($env.HUMOODAGEN_GHOSTTY_LAUNCH_LOG? | default '')
    if ($launch_log | is-empty) {
        return
    }

    let now = (ts-ns)
    if ($now | is-empty) {
        return
    }

    $"($now) | ($event) | launch_ts_ns=($env.HUMOODAGEN_LAUNCH_TS_NS? | default '') | pid=($nu.pid)" | save --append $launch_log
}

def main [event?: string] {
    let actual_event = ($event | default 'tmux:hook')
    if $actual_event == 'tmux:client-detached' {
        update-prefill-snapshot
    }
    log-event $actual_event
}
