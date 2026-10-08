function __opx_get --description "Read a secret from a 1Password item field"
    argparse --name "opx get" --max-args 1 h/help 'v/vault=' 'f/field=' c/copy 'a/as=' -- $argv; or return 2
    set -q _flag_help; and __opx_usage get; and return 0

    if set -q _flag_as
        set -lx OP_SERVICE_ACCOUNT_TOKEN (security find-generic-password -s $_flag_as -w 2>/dev/null)
        if test -z "$OP_SERVICE_ACCOUNT_TOKEN"
            __opx_err get "no Keychain token '$_flag_as'"
            return 1
        end
    end

    set -l name $argv[1]
    set -l vault (__opx_default_vault)
    set -q _flag_vault; and set vault $_flag_vault
    set -l field "$_flag_field"
    set -l interactive

    if test -z "$name"
        __opx_can_pick; or begin; __opx_usage get --error; return 2; end
        set interactive 1
        # As a service account, the picker lists only what that account can read.
        set -l scope $_flag_vault
        set -l pick (__opx_list items $scope | __opx_pick --hide-key item "pick an item")
        or return 1
        set -l cols (string split \t -- $pick[1])
        set name $cols[1]; set vault $cols[3]
    end

    set -l item (op item get $name --vault $vault --format json | string collect); or return 1
    set -l jq (__opx_jq)

    if test -z "$field"; and test -n "$interactive"
        set -l fields (printf '%s' $item | jq -r "$jq"'readable[] | "\(.label)\t\(.type | ascii_downcase)"')
        if test (count $fields) -gt 1
            set -l pick (printf '%s\n' $fields | __opx_pick field "several concealed fields"); or return 1
            set field (string split \t -- $pick[1])[1]
        end
    end

    set -l value (printf '%s' $item | jq -er --arg f "$field" "$jq"'field($f) | .value // empty' | string collect)
    or begin
        set -l title (printf '%s' $item | jq -r .title)
        __opx_err get "$vault/$title: no "(test -n "$field"; and echo "field '$field'"; or echo "concealed field")" with a value"
        return 1
    end

    if set -q _flag_copy
        printf %s $value | pbcopy
        __opx_err get copied
    else
        printf '%s\n' $value
    end
end
