# fzf shell integration.
#
# Hand-written, not the `$(brew --prefix)/opt/fzf/install` output: that script
# hardcodes /opt/homebrew/opt/fzf/bin with no OS guard and no existence check,
# which on Ubuntu appends a directory that does not exist. A non-existent PATH
# entry is a latent hijack slot on any host where the parent is writable by a
# less-privileged account, and fzf is Nix-provided here on both OSes anyway.

# Only prepend Homebrew's fzf bin if it actually exists (Intel and Apple Silicon
# prefixes differ, and neither is present on Linux).
for _fzf_dir in /opt/homebrew/opt/fzf/bin /usr/local/opt/fzf/bin; do
    if [[ -d "$_fzf_dir" && ":$PATH:" != *":$_fzf_dir:"* ]]; then
        PATH="$PATH:$_fzf_dir"
    fi
done
unset _fzf_dir

# fzf >= 0.48 ships its own shell integration; older builds use the split
# completion/key-binding files.
if command -v fzf >/dev/null 2>&1; then
    if fzf --zsh >/dev/null 2>&1; then
        source <(fzf --zsh)
    else
        [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
        [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
fi
