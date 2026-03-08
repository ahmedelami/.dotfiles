#!/opt/homebrew/bin/nu

def main [
    --existing-only
    --force
    in_file?: string
] {
    let repo_dir = ($env.FILE_PWD)
    let input = ($in_file | default ($repo_dir | path join 'entries.tsv'))

    if ((which zoxide | length) == 0) {
        print --stderr 'error: zoxide not found on PATH'
        exit 1
    }

    if not ($input | path exists) {
        print --stderr $"error: cannot read: ($input)"
        exit 1
    }

    let existing = if $force {
        []
    } else {
        (^zoxide query -l | complete).stdout | lines
    }

    mut imported = 0
    mut skipped = 0

    for line in (open $input | lines) {
        if (($line | str trim | is-empty) or ($line | str starts-with '#')) {
            continue
        }

        let parsed = if ($line | str contains (char tab)) {
            let split = ($line | split row (char tab))
            if (($split | length) < 2) {
                []
            } else {
                [{ score: ($split | get 0), path: ($split | skip 1 | str join (char tab)) }]
            }
        } else {
            $line | parse --regex '^(?P<score>\S+)\s+(?P<path>.+)$'
        }

        if ($parsed | is-empty) {
            continue
        }

        let row = ($parsed | get 0)
        let score = ($row.score | str trim)
        let path = ($row.path | str trim)

        if (($score | is-empty) or ($path | is-empty)) {
            continue
        }

        if ($existing_only and not ($path | path exists)) {
            $skipped += 1
            continue
        }

        if ((not $force) and ($existing | any {|candidate| $candidate == $path })) {
            $skipped += 1
            continue
        }

        do -i { ^zoxide add -s $score -- $path }
        $imported += 1
    }

    print $"imported: ($imported)"
    print $"skipped:  ($skipped)"
}
