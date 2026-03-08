#!/opt/homebrew/bin/nu

def main [out_file?: string] {
    let repo_dir = ($env.FILE_PWD)
    let target = ($out_file | default ($repo_dir | path join 'entries.tsv'))

    if ((which zoxide | length) == 0) {
        print --stderr 'error: zoxide not found on PATH'
        exit 1
    }

    let lines = (^zoxide query -ls | complete).stdout | lines
    let body = ($lines | where {|line| ($line | str trim | is-not-empty) } | each {|line|
        let parsed = ($line | parse --regex '^(?P<score>\S+)\s+(?P<path>.+)$')
        if ($parsed | is-empty) {
            null
        } else {
            let row = ($parsed | get 0)
            $"($row.score)\t($row.path)"
        }
    } | compact)

    (['# score\tpath'] | append $body | str join (char nl) | $"($in)(char nl)") | save -f $target
    print $"wrote: ($target)"
}
