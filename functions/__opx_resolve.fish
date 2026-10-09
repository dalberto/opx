function __opx_resolve --description "Resolve an item reference to 'id<TAB>title<TAB>vault<TAB>field'"
    # __opx_resolve CMD [--new] [--scope VAULT] [--default VAULT] [NAME]
    #
    # NAME may be:
    #   (empty)        fzf picker over items in --scope (else all vaults)
    #   op://V/I/F     vault V, item I, field F
    #   26-char id     item id, in any vault
    #   exact title    in --scope, else --default, else anywhere if unique
    #   partial title  unique case-insensitive substring match; otherwise the
    #                  picker, prefiltered (headless: error)
    # --new (opx set): never guess from a partial match. A name that isn't an
    # exact match creates a new item (id column empty) in --scope/--default;
    # interactively, similar items are offered first.
    set -l cmd $argv[1]
    argparse 'new' 'scope=' 'default=' -- $argv[2..-1]; or return 2
    set -l name $argv[1]
    set -l home $_flag_default
    set -q _flag_scope; and set home $_flag_scope

    # op://vault/item/field (any ?query is ignored; sections are not supported)
    if string match -q 'op://*' -- $name
        set -l parts (string replace 'op://' '' -- $name | string replace -r '\?.*$' '' | string split /)
        if test (count $parts) -lt 2
            __opx_err $cmd "bad reference '$name' (expected op://vault/item[/field])"
            return 2
        end
        set -l json (op item get $parts[2] --vault $parts[1] --format json 2>/dev/null | string collect)
        if test -z "$json"
            __opx_err $cmd "no item '$parts[2]' in vault '$parts[1]'"
            return 1
        end
        printf '%s' $json | jq -r --arg f "$parts[-1]" --argjson n (count $parts) \
            '"\(.id)\t\(.title)\t\(.vault.name)\t\(if $n > 2 then $f else "" end)"'
        return 0
    end

    # 1Password item id
    if string match -q -r '^[a-z0-9]{26}$' -- $name
        set -l json (op item get $name --format json 2>/dev/null | string collect)
        if test -n "$json"
            printf '%s' $json | jq -r '"\(.id)\t\(.title)\t\(.vault.name)\t"'
            return 0
        end
    end

    set -l rows (__opx_list items $_flag_scope)
    if test -n "$name"
        # exact title: home vault first, then anywhere (when not scoped)
        set -l exact (printf '%s\n' $rows | awk -F'\t' -v n="$name" -v v="$home" '$2 == n && $3 == v')
        test (count $exact) -eq 0; and not set -q _flag_scope
        and set exact (printf '%s\n' $rows | awk -F'\t' -v n="$name" '$2 == n')
        if test (count $exact) -eq 1
            printf '%s\t\n' (string split -f1,2,3 \t -- $exact | string join \t)
            return 0
        end
        set -l similar (printf '%s\n' $rows | awk -F'\t' -v n=(string lower -- $name) 'index(tolower($2), n)')
        test (count $exact) -gt 1; and set similar $exact

        if set -q _flag_new
            if test (count $similar) -gt 0; and __opx_can_pick
                set -l pick (begin
                        printf '\t+ create %s in %s\t\t\n' $name $home
                        printf '%s\n' $similar
                    end | __opx_pick --hide-key item "no exact match for '$name'")
                or return 1
                set -l c (string split \t -- $pick[1])
                test -n "$c[1]"; and printf '%s\t%s\t%s\t\n' $c[1] $c[2] $c[3]; and return 0
            end
            printf '\t%s\t%s\t\n' $name $home
            return 0
        end

        if test (count $similar) -eq 1
            set -l c (string split \t -- $similar)
            __opx_err $cmd "using $c[3]/$c[2]"
            printf '%s\t%s\t%s\t\n' $c[1] $c[2] $c[3]
            return 0
        end
        if not __opx_can_pick
            if test (count $similar) -eq 0
                __opx_err $cmd "no item matches '$name'"(set -q _flag_scope; and echo " in $_flag_scope"; or echo "")
            else
                set -l names (printf '%s\n' $similar | awk -F'\t' '{print $3 "/" $2}')
                test (count $names) -gt 6; and set names $names[1..6] "…"
                __opx_err $cmd "'$name' matches "(count $similar)" items: "(string join ', ' $names)"; be more specific"
            end
            return 1
        end
    else
        __opx_can_pick; or return 2
    end

    set -l q
    test -n "$name"; and set q --query $name
    set -l pick (printf '%s\n' $rows | __opx_pick --hide-key $q item "pick an item"); or return 1
    set -l c (string split \t -- $pick[1])
    printf '%s\t%s\t%s\t\n' $c[1] $c[2] $c[3]
end
