function __opx_sa --description "Mint a 1Password service account token and save it to 1Password and/or Keychain"
    argparse --max-args 1 h/help 'v/vault=+' 'e/expires=' C/can-create-vaults \
        's/save-vault=' 'i/item=' 'S/store=' 'k/keychain=' r/replace c/copy y/yes n/dry-run -- $argv
    or return
    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: opx sa NAME [-v VAULT[:PERMS]]... [-e DURATION] [options]
       (abbrs: opsa, op-service-token)

Mint a 1Password service account token and save it (as an API Credential
item and/or in the macOS Keychain) so the one-time token is never lost. With no -v, pick vaults and
permissions interactively (fzf, multi-select with Tab).

  -v, --vault VAULT[:PERMS]  grant access; repeatable. PERMS is a comma list of
                             read, write, share (or read_items, ...). Default
                             read. write/share imply read.
  -e, --expires DURATION     token lifetime, e.g. 24h, 7d, 4w (default: never)
  -C, --can-create-vaults    allow the service account to create vaults
  -s, --save-vault VAULT     where to save the token (default: Dev)
  -i, --item NAME            item title for the token (default: NAME)
  -S, --store WHERE          op | keychain | both (default: op, or both with -k)
  -k, --keychain SERVICE     Keychain service name (default: NAME)
  -r, --replace              overwrite an existing item/Keychain entry (rotation)
  -c, --copy                 also copy the token to the clipboard
  -y, --yes                  skip confirmation
  -n, --dry-run              show what would happen; mint nothing
  -h, --help                 show this help

Personal/Private vaults can't be granted. Revoke service accounts in the
1Password web app (Developer > Service Accounts); the CLI can't.

examples:
  opx sa ci-deploy                                   # interactive picker
  opx sa ci-deploy -v Dev -v Production:read,write -e 30d
  opx sa ci-agents -v ci-agents -e 30d -S both      # token in 1Password + Keychain
  set -x OP_SERVICE_ACCOUNT_TOKEN (opx get ci-deploy)

see also: opx agent, opx token, opx run, opx snippet, opx set, opx get" >&2
        set -q _flag_help; and return 0; or return 2
    end

    set -l name $argv[1]
    set -l save_vault Dev
    set -q _flag_save_vault; and set save_vault $_flag_save_vault
    set -l item $name
    set -q _flag_item; and set item $_flag_item
    set -l service $name
    set -q _flag_keychain; and set service $_flag_keychain
    set -l store op
    set -q _flag_keychain; and set store both
    set -q _flag_store; and set store $_flag_store
    if not contains -- $store op keychain both
        echo "opx sa: --store must be op, keychain, or both" >&2
        return 2
    end
    set -l to_op (contains -- $store op both; and echo 1)
    set -l to_kc (contains -- $store keychain both; and echo 1)
    if test -n "$to_kc"; and not string match -q -r '^[A-Za-z0-9._-]+$' -- $service
        echo "opx sa: Keychain service must match [A-Za-z0-9._-]+: $service (use -k)" >&2
        return 2
    end

    set -l specs $_flag_vault
    if test (count $specs) -eq 0
        if not isatty stdin
            echo "opx sa: no -v given and not interactive" >&2
            return 2
        end
        if not command -q fzf
            echo "opx sa: fzf not found; pass -v VAULT[:PERMS]" >&2
            return 1
        end
        set -l vaults (op vault list --format json | jq -r '.[].name' \
            | string match -v -r '^(Personal|Private)$' \
            | fzf --multi --height=40% --reverse --prompt="vaults> " \
                --header="Tab: select · Enter: confirm · grant '$name' access to")
        or return 1
        for v in $vaults
            set -l perms (printf '%s\n' read read,write read,share read,write,share \
                | fzf --height=30% --reverse --prompt="$v perms> " --header="permissions for $v")
            or return 1
            set -a specs "$v:$perms"
        end
    end

    # Normalize VAULT[:PERMS] → --vault VAULT:read_items[,write_items][,share_items]
    set -l vault_args
    set -l grants
    for spec in $specs
        set -l parts (string split -r -m1 : -- $spec)
        set -l vault $parts[1]
        set -l perms read
        set -q parts[2]; and set perms (string split , -- $parts[2])
        if string match -q -r '^(Personal|Private)$' -- $vault
            echo "opx sa: can't grant service accounts access to $vault" >&2
            return 1
        end
        set -l norm read_items
        for p in $perms
            set p (string replace -r '_items$' '' -- (string lower -- $p))
            switch $p
                case read r
                case write w
                    contains write_items $norm; or set -a norm write_items
                case share s
                    contains share_items $norm; or set -a norm share_items
                case '*'
                    echo "opx sa: unknown permission '$p' for $vault (use read, write, share)" >&2
                    return 1
            end
        end
        set -a vault_args --vault "$vault:"(string join , $norm)
        set -a grants "$vault:"(string join , $norm)
    end

    set -l extra_args
    set -q _flag_expires; and set -a extra_args --expires-in $_flag_expires
    set -q _flag_can_create_vaults; and set -a extra_args --can-create-vaults

    # Fail before minting if the token can't be saved — the token is shown once.
    set -l existing
    if test -n "$to_op"
        set existing (op item get $item --vault $save_vault --format json 2>/dev/null | string collect)
        if test -n "$existing"; and not set -q _flag_replace
            echo "opx sa: $save_vault/$item already exists; use -r/--replace or -i/--item" >&2
            return 1
        end
    end
    if test -n "$to_kc"; and security find-generic-password -s $service >/dev/null 2>&1; and not set -q _flag_replace
        echo "opx sa: Keychain item '$service' already exists; use -r/--replace or -k" >&2
        return 1
    end
    set -l targets
    test -n "$to_op"; and set -a targets "1Password $save_vault/$item"(test -n "$existing"; and echo " (replace)"; or echo "")
    test -n "$to_kc"; and set -a targets "Keychain $service"(set -q _flag_replace; and echo " (replace)"; or echo "")

    echo "service account: $name
