function __opx_complete --description "Completion helper for opx: vaults | items | all-items | items-in-first | fields | categories | grants | keychain"
    # Vault comes from -v/--vault on the current commandline, else Dev.
    set -l tokens (commandline -xpc)
    set -l vault Dev
    set -l name ""
    set -l i 3  # skip `opx SUBCOMMAND`
    while test $i -le (count $tokens)
        switch $tokens[$i]
            case -v --vault
                set i (math $i + 1)
                set -q tokens[$i]; and set vault $tokens[$i]
            case '--vault=*'
                set vault (string replace -- --vault= '' $tokens[$i])
            case '-v*'
                set vault (string sub -s 3 -- $tokens[$i])
            case -f --field -t --type -a --as -k --keychain -s --save-vault -e --expires -i --item -m --move -S --store --to --from
                set i (math $i + 1)
            case '-*'
            case '*'
                set name $tokens[$i]
        end
        set i (math $i + 1)
    end

    # grants: VAULT: then VAULT:PERMS once a colon is typed (service accounts
    # can't access Personal/Private).
    if test "$argv[1]" = grants
        set -l cur (commandline -ct | string replace -r -- '^(--vault=|-v)' '' \
            | string trim -l -c "\"'" | string replace -a '\\ ' ' ')
        if string match -q '*:*' -- $cur
            set -l v (string split -r -m1 : -- $cur)[1]
            printf "$v:%s\t%s\n" read 'read only' read,write 'read + write' \
                read,share 'read + share' read,write,share 'all'
        else
            __opx_complete vaults | string match -v -r '^(Personal|Private)$' | string replace -r '$' :
        end
        return
    end

    # op calls can be slow or trigger an unlock prompt; cache lists for 5 min.
    set -l key (string escape --style=var -- "$argv[1] $vault $name")
    set -l now (date +%s)
    if set -q __opx_complete_cache_$key
        set -l var __opx_complete_cache_$key
        set -l cached $$var
        if test (math $now - $cached[1]) -lt 300
            printf '%s\n' $cached[2..]
            return
        end
    end

    set -l out
    switch $argv[1]
        case vaults
            set out (op vault list --format json 2>/dev/null | jq -r '.[].name')
        case items
            set out (op item list --vault $vault --format json 2>/dev/null \
                | jq -r '.[] | "\(.title)\t\(.category | ascii_downcase)"')
        case fields
            test -n "$name"; or return
            set out (op item get $name --vault $vault --format json 2>/dev/null \
                | jq -r '.fields[]? | "\(.label)\t\(.type | ascii_downcase)"')
        case all-items
            set out (op item list --format json 2>/dev/null \
                | jq -r '.[] | "\(.title)\t\(.vault.name)"')
        case items-in-first
            # first positional arg is the vault (opsnippet VAULT ITEM...)
            set -l pos (string match -v -- '-*' $tokens[3..])
            test -n "$pos[1]"; or return
            set out (op item list --vault $pos[1] --format json 2>/dev/null | jq -r '.[].title')
        case keychain
            set out (__opx_keychain_services)
        case categories
            set out (op item template list --format json 2>/dev/null | jq -r '.[].name')
    end
    test (count $out) -gt 0; and set -g __opx_complete_cache_$key $now $out
    printf '%s\n' $out
end
