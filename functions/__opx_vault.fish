function __opx_vault --description "Create a 1Password vault if it doesn't exist"
    argparse --name "opx vault" --max-args 1 h/help -- $argv; or return 2
    set -q _flag_help; and __opx_usage vault; and return 0
    if test (count $argv) -ne 1
        __opx_usage vault --error
        return 2
    end
    if op vault get $argv[1] >/dev/null 2>&1
        __opx_err vault "$argv[1] exists"
        return 0
    end
    op vault create $argv[1] >/dev/null; or return 1
    __opx_list --flush
    __opx_err vault "created $argv[1]"
end
