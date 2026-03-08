#!/opt/homebrew/bin/nu

def epoch-seconds [] {
    ((^date +%s | complete).stdout | str trim | into int)
}

def read-int [path: string, default_value: int] {
    if ($path | path exists) {
        do -i { open $path | str trim | into int } | default $default_value
    } else {
        $default_value
    }
}

def main [] {
    let dir = ($nu.home-path | path join '.tmux' 'odometer')
    let total_file = ($dir | path join 'total_seconds')
    let last_run_file = ($dir | path join 'last_run')
    let state_file = ($dir | path join 'current_state')
    let lock_dir = ($dir | path join 'lock')

    let timeout_seconds = 1
    let color_on = '28'
    let color_off = '196'

    mkdir $dir
    if not ($total_file | path exists) { '0' | save -f $total_file }
    if not ($last_run_file | path exists) { ((epoch-seconds) | into string) | save -f $last_run_file }
    if not ($state_file | path exists) { '' | save -f $state_file }

    if ($lock_dir | path exists) {
        let now = (epoch-seconds)
        let last_mod = (do -i { (^stat -f %m $lock_dir | complete).stdout | str trim | into int } | default $now)
        let age = ($now - $last_mod)
        if $age > 3 {
            do -i { rmdir $lock_dir }
        }
    }

    let lock_result = (^mkdir $lock_dir | complete)
    if $lock_result.exit_code == 0 {
        let now = (epoch-seconds)
        let last = (read-int $last_run_file $now)
        mut total = (read-int $total_file 0)
        let delta = ($now - $last)
        mut style = $"#[fg=colour($color_off),bold]"

        if ($delta > 0 and $delta < 10) {
            let client_activity = ((^tmux list-clients -F '#{client_activity}' | complete).stdout | lines | each {|line|
                do -i { $line | str trim | into int } | default 0
            })
            let last_activity_ts = if ($client_activity | is-empty) { 0 } else { $client_activity | sort --reverse | get 0 }
            mut idle_time = ($now - $last_activity_ts)
            if $idle_time < 0 {
                $idle_time = 0
            }

            if $idle_time < $timeout_seconds {
                $total += $delta
                ($total | into string) | save -f $total_file
                $style = $"#[fg=colour($color_on),bold]"
            }
        }

        $style | save -f $state_file
        ($now | into string) | save -f $last_run_file
        do -i { rmdir $lock_dir }
    }

    let total = (read-int $total_file 0)
    let style = if ($state_file | path exists) { open $state_file | str trim } else { '' }
    let hours = ($total // 3600)
    let remainder = ($total mod 3600)
    let minutes = ($remainder // 60)
    let seconds = ($remainder mod 60)

    print -n $"($style)($hours)h ($minutes)m ($seconds)s "
}
