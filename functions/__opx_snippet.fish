function __opx_snippet --description "Print agent instructions for reading a vault's secrets via its service account"
    argparse h/help 'k/keychain=' c/copy -- $argv; or return
    if set -q _flag_help
        echo "usage: opx snippet [VAULT [ITEM...]] [-k SERVICE] [-c]

Print a markdown snippet an agent can follow to read secrets from VAULT
headlessly: token from Keychain SERVICE, one op:// reference per item.
With no VAULT, pick from vaults that have a Keychain token (set up by
opx agent). With no ITEM, includes every readable item in VAULT.

Items are read as the service account itself, so the snippet only lists
what the agent can actually access. Items without a concealed value, or
with '/' in the name, are skipped with a warning.

  -k, --keychain SERVICE   Keychain service holding the token (default: VAULT-op-sa)
  -c, --copy               copy instead of printing

examples:
  opx snippet -c                         # pick a vault, copy instructions
  opx snippet my-agents -c

see also: opx agent, opx token, opx run" >&2
        return 0
    end

    set -l vault $argv[1]
    if test -z "$vault"
        set -l agent_vaults (__opx_keychain_services | string replace -r -f -- '-op-sa$' '')
        if test (count $agent_vaults) -eq 0
            echo "opx snippet: no agent vaults found (no *-op-sa Keychain tokens); run opx agent VAULT first" >&2
            return 1
        end
        if not isatty stdin; or not command -q fzf
            echo "opx snippet: pass a VAULT; agent vaults: "(string join ', ' $agent_vaults) >&2
            return 2
        end
        set vault (printf '%s\n' $agent_vaults | fzf --select-1 --height=40% --reverse \
            --prompt="vault> " --header="agent vaults (Keychain tokens)")
        or return 1
    end
    set -l service $vault-op-sa
    set -q _flag_keychain; and set service $_flag_keychain
    set -l names $argv[2..]

    # Read as the service account: no biometric prompt, and the result reflects
    # exactly what the agent will be able to read.
    set -lx OP_SERVICE_ACCOUNT_TOKEN (security find-generic-password -s $service -w 2>/dev/null)
    if test -z "$OP_SERVICE_ACCOUNT_TOKEN"
        echo "opx snippet: no Keychain token '$service'; run opx agent $vault first (or pass -k SERVICE)" >&2
        return 1
    end
    set -l rows (op item list --vault $vault --format json \
        | jq -c --args '[.[] | select(($ARGS.positional | length) == 0 or (.title | IN($ARGS.positional[])))]' $names \
        | op item get - --format json \
        | jq -r '"\(.title)\t\([.fields[]? | select(.type == "CONCEALED" and (.value // "") != "")] | first | .label // "")"')
    or begin
        echo "opx snippet: can't read $vault as $service (expired or revoked token?)" >&2
        return 1
    end

    set -l refs
    set -l found
    for row in $rows
        set -l kv (string split \t -- $row)
        set -a found $kv[1]
        if string match -q '*/*' -- $kv[1]
            echo "opx snippet: skipped '$kv[1]': '/' in name can't be addressed by op://" >&2
        else if test -z "$kv[2]"
            echo "opx snippet: skipped '$kv[1]': no concealed field with a value" >&2
        else if string match -q '*/*' -- $kv[2]
            echo "opx snippet: skipped '$kv[1]': field '$kv[2]' has '/' in its name" >&2
        else
            set -a refs "op read 'op://$vault/$kv[1]/$kv[2]'"
        end
    end
    for n in $names
        contains -- $n $found; or echo "opx snippet: '$n' not found in $vault (or not readable as $service)" >&2
    end
    if test (count $refs) -eq 0
        echo "opx snippet: nothing usable in $vault" >&2
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
        echo "opx snippet: copied" >&2
    else
        printf '%s\n' $out
    end
end
