#!/opt/homebrew/bin/nu

def main [] {
    let aerospace_bin = '/opt/homebrew/bin/aerospace'
    if not ($aerospace_bin | path exists) {
        exit 0
    }

    let lock_dir = (($env.TMPDIR? | default '/tmp') | path join 'aerospace-chrome-tiles-fix.lock')
    let lock_result = (^/bin/mkdir $lock_dir | complete)
    if $lock_result.exit_code != 0 {
        exit 0
    }

    let focused_bundle_id = ((^$aerospace_bin list-windows --focused --format '%{app-bundle-id}' | complete).stdout | str trim)
    if ($focused_bundle_id | str starts-with 'com.google.Chrome') {
        let workspace = ((^$aerospace_bin list-windows --focused --format '%{workspace}' | complete).stdout | str trim)
        if ($workspace | is-not-empty) {
            let root_layout = ((^$aerospace_bin list-windows --focused --format '%{workspace-root-container-layout}' | complete).stdout | str trim)
            match $root_layout {
                'h_accordion' => { do -i { ^$aerospace_bin layout h_tiles } }
                'v_accordion' => { do -i { ^$aerospace_bin layout v_tiles } }
                _ => {}
            }
        }
    }

    rm -rf $lock_dir
}
