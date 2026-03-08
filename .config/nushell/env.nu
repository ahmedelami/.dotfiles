# Nushell Environment Config File
#
# version = "0.111.0"

use std/util "path add"

$env.SHELL = "/opt/homebrew/bin/nu"
$env.INSIDE_NU = "1"
$env.HOMEBREW_PREFIX = ($env.HOMEBREW_PREFIX? | default "/opt/homebrew")
$env.STARSHIP_CONFIG = "/Users/ahmedelamin/.config/starship.toml"
$env.EDITOR = ($env.EDITOR? | default "nvim")
$env.LESS = "-FRX"
$env.CLICOLOR = "1"
$env.LSCOLORS = "Fxfxcxdxexegedabagacad"
$env.PNPM_HOME = "/Users/ahmedelamin/Library/pnpm"
$env.BUN_INSTALL = "/Users/ahmedelamin/.bun"
$env.NVM_DIR = "/Users/ahmedelamin/.nvm"
$env.ANDROID_HOME = "/Users/ahmedelamin/Library/Android/sdk"
$env.JAVA_HOME = "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

path add "/opt/homebrew/bin"
path add "/opt/homebrew/sbin"
path add "/usr/local/opt/gnu-tar/libexec/gnubin"
path add "/Users/ahmedelamin/.local/bin"
path add "/Users/ahmed/.local/bin"
path add "/Applications/UTM.app/Contents/MacOS"
path add $env.PNPM_HOME
path add ($env.BUN_INSTALL | path join "bin")
path add "/Users/ahmedelamin/.antigravity/antigravity/bin"
path add "/Users/ahmedelamin/.orbstack/bin"
path add "/opt/local/bin"
path add "/opt/local/sbin"
path add "/Library/TeX/texbin"

if ($env.ANDROID_HOME | path exists) {
    path add ($env.ANDROID_HOME | path join "tools")
    path add ($env.ANDROID_HOME | path join "platform-tools")
}

if ("/opt/homebrew/opt/postgresql@16/bin" | path exists) {
    path add "/opt/homebrew/opt/postgresql@16/bin"
}
