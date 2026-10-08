function __opx_run --description "Run a command as a 1Password service account (token from Keychain)"
    if contains -- "$argv[1]" -h --help
        __opx_usage run
        return 0
    end
    set -l service
    if test "$argv[1]" != --
        set service $argv[1]
        set -e argv[1]
    end
    test "$argv[1]" = --; and set -e argv[1]
    if test (count $argv) -eq 0
        __opx_usage run --error
        return 2
    end
    if test -z "$service"
        __opx_can_pick; or begin; __opx_usage run --error; return 2; end
        set service (__opx_list keychain | __opx_pick token "run as" | cut -f1); or return 1
    end
    set -l token (__opx_token $service); or return 1
    env OP_SERVICE_ACCOUNT_TOKEN=$token $argv
end