grants:          "(string join ', ' $grants)"
expires:         "(set -q _flag_expires; and echo $_flag_expires; or echo never)"
create vaults:   "(set -q _flag_can_create_vaults; and echo yes; or echo no)"
save token to:   "(string join ', ' $targets) >&2

    if set -q _flag_dry_run
        echo "dry run: op service-account create $name "(string join ' ' -- (string escape -- $vault_args $extra_args))" --raw" >&2
        return 0
    end
    if not set -q _flag_yes
        read --prompt-str "mint? [y/N] " -l ok; or return 1
        string match -q -r '^[yY]' -- $ok; or return 1
    end

    set -l token (op service-account create $name $vault_args $extra_args --raw)
    or begin
        echo "opx sa: failed to create service account $name" >&2
        return 1
    end

    set -l saved
    set -l failed
    if test -n "$to_kc"
        printf %s $token | __opx_keychain_set $service (set -q _flag_replace; and echo --replace)
        and set -a saved "Keychain $service"
        or set -a failed "Keychain $service"
    end

    if test -n "$to_op"
        set -l notes "Service account: $name
Grants: "(string join ', ' $grants)"
Expires: "(set -q _flag_expires; and echo "$_flag_expires from "(date +%F); or echo never)"
Keychain: "(test -n "$to_kc"; and echo $service; or echo none)"
Created: "(date +%F)" via opx sa"
        set -l prog '
            .title = $t
            | .fields |= map(
                if .id == "credential" then .value = $s
                elif .id == "username" then .value = $u
                elif .id == "notesPlain" then .value = $n
                else . end)
            | .fields |= map(select(.type == "CONCEALED" or (.value // "") != ""))'
        if test -n "$existing"
            printf '%s\n' $existing \
                | jq --arg t $item --arg u $name --arg n $notes --rawfile s (printf %s $token | psub -F) $prog \
                | op item edit (printf '%s\n' $existing | jq -r .id) --vault $save_vault >/dev/null
        else
            op item template get "API Credential" \
                | jq --arg t $item --arg u $name --arg n $notes --rawfile s (printf %s $token | psub -F) $prog \
                | op item create --vault $save_vault --tags service-account - >/dev/null
        end
        and set -a saved "1Password $save_vault/$item"
        or set -a failed "1Password $save_vault/$item"
    end

    if test (count $saved) -eq 0
        printf %s $token | pbcopy
        echo "opx sa: SAVE FAILED ("(string join ', ' $failed)") — token is on your clipboard; store it now" >&2
        return 1
    end
    set -q _flag_copy; and printf %s $token | pbcopy
    echo "opx sa: saved to "(string join ', ' $saved)(set -q _flag_copy; and echo " (copied)"; or echo "") >&2
    if test (count $failed) -gt 0
        echo "opx sa: WARNING: failed to save to "(string join ', ' $failed)"; recover with opx get/opx token" >&2
        return 1
    end
end
