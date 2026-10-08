function __opx_mv --description "Move 1Password items to another vault"
    argparse --name "opx mv" h/help 'to=' 'from=' -- $argv; or return 2
    set -q _flag_help; and __opx_usage mv; and return 0

    # Resolve to "id<TAB>title<TAB>vault" rows.
    set -l rows
    set -l rc 0
    if test (count $argv) -eq 0
        __opx_can_pick; or begin; __opx_usage mv --error; return 2; end
        set rows (__opx_list items $_flag_from \
            | __opx_pick --multi --hide-key items "Tab: select · Enter: confirm")
        or return 1
    else
        set -l all (__opx_list items $_flag_from)
        for name in $argv
            set -l matches (printf '%s\n' $all | awk -F'\t' -v n="$name" '$2 == n')
            if test (count $matches) -eq 1
                set -a rows $matches
            else if test (count $matches) -eq 0
                __opx_err mv "'$name' not found"(set -q _flag_from; and echo " in $_flag_from"; or echo "")
                set rc 1
            else
                __opx_err mv "'$name' is in several vaults ("(printf '%s\n' $matches | cut -f3 | string join ', ')"); use --from"
                set rc 1
            end
        end
    end
    test (count $rows) -gt 0; or return 1

    set -l to "$_flag_to"
    if test -z "$to"
        __opx_can_pick; or begin; __opx_usage mv --error; return 2; end
        set to (__opx_list vaults | __opx_pick vault "move "(count $rows)" item(s) to" | cut -f1)
        or return 1
    end

    for row in $rows
        set -l c (string split \t -- $row)
        if test "$c[3]" = "$to"
            __opx_err mv "$c[2] already in $to"
            continue
        end
        op item move $c[1] --current-vault $c[3] --destination-vault $to >/dev/null
        and __opx_err mv "$c[3]/$c[2] → $to/$c[2]"
        or set rc 1
    end
    __opx_list --flush
    return $rc
end
