function __opx_vault --description "Create a 1Password vault if it doesn't exist"
    argparse --max-args 1 h/help -- $argv; or return
    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: opx vault NAME

Create vault NAME unless it already exists (idempotent).

see also: opx mv, opx agent" >&2
        set -q _flag_help; and return 0; or return 2
    end
    if op vault get $argv[1] >/dev/null 2>&1
        echo "opx vault: $argv[1] exists" >&2
        return 0
    end
    op vault create $argv[1] >/dev/null; or return
    echo "opx vault: created $argv[1]" >&2
end
