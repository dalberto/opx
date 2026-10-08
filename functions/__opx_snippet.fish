function __opx_snippet --description "Print agent instructions for reading a vault's secrets via its service account"
    argparse --name "opx snippet" h/help 'k/keychain=' c/copy -- $argv; or return 2
    set -q _flag_help; and __opx_usage snippet; and return 0

    set -l vault $argv[1]
    if test -z "$vault"
        __opx_can_pick; or begin; __opx_usage snippet --error; return 2; end
        set vault (__opx_list agent-vaults | __opx_pick vault "agent vaults (Keychain tokens)" | cut -f1)
        or begin
            __opx_list agent-vaults >/dev/null; or __opx_err snippet "no agent vaults yet; run opx agent VAULT"
            return 1
        end
    end
    set -l service (__opx_service $vault)
    set -q _flag_keychain; and set service $_flag_keychain
    set -l names $argv[2..]

    # Read as the service account: no biometric prompt, and the result reflects
    # exactly what the agent will be able to read.
    set -lx OP_SERVICE_ACCOUNT_TOKEN (security find-generic-password -s $service -w 2>/dev/null)
    if test -z "$OP_SERVICE_ACCOUNT_TOKEN"
        __opx_err snippet "no Keychain token '$service'; run opx agent $vault first (or pass -k SERVICE)"
        return 1
    end
    set -l rows (op item list --vault $vault --format json \
        | jq -c --args '[.[] | select(($ARGS.positional | length) == 0 or (.title | IN($ARGS.positional[])))]' $names \
        | op item get - --format json \
        | jq -r (__opx_jq)'"\(.title)\t\(readable | first | .label // "")"')
    or begin
        __opx_err snippet "can't read $vault as $service (expired or revoked token?)"
        return 1
    end

    set -l refs
    set -l found
    for row in $rows
        set -l kv (string split \t -- $row)
        set -a found $kv[1]
        if string match -q '*/*' -- $kv[1]
            __opx_err snippet "skipped '$kv[1]': '/' in name can't be addressed by op://"
        else if test -z "$kv[2]"
            __opx_err snippet "skipped '$kv[1]': no concealed field with a value"
        else if string match -q '*/*' -- $kv[2]
            __opx_err snippet "skipped '$kv[1]': field '$kv[2]' has '/' in its name"
        else
            set -a refs "op read 'op://$vault/$kv[1]/$kv[2]'"
        end
    end
    for n in $names
        contains -- $n $found; or __opx_err snippet "'$n' not found in $vault (or not readable as $service)"
    end
    if test (count $refs) -eq 0
        __opx_err snippet "nothing usable in $vault"
        return 1
    end

    set -l out "## Secrets ($vault)

Read secrets with the 1Password CLI as a read-only service account. The token
lives in the macOS Keychain; never write it or any secret to files, env files,
logs, or the repo. Fetch at the point of use.

```sh
export OP_SERVICE_ACCOUNT_TOKEN=\"\$(security find-generic-password -s $service -w)\"
"(string join \n -- $refs)"
```

Or scoped to one command (preferred; token isn't left in the environment):

```sh
OP_SERVICE_ACCOUNT_TOKEN=\"\$(security find-generic-password -s $service -w)\" $refs[1]
```

If `security` shows a Keychain prompt, ask the user to click \"Always Allow\".
Access is read-only to the `$vault` vault; ask the user to add new secrets there."

    if set -q _flag_copy
        printf '%s\n' $out | pbcopy
        __opx_err snippet copied
    else
        printf '%s\n' $out
    end
end
