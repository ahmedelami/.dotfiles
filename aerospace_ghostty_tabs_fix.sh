#!/opt/homebrew/bin/nu

def main [] {
    let aerospace_bin = '/opt/homebrew/bin/aerospace'
    if not ($aerospace_bin | path exists) {
        exit 0
    }

    let lock_dir = (($env.TMPDIR? | default '/tmp') | path join 'aerospace-native-tabs-fix.lock')
    let lock_result = (^/bin/mkdir $lock_dir | complete)
    if $lock_result.exit_code != 0 {
        exit 0
    }

    let focused_bundle_id = ((^$aerospace_bin list-windows --focused --format '%{app-bundle-id}' | complete).stdout | str trim)
    let is_target = ($focused_bundle_id == 'com.mitchellh.ghostty' or $focused_bundle_id == 'com.apple.Terminal')

    if $is_target {
        let workspace = ((^$aerospace_bin list-windows --focused --format '%{workspace}' | complete).stdout | str trim)
        if ($workspace | is-not-empty) {
            let root_layout = ((^$aerospace_bin list-windows --focused --format '%{workspace-root-container-layout}' | complete).stdout | str trim)
            if ($root_layout in ['h_tiles', 'v_tiles', 'h_accordion', 'v_accordion']) {
                let tabbed_app_count = (((^$aerospace_bin list-windows --workspace $workspace --app-bundle-id $focused_bundle_id --count | complete).stdout | str trim) | default '0')
                let total_count = (((^$aerospace_bin list-windows --workspace $workspace --count | complete).stdout | str trim) | default '0')

                if $tabbed_app_count == $total_count {
                    if (($tabbed_app_count | into int) >= 1) {
                        match $root_layout {
                            'h_tiles' => { do -i { ^$aerospace_bin layout h_accordion } }
                            'v_tiles' => { do -i { ^$aerospace_bin layout v_accordion } }
                            _ => {}
                        }
                    }
                }
            }
        }
    }

    rm -rf $lock_dir
}
