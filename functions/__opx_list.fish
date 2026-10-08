function __opx_list --description "List opx data as TSV (value<TAB>description), cached 5 min"
    # __opx_list vaults | agent-vaults | items [VAULT] | fields VAULT ITEM
    #            | categories | keychain | --flush
    # Used by completions and fzf pickers alike, so it never touches commandline.
    if test "$argv[1]" = --flush
        set -l vars (set -n | string match '__opx_list_cache_*')
        test (count $vars) -gt 0; and set -e $vars
        return 0
    end

    # Results differ per identity, so never cache while acting as a service account.
    set -l cache (set -q OP_SERVICE_ACCOUNT_TOKEN[1]; or echo 1)
    set -l key __opx_list_cache_(string escape --style=var -- "$argv")
    set -l now (date +%s)
    if test -n "$cache"; and set -q $key
        set -l cached $$key
        if test (math $now - $cached[1]) -lt 300
            printf '%s\n' $cached[2..]
            return 0
        end
    end

    set -l out
    switch $argv[1]
        case vaults
            set out (op vault list --format json 2>/dev/null \
                | jq -r '.[] | "\(.name)\t\(.items) items"')
        case agent-vaults
            # Vaults whose read-only service-account token is in the Keychain.
            set out (__opx_list keychain | string replace -r -f -- '-op-sa\t.*$' '\tagent vault')
        case items
            # value: item id; then title, vault, category. Optional VAULT filter.
            set -l scope
            set -q argv[2]; and test -n "$argv[2]"; and set scope --vault $argv[2]
            set out (op item list $scope --format json 2>/dev/null \
                | jq -r '.[] | "\(.id)\t\(.title)\t\(.vault.name)\t\(.category | ascii_downcase)"')
        case fields
            set out (op item get $argv[3] --vault $argv[2] --format json 2>/dev/null \
                | jq -r '.fields[]? | "\(.label)\t\(.type | ascii_downcase)"')
        case categories
            set out (op item template list --format json 2>/dev/null | jq -r '.[] | "\(.name)\t"')
        case keychain
            # Metadata only; no secrets are unlocked.
            set out (security dump-keychain 2>/dev/null \
                | string match -r -g '"svce"<blob>="([^"]*op-sa[^"]*)"' | sort -u \
                | string replace -r '$' '\tKeychain token')
        case '*'
            echo "__opx_list: unknown kind '$argv[1]'" >&2
            return 2
    end
    test (count $out) -gt 0; or return 1
    test -n "$cache"; and set -g $key $now $out
    printf '%s\n' $out
end
