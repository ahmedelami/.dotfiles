#!/opt/homebrew/bin/nu

def ts-ns [] {
    (^python3 -c 'import time; print(time.time_ns())' | complete).stdout | str trim
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

def main [] {
    log-event 'tmux:cmd:start'

    let result = (with-env { HUMOODAGEN_FAST_START: '1' } { ^nvim | complete })
    let status = $result.exit_code

    log-event $"tmux:cmd:nvim_exit status=($status)"

    ^/opt/homebrew/bin/nu -l
}
