function __opx_token_dir --description "Linux token directory (provisioned externally)"
    if set -q OPX_TOKEN_DIR; and test -n "$OPX_TOKEN_DIR"
        printf '%s\n' "$OPX_TOKEN_DIR"
    else if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        printf '%s/opx/tokens\n' "$XDG_CONFIG_HOME"
    else
        printf '%s/.config/opx/tokens\n' "$HOME"
    end
end
