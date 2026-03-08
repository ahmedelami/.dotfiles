#!/opt/homebrew/bin/nu

def main [] {
    let app = '/Applications/Ghostty.app'
    let existing = (^/usr/bin/pgrep -x ghostty | complete)
    if $existing.exit_code == 0 {
        exit 0
    }

    if not ($app | path exists) {
        print --stderr $"ghostty_prewarm: not found: ($app)"
        exit 1
    }

    ^/usr/bin/open -gj -a $app --args --initial-window=false --quit-after-last-window-closed=false
}
