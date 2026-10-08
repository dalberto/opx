function __opx_err --description "Print 'opx CMD: message' to stderr"
    echo "opx $argv[1]: $argv[2..]" >&2
end
