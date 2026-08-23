# ~/.bash_profile: executed by the command interpreter for login shells.

# PATH extensions
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# source bashrc for interactive, non-login shells' worth of config
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
