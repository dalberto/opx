function __opx_snippet --description "Print agent instructions for reading a vault's secrets via its service account"
    argparse --name "opx snippet" h/help 'k/keychain=' c/copy env 'o/out=' -- $argv; or return 2
    set -q _flag_help; and __opx_usage snippet; and return 0
    set -q _flag_out; and set _flag_env 1

    set -l vault $argv[1]
    if test -z "$vault"
        if not __opx_can_pick
            __opx_usage snippet --error
            set -l av (__opx_list agent-vaults | cut -f1)
            test (count $av) -gt 0; or set av "none (run opx agent VAULT)"
            __opx_err snippet "agent vaults: "(string join ', ' -- $av)
            return 2
        end
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
        | jq -r (__opx_jq)'.title as $t | exported as $e
            | if ($e | length) == 0 then "\($t)\t\t0"
              else $e[] | "\($t)\t\(.label)\t\($e | length)" end')
    or begin
        __opx_err snippet "can't read $vault as $service (expired or revoked token?)"
        return 1
    end

    # One op:// reference per usable item; sh-quoted for `op read`, and an
    # env-var name (vault prefix dropped, upper snake case) for --env.
    set -l refs
    set -l reads
    set -l envs
    set -l vars
    set -l found
    for row in $rows
        set -l kv (string split \t -- $row)
        set -a found $kv[1]
        if string match -q '*/*' -- $kv[1]
            __opx_err snippet "skipped '$kv[1]': '/' in name can't be addressed by op://"
        else if test -z "$kv[2]"
            __opx_err snippet "skipped '$kv[1]': no fields with a value"
        else if string match -q '*/*' -- $kv[2]
            __opx_err snippet "skipped '$kv[1]': field '$kv[2]' has '/' in its name"
        else if string match -q -r "'.*\"|\".*'" -- "$kv[1]$kv[2]"
            __opx_err snippet "skipped '$kv[1]': name has both ' and \" characters"
        else
            set -l ref "op://$vault/$kv[1]/$kv[2]"
            set -a refs $ref
            set -a reads "op read '"(string replace -a "'" "'\\''" -- $ref)"'"
            # Single-field item: name after the item. Multi-field: ITEM_FIELD.
            set -l stem (string replace -r -- "^\Q$vault\E[-_ ]+" '' $kv[1])
            test "$kv[3]" -gt 1; and set stem "$stem $kv[2]"
            set -l var (string upper -- $stem | string replace -r -a '[^A-Z0-9]+' _ | string trim -c _)
            string match -q -r '^[0-9]' -- $var; and set var _$var
            test -n "$var"; or set var SECRET
            set -l base $var
            set -l n 2
            while contains -- $var $vars
                set var {$base}_$n
                set n (math $n + 1)
            end
            set -q _flag_env; and test $var != $base; and __opx_err snippet "'$kv[1]' → $var ($base taken)"
            set -a vars $var
            set -l q "'"
            string match -q "*'*" -- $ref; and set q '"'
            set -a envs "$var=$q$ref$q"
        end
    end
    for n in $names
        contains -- $n $found; or __opx_err snippet "'$n' not found in $vault (or not readable as $service)"
    end
    if test (count $refs) -eq 0
        __opx_err snippet "nothing usable in $vault"
        return 1
    end

    set -l token_cmd "\$(security find-generic-password -s $service -w)"
    set -l out
    if set -q _flag_env
        set -l file $vault.env
        set -q _flag_out; and set file $_flag_out
        set -l envfile "# 1Password references for $vault (no secrets; safe to commit)" $envs
        if set -q _flag_out
            printf '%s\n' $envfile >$file; or return 1
            __opx_err snippet "wrote $file ("(count $envs)" refs)"
        end
        set out "## Secrets ($vault)

Secrets come from 1Password via a read-only service account whose token lives
in the macOS Keychain. Run commands that need them under `op run`; it injects
each secret as an environment variable and masks values in output. Never
print, log, or write secret values, or the token, anywhere.
"
        if set -q _flag_out
            set -a out "References are in `$file` (op:// references only, no secrets)."
        else
            set -a out "Save this as `$file` (op:// references only, no secrets):

```sh
"(string join \n -- $envfile | string collect)"
```"
        end
        set -a out "
Run a command with the secrets available as environment variables:

```sh
OP_SERVICE_ACCOUNT_TOKEN=\"$token_cmd\" op run --env-file $file -- <command>
```

Available: "(string join ', ' -- (printf '`%s`\n' $vars))"

If `security` shows a Keychain prompt, ask the user to click \"Always Allow\".
Access is read-only to the `$vault` vault; ask the user to add new secrets there."
    else
        set out "## Secrets ($vault)

Read secrets with the 1Password CLI as a read-only service account. The token
lives in the macOS Keychain; never write it or any secret to files, env files,
logs, or the repo. Fetch at the point of use.

```sh
export OP_SERVICE_ACCOUNT_TOKEN=\"$token_cmd\"
"(string join \n -- $reads | string collect)"
```

Or scoped to one command (preferred; token isn't left in the environment):

```sh
OP_SERVICE_ACCOUNT_TOKEN=\"$token_cmd\" $reads[1]
```

If `security` shows a Keychain prompt, ask the user to click \"Always Allow\".
Access is read-only to the `$vault` vault; ask the user to add new secrets there."
    end

    if set -q _flag_copy
        printf '%s\n' $out | pbcopy
        __opx_err snippet copied
    else
        printf '%s\n' $out
    end
end
