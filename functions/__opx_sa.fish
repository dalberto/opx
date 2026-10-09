function __opx_sa --description "Mint a 1Password service account token and save it to 1Password and/or Keychain"
    argparse --name "opx sa" --max-args 1 h/help 'v/vault=+' 'e/expires=' C/can-create-vaults \
        's/save-vault=' 'i/item=' 'S/store=' 'k/keychain=' r/replace c/copy y/yes n/dry-run -- $argv
    or return 2
    set -q _flag_help; and __opx_usage sa; and return 0
    if test (count $argv) -ne 1
        __opx_usage sa --error
        return 2
    end

    set -l name $argv[1]
    set -l save_vault (__opx_default_vault)
    set -q _flag_save_vault; and set save_vault $_flag_save_vault
    set -l item $name
    set -q _flag_item; and set item $_flag_item
    set -l service $name
    set -q _flag_keychain; and set service $_flag_keychain
    set -l store op
    set -q _flag_keychain; and set store both
    set -q _flag_store; and set store $_flag_store
    if not contains -- $store op keychain both
        __opx_err sa "--store must be op, keychain, or both"
        return 2
    end
    set -l to_op (contains -- $store op both; and echo 1)
    set -l to_kc (contains -- $store keychain both; and echo 1)
    if test -n "$to_kc"; and not string match -q -r '^[A-Za-z0-9._-]+$' -- $service
        __opx_err sa "Keychain service must match [A-Za-z0-9._-]+: $service (use -k)"
        return 2
    end

    set -l specs $_flag_vault
    if test (count $specs) -eq 0
        __opx_can_pick; or begin; __opx_usage sa --error; return 2; end
        set -l vaults (__opx_list vaults | string match -v -r '^(Personal|Private)\t' \
            | __opx_pick --multi vaults "Tab: select · Enter: confirm · grant '$name' access to" | cut -f1)
        or return 1
        for v in $vaults
            set -l perms (printf '%s\t%s\n' read 'read only' read,write 'read + write' \
                read,share 'read + share' read,write,share all \
                | __opx_pick perms "permissions for $v" | cut -f1)
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
            __opx_err sa "can't grant service accounts access to $vault"
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
                    __opx_err sa "unknown permission '$p' for $vault (use read, write, share)"
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
            __opx_err sa "$save_vault/$item already exists; use -r/--replace or -i/--item"
            return 1
        end
    end
    if test -n "$to_kc"; and security find-generic-password -s $service >/dev/null 2>&1; and not set -q _flag_replace
        __opx_err sa "Keychain item '$service' already exists; use -r/--replace or -k"
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
        __opx_err sa "dry run: op service-account create $name "(string join ' ' -- (string escape -- $vault_args $extra_args))" --raw"
        return 0
    end
    if not set -q _flag_yes
        read --prompt-str "mint? [y/N] " -l ok; or return 1
        string match -q -r '^[yY]' -- $ok; or return 1
    end

    set -l token (op service-account create $name $vault_args $extra_args --raw)
    or begin
        __opx_err sa "failed to create service account $name"
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
        __opx_err sa "SAVE FAILED ("(string join ', ' $failed)") — token is on your clipboard; store it now"
        return 1
    end
    set -q _flag_copy; and printf %s $token | __opx_copy_secret >/dev/null
    __opx_list --flush
    __opx_err sa "saved to "(string join ', ' $saved)(set -q _flag_copy; and echo " (copied)"; or echo "")
    if test (count $failed) -gt 0
        __opx_err sa "WARNING: failed to save to "(string join ', ' $failed)"; recover with opx get/opx token"
        return 1
    end
end
