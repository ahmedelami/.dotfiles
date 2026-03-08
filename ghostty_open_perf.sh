#!/opt/homebrew/bin/nu

def ts-ns [] {
    (^python3 -c 'import time; print(time.time_ns())' | complete).stdout | str trim
}

def main [...args: string] {
    let state_home = ($env.XDG_STATE_HOME? | default ($nu.home-path | path join '.local' 'state'))
    let state_dir = ($state_home | path join 'humoodagen')
    let open_ts_file = ($state_dir | path join 'ghostty-open-ts-ns')

    mkdir $state_dir
    (ts-ns) | save -f $open_ts_file

    ^/usr/bin/open -na /Applications/Ghostty.app --args ...$args
}
