# Keep fresh login shells rooted at home when the terminal launches them with
# "/" as the starting directory.
if [[ -o login && -o interactive && "$PWD" == "/" ]]; then
  cd "$HOME" || exit 1
fi
