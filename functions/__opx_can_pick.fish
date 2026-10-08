function __opx_can_pick --description "True when an fzf picker can be shown (interactive, TTY, fzf)"
    # stdin, not stdout: `set x (opx get)` still gets a picker (fzf draws on
    # /dev/tty), while scripts and agents fall through to a usage error.
    status is-interactive; and isatty stdin; and command -q fzf
end
