function __opx_agent --description "Set up a vault + read-only service account (token in Keychain) for agents"
    argparse --name "opx agent" --max-args 1 h/help 'm/move=+' 'e/expires=' 'k/keychain=' r/replace y/yes n/dry-run -- $argv
    or return 2
    set -q _flag_help; and __opx_usage agent; and return 0

    set -l vault $argv[1]
    if test -z "$vault"
        __opx_can_pick; or begin; __opx_usage agent --error; return 2; end
        set -l pick (__opx_list vaults | string match -v -r '^(Personal|Private)\t' \
            | __opx_pick --new vault "pick a vault, or type a new name to create it")
        or return 1
        set -l cols (string split \t -- $pick[1])
        set vault (test -n "$cols[1]"; and echo $cols[1]; or echo $cols[2])
    end
    if string match -q -r '^(Personal|Private)$' -- $vault
        __opx_err agent "service accounts can't access $vault"
        return 1
    end
    set -l service (__opx_service $vault)
    set -q _flag_keychain; and set service $_flag_keychain
    set -l expires 30d
    set -q _flag_expires; and set expires $_flag_expires

    set -l pass
    set -q _flag_yes; and set -a pass -y
    set -q _flag_dry_run; and set -a pass -n
    set -q _flag_replace; and set -a pass -r

    if set -q _flag_dry_run
        op vault get $vault >/dev/null 2>&1
        and __opx_err agent "dry run: vault $vault exists"
        or __opx_err agent "dry run: would create vault $vault"
        test (count $_flag_move) -gt 0; and __opx_err agent "dry run: would move "(string join ', ' $_flag_move)
    else
        __opx_vault $vault; or return 1
        if test (count $_flag_move) -gt 0
            __opx_mv $_flag_move --to $vault; or return 1
        end
    end

    __opx_sa $service -v "$vault:read" -e $expires -S both -k $service $pass; or return 1
    set -q _flag_dry_run; and return 0

    set -l token (security find-generic-password -s $service -w)
    set -l first (env OP_SERVICE_ACCOUNT_TOKEN=$token op item list --vault $vault --format json | jq -r '.[0].id // empty')
    or begin
        __opx_err agent "VERIFY FAILED: can't list $vault as $service"
        return 1
    end
    if test -z "$first"
        __opx_err agent "$vault is empty; verified access only"
    else if env OP_SERVICE_ACCOUNT_TOKEN=$token op item get $first --vault $vault >/dev/null
        __opx_err agent "verified headless read of $vault as $service"
    else
        __opx_err agent "VERIFY FAILED reading $vault as $service"
        return 1
    end

    echo >&2
    __opx_snippet $vault -k $service
end
