function __opx_complete --description "Completion candidates for opx: vaults | items | all-items | fields | vault-items | grants | keychain | agent-vaults | categories"
    switch $argv[1]
        case vaults
            __opx_list vaults
        case items
            # titles in -v VAULT (or the default vault)
            set -l vault (__opx_cl opt -v --vault); or set vault (__opx_default_vault)
            __opx_list items $vault | awk -F'\t' '{print $2 "\t" $4}'
        case all-items
            __opx_list items | awk -F'\t' '{print $2 "\t" $3}'
        case fields
            set -l item (__opx_cl pos)[1]
            test -n "$item"; or return
            set -l vault (__opx_cl opt -v --vault); or set vault (__opx_default_vault)
            __opx_list fields $vault $item
        case vault-items
            # titles in the first positional (opx snippet VAULT ITEM...)
            set -l vault (__opx_cl pos)[1]
            test -n "$vault"; and __opx_list items $vault | awk -F'\t' '{print $2 "\t" $4}'
        case grants
            # VAULT: first; VAULT:PERMS once a colon is typed.
            set -l cur (commandline -ct | string replace -r -- '^(--vault=|-v)' '' \
                | string trim -l -c "\"'" | string replace -a '\\ ' ' ')
            if string match -q '*:*' -- $cur
                set -l v (string split -r -m1 : -- $cur)[1]
                printf "$v:%s\t%s\n" read 'read only' read,write 'read + write' \
                    read,share 'read + share' read,write,share all
            else
                __opx_list vaults | string match -v -r '^(Personal|Private)\t' | string replace -r '\t.*' ':'
            end
        case keychain agent-vaults categories
            __opx_list $argv[1]
    end
end
