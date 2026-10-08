function __opx_default_vault --description "Default vault: \$OPX_VAULT, else Dev"
    set -q OPX_VAULT[1]; and echo $OPX_VAULT; or echo Dev
end
